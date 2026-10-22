"""Comptes (T072) : liste, détail, blocage, suppression douce, restauration, droits, audit.
Numéros par les fabriques ; mots de passe générés à l'exécution ; aucun secret écrit."""
import logging
import re
import secrets
from unittest import mock

import pytest
from django.contrib.auth.models import Group
from django.core.cache import cache
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.accounts.services.token_service import issue_tokens
from apps.admin_panel.models import AuditAction, AuditLog
from apps.admin_panel.services import audit_service
from apps.business.models import AccountType, BusinessStatus
from apps.search.tests.helpers import shop
from tests.factories.business_factory import make_owner, make_profile
from tests.factories.storage_factory import make_stored_file
from tests.factories.user_factory import AdminFactory, UserFactory
from tests.factories.zone_factory import make_maroua_chain

pytestmark = pytest.mark.django_db

LIST = "/api/admin/accounts/"
VALIDATEUR, COMPLET = "Validateur", "Administrateur complet"


@pytest.fixture(autouse=True)
def _env(settings):
    settings.DEBUG = True
    settings.SMS_PROVIDER = "console"
    cache.clear()
    yield
    cache.clear()


def admin_in(group, **extra):
    admin = AdminFactory(**extra)
    admin.groups.add(Group.objects.get(name=group))
    return admin


def api_as(user):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    return client


def url(user, action=""):
    return f"{LIST}{user.pk}/{action}"


# --- Droits de chaque route -----------------------------------------------------------


ROUTES = [
    ("get", LIST, None, "voir"),
    ("get", "{u}", None, "voir"),
    ("post", "{u}block/", {"reason": "Fraude"}, "complet"),
    ("post", "{u}unblock/", None, "complet"),
    ("delete", "{u}", {"reason": "Doublon"}, "complet"),
    ("post", "{u}restore/", None, "complet"),
]


def call(client, method, path, body, target):
    path = path.format(u=f"{LIST}{target.pk}/")
    kwargs = {"format": "json"} if body is not None else {}
    return getattr(client, method)(path, body, **kwargs) if body is not None else getattr(
        client, method)(path)


@pytest.mark.parametrize("method,path,body,level", ROUTES)
def test_permissions_par_route(method, path, body, level):
    target = UserFactory()
    # anonyme : 401
    assert call(APIClient(), method, path, body, target).status_code == 401
    # simple utilisateur, admin sans groupe : 403
    assert call(api_as(UserFactory()), method, path, body, target).status_code == 403
    assert call(api_as(AdminFactory()), method, path, body, target).status_code == 403
    # Validateur : lecture seulement
    validateur = call(api_as(admin_in(VALIDATEUR)), method, path, body, target)
    assert validateur.status_code == (200 if level == "voir" else 403)
    assert not AuditLog.objects.filter(action__in=[
        AuditAction.BLOCAGE_COMPTE, AuditAction.SUPPRESSION_COMPTE]).exists()
    target.refresh_from_db()
    assert not target.is_blocked and not target.is_deleted
    # Administrateur complet : jamais 401/403
    assert call(api_as(admin_in(COMPLET)), method, path, body, target).status_code not in (
        401, 403)


# --- Liste ------------------------------------------------------------------------------


def make_accounts():
    simple = UserFactory(name="Alice Simple")
    biz = make_profile(name="Chez Riz", status=BusinessStatus.ACTIVE)
    blocked = UserFactory(name="Bob Bloqué", is_blocked=True)
    return simple, biz.owner, blocked


def ids_of(response):
    assert response.status_code == 200, response.content
    return {row["id"] for row in response.json()["results"]}


def test_liste_filtres_type():
    simple, biz_owner, blocked = make_accounts()
    client = api_as(admin_in(VALIDATEUR))
    assert {simple.pk, biz_owner.pk, blocked.pk} <= ids_of(client.get(LIST))
    assert ids_of(client.get(LIST, {"type": "blocked"})) == {blocked.pk}
    business = ids_of(client.get(LIST, {"type": "business"}))
    assert business == {biz_owner.pk}
    simples = ids_of(client.get(LIST, {"type": "simple"}))
    assert simple.pk in simples and biz_owner.pk not in simples
    assert client.get(LIST, {"type": "nimportequoi"}).json()["code"] == "invalid_type"


