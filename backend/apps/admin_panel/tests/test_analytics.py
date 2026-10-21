"""Analyses, abonnements et lecture de l'audit (T074c)."""
import json
from datetime import date, datetime, time, timedelta

import pytest
from django.contrib.auth.models import Group
from django.core.cache import cache
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from rest_framework.test import APIClient

from apps.admin_panel.models import AuditAction, AuditLog
from apps.admin_panel.services import analytics_service
from apps.business.models import BusinessStatus
from apps.calls.models import CallChannel, CallLog, Platform
from apps.core.models import PlatformSetting, SettingKey
from apps.search.models import SearchLog
from tests.factories.business_factory import make_owner, make_profile, make_subscription

from ._t074 import COMPLET, VALIDATEUR, api_as


def admin_in(group):
    # make_owner partage son compteur de numéros avec les profils (pas de collision).
    admin = make_owner(is_admin=True)
    admin.groups.add(Group.objects.get(name=group))
    return admin

pytestmark = pytest.mark.django_db

SEARCHES, CALLS = "/api/admin/analytics/searches/", "/api/admin/analytics/calls/"
SUBS, AUDIT = "/api/admin/subscriptions/", "/api/admin/audit/"
ROUTES = [SEARCHES, CALLS, SUBS, AUDIT]


@pytest.fixture(scope="module", autouse=True)
def _numeros_hors_de_la_plage_de_userfactory():
    """`make_owner` et `UserFactory` numérotent chacun de leur côté : sans décalage, beaucoup de
    comptes créés ici feraient entrer le premier dans la plage du second (collision plus loin)."""
    from itertools import count

    from tests.factories import business_factory

    old = business_factory._numbers
    business_factory._numbers = count(20_000_000)
    yield
    business_factory._numbers = old


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()
    yield
    cache.clear()


def shop(**extra):
    extra.setdefault("status", BusinessStatus.ACTIVE)
    return make_profile(**extra)


def search(term, n=1, results=1, at=None, **extra):
    rows = [SearchLog.objects.create(term=term, results_count=results, **extra) for _ in range(n)]
    if at is not None:
        SearchLog.objects.filter(pk__in=[r.pk for r in rows]).update(created_at=at)


def calls(profile, n=1, at=None, **extra):
    extra.setdefault("channel", CallChannel.CALL)
    extra.setdefault("platform", Platform.ANDROID)
    caller = make_owner()
    rows = [CallLog.objects.create(caller=caller, profile=profile, **extra) for _ in range(n)]
    if at is not None:
        CallLog.objects.filter(pk__in=[r.pk for r in rows]).update(created_at=at)


# --- Droits ------------------------------------------------------------------------------


@pytest.mark.parametrize("url", ROUTES)
def test_permissions_par_route(url):
    assert APIClient().get(url).status_code == 401
    assert api_as(make_owner()).get(url).status_code == 403
    assert api_as(make_owner(is_admin=True)).get(url).status_code == 403
    for group in (VALIDATEUR, COMPLET):
        response = api_as(admin_in(group)).get(url)
        assert response.status_code == 200
        assert response["Cache-Control"] == "no-store"


@pytest.mark.parametrize("url", ROUTES)
@pytest.mark.parametrize("method", ["post", "put", "patch", "delete"])
def test_lecture_seule_405(url, method):
    client = api_as(admin_in(COMPLET))
    assert getattr(client, method)(url, {}, format="json").status_code == 405


@pytest.mark.parametrize("url", ROUTES)
def test_admin_bloque_refuse(url):
    admin = admin_in(COMPLET)
    admin.is_blocked = True
    admin.save()
    assert api_as(admin).get(url).status_code == 403


# --- Recherches ---------------------------------------------------------------------------


def test_recherches_termes_tries_limites_sans_compte():
    search("riz", 3, account_hash="a" * 64)
    search("poisson", 5)
    search("savon", 2, results=0)
    search("savon", 1, results=0)
    for i in range(60):
        search(f"terme{i:02d}")
    data = api_as(admin_in(VALIDATEUR)).get(SEARCHES).json()
    assert data["days"] == 7
    assert data["top_terms"][0] == {"term": "poisson", "count": 5}
    counts = [t["count"] for t in data["top_terms"]]
    assert counts == sorted(counts, reverse=True)
    assert len(data["top_terms"]) == 50
    assert data["no_result_terms"] == [{"term": "savon", "count": 3}]
    assert data["total_without_results"] == 3
    assert "a" * 64 not in json.dumps(data)
    assert set(data["top_terms"][0]) == {"term", "count"}


