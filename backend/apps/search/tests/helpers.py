"""Aides de test de la recherche : comptes, offres, abonnements."""
from apps.business.models import AccountType, BusinessStatus, Offer
from tests.factories.business_factory import make_owner, make_profile, make_subscription
from tests.factories.catalog_factory import make_sector, make_subcategory
from tests.factories.zone_factory import make_zone


def shop(name="Boutique test", offers=(), subscribed=False, zone=None, **extra):
    """Un commerce ACTIF avec ses offres (noms) ; abonné si demandé."""
    extra.setdefault("status", BusinessStatus.ACTIVE)
    if zone is not None:
        extra["zone"] = zone
    profile = make_profile(name=name, **extra)
    for offer in offers:
        Offer.objects.create(profile=profile, name=offer)
    if subscribed:
        make_subscription(profile)
    return profile


def provider(name="Prestataire test", category=None, **extra):
    from tests.factories.business_factory import get_service_category

    extra.setdefault("status", BusinessStatus.ACTIVE)
    if category is not None:
        extra["categorie_service"] = get_service_category(*category)
    return make_profile(AccountType.PRESTATAIRE_SERVICE, name=name, **extra)


def ids(outcome):
    return [hit.profile_id for hit in outcome.hits]


__all__ = ["ids", "make_owner", "make_sector", "make_subcategory", "make_zone", "provider", "shop"]