def test_liste_filtre_zone_et_sous_zone():
    make_maroua_chain()
    from apps.geo.models import Zone, ZoneLevel

    quartier = Zone.objects.filter(level=ZoneLevel.QUARTIER).first()
    in_zone = make_profile(zone=quartier, status=BusinessStatus.ACTIVE).owner
    make_owner()
    client = api_as(admin_in(VALIDATEUR))
    assert ids_of(client.get(LIST, {"zone": quartier.pk})) == {in_zone.pk}
    ville = quartier.parent  # le sous-arbre de la ville contient le quartier
    assert in_zone.pk in ids_of(client.get(LIST, {"zone": ville.pk}))
    assert client.get(LIST, {"zone": 999999}).json()["code"] == "invalid_zone"
    assert client.get(LIST, {"zone": "abc"}).status_code == 400


def test_recherche_nom_validateur_et_complet():
    biz_owner = make_profile(name="Quincaillerie du Port", status=BusinessStatus.ACTIVE).owner
    other = UserFactory(name="Zoé Autre")
    for group in (VALIDATEUR, COMPLET):
        client = api_as(admin_in(group))
        assert ids_of(client.get(LIST, {"q": "quincaillerie"})) == {biz_owner.pk}
        assert ids_of(client.get(LIST, {"q": "zoé"})) == {other.pk}
        assert ids_of(client.get(LIST, {"q": "introuvable-xyz"})) == set()


def test_recherche_par_numero_reservee_a_l_administrateur_complet():
    target = UserFactory(name="Cible")
    digits = target.phone[4:]
    forms = (digits, target.phone, f"{digits[:3]} {digits[3:6]} {digits[6:]}")
    validateur = api_as(admin_in(VALIDATEUR))
    for query in forms:
        assert target.pk not in ids_of(validateur.get(LIST, {"q": query}))
    complet = api_as(admin_in(COMPLET))
    for query in forms:
        response = complet.get(LIST, {"q": query})
        assert ids_of(response) == {target.pk}
        body = response.content.decode()
        assert digits not in body and target.phone not in body
        (row,) = response.json()["results"]
        assert row["phone_masked"] == f"+237 6•• •• •• {digits[-2:]}"


def test_nombre_de_requetes_de_la_liste_constant():
    from django.db import connection
    from django.test.utils import CaptureQueriesContext

    client = api_as(admin_in(COMPLET))

    def count():
        with CaptureQueriesContext(connection) as ctx:
            assert client.get(LIST, {"page_size": 50}).status_code == 200
        return len(ctx)

    for _ in range(2):
        make_profile(status=BusinessStatus.ACTIVE)
    small = count()
    for _ in range(8):
        make_profile(status=BusinessStatus.ACTIVE)
        UserFactory()
    assert count() == small


def test_dernier_administrateur_complet_ne_peut_etre_bloque_ni_supprime():
    from apps.admin_panel.services import account_service

    last = admin_in(COMPLET)
    actor = AdminFactory()  # n'est pas dans le groupe : n'est pas compté comme complet
    with pytest.raises(account_service.LastFullAdmin) as err:
        account_service.block(actor, last.pk, "Test")
    assert err.value.status_code == 409
    with pytest.raises(account_service.LastFullAdmin):
        account_service.soft_delete(actor, last.pk, "Test")
    last.refresh_from_db()
    assert not last.is_blocked and not last.is_deleted and not AuditLog.objects.exists()
    # avec un autre Administrateur complet actif, c'est permis
    other = admin_in(COMPLET)
    assert api_as(other).post(url(last, "block/"), {"reason": "Test"}, format="json"
                              ).status_code == 200


def test_liste_pagination_et_aucun_numero_complet():
    for _ in range(5):
        UserFactory()
    client = api_as(admin_in(COMPLET))  # même l'Administrateur complet : masqué en liste
    body = client.get(LIST, {"page_size": 2}).json()
    assert len(body["results"]) == 2 and body["count"] >= 6 and body["next"]
    raw = client.get(LIST, {"page_size": 50}).content.decode()
    for user in User.objects.all():
        assert user.phone not in raw and user.phone[4:] not in raw


