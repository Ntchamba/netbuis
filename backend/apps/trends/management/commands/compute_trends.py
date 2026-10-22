"""Commande `compute_trends` : recalcule les tendances par ville (T104).

À planifier une fois par jour (cron, ou tâche planifiée du serveur) :
    python manage.py compute_trends
Idempotente : relancer le même jour remplace les instantanés du jour.
"""
from django.core.management.base import BaseCommand

from apps.trends.services.compute_trends import compute_trends


class Command(BaseCommand):
    help = "Calcule les produits les plus recherchés et les commerces les plus contactés (7 jours)."

    def handle(self, *args, **options):
        result = compute_trends()
        self.stdout.write(
            f"Tendances calculées : {result['cities']} ville(s), {result['entries']} ligne(s).")
