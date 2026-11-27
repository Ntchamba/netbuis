"""Parcours d'accès (T123) : code SMS, jetons, déconnexion ; connexion administrateur.

Tout passe par l'API réelle (APIClient, vraie base PostgreSQL, SMS « console »).
Les codes sont lus sur la console du serveur ; les mots de passe sont générés par le test.
"""
import re
import secrets

import pytest
from django.core.cache import cache
from rest_framework.test import APIClient

from apps.accounts.models import User
from tests.e2e._aides import VALIDATEUR, administrateur

pytestmark = pytest.mark.django_db

PHONE = "600000042"
COOKIE = "netbuis_refresh"


@pytest.fixture(autouse=True)
def _env(settings):
    settings.DEBUG = True
    settings.SMS_PROVIDER = "console"
    cache.clear()
    yield
    cache.clear()


def test_code_sms_verification_me_rafraichissement_deconnexion(capsys):
    client = APIClient()

    # 1. L'inconnu n'accède à rien.
    assert client.get("/api/me/").status_code == 401

    # 2. Il demande un code ; le SMS « console » l'affiche, on le lit comme un développeur.
    capsys.readouterr()
    assert client.post("/api/auth/otp/request/", {"phone": PHONE}, format="json"
                       ).status_code == 202
    code = re.search(r"Votre code NetBuis : (\d{6})", capsys.readouterr().out)[1]

    # 3. Un mauvais code est refusé et ne crée pas de session.
    mauvais = f"{(int(code) + 1) % 1_000_000:06d}"
    refus = client.post("/api/auth/otp/verify/", {"phone": PHONE, "code": mauvais}, format="json")
    assert refus.status_code == 400 and "access" not in refus.json()

    # 4. Le bon code crée le compte et renvoie le couple de jetons.
    ok = client.post("/api/auth/otp/verify/", {"phone": PHONE, "code": code}, format="json")
    assert ok.status_code == 200
    tokens = ok.json()
    assert tokens["is_new"] is True and tokens["access"] and tokens["refresh"]
    assert User.objects.get(phone=f"+237{PHONE}").is_admin is False

    # 5. Le code est à usage unique : le rejouer échoue.
    rejeu = client.post("/api/auth/otp/verify/", {"phone": PHONE, "code": code}, format="json")
    assert rejeu.status_code == 400

    # 6. /api/me/ répond avec le numéro masqué (jamais en clair).
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
    me = client.get("/api/me/")
    assert me.status_code == 200
    assert me.json()["phone_masked"].endswith("42") and PHONE not in me.content.decode()

    # 7. Rafraîchissement : nouveau couple ; l'ancien jeton de rafraîchissement est mort.
    anonyme = APIClient()
    suite = anonyme.post("/api/auth/refresh/", {"refresh": tokens["refresh"]}, format="json")
    assert suite.status_code == 200
    nouveau = suite.json()
    assert nouveau["refresh"] != tokens["refresh"]
    ancien = anonyme.post("/api/auth/refresh/", {"refresh": tokens["refresh"]}, format="json")
    assert ancien.status_code == 401

    # 8. Le nouvel accès fonctionne.
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {nouveau['access']}")
    assert client.get("/api/me/").status_code == 200

    # 9. Déconnexion : le jeton de rafraîchissement ne sert plus.
    assert anonyme.post("/api/auth/logout/", {"refresh": nouveau["refresh"]}, format="json"
                        ).status_code == 204
    apres = anonyme.post("/api/auth/refresh/", {"refresh": nouveau["refresh"]}, format="json")
    assert apres.status_code == 401


def test_connexion_admin_mot_de_passe_cookie_de_rafraichissement():
    mot_de_passe = secrets.token_urlsafe(16)
    admin = administrateur(VALIDATEUR, password=mot_de_passe)
    navigateur = APIClient()

    # 1. Un mauvais mot de passe donne l'erreur unique, sans cookie.
    echec = navigateur.post("/api/auth/admin/login/",
                            {"phone": admin.phone, "password": secrets.token_urlsafe(8)},
                            format="json")
    assert echec.status_code == 401 and COOKIE not in echec.cookies

    # 2. Le bon mot de passe : accès dans le corps, rafraîchissement SEULEMENT en cookie HttpOnly.
    ok = navigateur.post("/api/auth/admin/login/",
                         {"phone": admin.phone, "password": mot_de_passe}, format="json")
    assert ok.status_code == 200 and set(ok.json()) == {"access"}
    cookie = ok.cookies[COOKIE]
    assert cookie["httponly"] and cookie["path"] == "/api/auth/"

    # 3. L'accès ouvre l'espace d'administration.
    navigateur.credentials(HTTP_AUTHORIZATION=f"Bearer {ok.json()['access']}")
    assert navigateur.get("/api/admin/me/").status_code == 200

    # 4. Le navigateur renvoie le cookie (corps vide) : nouvel accès + cookie tourné.
    ancien_cookie = cookie.value
    rafraichi = navigateur.post("/api/auth/refresh/")
    assert rafraichi.status_code == 200 and set(rafraichi.json()) == {"access"}
    assert rafraichi.cookies[COOKIE].value not in ("", ancien_cookie)

    # 5. Rejouer l'ancien cookie échoue et l'efface côté navigateur.
    voleur = APIClient()
    voleur.cookies[COOKIE] = ancien_cookie
    rejeu = voleur.post("/api/auth/refresh/")
    assert rejeu.status_code == 401 and rejeu.cookies[COOKIE].value == ""

    # 6. Déconnexion : cookie effacé, plus de rafraîchissement possible.
    sortie = navigateur.post("/api/auth/logout/")
    assert sortie.status_code == 204 and sortie.cookies[COOKIE].value == ""
    navigateur.cookies[COOKIE] = rafraichi.cookies[COOKIE].value
    assert navigateur.post("/api/auth/refresh/").status_code == 401


def test_un_compte_sms_ne_peut_pas_entrer_par_le_mot_de_passe_admin():
    simple = User.objects.create(phone="+237600000043")
    simple.set_password(secrets.token_urlsafe(12))
    simple.save()
    reponse = APIClient().post(
        "/api/auth/admin/login/", {"phone": simple.phone, "password": "x"}, format="json")
    assert reponse.status_code == 401
