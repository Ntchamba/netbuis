"""Ferme les sonneries dépassées (`missed`) et les appels « en cours » trop vieux (`ended`).

À planifier toutes les minutes (voir docs/deployment/) ; `--loop N` boucle toutes les N
secondes pour un processus dédié. Sûr à lancer en plusieurs exemplaires.
"""
import time

from django.core.management.base import BaseCommand

from apps.calls.services.session_service import expire_stale


class Command(BaseCommand):
    help = "Ferme les sonneries expirées et les appels trop vieux."

    def add_arguments(self, parser):
        parser.add_argument(
            "--loop", type=int, default=0, metavar="SECONDES",
            help="Reste actif et recommence toutes les SECONDES (0 = une seule passe).",
        )

    def handle(self, *args, **options):
        while True:
            closed = expire_stale()
            self.stdout.write(f"{closed} session(s) close(s).")
            if options["loop"] <= 0:
                return
            time.sleep(options["loop"])
