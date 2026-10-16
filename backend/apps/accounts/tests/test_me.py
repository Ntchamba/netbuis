"""Compte : T008. GET / PATCH / DELETE /api/me/ et permissions IsAuthenticatedNotBlocked,
IsActiveBusinessOwner, IsAdminRole. Numéros de test 6 00 00 00 XX (D-18) ; codes générés
par le serveur de test, jamais écrits."""
import logging
import re
from types import SimpleNamespace

import pytest
from django.core.cache import cache
from rest_framework.settings import api_settings
from rest_framework.test import APIClient
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken

from apps.accounts.models import User
from apps.accounts.permissions import (
    IsActiveBusinessOwner,
    IsAdminRole,
    IsAuthenticatedNotBlocked,
)
from apps.accounts.services.otp_service import AccountBlocked, AccountDeleted
from apps.accounts.services.token_service import issue_tokens
from tests.factories.user_factory import AdminFactory, UserFactory

pytestmark = pytest.mark.django_db

URL = "/api/me/"
PHONE = "+237600000012"
DIGITS = "600000012"


@pytest.fixture(autouse=True)
def _dev(settings):
    settings.DEBUG = True  # le fournisseur SMS console l'exige
    settings.SMS_PROVIDER = "console"
    settings.CREDITS_ENABLED = False
    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def user():
    return UserFactory(phone=PHONE, name="Jeff N.")


def connected(user):
    """Client avec un jeton d'accès valable pour `user` ; renvoie aussi le refresh."""
    tokens = issue_tokens(user)
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
    return client, tokens["refresh"]


@pytest.fixture
def business(monkeypatch):
    """Simule le compte business (le modèle BusinessProfile arrive en T025)."""

    def _set(status):
        profile = SimpleNamespace(status=status)
        monkeypatch.setattr(User, "business_profile", property(lambda self: profile), raising=False)

    return _set


# --- GET /api/me/ --------------------------------------------------------------------


def test_get_me_renvoie_l_identite_avec_le_numero_masque(user):
    client, _ = connected(user)
    response = client.get(URL)
    assert response.status_code == 200
    assert response.json() == {
        "id": user.pk,
        "name": "Jeff N.",
        "phone_masked": "+237 6•• •• •• 12",
        "language": "fr",
        "has_business": False,
        "free_call_available": None,
        "credits_balance": None,
    }
    assert DIGITS not in response.content.decode()


def test_get_me_sans_jeton_refuse():
    response = APIClient().get(URL)
    assert response.status_code == 401
    assert response.json()["code"] == "not_authenticated"


def test_get_me_jeton_faux_refuse():
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION="Bearer pas-un-jeton")
    assert client.get(URL).status_code == 401


@pytest.mark.parametrize("status", ["en_attente_validation", "actif", "rejete"])
def test_get_me_has_business_vrai_avec_un_compte_business(user, business, status):
    business(status)
    client, _ = connected(user)
    assert client.get(URL).json()["has_business"] is True


def test_compteurs_null_tant_que_credits_desactives(user, settings):
    assert settings.CREDITS_ENABLED is False
    client, _ = connected(user)
    body = client.get(URL).json()
    assert body["free_call_available"] is None
    assert body["credits_balance"] is None
    assert body["credits_balance"] != 0  # null, pas 0 : le mobile masque les blocs


# --- PATCH /api/me/ ------------------------------------------------------------------


def test_patch_me_modifie_nom_et_langue(user):
    client, _ = connected(user)
    response = client.patch(URL, {"name": "Jeff Ntchamba", "language": "en"}, format="json")
    assert response.status_code == 200
    assert response.json()["name"] == "Jeff Ntchamba"
    assert response.json()["language"] == "en"
    user.refresh_from_db()
    assert (user.name, user.language) == ("Jeff Ntchamba", "en")


def test_patch_me_langue_inconnue_refusee(user):
    client, _ = connected(user)
    response = client.patch(URL, {"language": "de"}, format="json")
    assert response.status_code == 400
    assert "language" in response.json()["fields"]
    user.refresh_from_db()
    assert user.language == "fr"


def test_patch_me_nom_trop_long_refuse(user):
    client, _ = connected(user)
    response = client.patch(URL, {"name": "x" * 121}, format="json")
    assert response.status_code == 400
    assert "name" in response.json()["fields"]


def test_patch_me_ne_change_ni_le_numero_ni_les_droits(user):
    client, _ = connected(user)
    response = client.patch(
        URL,
        {"phone": "+237600000099", "is_admin": True, "is_blocked": True, "id": 999},
        format="json",
    )
    assert response.status_code == 200
    user.refresh_from_db()
    assert user.phone == PHONE
    assert not user.is_admin and not user.is_blocked
    assert response.json()["id"] == user.pk


def test_put_me_non_disponible(user):
    client, _ = connected(user)
    assert client.put(URL, {"name": "x", "language": "fr"}, format="json").status_code == 405


# --- Jeton d'accès encore valable après blocage ou suppression (remarque T007) --------


@pytest.mark.parametrize(
    ("champs", "code"),
    [({"is_blocked": True}, "account_blocked"), ({"is_deleted": True}, "account_deleted")],
)
def test_jeton_d_acces_refuse_des_le_blocage_ou_la_suppression(user, champs, code):
    client, _ = connected(user)
    assert client.get(URL).status_code == 200
    User.objects.filter(pk=user.pk).update(**champs)
    response = client.get(URL)
    assert response.status_code == 403
    assert response.json()["code"] == code
    assert "Contactez le support" in response.json()["message"]
    assert client.patch(URL, {"name": "x"}, format="json").status_code == 403


