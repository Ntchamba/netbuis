"""Limites anti-abus (D-05) sur les sessions d'appel : N par minute, M par jour, par compte."""
from datetime import timedelta

import pytest
from django.utils import timezone

from apps.calls.models import CallSession
from apps.calls.tests.helpers import client_for, post_session
from apps.core.models import PlatformSetting, SettingKey
from apps.core.services.settings_service import invalidate_setting
from tests.factories.business_factory import make_owner

pytestmark = pytest.mark.django_db


def old_sessions(user, n, age):
    """n sessions closes datées de `age` avant maintenant."""
    when = timezone.now() - age
    for _ in range(n):
        session = CallSession.objects.create(
            caller=user, room=f"salle-{CallSession.objects.count()}-{age.total_seconds()}",
            state="ended",
        )
        CallSession.objects.filter(pk=session.pk).update(created_at=when)


def test_sixth_call_in_a_minute_is_429():
    user = make_owner()
    client = client_for(user)
    for _ in range(5):
        assert post_session(client).status_code == 200
    response = post_session(client)
    assert response.status_code == 429
    assert response.json()["code"] == "RATE_LIMITED"
    assert response["Cache-Control"] == "no-store"
    assert CallSession.objects.filter(caller=user).count() == 5


def test_minute_window_slides():
    user = make_owner()
    old_sessions(user, 5, timedelta(seconds=61))
    assert post_session(client_for(user)).status_code == 200


def test_limit_is_per_account():
    old_sessions(make_owner(), 5, timedelta(seconds=1))
    assert post_session(client_for(make_owner())).status_code == 200


def test_unavailable_attempts_count_too():
    user = make_owner()
    old_sessions(user, 5, timedelta(seconds=1))
    assert post_session(client_for(user)).status_code == 429


def test_day_limit_50():
    user = make_owner()
    old_sessions(user, 50, timedelta(hours=2))  # hors de la minute, dans les 24 h
    response = post_session(client_for(user))
    assert response.status_code == 429
    assert response.json()["code"] == "RATE_LIMITED"


def test_day_limit_not_reached_with_49_and_resets_after_24h():
    user = make_owner()
    old_sessions(user, 49, timedelta(hours=2))
    assert post_session(client_for(user)).status_code == 200
    other = make_owner()
    old_sessions(other, 60, timedelta(hours=25))
    assert post_session(client_for(other)).status_code == 200


def test_limits_come_from_platform_setting():
    user = make_owner()
    PlatformSetting.objects.create(key=SettingKey.LIMITE_APPELS_PAR_MINUTE, value=1)
    invalidate_setting(SettingKey.LIMITE_APPELS_PAR_MINUTE)
    client = client_for(user)
    assert post_session(client).status_code == 200
    assert post_session(client).status_code == 429
    PlatformSetting.objects.all().delete()
    invalidate_setting(SettingKey.LIMITE_APPELS_PAR_MINUTE)

    PlatformSetting.objects.create(key=SettingKey.LIMITE_APPELS_PAR_JOUR, value=2)
    invalidate_setting(SettingKey.LIMITE_APPELS_PAR_JOUR)
    other = make_owner()
    old_sessions(other, 2, timedelta(hours=2))
    assert post_session(client_for(other)).status_code == 429
    PlatformSetting.objects.all().delete()
    invalidate_setting(SettingKey.LIMITE_APPELS_PAR_JOUR)
