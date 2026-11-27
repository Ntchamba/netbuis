"""Commande `expire_subscriptions` : passe les abonnements échus en « expiré » (T110).

À planifier (cron ou tâche planifiée du serveur), par exemple toutes les heures :
    python manage.py expire_subscriptions
Idempotente ; ne supprime rien.
"""
from django.core.management.base import BaseCommand

from apps.business.services.subscription_expiry import expire_due_subscriptions


class Command(BaseCommand):
    help = "Passe en « expiré » les abonnements actifs dont la fin est atteinte."

    def handle(self, *args, **options):
        self.stdout.write(f"Abonnements passés en expiré : {expire_due_subscriptions()}.")
