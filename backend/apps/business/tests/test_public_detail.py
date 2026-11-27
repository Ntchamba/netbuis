"""Fiche publique GET /api/business/<id>/ (T047b)."""
import json
from concurrent.futures import ThreadPoolExecutor

import pytest
from django.db import connection
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.business.models import AccountType, BusinessProfile, BusinessStatus, Offer, ProfileView
from tests.factories.business_factory import get_structure_type, make_owner, make_profile

pytestmark = pytest.mark.django_db


def connected(user=None):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user or make_owner())['access']}")
    return client


def url(profile):
    return f"/api/business/{profile.pk}/"


def active(type_compte=AccountType.BOUTIQUE, **extra):
    extra.setdefault("status", BusinessStatus.ACTIVE)
    return make_profile(type_compte, **extra)


def test_active_profile_returned_without_secrets():
    profile = active(
        AccountType.PRESTATAIRE_SERVICE, cni_verifiee=True, diplome_photo="prive/diplome.jpg",
        repere="Près du marché",
    )
    Offer.objects.create(profile=profile, name="Réparation", price_fcfa=2000)
    Offer.objects.create(profile=profile, name="Cachée", is_active=False)
    response = connected().get(url(profile))
    assert response.status_code == 200
    body = response.json()
    assert body["verifie"] is True and body["diplome_fourni"] is True
    assert body["whatsapp_available"] is True and body["repere"] == "Près du marché"
    assert [o["name"] for o in body["offers"]] == ["Réparation"]
    assert "views_count" not in body and "calls_count" not in body
    assert "views_count" not in body["offers"][0]

    # Parcours de TOUTE la réponse : ni numéro (complet, fin, +237), ni pièce, ni motif.
    text = json.dumps(response.json(), ensure_ascii=False)
    phone = profile.phone_anchor
    for forbidden in (phone, phone[-8:], phone[-9:], "+237", "cni", "prive/", "diplome.jpg",
                      "motif_rejet", "phone", "numero_agrement"):
        assert forbidden not in text
    keys = set()

    def walk(node):
        if isinstance(node, dict):
            keys.update(node)
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for value in node:
                walk(value)

    walk(body)
    assert not keys & {"phone_anchor", "cni_photo", "diplome_photo", "motif_rejet", "owner"}


def test_not_verified_badge_false():
    profile = active(AccountType.PRESTATAIRE_SERVICE)
    body = connected().get(url(profile)).json()
    assert body["verifie"] is False and body["diplome_fourni"] is False


def test_company_and_structure_fields():
    company = active(AccountType.ENTREPRISE, description_activite="Vente en gros")
    body = connected().get(url(company)).json()
    assert body["forme_juridique"] == "sarl" and body["description_activite"] == "Vente en gros"

    restaurant = active(
        AccountType.STRUCTURE, structure_type=get_structure_type("restaurant", "Restaurant"),
        cuisine="camerounaise", livraison=True, horaires="8h-22h",
    )
    body = connected().get(url(restaurant)).json()
    assert body["details"] == {
        "cuisine": "camerounaise", "livraison": True, "horaires": "8h-22h"}
    assert body["structure_type"] == "Restaurant" and body["forme_juridique"] == ""


@pytest.mark.parametrize("status", [BusinessStatus.PENDING, BusinessStatus.REJECTED])
def test_inactive_profile_is_404(status):
    extra = {"motif_rejet": "Photo floue"} if status == BusinessStatus.REJECTED else {}
    profile = make_profile(status=status, **extra)
    assert connected().get(url(profile)).status_code == 404


@pytest.mark.parametrize("flag", ["is_blocked", "is_deleted"])
def test_blocked_or_deleted_owner_is_404(flag):
    profile = active()
    setattr(profile.owner, flag, True)
    profile.owner.save()
    assert connected().get(url(profile)).status_code == 404


def test_unknown_profile_404_and_anonymous_401():
    assert connected().get("/api/business/999999/").status_code == 404
    assert APIClient().get(url(active())).status_code == 401


def test_blocked_caller_refused():
    caller = make_owner(is_blocked=True)
    assert connected(caller).get(url(active())).status_code == 403


def views(profile):
    return BusinessProfile.objects.get(pk=profile.pk).views_count


def test_one_view_per_account_per_day():
    profile = active()
    client = connected()
    for _ in range(3):
        assert client.get(url(profile)).status_code == 200
    assert views(profile) == 1
    connected().get(url(profile))
    assert views(profile) == 2


def test_new_day_counts_again_and_owner_views_not_counted():
    profile = active()
    viewer = make_owner()
    client = connected(viewer)
    client.get(url(profile))
    ProfileView.objects.update(day="2000-01-01")
    client.get(url(profile))
    assert views(profile) == 2
    connected(profile.owner).get(url(profile))
    assert views(profile) == 2


def test_failed_lookup_counts_nothing():
    profile = make_profile(status=BusinessStatus.PENDING)
    connected().get(url(profile))
    assert views(profile) == 0


@pytest.mark.django_db(transaction=True)
def test_concurrent_requests_count_once():
    profile = active()
    viewer = make_owner()

    def hit(_):
        try:
            return connected(viewer).get(url(profile)).status_code
        finally:
            connection.close()

    with ThreadPoolExecutor(4) as pool:
        codes = list(pool.map(hit, range(4)))
    assert codes == [200] * 4
    assert views(profile) == 1
