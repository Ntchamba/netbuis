"""POST /api/calls/initiate/ (T050) : refus, succès, numéro absent des journaux."""
import logging
from unittest import mock

import pytest
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.business.models import AccountType, BusinessProfile, BusinessStatus
from apps.calls.models import BillingType, CallChannel, CallLog
from apps.calls.services.call_service import (
    FREE_CALLS_PER_DAY,
    CallRefused,
    ensure_channel_available,
)
from tests.factories.business_factory import make_owner, make_profile

pytestmark = pytest.mark.django_db

URL = "/api/calls/initiate/"


def connected(user=None):
    client = APIClient()
    user = user or make_owner()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    client.user = user
    return client


def shop(**extra):
    extra.setdefault("status", BusinessStatus.ACTIVE)
    return make_profile(**extra)


def body(profile, **extra):
    data = {"business_id": profile.pk, "channel": "call", "platform": "android"}
    data.update(extra)
    return data


def refused(response, status, code):
    assert response.status_code == status
    assert response.json()["code"] == code
    assert response["Cache-Control"] == "no-store"
    return response.json()


# --- Succès -----------------------------------------------------------------------------


def test_success_logs_call_returns_number_and_counts():
    profile = shop()
    client = connected()
    response = client.post(URL, body(profile, operator="orange"), format="json")
    assert response.status_code == 200
    data = response.json()
    assert data["phone"] == profile.phone_anchor
    assert set(data) == {"call_id", "phone"}
    assert response["Cache-Control"] == "no-store"
    log = CallLog.objects.get(pk=data["call_id"])
    assert (log.caller, log.profile) == (client.user, profile)
    assert (log.channel, log.platform, log.operator) == ("call", "android", "orange")
    assert log.billing_type == BillingType.NONE
    profile.refresh_from_db()
    assert profile.calls_count == 1


def test_operator_optional_and_ios():
    profile = shop()
    response = connected().post(URL, body(profile, platform="ios"), format="json")
    assert response.status_code == 200
    assert CallLog.objects.get().operator == ""


def test_log_created_before_response_rolls_back_with_failure():
    """Si le journal ne peut pas être écrit, aucun numéro n'est renvoyé."""
    profile = shop()
    client = APIClient(raise_request_exception=False)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(make_owner())['access']}")
    with mock.patch.object(CallLog.objects, "create", side_effect=RuntimeError("boom")):
        response = client.post(URL, body(profile), format="json")
    assert response.status_code == 500
    assert profile.phone_anchor not in response.content.decode()
    profile.refresh_from_db()
    assert profile.calls_count == 0


# --- Refus ------------------------------------------------------------------------------


def test_refused_not_authenticated():
    profile = shop()
    refused(APIClient().post(URL, body(profile), format="json"), 401, "NOT_AUTHENTICATED")
    assert not CallLog.objects.exists()


def test_refused_bad_token_is_not_authenticated():
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION="Bearer pas.un.jeton")
    refused(client.post(URL, body(shop()), format="json"), 401, "NOT_AUTHENTICATED")


def test_refused_caller_blocked():
    profile = shop()
    user = make_owner(is_blocked=True)
    refused(connected(user).post(URL, body(profile), format="json"), 403, "ACCOUNT_BLOCKED")
    assert not CallLog.objects.exists()


def test_refused_business_owner_blocked():
    profile = shop()
    profile.owner.is_blocked = True
    profile.owner.save()
    refused(connected().post(URL, body(profile), format="json"), 403, "ACCOUNT_BLOCKED")
    assert not CallLog.objects.exists()


@pytest.mark.parametrize("state", [BusinessStatus.PENDING, BusinessStatus.REJECTED])
def test_refused_business_not_active(state):
    profile = shop(status=state)
    data = refused(connected().post(URL, body(profile), format="json"), 404, "BUSINESS_NOT_ACTIVE")
    assert profile.phone_anchor not in str(data)


def test_refused_unknown_business():
    refused(connected().post(URL, {"business_id": 999999, "channel": "call", "platform": "ios"},
                             format="json"), 404, "BUSINESS_NOT_ACTIVE")


def test_simple_account_cannot_call_another_simple_account():
    """Seuls les comptes business sont appelables (pas un compte simple)."""
    other_simple = make_owner()
    assert not BusinessProfile.objects.filter(owner=other_simple).exists()
    missing = BusinessProfile.objects.count() + other_simple.pk + 1000
    response = connected().post(
        URL, {"business_id": missing, "channel": "call", "platform": "android"}, format="json"
    )
    refused(response, 404, "BUSINESS_NOT_ACTIVE")
    assert not CallLog.objects.exists()


def test_refused_own_business():
    profile = shop()
    refused(connected(profile.owner).post(URL, body(profile), format="json"), 403, "OWN_BUSINESS")
    assert not CallLog.objects.exists()