def test_recherches_ecarte_les_numeros_tapes():
    search("699123456", 4)
    search("6 99 12 34 56", 2)
    search("riz")
    data = api_as(admin_in(COMPLET)).get(SEARCHES).json()
    assert [t["term"] for t in data["top_terms"]] == ["riz"]
    assert "699" not in json.dumps(data)


def test_recherches_fenetre_et_bornes():
    now = timezone.now()
    search("ancien", at=now - timedelta(days=10))
    search("recent")
    client = api_as(admin_in(COMPLET))
    assert [t["term"] for t in client.get(SEARCHES).json()["top_terms"]] == ["recent"]
    wide = client.get(SEARCHES, {"days": 30}).json()
    assert {t["term"] for t in wide["top_terms"]} == {"ancien", "recent"}
    for bad in ("0", "91", "-1", "abc", "2.5"):
        response = client.get(SEARCHES, {"days": bad})
        assert response.status_code == 400, bad
    assert client.get(SEARCHES, {"days": 90}).status_code == 200
    assert client.get(SEARCHES, {"days": 1}).status_code == 200


def test_recherches_jours_calendaires_locaux():
    start = analytics_service.window(7)[1]
    search("limite", at=start + timedelta(seconds=1))
    search("avant", at=start - timedelta(seconds=1))
    data = api_as(admin_in(COMPLET)).get(SEARCHES).json()
    assert [t["term"] for t in data["top_terms"]] == ["limite"]


# --- Appels -------------------------------------------------------------------------------


def test_appels_agregats():
    profile = shop()
    calls(profile, 2, operator="orange")
    calls(profile, 1, operator="mtn", platform=Platform.IOS)
    calls(profile, 3, operator="", channel=CallChannel.WHATSAPP)
    calls(profile, 1, at=timezone.now() - timedelta(days=20))
    data = api_as(admin_in(VALIDATEUR)).get(CALLS).json()
    assert data["total_calls"] == 6
    assert data["by_operator"] == {"orange": 2, "mtn": 1, "unknown": 3}
    assert data["by_platform"] == {"android": 5, "ios": 1}
    assert data["by_channel"] == {"call": 3, "whatsapp": 3}
    assert len(data["by_day"]) == 7
    assert sum(d["count"] for d in data["by_day"]) == 6
    assert data["by_day"][-1]["count"] == 6
    assert data["by_day"][0]["date"] == data["since"]
    assert data["by_day"][0]["count"] == 0


def test_appels_aucun_appelant_ni_commercant():
    profile = shop(name="Chez Secret")
    calls(profile, 2, operator="orange")
    response = api_as(admin_in(COMPLET)).get(CALLS)
    text = response.content.decode()
    assert "Chez Secret" not in text and profile.owner.phone not in text
    assert set(response.json()) == {
        "days", "since", "total_calls", "by_day", "by_operator", "by_platform", "by_channel"}


def test_appels_fenetre_parametrable():
    profile = shop()
    calls(profile, 1, at=timezone.now() - timedelta(days=20))
    client = api_as(admin_in(COMPLET))
    assert client.get(CALLS).json()["total_calls"] == 0
    wide = client.get(CALLS, {"days": 30}).json()
    assert wide["total_calls"] == 1 and len(wide["by_day"]) == 30
    assert client.get(CALLS, {"days": 91}).status_code == 400
    assert client.get(CALLS, {"days": "x"}).status_code == 400


def _constant(url, grow, params=None):
    client = api_as(admin_in(COMPLET))

    def count():
        with CaptureQueriesContext(connection) as ctx:
            assert client.get(url, params or {}).status_code == 200
        return len(ctx)

    grow(2)
    count()  # chauffe le cache des réglages
    small = count()
    grow(8)
    assert count() == small


def test_requetes_constantes_analyses():
    def grow(n):
        for _ in range(n):
            search("riz", results=0)
            calls(shop(), 2, operator="mtn")

    _constant(SEARCHES, grow)
    _constant(CALLS, grow)


# --- Abonnements --------------------------------------------------------------------------


def _set_threshold(value):
    PlatformSetting.objects.update_or_create(
        key=SettingKey.SEUIL_APPELS_ABONNEMENT, defaults={"value": value})
    cache.clear()


