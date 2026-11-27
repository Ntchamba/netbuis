"""T110 : POST /api/admin/subscriptions/ (accorder un abonnement, sans paiement)."""
import json
import re
from datetime import timedelta
from unittest import mock

import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from rest_framework.test import APIClient

from apps.admin_panel.models import AuditAction, AuditLog
from apps.admin_panel.services import audit_service
from apps.business.models import (
    BusinessStatus,
    Subscription,
    SubscriptionSource,
    SubscriptionStatus,
)
from apps.business.services.subscription import is_subscribed
from apps.search.services.search_service import search
from apps.search.tests.helpers import ids, shop
from tests.factories.business_factory import get_sector, make_owner, make_profile, make_subscription
from tests.factories.catalog_factory import make_subcategory
from tests.factories.user_factory import UserFactory

from ._t074 import COMPLET, VALIDATEUR, admin_in, api_as

pytestmark = pytest.mark.django_db
URL = "/api/admin/subscriptions/"


def body(profile, **extra):
    return {"business_id": profile.pk, "duration_days": 30, "reason": "Geste commercial", **extra}


def test_accord_reussi_cree_l_abonnement_et_l_audit():
    admin = admin_in(COMPLET, name="Chef")
    profile = shop("Boutique A", ["Riz"])
    avant = timezone.now()
    response = api_as(admin).post(URL, body(profile), format="json")
    assert response.status_code == 201, response.content
    sub = Subscription.objects.get()
    assert (sub.profile_id, sub.source, sub.status, sub.granted_by_id) == (
        profile.pk, SubscriptionSource.MANUAL, SubscriptionStatus.ACTIVE, admin.pk)
    assert avant <= sub.start <= timezone.now()
    assert sub.end - sub.start == timedelta(days=30)
    data = response.json()
    assert data["id"] == sub.pk and data["business_id"] == profile.pk
    assert data["business_name"] == "Boutique A" and data["granted_by_id"] == admin.pk
    assert data["granted_by_name"] == "Chef"
    assert data["source"] == "manuel" and data["status"] == "actif"
    assert set(data) == {"id", "business_id", "business_name", "start", "end", "status",
                         "source", "granted_by_id", "granted_by_name"}
    assert "no-store" in response["Cache-Control"]
    log = AuditLog.objects.get()
    assert (log.admin_id, log.action, log.target_type, log.target_id, log.reason) == (
        admin.pk, AuditAction.ACCORD_ABONNEMENT, "business.subscription", sub.pk,
        "Geste commercial")


def test_effet_immediat_abonne_plafond_leve_et_classement():
    from apps.accounts.services.token_service import issue_tokens

    owner = make_owner()
    profile = make_profile(owner=owner, status=BusinessStatus.ACTIVE, name="Zeta")
    autre = shop("Alpha", ["Riz"])
    zeta = shop("Zzz", ["Riz"])
    assert not is_subscribed(profile)
    subs = [make_subcategory(get_sector(), f"s{i}", f"S{i}").pk for i in range(4)]
    mobile = APIClient()
    mobile.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(owner)['access']}")
    assert mobile.patch("/api/business/me/", {"sous_categories": subs},
                        format="json").status_code == 400
    # classement avant accord : ordre stable, aucun abonné
    assert api_as(admin_in(COMPLET)).post(URL, body(zeta), format="json").status_code == 201
    assert is_subscribed(zeta) and not is_subscribed(autre)
    assert ids(search("riz"))[0] == zeta.pk
    # plafond levé pour le profil abonné
    api_as(admin_in(COMPLET)).post(URL, body(profile), format="json")
    assert is_subscribed(profile)
    assert mobile.patch("/api/business/me/", {"sous_categories": subs},
                        format="json").status_code == 200


def test_validateur_refuse_et_rien_n_est_ecrit():
    profile = shop("B")
    assert api_as(admin_in(VALIDATEUR)).post(URL, body(profile), format="json"
                                             ).status_code == 403
    assert api_as(UserFactory()).post(URL, body(profile), format="json").status_code == 403
    assert Subscription.objects.count() == 0 and AuditLog.objects.count() == 0


def test_non_connecte_401():
    assert APIClient().post(URL, body(shop("B")), format="json").status_code == 401


@pytest.mark.parametrize("reason", [None, "", "   "])
def test_motif_obligatoire(reason):
    profile = shop("B")
    payload = body(profile)
    if reason is None:
        del payload["reason"]
    else:
        payload["reason"] = reason
    response = api_as(admin_in(COMPLET)).post(URL, payload, format="json")
    assert response.status_code == 400
    assert Subscription.objects.count() == 0 and AuditLog.objects.count() == 0


