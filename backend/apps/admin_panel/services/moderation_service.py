"""Modération du forum côté administration (T094, zone sensible : droits `peut_moderer_contenu`).

File des signalements : UNE ligne par cible signalée (publication, commentaire ou commerce),
agrégée en SQL puis complétée par quelques requêtes groupées pour la page (jamais une requête
par ligne). Les signalants ne sont jamais lus au-delà de leur nombre ; aucun numéro en clair.

Actions (masquer / restaurer / supprimer) : sur une publication ou un commentaire DÉJÀ signalé
(sinon 404). Une transaction verrouille la cible, change le statut et écrit l'audit
`moderation_contenu` ; le motif est obligatoire pour supprimer (400 reason_required, rien
d'écrit). Transitions : masquer = actif -> masque ; restaurer = masque -> actif (pose
`reports_reset_at` : les anciens signalements ne comptent plus pour le masquage automatique) ;
supprimer = actif ou masque -> supprime. Toute autre transition : 409 invalid_state (on ne
« restaure » jamais une suppression, qui peut venir de l'auteur). Un commerce ne se modère pas
ici (blocage de compte) : 400 unsupported_target.
Dans l'audit, le motif est préfixé par l'opération (« masquer », « restaurer », « supprimer »).
"""
from django.db import transaction
from django.db.models import Count, Max, Min, Q
from django.utils import timezone
from rest_framework import status
from rest_framework.exceptions import NotFound

from apps.business.models import BusinessProfile
from apps.core.exceptions import ApiError
from apps.core.log_filters import mask_personal_data
from apps.forum.models import Comment, ContentStatus, ForbiddenWord, Post, Report, ReportTarget
from apps.forum.models.forbidden_word import WORD_MAX
from apps.forum.services.spam_filter import normalize

from ..models import AuditAction
from .audit_service import ReasonRequired, record_action

PREVIEW_MAX = 140
HIDE, RESTORE, DELETE = "hide", "restore", "delete"
VERBS = {HIDE: "masquer", RESTORE: "restaurer", DELETE: "supprimer"}
_FIELD = {ReportTarget.POST: "post", ReportTarget.COMMENT: "comment",
          ReportTarget.BUSINESS: "business"}
_MODEL = {ReportTarget.POST: Post, ReportTarget.COMMENT: Comment,
          ReportTarget.BUSINESS: BusinessProfile}
STATUS_FILTERS = tuple(ContentStatus.values)
TYPE_FILTERS = tuple(ReportTarget.values)


