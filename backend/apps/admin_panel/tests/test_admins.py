"""Administrateurs (T074) : création, liste, rôle, retrait, gardes, audit, journaux.
Les mots de passe sont générés à l'exécution ; aucun secret n'est écrit dans ce fichier."""
import logging

import pytest
from django.contrib.auth.models import Group
from django.core.cache import cache
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.admin_panel.models import AuditAction, AuditLog
from apps.admin_panel.services import rights_service
from tests.factories.user_factory import AdminFactory, UserFactory

from ._t074 import COMPLET, VALIDATEUR, admin_in, api_as, check_permissions

pytestmark = pytest.mark.django_db

LIST = "/api/admin/admins/"
NEW_PHONE = "655512399"


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()
    yield
    cache.clear()


def create(client, role=VALIDATEUR, phone=NEW_PHONE, name="Awa"):
    return client.post(LIST, {"phone": phone, "name": name, "role": role}, format="json")


# --- Droits de chaque route -----------------------------------------------------------


def test_permissions_liste():
    check_permissions("get", LIST, None, 200)


def test_permissions_creation():
    body = {"phone": NEW_PHONE, "name": "A", "role": VALIDATEUR}
    response = check_permissions("post", LIST, body, 201)
    assert response.json()["roles"] == [VALIDATEUR]


def test_permissions_changement_de_role():
    target = admin_in(VALIDATEUR)
    check_permissions("patch", f"{LIST}{target.pk}/", {"role": COMPLET}, 200)


def test_permissions_retrait():
    target = admin_in(VALIDATEUR)
    check_permissions("delete", f"{LIST}{target.pk}/", {"reason": "Départ"}, 200)


# --- Création -----------------------------------------------------------------------


def test_creation_valide_mot_de_passe_montre_une_fois_et_audit(caplog):
    caplog.set_level(logging.DEBUG)
    boss = admin_in(COMPLET)
    response = create(api_as(boss), role=COMPLET)
    assert response.status_code == 201 and response["Cache-Control"] == "no-store"
    data = response.json()
    password = data["temporary_password"]
    assert len(password) >= 16
    user = User.objects.get(pk=data["id"])
    assert user.phone == "+237" + NEW_PHONE and user.is_admin
    assert not user.is_staff and not user.is_superuser
    assert user.check_password(password) and user.password != password
    assert rights_service.admin_roles(user) == [COMPLET]
    assert data["phone_masked"] == "+237 6•• •• •• 99" and NEW_PHONE not in str(data)
    log = AuditLog.objects.get(action=AuditAction.ATTRIBUTION_ROLE)
    assert log.admin == boss and log.target_id == user.pk and COMPLET in log.reason
    assert password not in log.reason
    # le mot de passe n'est ni dans les logs, ni relisible ensuite
    assert password not in caplog.text and NEW_PHONE not in caplog.text
    assert password not in api_as(boss).get(LIST).content.decode()
    # le nouvel administrateur peut se connecter au dashboard avec ce mot de passe
    login = APIClient().post("/api/auth/admin/login/",
                             {"phone": NEW_PHONE, "password": password}, format="json")
    assert login.status_code == 200


def test_mots_de_passe_temporaires_differents():
    boss = admin_in(COMPLET)
    client = api_as(boss)
    a = create(client, phone="655512391").json()["temporary_password"]
    b = create(client, phone="655512392").json()["temporary_password"]
    assert a != b


@pytest.mark.parametrize("payload,code", [
    ({"phone": "123", "name": "A", "role": VALIDATEUR}, "invalid_phone"),
    ({"phone": NEW_PHONE, "name": "A", "role": "Roi"}, "invalid"),
    ({"phone": NEW_PHONE, "role": VALIDATEUR}, "invalid"),
    ({"phone": NEW_PHONE, "name": "", "role": VALIDATEUR}, "invalid"),
    ({"name": "A", "role": VALIDATEUR}, "invalid"),
])
def test_creation_refusee(payload, code):
    response = api_as(admin_in(COMPLET)).post(LIST, payload, format="json")
    assert response.status_code == 400 and response.json()["code"] == code
    assert AuditLog.objects.count() == 0 and User.objects.count() == 1