def test_own_business_even_when_pending():
    profile = shop(status=BusinessStatus.PENDING)
    refused(connected(profile.owner).post(URL, body(profile), format="json"), 403, "OWN_BUSINESS")


def test_business_account_can_call_another_business():
    other = shop(type_compte=AccountType.PRESTATAIRE_SERVICE)
    response = connected(shop().owner).post(URL, body(other), format="json")
    assert response.status_code == 200


def test_channel_unavailable_when_whatsapp_disabled():
    profile = shop(whatsapp_available=False)
    with pytest.raises(CallRefused) as exc:
        ensure_channel_available(profile, CallChannel.WHATSAPP)
    assert exc.value.get_codes() == "CHANNEL_UNAVAILABLE"
    assert exc.value.status_code == 409
    ensure_channel_available(profile, CallChannel.CALL)  # l'appel reste possible
    ensure_channel_available(shop(), CallChannel.WHATSAPP)


@pytest.mark.parametrize("change", [
    {"business_id": 0}, {"business_id": "x"}, {"channel": "sms"},
    {"platform": "windows"}, {"operator": "camtel"},
])
def test_invalid_body_is_400(change):
    response = connected().post(URL, body(shop(), **change), format="json")
    assert response.status_code == 400
    assert response.json()["code"] == "invalid"
    assert not CallLog.objects.exists()


def test_get_not_allowed():
    assert connected().get(URL).status_code == 405


# --- Quota derrière CREDITS_ENABLED ----------------------------------------------------------


def _call_n(client, profile, n):
    return [client.post(URL, body(profile), format="json") for _ in range(n)]


def test_no_quota_when_credits_disabled(settings):
    settings.CREDITS_ENABLED = False
    profile = shop()
    client = connected()
    # sous la limite par minute (5) mais au-dessus du quota gratuit
    for response in _call_n(client, profile, FREE_CALLS_PER_DAY + 1):
        assert response.status_code == 200
    assert set(CallLog.objects.values_list("billing_type", flat=True)) == {BillingType.NONE}


def test_quota_applies_when_credits_enabled(settings):
    settings.CREDITS_ENABLED = True
    profile = shop()
    client = connected()
    responses = _call_n(client, profile, FREE_CALLS_PER_DAY + 1)
    assert [r.status_code for r in responses] == [200] * FREE_CALLS_PER_DAY + [429]
    assert responses[-1].json()["code"] == "RATE_LIMITED"
    assert profile.phone_anchor not in responses[-1].content.decode()
    assert CallLog.objects.filter(billing_type=BillingType.FREE).count() == FREE_CALLS_PER_DAY
    assert CallLog.objects.count() == FREE_CALLS_PER_DAY


def test_whatsapp_never_counts_for_quota(settings):
    from apps.calls.services.call_service import initiate_call

    settings.CREDITS_ENABLED = True
    profile = shop()
    user = make_owner()
    for _ in range(FREE_CALLS_PER_DAY):
        initiate_call(user, profile.pk, "whatsapp", "android")
    assert set(CallLog.objects.values_list("billing_type", flat=True)) == {BillingType.NONE}
    assert initiate_call(user, profile.pk, "call", "android")["call_id"]


# --- Le numéro n'apparaît dans aucun journal ---------------------------------------------------


def _all_text(caplog, response) -> str:
    fmt = logging.Formatter()
    records = " ".join(
        r.getMessage() + " " + (fmt.formatException(r.exc_info) if r.exc_info else "")
        for r in caplog.records
    )
    return records + " " + caplog.text + " " + response.content.decode()


def test_number_only_in_success_response_not_in_logs(caplog):
    logging.disable(logging.NOTSET)
    caplog.set_level(logging.DEBUG)
    profile = shop()
    phone = profile.phone_anchor
    client = connected()
    ok = client.post(URL, body(profile), format="json")
    assert ok.status_code == 200 and phone in ok.content.decode()
    assert phone not in caplog.text
    digits = phone[-8:]
    assert digits not in caplog.text


def test_number_absent_from_logs_on_refusal_and_exception(caplog):
    logging.disable(logging.NOTSET)
    caplog.set_level(logging.DEBUG)
    profile = shop()
    phone = profile.phone_anchor
    # refus
    blocked = connected(make_owner(is_blocked=True)).post(URL, body(profile), format="json")
    # exception interne pendant l'écriture du journal
    client = APIClient(raise_request_exception=False)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(make_owner())['access']}")
    with mock.patch.object(CallLog.objects, "create", side_effect=RuntimeError("echec")):
        crashed = client.post(URL, body(profile), format="json")
    assert crashed.status_code == 500
    assert any(r.exc_info for r in caplog.records)  # l'exception a bien été journalisée
    for response in (blocked, crashed):
        assert phone not in _all_text(caplog, response)
    assert phone[-8:] not in caplog.text
