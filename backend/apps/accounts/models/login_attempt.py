"""AdminLoginAttempt : essais ratés de connexion administrateur, par IP (T007).

En base (et non dans le cache LocMem, propre à chaque processus) : la limite tient
avec plusieurs workers. La ligne est verrouillée pour réserver un essai.
"""
from django.db import models


class AdminLoginAttempt(models.Model):
    ip = models.CharField("adresse IP", max_length=255, unique=True)
    # Essais ratés + essais en cours d'évaluation, dans la fenêtre courante.
    failures = models.PositiveSmallIntegerField("essais ratés", default=0)
    window_end = models.DateTimeField("fin de la fenêtre")

    class Meta:
        verbose_name = "essais de connexion administrateur"

    def __str__(self):
        return f"Essais de connexion {self.pk}"