# --- Blocage ------------------------------------------------------------------------------


def test_bloquer_exige_un_motif_et_n_ecrit_rien():
    target = UserFactory()
    client = api_as(admin_in(COMPLET))
    for body in ({}, {"reason": ""}, {"reason": "   "}):
        response = client.post(url(target, "block/"), body, format="json")
        assert response.status_code == 400 and response.json()["code"] == "reason_required"
    response = client.post(url(target, "block/"), {"reason": "x" * 256}, format="json")
    assert response.status_code == 400
    target.refresh_from_db()
    assert not target.is_blocked and target.blocked_reason == ""
    assert not AuditLog.objects.exists()


def test_bloquer_debloquer_ecrit_etat_et_audit():
    target = UserFactory()
    admin = admin_in(COMPLET)
    client = api_as(admin)
    response = client.post(url(target, "block/"), {"reason": " Fraude "}, format="json")
    assert response.status_code == 200 and response.json()["status"] == "bloque"
    target.refresh_from_db()
    assert target.is_blocked and target.blocked_reason == "Fraude" and target.blocked_at
    entry = AuditLog.objects.get(action=AuditAction.BLOCAGE_COMPTE)
    assert (entry.admin, entry.target_type, entry.target_id, entry.reason) == (
        admin, "accounts.user", target.pk, "Fraude")
    assert client.post(url(target, "block/"), {"reason": "encore"}, format="json"
                       ).status_code == 409
    assert client.post(url(target, "unblock/")).status_code == 200
    target.refresh_from_db()
    assert not target.is_blocked and target.blocked_reason == "" and target.blocked_at is None
    assert AuditLog.objects.filter(action=AuditAction.DEBLOCAGE_COMPTE).count() == 1
    assert client.post(url(target, "unblock/")).status_code == 409


def test_audit_en_echec_annule_le_blocage():
    target = UserFactory()
    client = api_as(admin_in(COMPLET))
    with mock.patch.object(audit_service, "record_action", side_effect=RuntimeError("boom")):
        client.raise_request_exception = False
        response = client.post(url(target, "block/"), {"reason": "Fraude"}, format="json")
    assert response.status_code == 500
    target.refresh_from_db()
    assert not target.is_blocked and target.blocked_reason == ""


def test_compte_inconnu_404():
    client = api_as(admin_in(COMPLET))
    assert client.post(f"{LIST}999999/block/", {"reason": "x"}, format="json"
                       ).status_code == 404
    assert client.get(f"{LIST}999999/").status_code == 404


# --- Suppression douce / restauration ---------------------------------------------------------


def test_supprimer_exige_un_motif_puis_suppression_douce_et_restauration():
    target = UserFactory()
    admin = admin_in(COMPLET)
    client = api_as(admin)
    response = client.delete(url(target))
    assert response.status_code == 400 and response.json()["code"] == "reason_required"
    target.refresh_from_db()
    assert not target.is_deleted and not AuditLog.objects.exists()

    response = client.delete(url(target), {"reason": "Demande du titulaire"}, format="json")
    assert response.status_code == 200 and response.json()["status"] == "supprime"
    assert User.objects.filter(pk=target.pk).exists()  # douce : la ligne reste
    target.refresh_from_db()
    assert target.is_deleted and target.deleted_at
    assert AuditLog.objects.get(action=AuditAction.SUPPRESSION_COMPTE).reason == (
        "Demande du titulaire")
    assert client.delete(url(target), {"reason": "x"}, format="json").status_code == 409
    assert client.post(url(target, "block/"), {"reason": "x"}, format="json"
                       ).status_code == 409
    assert client.post(url(target, "restore/")).status_code == 200
    target.refresh_from_db()
    assert not target.is_deleted and target.deleted_at is None and target.can_login()
    assert AuditLog.objects.filter(action=AuditAction.RESTAURATION_COMPTE).count() == 1
    assert client.post(url(target, "restore/")).status_code == 409


