"""Zone : un seul modèle hiérarchique Pays → Région → Département → Arrondissement →
Ville/village → Quartier → Repère (T020, docs/spec/MODELE_DONNEES.md § Zone).

Le référentiel est modifiable depuis l'admin Django : rien n'est figé dans le code.
Au-dessous de l'arrondissement, les listes ne sont pas officielles (NetBuis les construit).
"""
from django.core.exceptions import ValidationError
from django.db import models

from apps.core.models.base import TimeStampedModel
from apps.core.utils.text_normalize import normalize_text


class ZoneLevel(models.TextChoices):
    PAYS = "pays", "Pays"
    REGION = "region", "Région"
    DEPARTEMENT = "departement", "Département"
    ARRONDISSEMENT = "arrondissement", "Arrondissement"
    VILLE_VILLAGE = "ville_village", "Ville / village"
    QUARTIER = "quartier", "Quartier"
    REPERE = "repere", "Repère"


# Du plus haut (0) au plus bas : le parent doit avoir un rang strictement plus petit.
LEVEL_ORDER = [level.value for level in ZoneLevel]
LEVEL_RANK = {level: rank for rank, level in enumerate(LEVEL_ORDER)}

# Niveaux de parent acceptés pour chaque niveau. Une ville/village peut se rattacher à un
# arrondissement OU directement à un département (Maroua s'étend sur 3 arrondissements).
ALLOWED_PARENT_LEVELS = {
    ZoneLevel.PAYS: (),
    ZoneLevel.REGION: (ZoneLevel.PAYS,),
    ZoneLevel.DEPARTEMENT: (ZoneLevel.REGION,),
    ZoneLevel.ARRONDISSEMENT: (ZoneLevel.DEPARTEMENT,),
    ZoneLevel.VILLE_VILLAGE: (ZoneLevel.ARRONDISSEMENT, ZoneLevel.DEPARTEMENT),
    ZoneLevel.QUARTIER: (ZoneLevel.VILLE_VILLAGE,),
    ZoneLevel.REPERE: (ZoneLevel.QUARTIER, ZoneLevel.VILLE_VILLAGE),
}


class Zone(TimeStampedModel):
    name = models.CharField("nom", max_length=150)
    normalized_name = models.CharField(
        "nom normalisé", max_length=150, editable=False, db_index=True,
        help_text="Minuscules, sans accents (calculé à l'enregistrement).",
    )
    level = models.CharField("niveau", max_length=20, choices=ZoneLevel.choices)
    parent = models.ForeignKey(
        "self", verbose_name="parent", null=True, blank=True,
        on_delete=models.PROTECT, related_name="children",
    )
    official_code = models.CharField("code officiel", max_length=30, blank=True, default="")
    is_active = models.BooleanField("active", default=True)
    order = models.PositiveIntegerField("ordre", default=0)
    latitude = models.FloatField("latitude", null=True, blank=True)
    longitude = models.FloatField("longitude", null=True, blank=True)

    class Meta:
        verbose_name = "zone"
        verbose_name_plural = "zones"
        ordering = ["order", "normalized_name", "id"]
        constraints = [
            models.UniqueConstraint(
                fields=["level", "parent", "normalized_name"], name="geo_zone_unique_in_parent"
            ),
            # PostgreSQL traite les NULL comme distincts : le cas « sans parent » (pays)
            # a donc sa propre contrainte.
            models.UniqueConstraint(
                fields=["level", "normalized_name"],
                condition=models.Q(parent__isnull=True),
                name="geo_zone_unique_root",
            ),
        ]
        indexes = [
            models.Index(fields=["parent", "level"], name="geo_zone_parent_level_idx"),
            models.Index(fields=["level", "is_active"], name="geo_zone_level_active_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.name} ({self.get_level_display()})"

    def clean(self):
        """Vérifie le parent (niveau strictement supérieur), les cycles et les coordonnées."""
        errors = {}
        self.normalized_name = normalize_text(self.name)
        if not self.normalized_name:
            errors["name"] = "Le nom est obligatoire."
        if self.level not in LEVEL_RANK:
            errors["level"] = "Niveau inconnu."
        else:
            errors.update(self._parent_errors())
        for field, limit in (("latitude", 90), ("longitude", 180)):
            value = getattr(self, field)
            if value is not None and not -limit <= value <= limit:
                errors[field] = f"Doit être comprise entre -{limit} et {limit}."
        if not errors and self._is_duplicate():
            errors["name"] = "Une zone de ce nom existe déjà au même endroit."
        if errors:
            raise ValidationError(errors)

    def _is_duplicate(self) -> bool:
        others = Zone.objects.filter(
            level=self.level, parent_id=self.parent_id, normalized_name=self.normalized_name
        )
        if self.pk is not None:
            others = others.exclude(pk=self.pk)
        return others.exists()

    def _parent_errors(self) -> dict:
        allowed = ALLOWED_PARENT_LEVELS[ZoneLevel(self.level)]
        if self.parent_id is None:
            if allowed:
                return {"parent": "Ce niveau exige un parent."}
            return {}
        if not allowed:
            return {"parent": "Un pays n'a pas de parent."}
        if self.pk is not None and self.parent_id == self.pk:
            return {"parent": "Une zone ne peut pas être son propre parent."}
        parent = self.parent
        if LEVEL_RANK[parent.level] >= LEVEL_RANK[self.level]:
            return {"parent": "Le parent doit être d'un niveau strictement supérieur."}
        if parent.level not in allowed:
            attendus = " ou ".join(ZoneLevel(p).label.lower() for p in allowed)
            return {"parent": f"Le parent d'une zone de ce niveau doit être : {attendus}."}
        ancestor = parent
        while ancestor is not None:  # défense en profondeur contre un cycle
            if self.pk is not None and ancestor.pk == self.pk:
                return {"parent": "Une zone ne peut pas être son propre ancêtre."}
            ancestor = ancestor.parent
        return {}

    def save(self, *args, **kwargs):
        self.clean()
        update_fields = kwargs.get("update_fields")
        if update_fields is not None and "name" in update_fields:
            kwargs["update_fields"] = {*update_fields, "normalized_name"}
        super().save(*args, **kwargs)

    def get_path(self) -> list["Zone"]:
        """Les parents du pays jusqu'à cette zone incluse."""
        path = []
        zone = self
        while zone is not None:
            path.append(zone)
            zone = zone.parent
        path.reverse()
        return path
