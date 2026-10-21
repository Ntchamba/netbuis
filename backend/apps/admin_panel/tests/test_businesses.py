"""Demandes de compte business (T071) : file d'attente, validation, rejet, pièces privées.
Numéros de test générés par les fabriques ; aucun secret écrit."""
import logging
from unittest import mock

import pytest
from django.conf import settings
from django.contrib.auth.models import Group
from django.core.cache import cache
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.admin_panel.models import AuditLog
from apps.admin_panel.services import rights_service as rights
from apps.business.models import AccountType, BusinessProfile, BusinessStatus
from apps.business.services.storage_service import get_storage
from tests.factories.business_factory import make_owner, make_profile
from tests.factories.storage_factory import JPEG_BYTES, make_stored_file
from tests.factories.user_factory import AdminFactory, UserFactory

pytestmark = pytest.mark.django_db

LIST = "/api/admin/requests/"
PREFIX = settings.PRIVATE_DOWNLOAD_URL_PREFIX


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()
    yield
    cache.clear()


def admin_in(group):
    admin = AdminFactory()
    admin.groups.add(Group.objects.get(name=group))
    return admin


def api_as(user):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    return client


def pending_provider():
    owner = make_owner()
    return make_profile(
        AccountType.PRESTATAIRE_SERVICE, owner=owner,
        photo=make_stored_file(owner, "photo"),
        cni_photo=make_stored_file(owner, "cni_photo"),
        diplome_photo=make_stored_file(owner, "diplome_photo"),
    )


def approve(client, profile):
    return client.post(f"{LIST}{profile.pk}/approve/")


def reject(client, profile, reason=None):
    data = {} if reason is None else {"reason": reason}
    return client.post(f"{LIST}{profile.pk}/reject/", data, format="json")


def token_of(url):
    assert url.startswith(PREFIX)
    return url.rstrip("/").rsplit("/", 1)[1]


# --- File d'attente ------------------------------------------------------------------


def test_file_d_attente_paginee_les_plus_anciens_d_abord():
    first, second, third = (make_profile() for _ in range(3))
    client = api_as(admin_in("Validateur"))
    body = client.get(LIST, {"type": "business", "page_size": 2}).json()
    assert body["count"] == 3
    assert [r["id"] for r in body["results"]] == [first.pk, second.pk]
    assert body["next"] is not None
    page2 = client.get(LIST, {"type": "business", "page_size": 2, "page": 2}).json()
    assert [r["id"] for r in page2["results"]] == [third.pk]


def test_file_d_attente_ne_contient_que_les_demandes_en_attente():
    waiting = make_profile()
    make_profile(status=BusinessStatus.ACTIVE)
    make_profile(status=BusinessStatus.REJECTED, motif_rejet="Photo floue")
    make_profile(owner=make_owner(is_deleted=True))
    body = api_as(admin_in("Validateur")).get(LIST, {"type": "business"}).json()
    assert [r["id"] for r in body["results"]] == [waiting.pk]


def test_type_inconnu_refuse():
    response = api_as(admin_in("Validateur")).get(LIST, {"type": "autre"})
    assert response.status_code == 400
    assert response.json()["code"] == "invalid_type"


def test_prestataire_a_cni_et_diplome_en_urls_signees_et_photos():
    profile = pending_provider()
    admin = admin_in("Validateur")
    item = api_as(admin).get(LIST, {"type": "business"}).json()["results"][0]
    assert item["cni_url"].startswith(PREFIX) and item["diplome_url"].startswith(PREFIX)
    assert item["photo_url"] == get_storage().public_url(profile.photo)
    assert item["representant_photo_url"] is None  # clé non valide dans la fabrique
    assert profile.cni_photo not in str(item) and profile.diplome_photo not in str(item)


def test_commerce_sans_pieces_privees():
    make_profile()
    item = api_as(admin_in("Validateur")).get(LIST).json()["results"][0]
    assert item["cni_url"] is None and item["diplome_url"] is None