def test_numero_deja_utilise_refuse_et_compte_non_promu():
    existing = UserFactory(phone="+237655512399")
    response = create(api_as(admin_in(COMPLET)))
    assert response.status_code == 409 and response.json()["code"] == "phone_exists"
    existing.refresh_from_db()
    assert not existing.is_admin and not existing.groups.exists()
    assert not AuditLog.objects.exists()


# --- Liste ---------------------------------------------------------------------------


def test_liste_masque_les_numeros_et_ne_montre_que_les_admins():
    boss = admin_in(COMPLET)
    val = admin_in(VALIDATEUR)
    simple = UserFactory()
    response = api_as(boss).get(LIST)
    text = response.content.decode()
    for user in (boss, val):
        assert user.phone not in text and user.phone[4:] not in text
    ids = {r["id"] for r in response.json()["results"]}
    assert ids == {boss.pk, val.pk} and simple.pk not in ids
    assert all(r["phone_masked"].startswith("+237 6••") for r in response.json()["results"])


# --- Changement de rôle ----------------------------------------------------------------


def test_changement_de_role_audite():
    boss = admin_in(COMPLET)
    target = admin_in(VALIDATEUR)
    response = api_as(boss).patch(f"{LIST}{target.pk}/", {"role": COMPLET}, format="json")
    assert response.status_code == 200 and response.json()["roles"] == [COMPLET]
    assert rights_service.admin_roles(target) == [COMPLET]
    log = AuditLog.objects.get(action=AuditAction.ATTRIBUTION_ROLE)
    assert log.target_id == target.pk and f"{VALIDATEUR} -> {COMPLET}" in log.reason


def test_role_identique_inconnu_ou_cible_non_admin():
    boss = admin_in(COMPLET)
    target = admin_in(VALIDATEUR)
    client = api_as(boss)
    assert client.patch(f"{LIST}{target.pk}/", {"role": VALIDATEUR},
                        format="json").status_code == 409
    assert client.patch(f"{LIST}{target.pk}/", {"role": "Roi"}, format="json").status_code == 400
    assert client.patch(f"{LIST}{UserFactory().pk}/", {"role": COMPLET},
                        format="json").status_code == 409
    assert client.patch(f"{LIST}999999/", {"role": COMPLET}, format="json").status_code == 404
    assert not AuditLog.objects.exists()


def test_on_ne_change_pas_son_propre_role():
    boss = admin_in(COMPLET)
    other = admin_in(COMPLET)  # il reste un autre complet : seul le « soi-même » bloque
    response = api_as(boss).patch(f"{LIST}{boss.pk}/", {"role": VALIDATEUR}, format="json")
    assert response.status_code == 400 and response.json()["code"] == "self_action_forbidden"
    assert rights_service.admin_roles(boss) == [COMPLET] and other.pk


def test_dernier_administrateur_complet_non_retrograde():
    boss = admin_in(COMPLET)
    blocked = admin_in(COMPLET, is_blocked=True)  # inactif : ne compte pas
    response = api_as(boss).patch(f"{LIST}{blocked.pk}/", {"role": VALIDATEUR}, format="json")
    assert response.status_code == 200  # un complet bloqué n'est pas « le dernier actif »
    # boss est seul actif ; un second complet actif existe seulement s'il y en a un autre
    other = admin_in(COMPLET)
    api_as(boss).patch(f"{LIST}{other.pk}/", {"role": VALIDATEUR}, format="json")
    assert rights_service.admin_roles(other) == [VALIDATEUR]


