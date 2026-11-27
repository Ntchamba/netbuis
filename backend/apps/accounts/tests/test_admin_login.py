"""Connexion administrateur : T007. POST /api/auth/admin/login/ et entrée dans l'admin Django.
Numéros de test 6 00 00 00 XX (D-18) ; mots de passe générés par le test, jamais écrits."""
import secrets
import threading

import pytest
from django.core.cache import cache
from django.db import connection
from django.test import Client
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken
from rest_framework_simplejwt.tokens import AccessToken

from apps.accounts.models import AdminLoginAttempt, User
from tests.factories.user_factory import AdminFactory, UserFactory

pytestmark = pytest.mark.django_db

URL = "/api/auth/admin/login/"
COOKIE = "netbuis_refresh"
INVALID = {"code": "invalid_credentials", "message": "Numéro ou mot de passe incorrect."}


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()  # aucun état laissé dans le cache entre deux tests
    yield
    cache.clear()


@pytest.fixture
def client():
    return APIClient()


@pytest.fixture
def password():
    return secrets.token_urlsafe(16)


def login(client, phone, password, ip="127.0.0.1"):
    return client.post(URL, {"phone": phone, "password": password}, format="json", REMOTE_ADDR=ip)


# --- Succès ----------------------------------------------------------------------


@pytest.mark.parametrize("saisie", ["e164", "national"])
def test_admin_connecte(client, password, saisie):
    admin = AdminFactory(password=password)
    phone = admin.phone if saisie == "e164" else admin.phone.removeprefix("+237")
    response = login(client, phone, password)
    assert response.status_code == 200
    assert set(response.data) == {"access"}  # le refresh ne sort jamais dans le corps
    assert str(AccessToken(response.data["access"])["user_id"]) == str(admin.pk)
    cookie = response.cookies[COOKIE]
    assert cookie["httponly"] and cookie["samesite"] == "Lax" and cookie["path"] == "/api/auth/"
    assert OutstandingToken.objects.filter(user=admin).count() == 1


# --- Une seule erreur, identique dans tous les cas --------------------------------


@pytest.mark.parametrize(
    "cas",
    ["inexistant", "mauvais_mot_de_passe", "non_admin", "bloque", "supprime", "inactif",
     "numero_invalide", "compte_sms_sans_mot_de_passe"],
)
def test_erreur_identique(client, password, cas):
    phone = "+237600000081"
    if cas == "non_admin":
        UserFactory(phone=phone, password=password)
    elif cas == "bloque":
        AdminFactory(phone=phone, password=password, is_blocked=True, blocked_at=timezone.now())
    elif cas == "supprime":
        AdminFactory(phone=phone, password=password, is_deleted=True, deleted_at=timezone.now())
    elif cas == "inactif":
        AdminFactory(phone=phone, password=password, is_active=False)
    elif cas == "mauvais_mot_de_passe":
        AdminFactory(phone=phone, password=secrets.token_urlsafe(16))
    elif cas == "compte_sms_sans_mot_de_passe":
        UserFactory(phone=phone)  # mot de passe inutilisable
    elif cas == "numero_invalide":
        phone = "700000081"
    response = login(client, phone, password)
    assert response.status_code == 401
    assert response.data == INVALID
    assert COOKIE not in response.cookies


def test_champs_manquants(client):
    response = client.post(URL, {}, format="json")
    assert response.status_code == 400
    assert set(response.data["fields"]) == {"phone", "password"}


# --- 5 essais ratés / 15 min / IP --------------------------------------------------


def test_cinq_essais_rates_puis_429_meme_avec_le_bon_mot_de_passe(client, password):
    admin = AdminFactory(password=password)
    for _ in range(5):
        assert login(client, admin.phone, "faux").status_code == 401
    blocked = login(client, admin.phone, password)
    assert blocked.status_code == 429
    assert blocked.data["code"] == "too_many_requests"
    assert 890 <= int(blocked["Retry-After"]) <= 900
    assert COOKIE not in blocked.cookies


def test_quatre_essais_rates_le_cinquieme_reste_possible(client, password):
    admin = AdminFactory(password=password)
    for _ in range(4):
        login(client, admin.phone, "faux")
    assert login(client, admin.phone, password).status_code == 200


def test_comptes_inexistants_comptent_aussi(client, password):
    admin = AdminFactory(password=password)
    for n in range(5):
        login(client, f"+23760000009{n}", password)
    assert login(client, admin.phone, password).status_code == 429


def test_limite_par_ip(client, password):
    admin = AdminFactory(password=password)
    for _ in range(5):
        login(client, admin.phone, "faux", ip="10.0.0.1")
    assert login(client, admin.phone, password, ip="10.0.0.1").status_code == 429
    assert login(client, admin.phone, password, ip="10.0.0.2").status_code == 200


