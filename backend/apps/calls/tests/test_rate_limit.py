"""Limite anti-aspiration (D-05) : N par minute, M par jour, par compte."""
from datetime import timedelta

import pytest
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.business.models import BusinessStatus
from apps.calls.models import CallLog
from apps.core.models import PlatformSetting, SettingKey
from apps.core.services.settings_service import invalidate_setting
from tests.factories.business_factory import make_owner, make_profile

pytestmark = pytest.mark.django_db

URL = "/api/calls/initiate/"


def client_for(user):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    return client


def shop():
    return make_profile(status=BusinessStatus.ACTIVE)


def call(client, profile):
    return client.post(
        URL, {"business_id": profile.pk, "channel": "call", "platform": "android"}, format="json"
    )


def old_logs(user, profile, n, age, channel="call"):
    """n journaux datés de `age` avant maintenant."""
    when = timezone.now() - age
    for _ in range(n):
        log = CallLog.objects.create(caller=user, profile=profile, channel=channel,
                                     platform="android")
        CallLog.objects.filter(pk=log.pk).update(created_at=when)


def test_sixth_call_in_a_minute_is_429():
    profile, user = shop(), make_owner()
    client = client_for(user)
    assert [call(client, profile).status_code for _ in range(5)] == [200] * 5
    response = call(client, profile)
    assert response.status_code == 429
    assert response.json()["code"] == "RATE_LIMITED"
    assert response["Cache-Control"] == "no-store"
    assert profile.phone_anchor not in response.content.decode()
    assert CallLog.objects.count() == 5
    profile.refresh_from_db()
    assert profile.calls_count == 5


def test_minute_window_slides():
    profile, user = shop(), make_owner()
    old_logs(user, profile, 5, timedelta(seconds=61))
    assert call(client_for(user), profile).status_code == 200


def test_limit_is_per_account():
    profile = shop()
    old_logs(make_owner(), profile, 5, timedelta(seconds=1))
    assert call(client_for(make_owner()), profile).status_code == 200


def test_whatsapp_logs_count_for_the_limit():
    profile, user = shop(), make_owner()
    old_logs(user, profile, 5, timedelta(seconds=1), channel="whatsapp")
    assert call(client_for(user), profile).status_code == 429


def test_day_limit_50():
    profile, user = shop(), make_owner()
    old_logs(user, profile, 50, timedelta(hours=2))  # hors de la minute, dans les 24 h
    response = call(client_for(user), profile)
    assert response.status_code == 429
    assert response.json()["code"] == "RATE_LIMITED"


def test_day_limit_not_reached_with_49_and_resets_after_24h():
    profile, user = shop(), make_owner()
    old_logs(user, profile, 49, timedelta(hours=2))
    assert call(client_for(user), profile).status_code == 200
    other = make_owner()
    old_logs(other, profile, 60, timedelta(hours=25))
    assert call(client_for(other), profile).status_code == 200


def test_limits_come_from_platform_setting():
    profile, user = shop(), make_owner()
    PlatformSetting.objects.create(key=SettingKey.LIMITE_APPELS_PAR_MINUTE, value=1)
    invalidate_setting(SettingKey.LIMITE_APPELS_PAR_MINUTE)
    client = client_for(user)
    assert call(client, profile).status_code == 200
    assert call(client, profile).status_code == 429
    PlatformSetting.objects.all().delete()
    invalidate_setting(SettingKey.LIMITE_APPELS_PAR_MINUTE)

    PlatformSetting.objects.create(key=SettingKey.LIMITE_APPELS_PAR_JOUR, value=2)
    invalidate_setting(SettingKey.LIMITE_APPELS_PAR_JOUR)
    other = make_owner()
    old_logs(other, profile, 2, timedelta(hours=2))
    assert call(client_for(other), profile).status_code == 429
    PlatformSetting.objects.all().delete()
    invalidate_setting(SettingKey.LIMITE_APPELS_PAR_JOUR)