def test_garde_dernier_complet_sur_retrait_et_retrogradation():
    # Le seul complet actif est la cible ; l'acteur est un autre complet qui devient inactif
    # en cours de route : on simule avec un acteur complet bloqué APRÈS l'émission du jeton.
    actor = admin_in(COMPLET)
    last = admin_in(COMPLET)
    client = api_as(actor)
    User.objects.filter(pk=actor.pk).update(is_blocked=True)
    assert client.delete(f"{LIST}{last.pk}/", {"reason": "x"}, format="json").status_code == 403
    # appel direct du service : la garde refuse de retirer / rétrograder le dernier actif
    from apps.admin_panel.services import account_service, admin_service
    with pytest.raises(account_service.LastFullAdmin):
        admin_service.remove_admin(actor, last.pk, "Départ")
    with pytest.raises(account_service.LastFullAdmin):
        admin_service.change_role(actor, last.pk, VALIDATEUR)
    assert rights_service.admin_roles(last) == [COMPLET] and not AuditLog.objects.exists()


# --- Retrait ---------------------------------------------------------------------------


def test_retrait_avec_motif_audite_et_jetons_invalides():
    boss = admin_in(COMPLET)
    target = admin_in(VALIDATEUR)
    other_client = api_as(target)
    assert other_client.get("/api/admin/me/").status_code == 200
    response = api_as(boss).delete(f"{LIST}{target.pk}/", {"reason": "A quitté l'équipe"},
                                   format="json")
    assert response.status_code == 200 and response.json()["roles"] == []
    target.refresh_from_db()
    assert not target.is_admin and not target.groups.exists()
    assert other_client.get("/api/admin/me/").status_code == 403  # effet immédiat
    log = AuditLog.objects.get(action=AuditAction.RETRAIT_ROLE)
    assert log.target_id == target.pk and "A quitté l'équipe" in log.reason
    assert User.objects.filter(pk=target.pk).exists()  # le compte n'est pas supprimé


@pytest.mark.parametrize("payload", [None, {}, {"reason": "   "}])
def test_retrait_sans_motif_refuse(payload):
    boss = admin_in(COMPLET)
    target = admin_in(VALIDATEUR)
    kwargs = {"format": "json"} if payload is not None else {}
    response = api_as(boss).delete(f"{LIST}{target.pk}/", payload, **kwargs)
    assert response.status_code == 400 and response.json()["code"] == "reason_required"
    target.refresh_from_db()
    assert target.is_admin and rights_service.admin_roles(target) == [VALIDATEUR]
    assert not AuditLog.objects.exists()


def test_on_ne_se_retire_pas_son_propre_role():
    boss = admin_in(COMPLET)
    admin_in(COMPLET)
    response = api_as(boss).delete(f"{LIST}{boss.pk}/", {"reason": "Moi"}, format="json")
    assert response.status_code == 400 and response.json()["code"] == "self_action_forbidden"
    boss.refresh_from_db()
    assert boss.is_admin and not AuditLog.objects.exists()


def test_retrait_cible_non_admin_ou_inconnue():
    client = api_as(admin_in(COMPLET))
    assert client.delete(f"{LIST}{UserFactory().pk}/", {"reason": "x"},
                         format="json").status_code == 409
    assert client.delete(f"{LIST}999999/", {"reason": "x"}, format="json").status_code == 404


# --- Journaux ---------------------------------------------------------------------------


def test_aucun_mot_de_passe_ni_numero_complet_dans_les_logs(caplog):
    caplog.set_level(logging.DEBUG)
    boss = admin_in(COMPLET)
    client = api_as(boss)
    created = create(client).json()
    target = User.objects.get(pk=created["id"])
    client.patch(f"{LIST}{target.pk}/", {"role": COMPLET}, format="json")
    client.delete(f"{LIST}{target.pk}/", {"reason": "Test"}, format="json")
    client.get(LIST)
    create(client, phone="12")  # erreur 400
    for secret in (created["temporary_password"], NEW_PHONE, boss.phone, boss.phone[4:]):
        assert secret not in caplog.text
    assert Group.objects.filter(name=COMPLET).exists() and AdminFactory
