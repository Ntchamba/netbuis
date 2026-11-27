"""Jetons : T007. Durées, rafraîchissement (D-01 : corps pour le mobile, cookie pour le
dashboard), déconnexion, comptes bloqués / supprimés, aucun jeton dans les journaux.
Numéros de test 6 00 00 00 XX (D-18) ; codes et mots de passe générés par le test."""
import logging
import re
import secrets
from datetime import timedelta

import pytest
from django.core.cache import cache
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken
from rest_framework_simplejwt.tokens import AccessToken, RefreshToken

from apps.accounts.models import User
from apps.accounts.services.token_service import issue_tokens
from apps.core.log_filters import mask_personal_data
from tests.factories.user_factory import AdminFactory, UserFactory

pytestmark = pytest.mark.django_db

REQUEST_URL = "/api/auth/otp/request/"
VERIFY_URL = "/api/auth/otp/verify/"
REFRESH_URL = "/api/auth/refresh/"
LOGOUT_URL = "/api/auth/logout/"
ADMIN_LOGIN_URL = "/api/auth/admin/login/"
COOKIE = "netbuis_refresh"
PHONE = "600000071"


@pytest.fixture(autouse=True)
def _dev(settings):
    settings.DEBUG = True  # le fournisseur SMS console l'exige
    settings.SMS_PROVIDER = "console"
    cache.clear()
    yield
    cache.clear()


@pytest.fixture
def client():
    return APIClient()


def ask_code(client, capsys, phone=PHONE):
    capsys.readouterr()
    assert client.post(REQUEST_URL, {"phone": phone}, format="json").status_code == 202
    return re.search(r"Votre code NetBuis : (\d{6})", capsys.readouterr().out)[1]


def refresh(client, token):
    return client.post(REFRESH_URL, {"refresh": token}, format="json")


def admin_cookie(client):
    """Connexion admin : le jeton de rafraîchissement arrive dans le cookie."""
    password = secrets.token_urlsafe(16)
    admin = AdminFactory(password=password)
    response = client.post(
        ADMIN_LOGIN_URL, {"phone": admin.phone, "password": password}, format="json"
    )
    assert response.status_code == 200, response.data
    return admin, response.cookies[COOKIE].value


def tamper(token):
    """Signature remplacée par celle d'un autre contenu : elle ne correspond plus."""
    header, payload, _ = token.split(".")
    other = issue_tokens(UserFactory())["refresh"].split(".")[2]
    return f"{header}.{payload}.{other}"


def same_user(token, user):
    return str(token["user_id"]) == str(user.pk)


def lifetime(token):
    return timedelta(seconds=token["exp"] - token["iat"])


# --- 1. verify : accès 15 min, rafraîchissement 30 jours, compte créé -------------


def test_verify_renvoie_acces_15_min_et_refresh_30_jours(client, capsys):
    response = client.post(
        VERIFY_URL, {"phone": PHONE, "code": ask_code(client, capsys)}, format="json"
    )
    assert response.status_code == 200
    assert response.data["is_new"] is True
    user = User.objects.get(phone="+237600000071")
    access, refresh_token = AccessToken(response.data["access"]), RefreshToken(
        response.data["refresh"]
    )
    assert lifetime(access) == timedelta(minutes=15)
    assert lifetime(refresh_token) == timedelta(days=30)
    assert same_user(access, user) and same_user(refresh_token, user)


def test_verify_code_faux_ni_jeton_ni_compte(client, capsys):
    code = ask_code(client, capsys)
    wrong = f"{(int(code) + 1) % 1_000_000:06d}"
    response = client.post(VERIFY_URL, {"phone": PHONE, "code": wrong}, format="json")
    assert response.status_code == 400
    assert "access" not in response.data and "refresh" not in response.data
    assert not User.objects.exists()


# --- 2. refresh : corps JSON (mobile) ---------------------------------------------


def test_refresh_mobile_renvoie_un_nouveau_couple(client):
    user = UserFactory()
    old = issue_tokens(user)["refresh"]
    response = refresh(client, old)
    assert response.status_code == 200
    assert same_user(AccessToken(response.data["access"]), user)
    assert lifetime(AccessToken(response.data["access"])) == timedelta(minutes=15)
    assert response.data["refresh"] != old
    assert COOKIE not in response.cookies  # le mobile n'utilise pas de cookie


