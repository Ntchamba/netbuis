"""Report : signalement d'une publication, d'un commentaire ou d'un commerce — T090.

Une seule cible par signalement (publication, commentaire OU commerce) et UN SEUL signalement
par compte et par cible (contraintes d'unicité conditionnelles). Motif : liste fermée de 4.
L'auteur du signalement n'est exposé par aucune réponse de l'API.
"""
from django.conf import settings
from django.db import models
from django.db.models import Q

from apps.core.models.base import TimeStampedModel


class ReportReason(models.TextChoices):
    SPAM = "spam", "Spam"
    SCAM = "arnaque", "Arnaque"
    INAPPROPRIATE = "contenu_inapproprie", "Contenu inapproprié"
    OTHER = "autre", "Autre"


class ReportTarget(models.TextChoices):
    POST = "post", "Publication"
    COMMENT = "comment", "Commentaire"
    BUSINESS = "business", "Commerce"


class Report(TimeStampedModel):
    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL, verbose_name="auteur du signalement",
        on_delete=models.CASCADE, related_name="forum_reports",
    )
    target_type = models.CharField("cible", max_length=8, choices=ReportTarget.choices)
    post = models.ForeignKey(
        "forum.Post", null=True, blank=True, on_delete=models.CASCADE, related_name="reports"
    )
    comment = models.ForeignKey(
        "forum.Comment", null=True, blank=True, on_delete=models.CASCADE, related_name="reports"
    )
    business = models.ForeignKey(
        "business.BusinessProfile", null=True, blank=True, on_delete=models.CASCADE,
        related_name="reports",
    )
    reason = models.CharField("motif", max_length=20, choices=ReportReason.choices)

    class Meta:
        verbose_name = "signalement"
        verbose_name_plural = "signalements"
        ordering = ["-created_at", "-id"]
        constraints = [
            models.CheckConstraint(
                name="forum_report_one_target",
                condition=(
                    Q(target_type="post", post__isnull=False, comment__isnull=True,
                      business__isnull=True)
                    | Q(target_type="comment", comment__isnull=False, post__isnull=True,
                        business__isnull=True)
                    | Q(target_type="business", business__isnull=False, post__isnull=True,
                        comment__isnull=True)
                ),
            ),
            models.UniqueConstraint(
                fields=["reporter", "post"], condition=Q(post__isnull=False),
                name="forum_report_unique_post",
            ),
            models.UniqueConstraint(
                fields=["reporter", "comment"], condition=Q(comment__isnull=False),
                name="forum_report_unique_comment",
            ),
            models.UniqueConstraint(
                fields=["reporter", "business"], condition=Q(business__isnull=False),
                name="forum_report_unique_business",
            ),
        ]

    def __str__(self) -> str:
        return f"Signalement {self.pk} ({self.target_type})"