def test_numero_complet_jamais_dans_les_reponses_admin():
    profile = pending_provider()
    full = [profile.phone_anchor, profile.phone_anchor[4:], profile.owner.phone]
    client = api_as(admin_in("Validateur"))
    listing = client.get(LIST)
    masked = listing.json()["results"][0]["phone_masked"]
    assert masked == "+237 6•• •• •• " + profile.phone_anchor[-2:]
    other = make_profile()
    responses = [listing, approve(client, profile), reject(client, other, "Photo floue"),
                 reject(client, other, "encore"), approve(client, other)]
    for response in responses:
        text = response.content.decode()
        assert not any(number in text for number in full + [other.phone_anchor[4:]])


# --- Permissions ---------------------------------------------------------------------


def test_anonyme_401():
    profile = make_profile()
    client = APIClient()
    assert client.get(LIST).status_code == 401
    assert approve(client, profile).status_code == 401
    assert reject(client, profile, "x").status_code == 401


@pytest.mark.parametrize("who", ["simple", "admin_sans_groupe", "groupe_sans_admin"])
def test_non_admin_ou_sans_groupe_403(who):
    profile = make_profile()
    user = {"simple": UserFactory, "admin_sans_groupe": AdminFactory,
            "groupe_sans_admin": UserFactory}[who]()
    if who == "groupe_sans_admin":
        user.groups.add(Group.objects.get(name="Validateur"))
    client = api_as(user)
    assert client.get(LIST).status_code == 403
    assert approve(client, profile).status_code == 403
    assert reject(client, profile, "x").status_code == 403
    profile.refresh_from_db()
    assert profile.status == BusinessStatus.PENDING
    assert not AuditLog.objects.exists()


def test_validateur_peut_valider_et_rejeter():
    assert rights.has_admin_permission(admin_in("Validateur"), rights.VALIDER_DEMANDE)
    client = api_as(admin_in("Validateur"))
    a, b = make_profile(), make_profile()
    assert approve(client, a).status_code == 200
    assert reject(client, b, "Photo floue").status_code == 200


def test_sans_peut_valider_demande_lecture_seule():
    Group.objects.get(name="Validateur").permissions.remove(
        *Group.objects.get(name="Validateur").permissions.filter(
            codename=rights.VALIDER_DEMANDE)
    )
    profile = make_profile()
    client = api_as(admin_in("Validateur"))
    assert client.get(LIST).status_code == 200
    assert approve(client, profile).status_code == 403
    assert reject(client, profile, "x").status_code == 403


def test_sans_peut_voir_demandes_liste_et_pieces_refusees():
    Group.objects.get(name="Validateur").permissions.remove(
        *Group.objects.get(name="Validateur").permissions.filter(codename=rights.VOIR_DEMANDES)
    )
    admin = admin_in("Validateur")
    url = get_storage().private_download_url(
        make_stored_file(make_owner(), "cni_photo"), admin_id=admin.pk)
    client = api_as(admin)
    assert client.get(LIST).status_code == 403
    assert client.get(url).status_code == 403


# --- Validation / rejet ---------------------------------------------------------------


def test_approve_prestataire_actif_et_cni_verifiee_puis_lu_par_le_proprietaire():
    profile = pending_provider()
    admin = admin_in("Validateur")
    response = approve(api_as(admin), profile)
    assert response.status_code == 200
    assert response.json() == {
        "id": profile.pk, "status": "actif", "cni_verifiee": True, "motif_rejet": ""}
    profile.refresh_from_db()
    assert profile.status == BusinessStatus.ACTIVE and profile.cni_verifiee is True
    me = api_as(profile.owner).get("/api/business/me/").json()
    assert me["status"] == "actif" and me["cni_verifiee"] is True
    log = AuditLog.objects.get()
    assert (log.admin, log.action, log.target_type, log.target_id, log.reason) == (
        admin, "validation_business", "business.businessprofile", profile.pk, "")


