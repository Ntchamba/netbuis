"""Commande `seed_referentials` : jeu de départ des référentiels (T021).

Usage : python manage.py seed_referentials

Charge :
- data/categories.json : les 10 secteurs (avec icône) et leurs sous-catégories, les 7 catégories
  de service, les 5 types de structure (avec icône), exactement ceux de
  docs/spec/MODELE_DONNEES.md ;
- data/products.csv  (colonnes : name,sector_code,subcategory_code) : produits du catalogue ;
- data/synonyms.csv  (colonnes : term,product_name) : synonymes (le produit doit exister).
Les deux CSV sont vides tant que Jeff n'a pas fourni les listes : rien n'est inventé.

Idempotent : chaque ligne est retrouvée par son code stable (produit : nom normalisé ; synonyme :
produit + terme normalisé). Relancer ne crée aucun doublon et N'ÉCRASE PAS ce qui a été modifié dans
l'admin (nom, icône, ordre, activation) : une ligne existante est laissée telle quelle.
Tout est annulé si une ligne du fichier est refusée (message avec le numéro de ligne).
"""
import csv
import json
from pathlib import Path

from django.core.exceptions import ValidationError
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from apps.catalog.models import (
    CatalogProduct,
    Sector,
    ServiceCategory,
    StructureType,
    Subcategory,
    Synonym,
)
from apps.core.utils.text_normalize import normalize_text

DATA_DIR = Path(__file__).resolve().parents[2] / "data"
PRODUCT_COLUMNS = {"name", "sector_code", "subcategory_code"}
SYNONYM_COLUMNS = {"term", "product_name"}


class Counter:
    def __init__(self):
        self.created = 0
        self.existing = 0

    def add(self, created: bool):
        if created:
            self.created += 1
        else:
            self.existing += 1

    def __str__(self):
        return f"{self.created} créés, {self.existing} déjà présents"


def _defaults(entry: dict) -> dict:
    return {
        "name": entry["name"],
        "icon": entry.get("icon", ""),
        "order": entry.get("order", 0),
    }


class Command(BaseCommand):
    help = (
        "Crée les secteurs, sous-catégories, catégories de service, types de structure "
        "(et le catalogue fourni), sans doublon."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--data-dir", default=str(DATA_DIR), help="Dossier des fichiers de données."
        )

    def handle(self, *args, **options):
        data_dir = Path(options["data_dir"])
        referentials = data_dir / "categories.json"
        if not referentials.is_file():
            raise CommandError(f"Fichier introuvable : {referentials}")
        try:
            data = json.loads(referentials.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise CommandError(f"{referentials.name} : JSON invalide ({exc}).") from exc
        counters = {
            label: Counter()
            for label in (
                "Secteurs", "Sous-catégories", "Catégories de service", "Types de structure",
                "Produits", "Synonymes",
            )
        }
        with transaction.atomic():
            self._load_referentials(data, counters)
            self._load_products(data_dir / "products.csv", counters)
            self._load_synonyms(data_dir / "synonyms.csv", counters)
        for label, counter in counters.items():
            self.stdout.write(f"{label} : {counter}.")

    def _load_referentials(self, data, counters):
        try:
            for sector_entry in data.get("sectors", []):
                sector, created = Sector.objects.get_or_create(
                    code=sector_entry["code"], defaults=_defaults(sector_entry)
                )
                counters["Secteurs"].add(created)
                for sub in sector_entry.get("subcategories", []):
                    _, created = Subcategory.objects.get_or_create(
                        sector=sector, code=sub["code"], defaults=_defaults(sub)
                    )
                    counters["Sous-catégories"].add(created)
            for key, model, label in (
                ("service_categories", ServiceCategory, "Catégories de service"),
                ("structure_types", StructureType, "Types de structure"),
            ):
                for entry in data.get(key, []):
                    _, created = model.objects.get_or_create(
                        code=entry["code"], defaults=_defaults(entry)
                    )
                    counters[label].add(created)
        except KeyError as exc:
            raise CommandError(f"categories.json : clé manquante {exc}.") from exc

    @staticmethod
    def _rows(path: Path, required: set[str]):
        """Lignes d'un CSV (UTF-8) ; fichier vide ou absent = aucune ligne."""
        if not path.is_file() or not path.read_text(encoding="utf-8-sig").strip():
            return
        with path.open(encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            missing = required - set(reader.fieldnames or [])
            if missing:
                names = ", ".join(sorted(missing))
                raise CommandError(f"{path.name} : colonnes manquantes : {names}")
            for row in reader:
                if any((value or "").strip() for value in row.values()):
                    yield reader.line_num, {k: (v or "").strip() for k, v in row.items() if k}

    def _load_products(self, path, counters):
        for line, row in self._rows(path, PRODUCT_COLUMNS):
            try:
                subcategory = None
                if row["subcategory_code"]:
                    subcategory = Subcategory.objects.filter(
                        sector__code=row["sector_code"], code=row["subcategory_code"]
                    ).first()
                    if subcategory is None:
                        raise ValueError(
                            f"sous-catégorie introuvable ({row['sector_code']} / "
                            f"{row['subcategory_code']})."
                        )
                if not row["name"]:
                    raise ValueError("nom vide.")
                product = CatalogProduct.objects.filter(
                    normalized_name=normalize_text(row["name"])
                ).first()
                if product is None:
                    CatalogProduct(name=row["name"], category=subcategory).save()
                counters["Produits"].add(product is None)
            except (ValidationError, ValueError) as exc:
                raise CommandError(f"{path.name} ligne {line} : {self._message(exc)}") from exc

    def _load_synonyms(self, path, counters):
        for line, row in self._rows(path, SYNONYM_COLUMNS):
            try:
                product = CatalogProduct.objects.filter(
                    normalized_name=normalize_text(row["product_name"])
                ).first()
                if product is None:
                    raise ValueError(f"produit introuvable « {row['product_name']} ».")
                if not normalize_text(row["term"]):
                    raise ValueError("synonyme vide.")
                exists = Synonym.objects.filter(
                    product=product, normalized_term=normalize_text(row["term"])
                ).exists()
                if not exists:
                    Synonym(product=product, term=row["term"]).save()
                counters["Synonymes"].add(not exists)
            except (ValidationError, ValueError) as exc:
                raise CommandError(f"{path.name} ligne {line} : {self._message(exc)}") from exc

    @staticmethod
    def _message(exc) -> str:
        if isinstance(exc, ValidationError):
            return " ; ".join(exc.messages)
        return str(exc)