def test_liste_filtre_supprimes():
    target = UserFactory(is_deleted=True)
    client = api_as(admin_in(VALIDATEUR))
    assert ids_of(client.get(LIST, {"type": "deleted"})) == {target.pk}
    row = client.get(LIST, {"type": "deleted"}).json()["results"][0]
    assert row["status"] == "supprime"


def test_un_admin_ne_peut_se_bloquer_ni_se_supprimer():
    admin = admin_in(COMPLET)
    client = api_as(admin)
    for response in (
        client.post(url(admin, "block/"), {"reason": "x"}, format="json"),
        client.delete(url(admin), {"reason": "x"}, format="json"),
    ):
        assert response.status_code == 400
        assert response.json()["code"] == "self_action_forbidden"
    admin.refresh_from_db()
    assert not admin.is_blocked and not admin.is_deleted
    assert not AuditLog.objects.exists()


# --- Effets de bout en bout (T007, T040, T050, calls) ----------------------------------------


def ask_code(client, capsys, phone):
    capsys.readouterr()
    assert client.post("/api/auth/otp/request/", {"phone": phone}, format="json"
                       ).status_code == 202
    return re.search(r"Votre code NetBuis : (\d{6})", capsys.readouterr().out)[1]


def test_compte_bloque_ne_se_connecte_plus_et_disparait(capsys):
    profile = shop("Chez Riz Unique", ["Riz parfumé"])
    owner = profile.owner
    tokens = issue_tokens(owner)
    visitor = api_as(make_owner())
    assert len(visitor.get("/api/search/", {"q": "riz"}).json()["results"]) == 1
    assert visitor.get(f"/api/business/{profile.pk}/").status_code == 200

    admin = admin_in(COMPLET)
    response = api_as(admin).post(url(owner, "block/"), {"reason": "Fraude"}, format="json")
    assert response.status_code == 200

    # jeton d'accès déjà émis
    old = APIClient()
    old.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
    blocked = old.get("/api/me/")
    assert blocked.status_code == 403 and blocked.json()["code"] == "account_blocked"
    # rafraîchissement
    refresh = APIClient().post("/api/auth/refresh/", {"refresh": tokens["refresh"]},
                               format="json")
    assert refresh.status_code in (401, 403)
    # code SMS
    anon = APIClient()
    code = ask_code(anon, capsys, owner.phone)
    verify = anon.post("/api/auth/otp/verify/", {"phone": owner.phone, "code": code},
                       format="json")
    assert verify.status_code == 403 and verify.json()["code"] == "account_blocked"
    # recherche, fiche, appel
    assert visitor.get("/api/search/", {"q": "riz"}).json()["results"] == []
    assert visitor.get(f"/api/business/{profile.pk}/").status_code == 404
    call = visitor.post("/api/calls/whatsapp/", {
        "business_id": profile.pk, "platform": "android"}, format="json")
    assert call.status_code != 200 and profile.phone_anchor not in call.content.decode()

    # un admin bloqué ne se connecte plus au dashboard
    password = secrets.token_urlsafe(16)
    other = admin_in(COMPLET, password=password)
    api_as(admin).post(url(other, "block/"), {"reason": "Départ"}, format="json")
    login = APIClient().post("/api/auth/admin/login/",
                             {"phone": other.phone, "password": password}, format="json")
    assert login.status_code == 401

    # débloqué : tout revient
    api_as(admin).post(url(owner, "unblock/"))
    assert len(visitor.get("/api/search/", {"q": "riz"}).json()["results"]) == 1


def test_compte_supprime_idem_et_profil_masque(capsys):
    profile = shop("Chez Riz Unique", ["Riz parfumé"])
    owner = profile.owner
    tokens = issue_tokens(owner)
    visitor = api_as(make_owner())
    api_as(admin_in(COMPLET)).delete(url(owner), {"reason": "Fraude"}, format="json")

    old = APIClient()
    old.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")
    gone = old.get("/api/me/")
    assert gone.status_code == 403 and gone.json()["code"] == "account_deleted"
    assert APIClient().post("/api/auth/refresh/", {"refresh": tokens["refresh"]},
                            format="json").status_code in (401, 403)
    anon = APIClient()
    code = ask_code(anon, capsys, owner.phone)
    verify = anon.post("/api/auth/otp/verify/", {"phone": owner.phone, "code": code},
                       format="json")
    assert verify.status_code == 403 and verify.json()["code"] == "account_deleted"
    assert visitor.get("/api/search/", {"q": "riz"}).json()["results"] == []
    assert visitor.get(f"/api/business/{profile.pk}/").status_code == 404
    from apps.business.models import BusinessProfile

    assert not BusinessProfile.objects.visible().filter(pk=profile.pk).exists()