def test_refresh_mobile_ancien_jeton_refuse_apres_rotation(client):
    old = issue_tokens(UserFactory())["refresh"]
    new = refresh(client, old).data["refresh"]
    reused = refresh(client, old)
    assert reused.status_code == 401
    assert reused.data["code"] == "token_invalid"
    assert refresh(client, new).status_code == 200


def test_refresh_jeton_expire_refuse(client):
    token = RefreshToken.for_user(UserFactory())
    token.set_exp(lifetime=timedelta(seconds=-1))
    response = refresh(client, str(token))
    assert response.status_code == 401
    assert response.data == {
        "code": "token_invalid",
        "message": "Votre session a expiré. Reconnectez-vous.",
    }


@pytest.mark.parametrize("cas", ["texte", "signature", "acces", "absent"])
def test_refresh_jeton_invalide_refuse(client, cas):
    tokens = issue_tokens(UserFactory())
    body = {
        "texte": {"refresh": "pas-un-jeton"},
        "signature": {"refresh": tamper(tokens["refresh"])},
        "acces": {"refresh": tokens["access"]},  # un jeton d'accès n'est pas un refresh
        "absent": {},
    }[cas]
    response = client.post(REFRESH_URL, body, format="json")
    assert response.status_code == 401
    assert response.data["code"] == "token_invalid"
    assert "access" not in response.data


def test_refresh_jeton_non_emis_par_le_serveur_refuse(client):
    """Bien signé mais jamais enregistré (absent de la liste des jetons émis)."""
    token = RefreshToken.for_user(UserFactory())
    OutstandingToken.objects.filter(jti=token["jti"]).delete()
    assert refresh(client, str(token)).status_code == 401


# --- 2. refresh : cookie HttpOnly (dashboard, D-01) -------------------------------


def test_refresh_dashboard_par_cookie(client):
    admin, old = admin_cookie(client)
    response = client.post(REFRESH_URL, format="json")  # rien dans le corps
    assert response.status_code == 200
    assert set(response.data) == {"access"}  # le refresh ne sort jamais dans le corps
    assert same_user(AccessToken(response.data["access"]), admin)
    cookie = response.cookies[COOKIE]
    assert cookie.value and cookie.value != old
    assert cookie["httponly"] and cookie["samesite"] == "Lax"
    assert cookie["path"] == "/api/auth/"
    assert int(cookie["max-age"]) == 30 * 24 * 3600


def test_cookie_secure_hors_developpement(client, settings):
    settings.DEBUG = False
    password = secrets.token_urlsafe(16)
    admin = AdminFactory(password=password)
    response = client.post(
        ADMIN_LOGIN_URL, {"phone": admin.phone, "password": password}, format="json"
    )
    assert response.cookies[COOKIE]["secure"] is True


def test_cookie_non_secure_en_developpement(client):
    admin_cookie(client)
    assert client.post(REFRESH_URL).cookies[COOKIE]["secure"] == ""


def test_refresh_dashboard_ancien_cookie_refuse(client):
    _, old = admin_cookie(client)
    assert client.post(REFRESH_URL).status_code == 200
    client.cookies[COOKIE] = old  # rejeu de l'ancien cookie
    response = client.post(REFRESH_URL)
    assert response.status_code == 401
    assert response.data["code"] == "token_invalid"
    assert response.cookies[COOKIE].value == ""  # le cookie refusé est effacé


def test_refresh_dashboard_cookie_invalide_refuse(client):
    client.cookies[COOKIE] = "pas-un-jeton"
    response = client.post(REFRESH_URL)
    assert response.status_code == 401
    assert response.cookies[COOKIE]["max-age"] == 0


# --- 3. logout --------------------------------------------------------------------


def test_logout_mobile_invalide_le_refresh(client):
    token = issue_tokens(UserFactory())["refresh"]
    assert client.post(LOGOUT_URL, {"refresh": token}, format="json").status_code == 204
    after = refresh(client, token)
    assert after.status_code == 401
    assert after.data["code"] == "token_invalid"


def test_logout_dashboard_efface_le_cookie_et_invalide_le_refresh(client):
    _, token = admin_cookie(client)
    response = client.post(LOGOUT_URL)
    assert response.status_code == 204
    assert response.cookies[COOKIE].value == ""
    assert response.cookies[COOKIE]["max-age"] == 0
    assert response.cookies[COOKIE]["path"] == "/api/auth/"
    client.cookies[COOKIE] = token  # cookie conservé malgré tout : refusé
    assert client.post(REFRESH_URL).status_code == 401


