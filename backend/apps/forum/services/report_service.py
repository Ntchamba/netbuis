"""Signalements (T090) : un par compte et par cible, motif parmi 4.

La cible doit être visible pour l'auteur (sinon 404, on ne confirme pas son existence).
Un contenu déjà signalé par l'auteur reste retrouvable ici pour répondre 409 (et non 404) au
second signalement. Son propre contenu ne se signale pas.
"""
from django.db import IntegrityError, transaction
from rest_framework.exceptions import NotFound

from apps.business.models import BusinessProfile
from apps.forum.models import Comment, Post, Report, ReportTarget
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
            return Report.objects.create(
                reporter=user, target_type=target_type, reason=reason, **{field: obj}
            )
    except IntegrityError:  # deux requêtes simultanées : la contrainte d'unicité tranche
        raise AlreadyReported() from None
