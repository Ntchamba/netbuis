"""Limites anti-spam du forum (T090).

Ce sont des CONSTANTES (pas des PlatformSetting : la liste des clés de réglage est figée par
un test de core). Le plafond de « 5 publications ACTIVES sans abonnement » est une autre règle
(PlatformSetting `plafond_publications_non_abonne`, voir post_service).
"""
from datetime import timedelta

COMMENT_LIMIT = 10  # commentaires par compte...
COMMENT_WINDOW = timedelta(minutes=10)  # ...sur 10 minutes glissantes
POST_DAILY_LIMIT = 5  # publications par commerce...
POST_WINDOW = timedelta(hours=24)  # ...sur 24 heures glissantes (supprimées comprises)