def test_limite_levee_apres_15_minutes(client, password):
    admin = AdminFactory(password=password)
    for _ in range(5):
        login(client, admin.phone, "faux")
    assert login(client, admin.phone, password).status_code == 429
    # Fin de la fenêtre de 15 min.
    AdminLoginAttempt.objects.filter(ip="127.0.0.1").update(window_end=timezone.now())
    assert login(client, admin.phone, password).status_code == 200


@pytest.mark.django_db(transaction=True)
def test_limite_tenue_meme_en_simultane(password):
    """20 mauvais mots de passe lancés en même temps depuis une IP : 5 évalués au plus."""
    admin = AdminFactory(password=password)
    count = 20
    barrier = threading.Barrier(count)
    statuses = []

    def attempt():
        try:
            barrier.wait()
            statuses.append(login(APIClient(), admin.phone, "faux", ip="10.0.0.9").status_code)
        finally:
            connection.close()

    threads = [threading.Thread(target=attempt) for _ in range(count)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    assert sorted(statuses) == [401] * 5 + [429] * (count - 5)
    # Le bon mot de passe est lui aussi refusé ensuite.
    assert login(APIClient(), admin.phone, password, ip="10.0.0.9").status_code == 429


def test_les_connexions_reussies_ne_comptent_pas(client, password):
    admin = AdminFactory(password=password)
    for _ in range(6):
        assert login(client, admin.phone, password).status_code == 200


# --- Admin Django : même règle (is_admin + can_login) ------------------------------


def django_admin_login(phone, password):
    browser = Client()
    browser.post("/django-admin/login/", {"username": phone, "password": password})
    return browser, browser.get("/django-admin/").status_code


def test_admin_django_admin_valide_entre(password):
    admin = AdminFactory(password=password, is_staff=True)
    _, status = django_admin_login(admin.phone, password)
    assert status == 200


@pytest.mark.parametrize(
    "champs",
    [
        {"is_admin": True, "is_blocked": True},
        {"is_admin": True, "is_deleted": True},
        {"is_admin": False},  # is_staff seul ne suffit pas
    ],
)
def test_admin_django_refuse_bloque_supprime_non_admin(password, champs):
    user = UserFactory(password=password, is_staff=True, **champs)
    _, status = django_admin_login(user.phone, password)
    assert status == 302  # renvoyé vers la page de connexion


def test_admin_django_session_coupee_des_le_blocage(password):
    admin = AdminFactory(password=password, is_staff=True)
    browser, status = django_admin_login(admin.phone, password)
    assert status == 200
    User.objects.filter(pk=admin.pk).update(is_blocked=True)
    assert browser.get("/django-admin/").status_code == 302


def test_admin_django_n_affiche_jamais_la_valeur_d_un_jeton(client, password):
    admin = AdminFactory(password=password, is_staff=True, is_superuser=True)
    login(client, admin.phone, password)
    raw = OutstandingToken.objects.get(user=admin).token
    browser, _ = django_admin_login(admin.phone, password)
    pk = OutstandingToken.objects.get(user=admin).pk
    page = browser.get(f"/django-admin/token_blacklist/outstandingtoken/{pk}/change/")
    assert page.status_code == 200
    assert raw not in page.content.decode()


def test_admin_django_fiche_compte_avec_langue_sans_mot_de_passe(password):
    admin = AdminFactory(password=password, is_staff=True, is_superuser=True)
    user = UserFactory(language="en")
    browser, _ = django_admin_login(admin.phone, password)
    page = browser.get(f"/django-admin/accounts/user/{user.pk}/change/")
    assert page.status_code == 200
    content = page.content.decode()
    assert 'name="language"' in content
    assert 'name="password"' not in content  # le mot de passe ne s'édite pas ici
    assert admin.password not in content


def test_admin_django_liste_filtrable_par_langue(password):
    admin = AdminFactory(password=password, is_staff=True, is_superuser=True)
    UserFactory(language="en", name="Compte anglais")
    UserFactory(language="fr", name="Compte francais")
    browser, _ = django_admin_login(admin.phone, password)
    page = browser.get("/django-admin/accounts/user/?language__exact=en")
    assert page.status_code == 200
    assert "Compte anglais" in page.content.decode()
    assert "Compte francais" not in page.content.decode()


def test_admin_django_refuse_un_compte_simple(password):
    user = UserFactory(password=password)
    browser, status = django_admin_login(user.phone, password)
    assert status == 302
    assert browser.get("/django-admin/accounts/user/").status_code == 302
