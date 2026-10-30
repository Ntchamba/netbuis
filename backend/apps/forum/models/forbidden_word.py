"""Mot interdit du forum (T094) : configuré par un Administrateur complet.

Le mot est stocké NORMALISÉ (minuscules, sans accents, espaces simples) : voir
`services.spam_filter.normalize`. Une publication ou un commentaire qui le contient
(comme mot entier ou suite de mots entiers) est refusé (400 `spam_detected`).
Un petit modèle plutôt qu'un PlatformSetting : la liste des clés de réglage est figée par un test.
"""
from django.db import models

from apps.core.models.base import TimeStampedModel

WORD_MAX = 60


class ForbiddenWord(TimeStampedModel):
    word = models.CharField("mot interdit (normalisé)", max_length=WORD_MAX, unique=True)

    class Meta:
        verbose_name = "mot interdit"
        verbose_name_plural = "mots interdits"
        ordering = ["word"]

    def __str__(self) -> str:
        return self.word