def test_motif_trop_long_400():
    profile = shop("B")
    response = api_as(admin_in(COMPLET)).post(
        URL, body(profile, reason="x" * (audit_service.MAX_REASON + 1)), format="json")
    assert response.status_code == 400 and Subscription.objects.count() == 0


@pytest.mark.parametrize("days", [0, -5, 367, 1.5, "abc", None])
def test_duree_invalide_400(days):
    profile = shop("B")
    response = api_as(admin_in(COMPLET)).post(
        URL, body(profile, duration_days=days), format="json")
    assert response.status_code == 400, days
    assert Subscription.objects.count() == 0 and AuditLog.objects.count() == 0


@pytest.mark.parametrize("days", [1, 366])
def test_durees_limites_acceptees(days):
    profile = shop("B")
    response = api_as(admin_in(COMPLET)).post(
        URL, body(profile, duration_days=days), format="json")
    assert response.status_code == 201
    sub = Subscription.objects.get()
    assert sub.end - sub.start == timedelta(days=days)


@pytest.mark.parametrize("business_id", [999999, "x", None])
def test_commerce_inconnu_ou_identifiant_invalide(business_id):
    response = api_as(admin_in(COMPLET)).post(
        URL, {"business_id": business_id, "duration_days": 5, "reason": "ok"}, format="json")
    assert response.status_code in (400, 404)
    if business_id == 999999:
        assert response.status_code == 404 and response.json()["code"] == "not_found"
    assert Subscription.objects.count() == 0


def test_commerce_supprime_404():
    profile = shop("B")
    profile.owner.is_deleted = True
    profile.owner.save()
    response = api_as(admin_in(COMPLET)).post(URL, body(profile), format="json")
    assert response.status_code == 404 and Subscription.objects.count() == 0


@pytest.mark.parametrize("etat", ["pending", "rejected", "bloque"])
def test_commerce_non_actif_409(etat):
    profile = shop("B")
    if etat == "bloque":
        profile.owner.is_blocked = True
        profile.owner.save()
    else:
        profile.status = BusinessStatus.PENDING if etat == "pending" else BusinessStatus.REJECTED
        profile.save()
    response = api_as(admin_in(COMPLET)).post(URL, body(profile), format="json")
    assert response.status_code == 409 and response.json()["code"] == "business_not_active"
    assert Subscription.objects.count() == 0 and AuditLog.objects.count() == 0


def test_double_accord_refuse_409_sans_cumul():
    profile = shop("B", subscribed=True)
    response = api_as(admin_in(COMPLET)).post(URL, body(profile), format="json")
    assert response.status_code == 409 and response.json()["code"] == "already_subscribed"
    assert Subscription.objects.count() == 1 and AuditLog.objects.count() == 0


def test_nouvel_accord_possible_apres_echeance():
    profile = shop("B")
    make_subscription(profile, start=timezone.now() - timedelta(days=40),
                      end=timezone.now() - timedelta(days=1))
    response = api_as(admin_in(COMPLET)).post(URL, body(profile), format="json")
    assert response.status_code == 201 and is_subscribed(profile)
    assert Subscription.objects.count() == 2


def test_atomicite_si_l_audit_echoue_rien_n_est_cree():
    profile = shop("B")
    client = api_as(admin_in(COMPLET))
    client.raise_request_exception = False
    with mock.patch.object(audit_service.AuditLog.objects, "create",
                           side_effect=RuntimeError("panne audit")):
        response = client.post(URL, body(profile), format="json")
    assert response.status_code == 500
    assert Subscription.objects.count() == 0 and not is_subscribed(profile)


def test_reponse_sans_numero_ni_donnee_personnelle():
    owner = make_owner(name="Marie Dupont")
    profile = make_profile(owner=owner, status=BusinessStatus.ACTIVE, name="Chez Marie")
    response = api_as(admin_in(COMPLET)).post(URL, body(profile), format="json")
    assert response.status_code == 201
    text = json.dumps(response.json())
    phone = owner.phone
    assert phone not in text and phone.lstrip("+") not in text and phone[-8:] not in text
    assert not re.search(r"\+?237\d|\b6\d{8}\b", text) and "Marie Dupont" not in text
    assert "phone" not in text


def test_pas_de_n_plus_un():
    """Nombre de requêtes constant d'un accord à l'autre (après un premier appel d'échauffement)."""
    client = api_as(admin_in(COMPLET))
    assert client.post(URL, body(shop("A")), format="json").status_code == 201
    comptes = []
    for nom in ("B", "C", "D"):
        profile = shop(nom)
        with CaptureQueriesContext(connection) as ctx:
            assert client.post(URL, body(profile), format="json").status_code == 201
        comptes.append(len(ctx))
    assert len(set(comptes)) == 1 and comptes[0] <= 15, comptes


def test_get_reste_en_lecture_pour_le_validateur():
    assert api_as(admin_in(VALIDATEUR)).get(URL).status_code == 200