def test_approve_commerce_n_a_pas_de_cni_verifiee():
    profile = make_profile()
    approve(api_as(admin_in("Validateur")), profile)
    profile.refresh_from_db()
    assert profile.status == BusinessStatus.ACTIVE and profile.cni_verifiee is False
    assert BusinessProfile.objects.visible().filter(pk=profile.pk).exists()


def test_reject_enregistre_le_motif_visible_du_proprietaire_et_l_audit():
    profile = pending_provider()
    admin = admin_in("Administrateur complet")
    response = reject(api_as(admin), profile, "  CNI illisible  ")
    assert response.status_code == 200
    assert response.json()["status"] == "rejete"
    me = api_as(profile.owner).get("/api/business/me/").json()
    assert me["status"] == "rejete" and me["motif_rejet"] == "CNI illisible"
    assert me["cni_verifiee"] is False
    log = AuditLog.objects.get()
    assert (log.action, log.target_id, log.reason, log.admin) == (
        "rejet_business", profile.pk, "CNI illisible", admin)
    assert not BusinessProfile.objects.visible().filter(pk=profile.pk).exists()


@pytest.mark.parametrize("body", [None, "", "   "])
def test_reject_sans_motif_refuse_et_rien_ne_change(body):
    profile = make_profile()
    response = reject(api_as(admin_in("Validateur")), profile, body)
    assert response.status_code == 400
    assert response.json()["code"] == "reason_required"
    profile.refresh_from_db()
    assert profile.status == BusinessStatus.PENDING and profile.motif_rejet == ""
    assert not AuditLog.objects.exists()


def test_reject_motif_trop_long_refuse():
    profile = make_profile()
    response = reject(api_as(admin_in("Validateur")), profile, "x" * 1001)
    assert response.status_code == 400
    profile.refresh_from_db()
    assert profile.status == BusinessStatus.PENDING


def test_demande_deja_traitee_409_sans_second_audit():
    admin_client = api_as(admin_in("Validateur"))
    done, refused = make_profile(), make_profile()
    approve(admin_client, done)
    reject(admin_client, refused, "Photo floue")
    assert AuditLog.objects.count() == 2
    for profile in (done, refused):
        for response in (approve(admin_client, profile),
                         reject(admin_client, profile, "encore")):
            assert response.status_code == 409
            assert response.json()["code"] == "already_processed"
    done.refresh_from_db()
    refused.refresh_from_db()
    assert done.status == BusinessStatus.ACTIVE
    assert refused.status == BusinessStatus.REJECTED and refused.motif_rejet == "Photo floue"
    assert AuditLog.objects.count() == 2


def test_demande_inconnue_404():
    client = api_as(admin_in("Validateur"))
    assert client.post(f"{LIST}999999/approve/").status_code == 404
    assert client.post(f"{LIST}999999/reject/", {"reason": "x"}, format="json").status_code == 404


def test_si_l_audit_echoue_le_statut_ne_change_pas():
    profile = make_profile()
    admin = admin_in("Validateur")
    with mock.patch("apps.admin_panel.services.request_service.audit_service.record_action",
                    side_effect=RuntimeError("panne")), pytest.raises(RuntimeError):
        from apps.admin_panel.services import request_service
        request_service.approve(admin, profile)
    profile.refresh_from_db()
    assert profile.status == BusinessStatus.PENDING


# --- Pièces privées -------------------------------------------------------------------


def test_admin_du_lien_lit_la_cni():
    profile = pending_provider()
    admin = admin_in("Validateur")
    client = api_as(admin)
    url = client.get(LIST).json()["results"][0]["cni_url"]
    response = client.get(url)
    assert response.status_code == 200
    assert b"".join(response.streaming_content) == JPEG_BYTES
    assert response["Content-Type"] == "image/jpeg"
    assert "no-store" in response["Cache-Control"]
    assert profile.cni_photo not in url


def test_lien_lie_a_l_admin_un_autre_admin_est_refuse():
    pending_provider()
    url = api_as(admin_in("Validateur")).get(LIST).json()["results"][0]["cni_url"]
    other = api_as(admin_in("Administrateur complet"))
    response = other.get(url)
    assert response.status_code == 403 and response.json()["code"] == "invalid_link"