# --- Vue détaillée ---------------------------------------------------------------------------


def provider_with_files():
    owner = make_owner(name="Paul Prestataire")
    return make_profile(
        AccountType.PRESTATAIRE_SERVICE, owner=owner,
        photo=make_stored_file(owner, "photo"),
        cni_photo=make_stored_file(owner, "cni_photo"),
        diplome_photo=make_stored_file(owner, "diplome_photo"),
    )


def test_detail_complet_numero_complet_audite_et_pieces_signees():
    profile = provider_with_files()
    owner = profile.owner
    admin = admin_in(COMPLET)
    client = api_as(admin)
    api_as(admin).post(url(owner, "block/"), {"reason": "Vérification"}, format="json")
    api_as(admin).post(url(owner, "unblock/"))

    response = client.get(url(owner))
    assert response.status_code == 200 and response["Cache-Control"] == "no-store"
    body = response.json()
    assert body["phone"] == owner.phone
    assert body["phone_masked"].startswith("+237 6••")
    assert body["type"] == "business" and body["name"] == "Paul Prestataire"
    assert body["business"]["id"] == profile.pk
    assert body["business"]["cni_url"] and body["business"]["diplome_url"]
    assert "prive/" not in body["business"]["cni_url"]
    assert [h["action"] for h in body["status_history"]] == [
        "deblocage_compte", "blocage_compte"]
    assert body["status_history"][1]["reason"] == "Vérification"
    assert body["recent_audit"][0]["admin_name"] == admin.name
    # chaque affichage du numéro complet est audité
    assert AuditLog.objects.filter(action=AuditAction.CONSULTATION_NUMERO,
                                   target_id=owner.pk, admin=admin).count() == 1
    client.get(url(owner))
    assert AuditLog.objects.filter(action=AuditAction.CONSULTATION_NUMERO).count() == 2


def test_detail_validateur_voit_le_masque_et_rien_n_est_audite():
    profile = provider_with_files()
    owner = profile.owner
    response = api_as(admin_in(VALIDATEUR)).get(url(owner))
    assert response.status_code == 200
    body = response.json()
    assert body["phone"] is None and body["phone_masked"].startswith("+237 6••")
    raw = response.content.decode()
    assert owner.phone not in raw and owner.phone[4:] not in raw
    assert profile.phone_anchor not in raw and profile.phone_anchor[4:] not in raw
    assert not AuditLog.objects.filter(action=AuditAction.CONSULTATION_NUMERO).exists()


def test_detail_compte_simple_sans_profil():
    owner = UserFactory(name="Simple")
    body = api_as(admin_in(COMPLET)).get(url(owner)).json()
    assert body["type"] == "simple" and body["business"] is None
    assert body["status"] == "actif"


# --- Journaux ---------------------------------------------------------------------------------


def test_aucun_numero_jeton_ni_lien_signe_dans_les_logs(caplog):
    logging.disable(logging.NOTSET)
    caplog.set_level(logging.DEBUG)
    profile = provider_with_files()
    owner = profile.owner
    admin = admin_in(COMPLET)
    client = api_as(admin)
    access = client._credentials["HTTP_AUTHORIZATION"].split()[1]
    detail = client.get(url(owner)).json()
    client.post(url(owner, "block/"), {"reason": "Fraude"}, format="json")
    client.post(url(owner, "unblock/"))
    client.delete(url(owner), {"reason": "Fraude"}, format="json")
    client.post(url(owner, "restore/"))
    client.get(LIST, {"q": owner.phone[4:]})
    signed = detail["business"]["cni_url"].rstrip("/").rsplit("/", 1)[1]
    for secret in (owner.phone, owner.phone[4:], profile.phone_anchor,
                   profile.phone_anchor[4:], access, signed):
        assert secret not in caplog.text