class InvalidFilter(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid_filter"
    default_detail = "Filtre inconnu."


class InvalidState(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "invalid_state"
    default_detail = "Cette action n'est pas possible dans l'état actuel du contenu."


class UnsupportedTarget(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "unsupported_target"
    default_detail = "Un commerce ne se modère pas ici : utilisez le blocage du compte."


# --- file des signalements ---------------------------------------------------------------


def queue(content_status=None, target_type=None):
    """Une ligne (dict) par cible signalée, la plus récemment signalée d'abord."""
    if content_status not in (None, "") and content_status not in STATUS_FILTERS:
        raise InvalidFilter("Statut inconnu. Valeurs : actif, masque, supprime.")
    if target_type not in (None, "") and target_type not in TYPE_FILTERS:
        raise InvalidFilter("Type inconnu. Valeurs : post, comment, business.")
    reports = Report.objects.all()
    if target_type:
        reports = reports.filter(target_type=target_type)
    if content_status:
        # Pour un commerce, le « statut » est celui de son compte (actif, rejete…).
        reports = reports.filter(
            Q(post__status=content_status) | Q(comment__status=content_status)
            | Q(business__status=content_status)
        )
    return (
        reports.order_by().values("target_type", "post_id", "comment_id", "business_id")
        .annotate(
            reporters_count=Count("reporter", distinct=True),
            first_reported_at=Min("created_at"), last_reported_at=Max("created_at"),
        )
        .order_by("-last_reported_at", "target_type", "post_id", "comment_id", "business_id")
    )


def _target_id(group):
    return group[_FIELD[group["target_type"]] + "_id"]


def _short(text: str) -> str:
    """Aperçu : tout numéro, code ou jeton écrit dans le contenu est masqué avant de tronquer."""
    text = mask_personal_data(text or "")
    return text if len(text) <= PREVIEW_MAX else text[:PREVIEW_MAX].rstrip() + "…"


def build_rows(groups) -> list[dict]:
    """Complète les groupes d'une page : 4 requêtes au plus, quel que soit leur nombre."""
    groups = list(groups)
    ids = {kind: [_target_id(g) for g in groups if g["target_type"] == kind] for kind in _FIELD}
    reasons = {}
    if groups:
        flt = Q()
        for kind, field in _FIELD.items():
            if ids[kind]:
                flt |= Q(**{f"{field}_id__in": ids[kind]})
        for item in (
            Report.objects.filter(flt).order_by()
            .values("target_type", "post_id", "comment_id", "business_id", "reason")
            .annotate(n=Count("id")).order_by("reason")
        ):
            reasons.setdefault((item["target_type"], _target_id(item)), []).append(
                {"reason": item["reason"], "count": item["n"]})
    posts = {p.pk: p for p in Post.objects.filter(pk__in=ids["post"]).select_related(
        "profile", "profile__owner")} if ids["post"] else {}
    comments = {c.pk: c for c in Comment.objects.filter(pk__in=ids["comment"]).select_related(
        "author", "post__profile")} if ids["comment"] else {}
    businesses = {b.pk: b for b in BusinessProfile.objects.filter(
        pk__in=ids["business"]).select_related("owner")} if ids["business"] else {}
    rows = []
    for g in groups:
        kind, pk = g["target_type"], _target_id(g)
        base = {
            "target_type": kind, "target_id": pk, "reasons": reasons.get((kind, pk), []),
            "reporters_count": g["reporters_count"],
            "first_reported_at": g["first_reported_at"],
            "last_reported_at": g["last_reported_at"],
            "media_type": None, "post_id": None,
        }
        if kind == ReportTarget.POST and pk in posts:
            p = posts[pk]
            base.update(
                content_status=p.status, preview=_short(p.caption), media_type=p.media_type,
                author=p.profile.owner, business_id=p.profile_id, business_name=p.profile.name,
                author_name=p.profile.name)
        elif kind == ReportTarget.COMMENT and pk in comments:
            c = comments[pk]
            base.update(
                content_status=c.status, preview=_short(c.text), post_id=c.post_id,
                author=c.author, business_id=c.post.profile_id,
                business_name=c.post.profile.name, author_name=c.author.name)
        elif kind == ReportTarget.BUSINESS and pk in businesses:
            b = businesses[pk]
            base.update(
                content_status=b.status, preview=_short(b.name), author=b.owner,
                business_id=b.pk, business_name=b.name, author_name=b.owner.name)
        else:
            continue
        rows.append(base)
    return rows


def row_for(target_type, target_id) -> dict:
    groups = queue(target_type=target_type).filter(
        **{_FIELD[target_type] + "_id": target_id})
    rows = build_rows(groups)
    if not rows:
        raise NotFound()
    return rows[0]


# --- actions -----------------------------------------------------------------------------


def moderate(admin, action, target_type, target_id, reason="") -> dict:
    if target_type == ReportTarget.BUSINESS:
        raise UnsupportedTarget()
    if target_type not in (ReportTarget.POST, ReportTarget.COMMENT):
        raise NotFound()
    field, model = _FIELD[target_type], _MODEL[target_type]
    reason = reason.strip() if isinstance(reason, str) else ""
    with transaction.atomic():
        obj = model.objects.select_for_update().filter(pk=target_id).first()
        if obj is None or not Report.objects.filter(**{field: obj}).exists():
            raise NotFound()
        if action == DELETE and not reason:
            raise ReasonRequired()
        current = obj.status
        allowed = {
            HIDE: {ContentStatus.ACTIVE}, RESTORE: {ContentStatus.HIDDEN},
            DELETE: {ContentStatus.ACTIVE, ContentStatus.HIDDEN},
        }[action]
        if current not in allowed:
            raise InvalidState()
        values = {"updated_at": timezone.now()}
        if action == HIDE:
            values["status"] = ContentStatus.HIDDEN
        elif action == RESTORE:
            values.update(status=ContentStatus.ACTIVE, reports_reset_at=timezone.now())
        else:
            values["status"] = ContentStatus.DELETED
        model.objects.filter(pk=obj.pk).update(**values)
        verb = VERBS[action]
        record_action(admin, AuditAction.MODERATION_CONTENU, obj,
                      f"{verb} : {reason}" if reason else verb)
    return row_for(target_type, target_id)


# --- mots interdits ----------------------------------------------------------------------


class InvalidWord(ApiError):
    status_code = status.HTTP_400_BAD_REQUEST
    default_code = "invalid"
    default_detail = "Mot interdit invalide."


class WordExists(ApiError):
    status_code = status.HTTP_409_CONFLICT
    default_code = "word_exists"
    default_detail = "Ce mot est déjà dans la liste."


def add_word(admin, raw: str) -> ForbiddenWord:
    word = normalize(raw)
    if len(word) < 2 or len(word) > WORD_MAX:
        raise InvalidWord(f"Le mot doit faire de 2 à {WORD_MAX} caractères (lettres ou chiffres).")
    with transaction.atomic():
        obj, created = ForbiddenWord.objects.get_or_create(word=word)
        if not created:
            raise WordExists()
        record_action(admin, AuditAction.MODERATION_CONTENU, obj, "mot interdit ajouté")
    return obj


def remove_word(admin, pk: int) -> None:
    with transaction.atomic():
        obj = ForbiddenWord.objects.select_for_update().filter(pk=pk).first()
        if obj is None:
            raise NotFound()
        record_action(admin, AuditAction.MODERATION_CONTENU, obj, "mot interdit retiré")
        obj.delete()
