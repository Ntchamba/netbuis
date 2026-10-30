"""Signalements (T090) : un par compte et par cible, motif parmi 4.

La cible doit être visible pour l'auteur (sinon 404, on ne confirme pas son existence).
Un contenu déjà signalé par l'auteur reste retrouvable ici pour répondre 409 (et non 404) au
second signalement. Son propre contenu ne se signale pas.

Masquage automatique (T094) : quand une publication ou un commentaire ACTIF atteint
`AUTO_HIDE_THRESHOLD` (3) signalants DISTINCTS, il passe à `masque` en attente de revue.
- Comptent : les signalements de comptes utilisables (actifs, ni bloqués ni supprimés) ; un
  compte bloqué ou supprimé ne peut pas, à lui seul, faire masquer le contenu d'un autre.
- Seuls comptent les signalements POSTÉRIEURS à `reports_reset_at` (posé quand un admin
  restaure) : après restauration, le contenu ne se remasque que par 3 NOUVEAUX signalants.
- Un commerce signalé n'est jamais masqué automatiquement : il reste dans la file admin.
- La ligne de la cible est verrouillée : deux 3e signalements simultanés ne s'ignorent pas.
"""
from django.db import IntegrityError, transaction
from django.utils import timezone
from rest_framework.exceptions import NotFound

from apps.business.models import BusinessProfile
from apps.forum.models import Comment, ContentStatus, Post, Report, ReportTarget
from apps.forum.services.errors import AlreadyReported, OwnContent


def _target(user, target_type, target_id):
    """Retourne (champ du Report, objet, auteur du contenu)."""
    if target_type == ReportTarget.POST:
        obj = (
            Post.objects.filter(pk=target_id, status="actif")
            .filter(profile__in=BusinessProfile.objects.visible().values("pk"))
            .select_related("profile").first()
        )
        return "post", obj, obj and obj.profile.owner_id
    if target_type == ReportTarget.COMMENT:
        obj = (
            Comment.objects.filter(
                pk=target_id, status="actif", author__is_blocked=False,
                author__is_deleted=False, author__is_active=True,
                post__status="actif",
                post__profile__in=BusinessProfile.objects.visible().values("pk"),
            ).first()
        )
        return "comment", obj, obj and obj.author_id
    obj = BusinessProfile.objects.visible().filter(pk=target_id).first()
    return "business", obj, obj and obj.owner_id


AUTO_HIDE_THRESHOLD = 3  # signalants distincts


def distinct_valid_reporters(field, obj) -> int:
    """Signalants distincts et utilisables de `obj`, depuis sa dernière restauration."""
    reports = Report.objects.filter(
        **{field: obj}, reporter__is_active=True, reporter__is_blocked=False,
        reporter__is_deleted=False,
    )
    if obj.reports_reset_at is not None:
        reports = reports.filter(created_at__gt=obj.reports_reset_at)
    return reports.values("reporter").distinct().count()


def _auto_hide_if_needed(field, obj) -> None:
    """Appelé dans la transaction, `obj` verrouillé : masque à partir du seuil."""
    if obj.status == ContentStatus.ACTIVE and distinct_valid_reporters(field, obj) >= (
        AUTO_HIDE_THRESHOLD
    ):
        type(obj).objects.filter(pk=obj.pk).update(
            status=ContentStatus.HIDDEN, updated_at=timezone.now()
        )


def create_report(user, target_type, target_id, reason) -> Report:
    field, obj, owner_id = _target(user, target_type, target_id)
    if obj is None:
        raise NotFound()
    if owner_id == user.pk:
        raise OwnContent()
    if Report.objects.filter(reporter=user, **{field: obj}).exists():
        raise AlreadyReported()
    try:
        with transaction.atomic():
            if field in ("post", "comment"):  # serialise les signalements de la même cible
                locked = type(obj).objects.select_for_update().filter(pk=obj.pk).first()
                if locked is None or locked.status != ContentStatus.ACTIVE:
                    raise NotFound()
                obj = locked
            report = Report.objects.create(
                reporter=user, target_type=target_type, reason=reason, **{field: obj}
            )
            if field in ("post", "comment"):
                _auto_hide_if_needed(field, obj)
            return report
    except IntegrityError:  # deux requêtes simultanées : la contrainte d'unicité tranche
        raise AlreadyReported() from None
