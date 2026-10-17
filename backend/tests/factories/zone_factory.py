"""Fabrique de zones : chaînes valides Cameroun → Quartier prêtes à l'emploi."""
from apps.geo.models import Zone, ZoneLevel


def make_zone(name, level, parent=None, **extra):
    return Zone.objects.create(name=name, level=level, parent=parent, **extra)


def make_maroua_chain():
    """Cameroun > Extrême-Nord > Diamaré > Maroua (ville) > Hardé (quartier)."""
    pays = make_zone("Cameroun", ZoneLevel.PAYS)
    region = make_zone("Extrême-Nord", ZoneLevel.REGION, pays)
    departement = make_zone("Diamaré", ZoneLevel.DEPARTEMENT, region)
    ville = make_zone("Maroua", ZoneLevel.VILLE_VILLAGE, departement)
    quartier = make_zone("Hardé", ZoneLevel.QUARTIER, ville)
    return pays, region, departement, ville, quartier
