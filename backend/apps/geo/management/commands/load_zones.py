"""Commande `load_zones` : charge le référentiel des zones depuis un fichier CSV (T020).

Usage : python manage.py load_zones [--file chemin.csv]
Par défaut : apps/geo/data/zones.csv.

Format (UTF-8, une ligne d'en-tête, une ligne par zone) :
    level,name,parent_level,parent_name,order,official_code,latitude,longitude[,is_active]
- level : pays, region, departement, arrondissement, ville_village, quartier ou repere.
- parent_level + parent_name : le parent, désigné par son niveau et son nom (comparé sans
  accents ni majuscules). Vides pour un pays. Le parent doit figurer plus haut dans le
  fichier (ou déjà exister en base) et son niveau doit être admis pour ce niveau.
- order : entier (vide = 0). official_code, latitude, longitude : facultatifs (vides = absents).
- is_active : facultatif, « 0 »/« false »/« non » désactive la zone ; vide = active.

Idempotent : la clé est (niveau, parent, nom normalisé). Relancer ne crée aucun doublon ;
une zone existante est mise à jour (nom, ordre, code, coordonnées, activation) si le
fichier diffère. Tout est annulé si une ligne est refusée (message avec le numéro de ligne).
"""
import csv
from pathlib import Path

from django.core.exceptions import ValidationError
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.core.utils.text_normalize import normalize_text
from apps.geo.models import Zone, ZoneLevel

DEFAULT_FILE = Path(__file__).resolve().parents[2] / "data" / "zones.csv"
REQUIRED_COLUMNS = {
    "level", "name", "parent_level", "parent_name", "order", "official_code", "latitude",
    "longitude",
}
FALSE_VALUES = {"0", "false", "non", "no", "faux"}


class Command(BaseCommand):
    help = "Charge les zones (pays → quartier) depuis un fichier CSV, sans créer de doublon."

    def add_arguments(self, parser):
        parser.add_argument("--file", default=str(DEFAULT_FILE), help="Fichier CSV à charger.")

    def handle(self, *args, **options):
        path = Path(options["file"])
        if not path.is_file():
            raise CommandError(f"Fichier introuvable : {path}")
        counts = {"créées": 0, "mises à jour": 0, "inchangées": 0}
        with path.open(encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            missing = REQUIRED_COLUMNS - set(reader.fieldnames or [])
            if missing:
                raise CommandError(f"Colonnes manquantes : {', '.join(sorted(missing))}")
            with transaction.atomic():
                for row in reader:
                    line = reader.line_num
                    try:
                        counts[self._load_row(row)] += 1
                    except (ValidationError, ValueError) as exc:
                        raise CommandError(f"Ligne {line} : {self._message(exc)}") from exc
        self.stdout.write(
            f"Zones : {counts['créées']} créées, {counts['mises à jour']} mises à jour, "
            f"{counts['inchangées']} inchangées."
        )

    @staticmethod
    def _message(exc) -> str:
        if isinstance(exc, ValidationError):
            return " ; ".join(exc.messages)
        return str(exc)

    @staticmethod
    def _number(value, kind, label):
        value = (value or "").strip()
        if not value:
            return None
        try:
            return kind(value)
        except ValueError:
            raise ValueError(f"{label} « {value} » n'est pas un nombre valide.") from None

    def _find_parent(self, row):
        parent_level = (row["parent_level"] or "").strip()
        parent_name = (row["parent_name"] or "").strip()
        if not parent_level and not parent_name:
            return None
        if parent_level not in ZoneLevel.values:
            raise ValueError(f"niveau de parent inconnu « {parent_level} ».")
        matches = list(
            Zone.objects.filter(level=parent_level, normalized_name=normalize_text(parent_name))[:2]
        )
        if not matches:
            raise ValueError(f"parent introuvable ({parent_level} « {parent_name} »).")
        if len(matches) > 1:
            raise ValueError(f"parent ambigu ({parent_level} « {parent_name} »).")
        return matches[0]

    def _load_row(self, row) -> str:
        level = (row["level"] or "").strip()
        name = (row["name"] or "").strip()
        if level not in ZoneLevel.values:
            raise ValueError(f"niveau inconnu « {level} ».")
        if not name:
            raise ValueError("nom vide.")
        parent = self._find_parent(row)
        values = {
            "name": name,
            "order": self._number(row["order"], int, "ordre") or 0,
            "official_code": (row["official_code"] or "").strip(),
            "latitude": self._number(row["latitude"], float, "latitude"),
            "longitude": self._number(row["longitude"], float, "longitude"),
            "is_active": (row.get("is_active") or "").strip().lower() not in FALSE_VALUES,
        }
        zone = Zone.objects.filter(
            level=level, parent=parent, normalized_name=normalize_text(name)
        ).first()
        if zone is None:
            Zone(level=level, parent=parent, **values).save()
            return "créées"
        if all(getattr(zone, key) == value for key, value in values.items()):
            return "inchangées"
        for key, value in values.items():
            setattr(zone, key, value)
        zone.save()
        return "mises à jour"