def test_logout_deux_fois_refuse(client):
    token = issue_tokens(UserFactory())["refresh"]
    assert client.post(LOGOUT_URL, {"refresh": token}, format="json").status_code == 204
    second = client.post(LOGOUT_URL, {"refresh": token}, format="json")
    assert second.status_code == 401


@pytest.mark.parametrize("body", [{}, {"refresh": "pas-un-jeton"}])
def test_logout_jeton_invalide_refuse(client, body):
    response = client.post(LOGOUT_URL, body, format="json")
    assert response.status_code == 401
    assert response.data["code"] == "token_invalid"


def test_logout_ne_touche_pas_aux_autres_sessions(client):
    user = UserFactory()
    phone_a, phone_b = issue_tokens(user)["refresh"], issue_tokens(user)["refresh"]
    client.post(LOGOUT_URL, {"refresh": phone_a}, format="json")
    assert refresh(client, phone_b).status_code == 200


# --- 5. comptes bloqués / supprimés -----------------------------------------------


@pytest.mark.parametrize(
    "champs, code",
    [
        ({"is_blocked": True, "blocked_at": timezone.now()}, "account_blocked"),
        ({"is_deleted": True, "deleted_at": timezone.now()}, "account_deleted"),
    ],
)
def test_refresh_refuse_compte_bloque_ou_supprime(client, champs, code):
    user = UserFactory()
    token = issue_tokens(user)["refresh"]
    User.objects.filter(pk=user.pk).update(**champs)
    response = refresh(client, token)
    assert response.status_code == 403
    assert response.data["code"] == code
    assert "access" not in response.data
    # Le jeton présenté reste invalidé, même après déblocage.
    User.objects.filter(pk=user.pk).update(is_blocked=False, is_deleted=False)
    assert refresh(client, token).status_code == 401


def test_refresh_refuse_compte_inactif(client):
    user = UserFactory()
    token = issue_tokens(user)["refresh"]
    User.objects.filter(pk=user.pk).update(is_active=False)
    assert refresh(client, token).status_code == 401


def test_refresh_refuse_cookie_d_un_admin_bloque(client):
    admin, _ = admin_cookie(client)
    User.objects.filter(pk=admin.pk).update(is_blocked=True)
    response = client.post(REFRESH_URL)
    assert response.status_code == 403
    assert response.data["code"] == "account_blocked"
    assert response.cookies[COOKIE].value == ""


@pytest.mark.parametrize(
    "champs, code",
    [({"is_blocked": True}, "account_blocked"), ({"is_deleted": True}, "account_deleted")],
)
def test_verify_refuse_compte_bloque_ou_supprime(client, capsys, champs, code):
    UserFactory(phone="+237600000071", **champs)
    response = client.post(
        VERIFY_URL, {"phone": PHONE, "code": ask_code(client, capsys)}, format="json"
    )
    assert response.status_code == 403
    assert response.data["code"] == code
    assert "access" not in response.data and "refresh" not in response.data


# --- 6. aucun jeton dans les journaux ---------------------------------------------


def test_aucun_jeton_dans_les_journaux(client, capsys, caplog):
    caplog.set_level(logging.DEBUG)
    code = ask_code(client, capsys)
    tokens = client.post(VERIFY_URL, {"phone": PHONE, "code": code}, format="json").data
    new = refresh(client, tokens["refresh"]).data
    refresh(client, tokens["refresh"])  # refus : journalisé par Django (401)
    client.post(LOGOUT_URL, {"refresh": new["refresh"]}, format="json")
    admin_cookie(client)
    client.post(REFRESH_URL)
    journal = caplog.text + capsys.readouterr().err
    for token in (tokens["access"], tokens["refresh"], new["access"], new["refresh"]):
        assert token not in journal
    assert "eyJ" not in journal


def test_le_filtre_masque_les_jetons():
    tokens = issue_tokens(UserFactory())
    text = mask_personal_data(f"refresh={tokens['refresh']} access={tokens['access']}")
    assert tokens["refresh"] not in text and tokens["access"] not in text
    assert text == "refresh=[jeton masqué] access=[jeton masqué]"