def test_abonnements_filtres_et_numero_masque():
    _set_threshold(3)
    abonne = shop(name="Abonné")
    make_subscription(abonne)
    calls(abonne, 5)  # abonné : jamais « fort trafic »
    fort = shop(name="Fort")
    calls(fort, 4)
    calme = shop(name="Calme")
    calls(calme, 3)  # égal au seuil : pas au-dessus
    expire = shop(name="Expiré")
    make_subscription(expire, start=timezone.now() - timedelta(days=60),
                      end=timezone.now() - timedelta(days=30))
    shop(name="Bloqué", owner=make_owner(is_blocked=True))
    shop(name="Attente", status=BusinessStatus.PENDING)
    client = api_as(admin_in(VALIDATEUR))

    def names(**params):
        return [r["name"] for r in client.get(SUBS, params).json()["results"]]

    assert set(names()) == {"Abonné", "Fort", "Calme", "Expiré"}
    assert names(filter="subscribed") == ["Abonné"]
    assert set(names(filter="unsubscribed")) == {"Fort", "Calme", "Expiré"}
    assert names(filter="high_traffic") == ["Fort"]
    rows = {r["name"]: r for r in client.get(SUBS).json()["results"]}
    assert rows["Fort"]["high_traffic"] is True and rows["Calme"]["high_traffic"] is False
    assert rows["Abonné"]["is_subscribed"] and rows["Abonné"]["subscription_end"]
    assert rows["Expiré"]["subscription_end"] is None
    assert rows["Fort"]["calls_last_day"] == 4
    assert rows["Fort"]["phone_masked"].startswith("+237 6•• ••")
    assert fort.owner.phone not in client.get(SUBS).content.decode()
    assert client.get(SUBS, {"filter": "zzz"}).status_code == 400


def test_abonnements_seuil_lu_dans_les_reglages_et_fenetre_24h():
    p = shop()
    calls(p, 2)
    calls(p, 10, at=timezone.now() - timedelta(hours=30))  # hors des 24 h
    client = api_as(admin_in(COMPLET))
    _set_threshold(1)
    assert len(client.get(SUBS, {"filter": "high_traffic"}).json()["results"]) == 1
    _set_threshold(2)
    assert client.get(SUBS, {"filter": "high_traffic"}).json()["results"] == []


def test_abonnements_pagination():
    for _ in range(3):
        shop()
    data = api_as(admin_in(COMPLET)).get(SUBS, {"page_size": 2}).json()
    assert data["count"] == 3 and len(data["results"]) == 2 and data["next"]


def test_requetes_constantes_abonnements():
    def grow(n):
        for _ in range(n):
            p = shop()
            make_subscription(p)
            calls(shop(), 2)

    _constant(SUBS, grow, {"page_size": 50})


# --- Audit --------------------------------------------------------------------------------


def entry(admin, action, reason="", at=None, target=None):
    target = target or make_owner()
    row = AuditLog.objects.create(
        admin=admin, action=action, target_type="accounts.user", target_id=target.pk,
        reason=reason)
    if at is not None:
        AuditLog.objects.filter(pk=row.pk).update(created_at=at)
    return row


def test_audit_ordre_filtres_et_pagination():
    a1, a2 = admin_in(COMPLET), admin_in(VALIDATEUR)
    now = timezone.now()
    e1 = entry(a1, AuditAction.BLOCAGE_COMPTE, "Fraude", at=now - timedelta(days=3))
    e2 = entry(a2, AuditAction.VALIDATION_BUSINESS, at=now - timedelta(days=2))
    e3 = entry(a1, AuditAction.DEBLOCAGE_COMPTE, at=now - timedelta(days=1))
    client = api_as(a1)

    def ids(**p):
        return [r["id"] for r in client.get(AUDIT, p).json()["results"]]

    assert ids() == [e3.pk, e2.pk, e1.pk]
    assert ids(admin=a2.pk) == [e2.pk]
    assert ids(action="blocage_compte") == [e1.pk]
    assert ids(admin=a1.pk, action="deblocage_compte") == [e3.pk]
    assert client.get(AUDIT, {"page_size": 2}).json()["count"] == 3
    row = client.get(AUDIT, {"action": "blocage_compte"}).json()["results"][0]
    assert row["reason"] == "Fraude" and row["admin_name"] == a1.name
    assert row["action_label"] and row["target_type"] == "accounts.user"


