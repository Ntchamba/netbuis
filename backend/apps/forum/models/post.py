"""Post (publication d'un commerce) et Comment (commentaire de n'importe quel compte) — T090.

- `Post.media` : clé de stockage (kind `post_image` ou `post_video`) de l'auteur ; `media_type`
  en est déduit par le serveur. Légende ≤ 500 caractères, texte stocké TEL QUEL (jamais
  interprété : pas de HTML).
- `Post.offer` : produit associé facultatif, une Offer du MÊME profil.
- Statuts : `actif` (visible), `masque` (modération), `supprime` (suppression douce par l'auteur).
- `visible_for(user)` est l'UNIQUE définition de « ce que cet utilisateur voit » : contenu actif,
  profil `visible()` (donc compte ni bloqué ni supprimé), et rien de ce que l'utilisateur a lui-même
  signalé (la publication, son commerce, ou le commentaire).
"""
from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.db.models import Exists, OuterRef

from apps.core.models.base import TimeStampedModel

CAPTION_MAX = 500
COMMENT_MAX = 300


class MediaType(models.TextChoices):
    IMAGE = "image", "Image"
    VIDEO = "video", "Vidéo"


class ContentStatus(models.TextChoices):
    ACTIVE = "actif", "Actif"
    HIDDEN = "masque", "Masqué"
    DELETED = "supprime", "Supprimé"


def _reports():
    from apps.forum.models.report import Report

    return Report.objects


class PostQuerySet(models.QuerySet):
    def visible_for(self, user):
        """Publications que `user` peut voir (voir l'en-tête du module)."""
        from apps.business.models import BusinessProfile

        return (
            self.filter(
                status=ContentStatus.ACTIVE,
                profile__in=BusinessProfile.objects.visible().values("pk"),
            )
            .exclude(Exists(_reports().filter(reporter=user, post=OuterRef("pk"))))
            .exclude(Exists(_reports().filter(reporter=user, business=OuterRef("profile_id"))))
        )


class Post(TimeStampedModel):
    profile = models.ForeignKey(
        "business.BusinessProfile", verbose_name="compte business", on_delete=models.CASCADE,
        related_name="posts",
    )
    media_type = models.CharField("type de média", max_length=5, choices=MediaType.choices)
    media = models.CharField("média (clé de stockage)", max_length=255)
    caption = models.CharField("légende", max_length=CAPTION_MAX, blank=True, default="")
    offer = models.ForeignKey(
        "business.Offer", verbose_name="produit associé", null=True, blank=True,
        on_delete=models.SET_NULL, related_name="posts",
    )
    status = models.CharField(
        "statut", max_length=8, choices=ContentStatus.choices, default=ContentStatus.ACTIVE
    )
    reports_reset_at = models.DateTimeField(
        "signalements comptés depuis", null=True, blank=True,
        help_text="Posé à la restauration : seuls les signalements POSTÉRIEURS comptent pour "
                  "le masquage automatique.",
    )

    objects = PostQuerySet.as_manager()

    class Meta:
        verbose_name = "publication"
        verbose_name_plural = "publications"
        ordering = ["-created_at", "-id"]
        indexes = [
            models.Index(fields=["status", "-created_at"], name="forum_post_status_created"),
            models.Index(fields=["profile", "status"], name="forum_post_profile_status"),
        ]

    def __str__(self) -> str:
        return f"Publication {self.pk} de {self.profile_id}"

    def clean(self):
        errors = {}
        if len(self.caption or "") > CAPTION_MAX:
            errors["caption"] = f"{CAPTION_MAX} caractères au maximum."
        if not self.media:
            errors["media"] = "Le média est obligatoire."
        if self.offer_id and self.offer.profile_id != self.profile_id:
            errors["offer"] = "Le produit doit appartenir au même commerce."
        if errors:
            raise ValidationError(errors)

    def save(self, *args, **kwargs):
        self.clean()
        super().save(*args, **kwargs)


class CommentQuerySet(models.QuerySet):
    def visible_for(self, user):
        """Commentaires que `user` peut voir : actifs, auteur utilisable (ni bloqué, ni supprimé),
        publication visible, et pas signalés par `user` lui-même."""
        return (
            self.filter(
                status=ContentStatus.ACTIVE,
                author__is_active=True, author__is_blocked=False, author__is_deleted=False,
                post__in=Post.objects.visible_for(user).values("pk"),
            )
            .exclude(Exists(_reports().filter(reporter=user, comment=OuterRef("pk"))))
        )


class Comment(TimeStampedModel):
    post = models.ForeignKey(
        Post, verbose_name="publication", on_delete=models.CASCADE, related_name="comments"
    )
    author = models.ForeignKey(
        settings.AUTH_USER_MODEL, verbose_name="auteur", on_delete=models.CASCADE,
        related_name="forum_comments",
    )
    text = models.CharField("texte", max_length=COMMENT_MAX)
    status = models.CharField(
        "statut", max_length=8, choices=ContentStatus.choices, default=ContentStatus.ACTIVE
    )
    reports_reset_at = models.DateTimeField(
        "signalements comptés depuis", null=True, blank=True,
        help_text="Posé à la restauration : seuls les signalements POSTÉRIEURS comptent pour "
                  "le masquage automatique.",
    )

    objects = CommentQuerySet.as_manager()

    class Meta:
        verbose_name = "commentaire"
        verbose_name_plural = "commentaires"
        ordering = ["created_at", "id"]
        indexes = [
            models.Index(fields=["post", "status", "created_at"], name="forum_comment_post_st_cr"),
            models.Index(fields=["author", "created_at"], name="forum_comment_author_cr"),
        ]

    def __str__(self) -> str:
        return f"Commentaire {self.pk}"

    def clean(self):
        text = (self.text or "").strip()
        if not text:
            raise ValidationError({"text": "Le commentaire est vide."})
        if len(self.text) > COMMENT_MAX:
            raise ValidationError({"text": f"{COMMENT_MAX} caractères au maximum."})

    def save(self, *args, **kwargs):
        self.clean()
        super().save(*args, **kwargs)
