"""Commande `seed_demo` : commerces FICTIFS de Maroua pour la démonstration et les mesures (T028).

Usage : python manage.py seed_demo [--count N] [--flush]

- `--count N` : N commerces (1 à 5 000, défaut 20) ; relançable, sans doublon, sans écraser ce
  qui a été modifié dans l'admin ; `--count 30` après `--count 20` ajoute seulement les 10 de plus.
- `--flush` : supprime UNIQUEMENT les données de démonstration (nom « [DÉMO] … » ET propriétaire
  au téléphone réservé aux données fictives), jamais un vrai compte.
- Refusée si DEBUG=False. Exige les zones et les référentiels (`load_zones`, `seed_referentials`).
Les règles et la structure sont dans apps/business/services/demo_data.py ; les publications
et commentaires (T090) dans apps/forum/services/demo_data.py.
"""
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from apps.business.services import demo_data
from apps.forum.services import demo_data as demo_forum


class Command(BaseCommand):
    help = "Crée (ou supprime avec --flush) des commerces fictifs « [DÉMO] » à Maroua."

    def add_arguments(self, parser):
        parser.add_argument(
            "--count", type=int, default=demo_data.DEFAULT_COUNT,
            help=f"Nombre de commerces (1 à {demo_data.MAX_COUNT}, défaut "
                 f"{demo_data.DEFAULT_COUNT}).",
        )
        parser.add_argument(
            "--flush", action="store_true",
            help="Supprime uniquement les données de démonstration.",
        )

    def handle(self, *args, **options):
        if not settings.DEBUG:
            raise CommandError("seed_demo est désactivée quand DEBUG=False : rien n'a été fait.")
        count = options["count"]
        if not 1 <= count <= demo_data.MAX_COUNT:
            raise CommandError(f"--count doit être compris entre 1 et {demo_data.MAX_COUNT}.")
        if options["flush"]:
            profiles, owners = demo_data.flush()
            self.stdout.write(
                f"Données de démonstration supprimées : {profiles} commerces, {owners} comptes."
            )
            return
        try:
            created, existing = demo_data.seed(count)
        except demo_data.MissingReferentials as exc:
            raise CommandError(str(exc)) from exc
        self.stdout.write(
            f"Commerces de démonstration : {created} créés, {existing} déjà présents."
        )
        posts, comments = demo_forum.seed(count)  # publications et commentaires (T090)
        self.stdout.write(
            f"Forum de démonstration : {posts} publications et {comments} commentaires créés."
        )