# --- DELETE /api/me/ : suppression douce (D-09) ---------------------------------------


def test_delete_me_suppression_douce(user):
    client, _ = connected(user)
    response = client.delete(URL)
    assert response.status_code == 204
    user.refresh_from_db()
    assert user.is_deleted and user.deleted_at is not None
    # Suppression douce : le compte et ses données restent en base.
    assert user.phone == PHONE and user.name == "Jeff N."


def test_delete_me_invalide_tous_les_jetons(user):
    client, refresh = connected(user)
    _, other_refresh = connected(user)  # deuxième appareil
    assert client.delete(URL).status_code == 204
    pending = OutstandingToken.objects.filter(user=user, blacklistedtoken__isnull=True)
    assert not pending.exists()
    assert BlacklistedToken.objects.filter(token__user=user).count() == 2
    for token in (refresh, other_refresh):
        response = APIClient().post("/api/auth/refresh/", {"refresh": token}, format="json")
        assert response.status_code == 401
    # Le jeton d'accès encore valable ne sert plus à rien.
    assert client.get(URL).status_code == 403


def test_delete_me_ne_touche_pas_aux_autres_comptes(user):
    other = UserFactory()
    client, _ = connected(user)
    _, other_refresh = connected(other)
    assert client.delete(URL).status_code == 204
    other.refresh_from_db()
    assert not other.is_deleted
    response = APIClient().post("/api/auth/refresh/", {"refresh": other_refresh}, format="json")
    assert response.status_code == 200


def test_delete_me_sans_jeton_refuse(user):
    assert APIClient().delete(URL).status_code == 401
    user.refresh_from_db()
    assert not user.is_deleted


def test_compte_supprime_qui_se_reconnecte_contacte_le_support(user, capsys):
    client, _ = connected(user)
    assert client.delete(URL).status_code == 204
    public = APIClient()
    capsys.readouterr()
    asked = public.post("/api/auth/otp/request/", {"phone": DIGITS}, format="json")
    assert asked.status_code == 202
    code = re.search(r"Votre code NetBuis : (\d{6})", capsys.readouterr().out)[1]
    response = public.post("/api/auth/otp/verify/", {"phone": DIGITS, "code": code}, format="json")
    assert response.status_code == 403
    assert response.json() == {
        "code": "account_deleted",
        "message": "Ce compte a été supprimé. Contactez le support.",
    }
    assert User.objects.filter(phone=PHONE).count() == 1  # pas de nouveau compte


def test_aucun_numero_complet_dans_les_journaux(user, caplog):
    client, _ = connected(user)
    with caplog.at_level(logging.DEBUG):
        client.get(URL)
        client.patch(URL, {"language": "de"}, format="json")
        client.delete(URL)
        client.get(URL)
    assert DIGITS not in caplog.text


# --- Permissions ---------------------------------------------------------------------


def _request(user):
    return SimpleNamespace(user=user)


class _Anonymous:
    is_authenticated = False


def test_permission_par_defaut_de_drf():
    assert api_settings.DEFAULT_PERMISSION_CLASSES == [IsAuthenticatedNotBlocked]


ALL_PERMISSIONS = [IsAuthenticatedNotBlocked, IsActiveBusinessOwner, IsAdminRole]


@pytest.mark.parametrize("permission", ALL_PERMISSIONS)
def test_permissions_refusent_l_anonyme(permission):
    assert not permission().has_permission(_request(_Anonymous()), None)
    assert not permission().has_permission(_request(None), None)


def test_is_authenticated_not_blocked_accepte_un_compte_normal():
    assert IsAuthenticatedNotBlocked().has_permission(_request(UserFactory()), None)


@pytest.mark.parametrize(
    ("permission", "champs"),
    [
        (IsAuthenticatedNotBlocked, {}),
        (IsActiveBusinessOwner, {}),
        (IsAdminRole, {"is_admin": True}),
    ],
)
@pytest.mark.parametrize(
    ("etat", "erreur"),
    [({"is_blocked": True}, AccountBlocked), ({"is_deleted": True}, AccountDeleted)],
)
def test_permissions_refusent_bloque_et_supprime(business, permission, champs, etat, erreur):
    business("actif")
    user = UserFactory(**champs, **etat)
    with pytest.raises(erreur):
        permission().has_permission(_request(user), None)


def test_is_active_business_owner_accepte_un_compte_business_actif(business):
    business("actif")
    assert IsActiveBusinessOwner().has_permission(_request(UserFactory()), None)


@pytest.mark.parametrize("status", ["en_attente_validation", "rejete"])
def test_is_active_business_owner_refuse_un_compte_business_non_actif(business, status):
    business(status)
    assert not IsActiveBusinessOwner().has_permission(_request(UserFactory()), None)


def test_is_active_business_owner_refuse_un_compte_simple():
    assert not IsActiveBusinessOwner().has_permission(_request(UserFactory()), None)


def test_is_admin_role_provisoire_depend_de_is_admin():
    assert IsAdminRole().has_permission(_request(AdminFactory()), None)
    assert not IsAdminRole().has_permission(_request(UserFactory()), None)
    # is_staff (admin Django) ne suffit pas.
    assert not IsAdminRole().has_permission(_request(UserFactory(is_staff=True)), None)