def test_audit_bornes_de_dates_incluses():
    admin = admin_in(COMPLET)
    local = timezone.localtime(timezone.now())
    day = local.date() - timedelta(days=5)
    midnight = timezone.make_aware(datetime.combine(day, time.min))
    first = entry(admin, AuditAction.EXPORT_COMPTES, at=midnight)
    last = entry(admin, AuditAction.EXPORT_COMPTES, at=midnight + timedelta(hours=23, minutes=59))
    before = entry(admin, AuditAction.EXPORT_COMPTES, at=midnight - timedelta(seconds=1))
    after = entry(admin, AuditAction.EXPORT_COMPTES, at=midnight + timedelta(days=1))
    client = api_as(admin)
    iso = day.isoformat()

    def ids(**p):
        return {r["id"] for r in client.get(AUDIT, p).json()["results"]}

    assert ids(**{"from": iso, "to": iso}) == {first.pk, last.pk}
    assert ids(**{"from": iso}) >= {first.pk, last.pk, after.pk}
    assert before.pk not in ids(**{"from": iso})
    assert ids(**{"to": iso}) >= {before.pk, first.pk, last.pk}
    assert after.pk not in ids(**{"to": iso})


@pytest.mark.parametrize("params", [
    {"from": "pas-une-date"}, {"to": "2026-13-40"}, {"from": "2026-05-02", "to": "2026-05-01"},
    {"action": "inconnue"}, {"admin": "abc"},
    {"to": "9999-12-31"}, {"from": "0001-01-01"}, {"from": "1900-01-01"},
    {"to": "1999-12-31"}, {"from": "2999-01-01"}, {"from": "2026-1-1"}, {"to": "٢٠٢٦-٠١-٠١"},
    {"admin": " 1"}, {"admin": "1_0"}, {"admin": "+5"}, {"admin": "١٢"}, {"admin": "-1"},
    {"admin": "9" * 30},
])
def test_audit_filtres_invalides_400(params):
    assert api_as(admin_in(COMPLET)).get(AUDIT, params).status_code == 400


def test_audit_aucun_numero_ni_lien_ni_jeton_dans_les_motifs():
    admin = admin_in(COMPLET)
    entry(admin, AuditAction.REJET_BUSINESS,
          "Voir +237 699 12 34 56 ou 699123456 sur https://x.test/api/admin/private-files/"
          "abc123/ code 123456 jeton eyJhbGciOi.eyJzdWIi.sig mot de passe ok")
    text = api_as(admin).get(AUDIT).content.decode()
    for secret in ("699", "x.test", "private-files", "abc123", "123456", "eyJ"):
        assert secret not in text
    assert "[numéro masqué]" in text and "[lien masqué]" in text


def test_audit_aucun_champ_sensible_dans_la_reponse():
    admin = admin_in(COMPLET)
    entry(admin, AuditAction.BLOCAGE_COMPTE, "x")
    row = api_as(admin).get(AUDIT).json()["results"][0]
    assert set(row) == {"id", "admin_id", "admin_name", "action", "action_label",
                        "target_type", "target_id", "reason", "created_at"}
    assert admin.phone not in json.dumps(row)


def test_requetes_constantes_audit():
    def grow(n):
        for _ in range(n):
            entry(admin_in(VALIDATEUR), AuditAction.BLOCAGE_COMPTE, "m")

    _constant(AUDIT, grow, {"page_size": 50})


def test_audit_dates_limites_valides():
    client = api_as(admin_in(COMPLET))
    today = timezone.localdate()
    for params in ({"from": "2000-01-01"}, {"to": today.isoformat()},
                   {"to": today.replace(year=today.year + 1).isoformat()}):
        assert client.get(AUDIT, params).status_code == 200, params


@pytest.mark.parametrize("bad", [" 1", "1_0", "+5", "١٢", "0x5", "", "1000"])
def test_days_strict_chiffres_ascii(bad):
    client = api_as(admin_in(COMPLET))
    if bad == "":
        assert client.get(SEARCHES, {"days": bad}).status_code == 200  # absent : défaut
        return
    for url in (SEARCHES, CALLS):
        assert client.get(url, {"days": bad}).status_code == 400, bad


def test_audit_dates_un_29_fevrier(monkeypatch):
    monkeypatch.setattr(timezone, "localdate", lambda *a, **k: date(2028, 2, 29))
    client = api_as(admin_in(COMPLET))
    for params in ({"from": "2028-02-29"}, {"to": "2028-02-29"}, {"to": "2029-03-01"},
                   {"from": "2000-01-01", "to": "2028-02-28"}):
        assert client.get(AUDIT, params).status_code == 200, params
    assert client.get(AUDIT, {"to": "2029-03-02"}).status_code == 400
