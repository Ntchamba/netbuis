"""Canal WhatsApp (T051) : lien wa.me côté serveur, mêmes contrôles que l'appel, signalements."""
import logging

import pytest
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.business.models import BusinessProfile, BusinessStatus
from apps.calls.models import CallChannel, CallLog, WhatsAppReport
from apps.calls.services.whatsapp_service import build_wa_url
from tests.factories.business_factory import make_owner, make_profile

pytestmark = pytest.mark.django_db

INITIATE = "/api/calls/initiate/"
REPORT = "/api/calls/whatsapp-report/"


def connected(user=None):
    client = APIClient()
    user = user or make_owner()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    client.user = user
    return client


def shop(**extra):
    extra.setdefault("status", BusinessStatus.ACTIVE)
    return make_profile(**extra)


def wa(client, profile):
    return client.post(
        INITIATE, {"business_id": profile.pk, "channel": "whatsapp", "platform": "android"},
        format="json",
    )


def test_build_wa_url_digits_prefix_and_encoding():
    url = build_wa_url("+237600000001", "Bonjour & merci")
    assert url == "https://wa.me/237600000001?text=Bonjour%20%26%20merci"
    assert build_wa_url("600 00 00 01", "x").startswith("https://wa.me/237600000001?")


def test_whatsapp_returns_link_and_logs_same_journal():
    profile = shop(name="Chez Riz")
    client = connected()
    response = wa(client, profile)
    assert response.status_code == 200
    data = response.json()
    assert set(data) == {"call_id", "wa_url"}  # pas de numéro brut
    assert data["wa_url"].startswith("https://wa.me/237" + profile.phone_anchor[4:] + "?text=")
    assert "Chez%20Riz" in data["wa_url"]
    assert response["Cache-Control"] == "no-store"
    log = CallLog.objects.get(pk=data["call_id"])
    assert (log.channel, log.caller, log.profile) == ("whatsapp", client.user, profile)
    profile.refresh_from_db()
    assert profile.calls_count == 1


def test_whatsapp_refused_when_unavailable_and_nothing_leaks():
    profile = shop(whatsapp_available=False)
    response = wa(connected(), profile)
    assert response.status_code == 409 and response.json()["code"] == "CHANNEL_UNAVAILABLE"
    assert profile.phone_anchor not in response.content.decode()
    assert not CallLog.objects.exists()


def test_whatsapp_same_refusals_as_call():
    own = shop()
    assert wa(connected(own.owner), own).json()["code"] == "OWN_BUSINESS"
    pending = shop(status=BusinessStatus.PENDING)
    assert wa(connected(), pending).json()["code"] == "BUSINESS_NOT_ACTIVE"
    assert wa(APIClient(), shop()).json()["code"] == "NOT_AUTHENTICATED"
    blocked = connected(make_owner(is_blocked=True))
    assert wa(blocked, shop()).json()["code"] == "ACCOUNT_BLOCKED"


def test_whatsapp_counts_for_rate_limit():
    client = connected()
    for _ in range(5):
        assert wa(client, shop()).status_code == 200
    assert wa(client, shop()).json()["code"] == "RATE_LIMITED"


def test_link_and_number_absent_from_logs(caplog):
    logging.disable(logging.NOTSET)
    caplog.set_level(logging.DEBUG)
    profile = shop()
    response = wa(connected(), profile)
    assert response.status_code == 200
    assert profile.phone_anchor[-8:] not in caplog.text
    assert "wa.me" not in caplog.text


# --- Signalement « pas de WhatsApp » ------------------------------------------------------


def reporter_with_link(profile):
    client = connected()
    assert wa(client, profile).status_code == 200
    return client


def report(client, profile):
    return client.post(REPORT, {"business_id": profile.pk}, format="json")


def test_three_distinct_accounts_disable_whatsapp():
    profile = shop()
    clients = [reporter_with_link(profile) for _ in range(3)]
    for client in clients[:2]:
        assert report(client, profile).status_code == 200
    profile.refresh_from_db()
    assert profile.whatsapp_available is True
    response = report(clients[2], profile)
    assert response.status_code == 200 and response.json() == {"recorded": True}
    profile.refresh_from_db()
    assert profile.whatsapp_available is False
    assert wa(connected(), profile).json()["code"] == "CHANNEL_UNAVAILABLE"
    assert BusinessProfile.objects.get(pk=profile.pk).status == BusinessStatus.ACTIVE


def test_same_account_reporting_three_times_counts_once():
    profile = shop()
    client = reporter_with_link(profile)
    for _ in range(4):
        assert report(client, profile).status_code == 200
    assert WhatsAppReport.objects.count() == 1
    profile.refresh_from_db()
    assert profile.whatsapp_available is True


def test_reviewed_reports_do_not_count_after_admin_review():
    profile = shop()
    clients = [reporter_with_link(profile) for _ in range(3)]
    for client in clients:
        report(client, profile)
    # revue admin : WhatsApp réactivé, signalements examinés
    BusinessProfile.objects.filter(pk=profile.pk).update(whatsapp_available=True)
    WhatsAppReport.objects.update(reviewed=True)
    report(reporter_with_link(profile), profile)
    profile.refresh_from_db()
    assert profile.whatsapp_available is True


def test_report_requires_a_received_whatsapp_link():
    profile = shop()
    stranger = connected()
    assert report(stranger, profile).status_code == 404
    # un appel simple ne suffit pas
    stranger.post(INITIATE, {"business_id": profile.pk, "channel": "call",
                             "platform": "android"}, format="json")
    assert CallLog.objects.filter(channel=CallChannel.CALL).count() == 1
    assert report(stranger, profile).status_code == 404
    assert not WhatsAppReport.objects.exists()


def test_report_requires_login_and_valid_body():
    profile = shop()
    assert APIClient().post(REPORT, {"business_id": profile.pk}, format="json").status_code == 401
    assert connected().post(REPORT, {}, format="json").status_code == 400
    unknown = connected().post(REPORT, {"business_id": 999999}, format="json")
    assert unknown.status_code == 404
