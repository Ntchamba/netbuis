"""SearchLog : une ligne par recherche non vide (T040).

On garde le terme NORMALISÉ (pas le texte brut), la zone, le nombre de résultats et un HACHAGE
du compte qui cherche (de quoi compter des comptes distincts, T104, sans jamais stocker le compte
ni son numéro). Aucun numéro de téléphone dans ce journal.
"""
from django.db import models


class SearchMode(models.TextChoices):
    TEXT = "text", "Écrite"
    VOICE = "voice", "Vocale"


class SearchLog(models.Model):
    term = models.CharField("terme normalisé", max_length=100)
    mode = models.CharField("mode", max_length=5, choices=SearchMode.choices,
                            default=SearchMode.TEXT)
    zone = models.ForeignKey(
        "geo.Zone", verbose_name="zone", null=True, blank=True, on_delete=models.SET_NULL,
        related_name="+",
    )
    results_count = models.PositiveIntegerField("nombre de résultats", default=0)
    account_hash = models.CharField(
        "compte (haché)", max_length=64, blank=True, default="",
        help_text="HMAC du compte : jamais le compte ni le numéro. Vide si recherche anonyme.",
    )
    created_at = models.DateTimeField("date", auto_now_add=True)

    class Meta:
        verbose_name = "recherche"
        verbose_name_plural = "recherches"
        ordering = ["-created_at", "-id"]
        indexes = [
            models.Index(fields=["created_at"], name="search_log_created_idx"),
            models.Index(fields=["term", "created_at"], name="search_log_term_created_idx"),
            models.Index(fields=["account_hash"], name="search_log_account_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.term} ({self.results_count})"
