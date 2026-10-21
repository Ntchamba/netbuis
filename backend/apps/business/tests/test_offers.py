"""Offres du commerçant (T037) : GET/POST /api/business/me/offers/, PATCH/DELETE …/<id>/."""
import pytest
from django.core.cache import cache
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.business.models import BusinessStatus, Offer
from tests.factories.business_factory import make_owner, make_profile
from tests.factories.catalog_factory import make_product
from tests.factories.storage_factory import make_stored_file

pytestmark = pytest.mark.django_db

URL = "/api/business/me/offers/"


@pytest.fixture(autouse=True)
def _clear_cache():
    cache.clear()
    yield
    cache.clear()


def connected(user):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    return client


def active_merchant(**extra):
    profile = make_profile(status=BusinessStatus.ACTIVE, **extra)
    return profile, connected(profile.owner)


def make_offer(profile, **extra):
    values = {"name": "Riz 25 kg", "price_fcfa": 15000}
    values.update(extra)
    return Offer.objects.create(profile=profile, **values)


def test_create_list_update_delete():
    profile, client = active_merchant()
    response = client.post(URL, {"name": " Riz 25 kg ", "price_fcfa": 15000}, format="json")
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Riz 25 kg"
    assert body["price_fcfa"] == 15000 and body["on_request"] is False
    assert body["is_active"] is True and body["photos"] == []
    listing = client.get(URL).json()
    assert [o["id"] for o in listing["results"]] == [body["id"]]
    patched = client.patch(f"{URL}{body['id']}/", {"is_active": False, "price_fcfa": None},
                           format="json")
    assert patched.status_code == 200
    assert patched.json()["is_active"] is False and patched.json()["on_request"] is True
    assert client.delete(f"{URL}{body['id']}/").status_code == 204
    assert not Offer.objects.filter(profile=profile).exists()


def test_price_zero_ok_negative_and_text_refused():
    _, client = active_merchant()
    assert client.post(URL, {"name": "Cadeau", "price_fcfa": 0}, format="json").status_code == 201
    for bad in (-1, "abc", 1.5):
        response = client.post(URL, {"name": "X", "price_fcfa": bad}, format="json")
        assert response.status_code == 400, bad
        assert "price_fcfa" in response.json()["fields"]


def test_name_required():
    _, client = active_merchant()
    for body in ({}, {"name": "   "}):
        response = client.post(URL, body, format="json")
        assert response.status_code == 400 and "name" in response.json()["fields"]


def test_photos_max_four_and_own_files_only():
    profile, client = active_merchant()
    owner = profile.owner
    four = [make_stored_file(owner) for _ in range(4)]
    ok = client.post(URL, {"name": "A", "photos": four}, format="json")
    assert ok.status_code == 201 and ok.json()["photos"] == four
    five = [*four, make_stored_file(owner)]
    too_many = client.post(URL, {"name": "B", "photos": five}, format="json")
    assert too_many.status_code == 400 and "photos" in too_many.json()["fields"]
    foreign = make_stored_file(make_owner())
    stolen = client.post(URL, {"name": "C", "photos": [foreign]}, format="json")
    assert stolen.status_code == 400
    wrong_kind = make_stored_file(owner, kind="post_image")
    assert client.post(URL, {"name": "D", "photos": [wrong_kind]}, format="json").status_code == 400


def test_catalog_link_optional_and_must_exist():
    _, client = active_merchant()
    product = make_product("Riz parfumé")
    linked = client.post(URL, {"name": "Riz", "catalog_product": product.pk}, format="json")
    assert linked.status_code == 201 and linked.json()["catalog_product"] == product.pk
    unknown = client.post(URL, {"name": "Riz", "catalog_product": 999999}, format="json")
    assert unknown.status_code == 400


def test_no_counter_on_offer():
    profile, client = active_merchant()
    make_offer(profile)
    row = client.get(URL).json()["results"][0]
    assert not {k for k in row if "count" in k or "view" in k or "call" in k}
    assert not {f.name for f in Offer._meta.fields if "count" in f.name or "view" in f.name}


def test_merchant_never_sees_or_touches_another_merchants_offers():
    mine, client = active_merchant()
    other, _ = active_merchant()
    theirs = make_offer(other, name="Offre de l'autre")
    own = make_offer(mine, name="Mon offre")
    ids = [o["id"] for o in client.get(URL).json()["results"]]
    assert ids == [own.pk]
    assert client.patch(f"{URL}{theirs.pk}/", {"name": "Piraté"}, format="json").status_code == 404
    assert client.delete(f"{URL}{theirs.pk}/").status_code == 404
    theirs.refresh_from_db()
    assert theirs.name == "Offre de l'autre"


def test_profile_field_in_body_is_ignored():
    mine, client = active_merchant()
    other, _ = active_merchant()
    response = client.post(URL, {"name": "X", "profile": other.pk}, format="json")
    assert response.status_code == 201
    assert Offer.objects.get(pk=response.json()["id"]).profile_id == mine.pk


@pytest.mark.parametrize(
    "state", [BusinessStatus.PENDING, BusinessStatus.REJECTED]
)
def test_non_active_profile_refused(state):
    profile = make_profile(status=state)
    client = connected(profile.owner)
    offer = make_offer(profile)
    for response in (
        client.get(URL),
        client.post(URL, {"name": "X"}, format="json"),
        client.patch(f"{URL}{offer.pk}/", {"name": "Y"}, format="json"),
        client.delete(f"{URL}{offer.pk}/"),
    ):
        assert response.status_code == 403
        assert response.json()["code"] == "business_not_active"


def test_no_profile_is_404_and_anonymous_is_401():
    assert connected(make_owner()).get(URL).status_code == 404
    assert connected(make_owner()).get(URL).json()["code"] == "no_business"
    assert APIClient().get(URL).status_code == 401
    assert APIClient().post(URL, {"name": "X"}, format="json").status_code == 401


def test_offers_deleted_with_profile_and_product_link_cleared():
    profile, _ = active_merchant()
    product = make_product("Huile")
    offer = make_offer(profile, catalog_product=product)
    product.delete()
    offer.refresh_from_db()
    assert offer.catalog_product is None