def test_lien_expire_refuse():
    pending_provider()
    client = api_as(admin_in("Validateur"))
    url = client.get(LIST).json()["results"][0]["cni_url"]
    assert client.get(url).status_code == 200
    real = __import__("time").time()
    with mock.patch("time.time", return_value=real + settings.PRIVATE_DOWNLOAD_TTL + 5):
        assert client.get(url).status_code == 403


def test_duree_courte():
    assert 0 < settings.PRIVATE_DOWNLOAD_TTL <= 300


def test_lien_falsifie_ou_devine_refuse():
    pending_provider()
    client = api_as(admin_in("Validateur"))
    token = token_of(client.get(LIST).json()["results"][0]["cni_url"])
    for bad in (token[:-2] + "xx", "abc", token + "a", token.replace(":", "-")):
        assert client.get(f"{PREFIX}{bad}/").status_code == 403
    assert len(token) > 60


def test_jeton_d_envoi_ne_lit_rien():
    owner = make_owner()
    sign = get_storage().create_upload("cni_photo", owner.pk, "image/jpeg", 40)
    client = api_as(admin_in("Validateur"))
    upload_token = sign.upload_url.rstrip("/").rsplit("/", 1)[1]
    assert client.get(f"{PREFIX}{upload_token}/").status_code == 403


def test_lien_sans_connexion_ou_pour_un_non_admin_refuse():
    profile = pending_provider()
    admin = admin_in("Validateur")
    url = get_storage().private_download_url(profile.cni_photo, admin_id=admin.pk)
    assert APIClient().get(url).status_code == 401
    assert api_as(profile.owner).get(url).status_code == 403  # même le propriétaire


def test_cni_non_servie_par_les_routes_publiques_ni_au_proprietaire():
    profile = pending_provider()
    admin_client = api_as(admin_in("Validateur"))
    approve(admin_client, profile)
    profile.refresh_from_db()
    owner = api_as(profile.owner)
    zone = profile.zone_id
    responses = [
        owner.get("/api/business/me/"),
        owner.get(f"/api/business/{profile.pk}/"),
        APIClient().get(f"/api/business/{profile.pk}/"),
        owner.get("/api/search/", {"zone": zone}),
        owner.get(f"/api/map/areas/{zone}/businesses/"),
        owner.get(f"/api/map/cities/{zone}/areas/"),
    ]
    assert responses[0].status_code == 200
    for response in responses:
        text = response.content.decode()
        assert profile.cni_photo not in text
        assert "cni_url" not in text and "private-files" not in text
        assert profile.phone_anchor not in text
    # aucune route publique ne sert l'espace privé
    assert owner.get(f"/media/{profile.cni_photo}").status_code == 404
    assert owner.get(f"/private_media/{profile.cni_photo}").status_code == 404


# --- Journaux -------------------------------------------------------------------------


def test_aucun_lien_signe_ni_numero_ni_jeton_dans_les_logs(caplog):
    caplog.set_level(logging.DEBUG)
    profile = pending_provider()
    other = make_profile()
    admin = admin_in("Validateur")
    access = issue_tokens(admin)["access"]
    client = api_as(admin)
    url = client.get(LIST).json()["results"][0]["cni_url"]
    client.get(url)
    bad = f"{PREFIX}{token_of(url)[:-2]}xx/"
    client.get(bad)  # 403 journalisé par Django avec le chemin
    api_as(admin_in("Administrateur complet")).get(url)
    reject(client, other, "")
    approve(client, profile)
    approve(client, profile)  # 409
    text = caplog.text + "".join(str(r.__dict__) for r in caplog.records)
    for secret in (token_of(url), token_of(url)[:40], token_of(bad), access,
                   profile.phone_anchor, profile.phone_anchor[4:], profile.owner.phone,
                   other.phone_anchor, profile.cni_photo, profile.diplome_photo):
        assert secret not in text
    assert any("[lien masqué]" in r.getMessage() for r in caplog.records)
