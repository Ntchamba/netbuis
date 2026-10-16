"""OtpCode : un code SMS envoyé à un numéro. Le code n'est jamais stocké en clair."""
from django.db import models


class OtpCode(models.Model):
    phone = models.CharField("téléphone", max_length=16)  # E.164
    code_hash = models.CharField("code haché", max_length=128)  # HMAC-SHA256 en hexadécimal
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField("expire le")
    attempts = models.PositiveSmallIntegerField("essais ratés", default=0)
    used_at = models.DateTimeField("utilisé le", null=True, blank=True)
    # Rempli au 5e essai raté : le numéro ne peut plus ni demander ni vérifier de code avant.
    blocked_until = models.DateTimeField("numéro bloqué jusqu'au", null=True, blank=True)

    class Meta:
        verbose_name = "code SMS"
        indexes = [models.Index(fields=["phone", "-created_at"])]

    def __str__(self):
        return f"Code SMS {self.pk}"
