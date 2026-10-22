"""POST /api/calls/sessions/ et vie d'une session (T131, points 1, 2, 5 et 8b)."""
import logging
from datetime import timedelta
from io import StringIO

import pytest
from django.core.management import call_command
from django.db import IntegrityError, transaction
from django.utils import timezone
from rest_framework.test import APIClient

from apps.business.models import BusinessStatus
from apps.calls.models import BillingType, CallSession, EndReason, SessionState
from apps.calls.services.call_service import CallRefused
from apps.calls.services.quota import FREE_CALLS_PER_DAY, caller_may_start_call
from apps.calls.tests.helpers import SESSIONS, client_for, make_agent, post_session
from tests.factories.business_factory import make_owner, make_profile

pytestmark = pytest.mark.django_db


def shop(**extra):
    extra.setdefault("status", BusinessStatus.ACTIVE)
    return make_profile(**extra)


def url(session_id, action=""):
    return f"{SESSIONS}{session_id}/{action}"


# --- 1. Modèles et migrations ------------------------------------------------------------


def test_les_sept_etats_existent():
    assert {s.value for s in SessionState} == {
        "ringing", "answered", "ended", "missed", "declined", "unavailable", "cancelled"}


def test_migrations_propres():
    out = StringIO()
    try:
        call_command("makemigrations", "--check", "--dry-run", stdout=out, stderr=out)
    except SystemExit as exc:  # pragma: no cover - échec attendu seulement si une migration manque
        pytest.fail(f"migration manquante : {out.getvalue()} ({exc.code})")


def test_la_base_refuse_deux_sessions_actives_pour_un_appelant():
    caller = make_owner()
    CallSession.objects.create(caller=caller, room="salle-a", state=SessionState.RINGING)
    with pytest.raises(IntegrityError), transaction.atomic():
        CallSession.objects.create(caller=caller, room="salle-b", state=SessionState.ANSWERED)
    # une session terminée ne gêne pas
    CallSession.objects.create(caller=caller, room="salle-c", state=SessionState.ENDED)


# --- 2. Création -------------------------------------------------------------------------


def test_succes_renvoie_session_jitsi_et_duree_de_sonnerie():
    make_agent()
    profile = shop(name="Chez Riz")
    client = client_for(make_owner(name="Awa"))
    response = post_session(client, profile.pk)
    assert response.status_code == 200
    data = response.json()
    assert set(data) == {"session_id", "state", "code", "jitsi", "ring_seconds"}
    assert data["state"] == "ringing" and data["code"] is None
    assert data["ring_seconds"] == 30
    assert set(data["jitsi"]) == {"domain", "room", "jwt"}
    assert data["jitsi"]["domain"] == "jitsi.example.test"
    assert response["Cache-Control"] == "no-store"
    session = CallSession.objects.get(pk=data["session_id"])
    assert session.state == SessionState.RINGING and session.business == profile
    assert session.expires_at - session.ringing_at == timedelta(seconds=30)
    assert session.room == data["jitsi"]["room"]


def test_business_id_facultatif():
    make_agent()
    response = post_session(client_for(make_owner()))
    assert response.status_code == 200
    assert CallSession.objects.get().business is None


def test_une_seule_session_active_par_appelant_409():
    make_agent()
    client = client_for(make_owner())
    first = post_session(client).json()
    second = post_session(client)
    assert second.status_code == 409
    body = second.json()
    assert body["code"] == "call_already_active"
    assert body["session_id"] == first["session_id"]
    assert CallSession.objects.count() == 1


def test_sans_agent_disponible_reponse_unavailable_immediate():
    make_agent(available=False)  # présent mais pas « Disponible »
    response = post_session(client_for(make_owner()))
    assert response.status_code == 200
    data = response.json()
    assert (data["state"], data["code"], data["jitsi"], data["ring_seconds"]) == (
        "unavailable", "no_agent_available", None, 0)
    session = CallSession.objects.get()
    assert session.state == SessionState.UNAVAILABLE and session.end_reason == EndReason.NO_AGENT
    # une nouvelle tentative est permise tout de suite : la session n'est pas « active »
    assert post_session(client_for(session.caller)).status_code == 200


@pytest.mark.parametrize("change", [
    {"streams": 0},  # pas de flux ouvert
    {"group": "Validateur", "stale": True},  # activité périmée
])
def test_agent_sans_flux_ou_inactif_n_est_pas_disponible(change):
    agent = make_agent(streams=change.get("streams", 1))
    if change.get("stale"):
        agent.call_presence.last_seen = timezone.now() - timedelta(seconds=26)
        agent.call_presence.save()
    assert post_session(client_for(make_owner())).json()["state"] == "unavailable"


def test_agent_bloque_ou_sans_le_droit_n_est_pas_disponible():
    blocked = make_agent(is_blocked=True)
    assert blocked.pk
    assert post_session(client_for(make_owner())).json()["state"] == "unavailable"


def test_refus_non_connecte_et_bloque():
    assert APIClient().post(SESSIONS, {}, format="json").status_code == 401
    blocked = client_for(make_owner(is_blocked=True))
    response = post_session(blocked)
    assert response.status_code == 403 and response.json()["code"] == "account_blocked"
    assert not CallSession.objects.exists()


@pytest.mark.parametrize("state", [BusinessStatus.PENDING, BusinessStatus.REJECTED])
def test_commerce_non_actif_refuse(state):
    make_agent()
    response = post_session(client_for(make_owner()), shop(status=state).pk)
    assert response.status_code == 404 and response.json()["code"] == "BUSINESS_NOT_ACTIVE"
    assert not CallSession.objects.exists()


def test_commerce_inconnu_et_corps_invalide():
    make_agent()
    client = client_for(make_owner())
    assert post_session(client, 999999).status_code == 404
    for bad in ({"business_id": 0}, {"business_id": "x"}):
        assert client.post(SESSIONS, bad, format="json").status_code == 400


def test_get_non_autorise_sur_la_creation():
    assert client_for(make_owner()).get(SESSIONS).status_code == 405


def test_jitsi_non_configure_refuse_sans_creer_de_session(settings):
    make_agent()
    settings.JITSI_JWT_SECRET = ""
    response = post_session(client_for(make_owner()))
    assert response.status_code == 503 and response.json()["code"] == "jitsi_not_configured"
    assert not CallSession.objects.exists()


# --- 5. Fin de session -------------------------------------------------------------------


def test_annuler_avant_reponse():
    make_agent()
    client = client_for(make_owner())
    sid = post_session(client).json()["session_id"]
    response = client.post(url(sid, "cancel/"))
    assert response.status_code == 200 and response.json()["state"] == "cancelled"
    assert client.post(url(sid, "cancel/")).status_code == 200  # répété : sans effet
    # la session n'est plus active : un nouvel appel est possible
    assert post_session(client).status_code == 200


def test_annuler_apres_reponse_est_refuse():
    agent = make_agent()
    client = client_for(make_owner())
    sid = post_session(client).json()["session_id"]
    assert client_for(agent).post(f"/api/admin/calls/sessions/{sid}/accept/").status_code == 200
    response = client.post(url(sid, "cancel/"))
    assert response.status_code == 409 and response.json()["code"] == "call_not_ringing"


def test_fin_par_lappelant_puis_par_lagent():
    agent = make_agent()
    caller = client_for(make_owner())
    sid = post_session(caller).json()["session_id"]
    assert caller.post(url(sid, "end/")).status_code == 409  # pas encore en cours
    client_for(agent).post(f"/api/admin/calls/sessions/{sid}/accept/")
    ended = caller.post(url(sid, "end/"))
    assert ended.status_code == 200 and ended.json()["state"] == "ended"
    session = CallSession.objects.get(pk=sid)
    assert session.end_reason == EndReason.CALLER_HANGUP and session.ended_at
    again = client_for(agent).post(f"/api/admin/calls/sessions/{sid}/end/")
    assert again.status_code == 200  # l'autre côté raccroche après : sans effet
    assert CallSession.objects.get(pk=sid).end_reason == EndReason.CALLER_HANGUP


def test_fin_par_lagent():
    agent = make_agent()
    caller = client_for(make_owner())
    sid = post_session(caller).json()["session_id"]
    client_for(agent).post(f"/api/admin/calls/sessions/{sid}/accept/")
    response = client_for(agent).post(f"/api/admin/calls/sessions/{sid}/end/")
    assert response.status_code == 200
    assert CallSession.objects.get(pk=sid).end_reason == EndReason.AGENT_HANGUP
    assert caller.get(url(sid)).json()["state"] == "ended"


def test_un_autre_compte_ne_voit_ni_ne_termine_la_session():
    make_agent()
    sid = post_session(client_for(make_owner())).json()["session_id"]
    stranger = client_for(make_owner())
    assert stranger.get(url(sid)).status_code == 404
    assert stranger.post(url(sid, "cancel/")).status_code == 404
    assert stranger.post(url(sid, "end/")).status_code == 404
    assert stranger.get(url(sid, "events/")).status_code == 404
    assert CallSession.objects.get(pk=sid).state == SessionState.RINGING


def test_consultation_courte_ne_renvoie_ni_salle_ni_jeton():
    make_agent()
    client = client_for(make_owner())
    started = post_session(client).json()
    body = client.get(url(started["session_id"])).json()
    assert body["state"] == "ringing"
    text = str(body)
    assert started["jitsi"]["room"] not in text and started["jitsi"]["jwt"] not in text
    assert set(body) == {"session_id", "state", "end_reason", "created_at", "expires_at",
                         "answered_at", "ended_at"}


def test_sonnerie_depassee_devient_manquee_a_la_consultation():
    make_agent()
    client = client_for(make_owner())
    sid = post_session(client).json()["session_id"]
    CallSession.objects.filter(pk=sid).update(expires_at=timezone.now() - timedelta(seconds=1))
    body = client.get(url(sid)).json()
    assert body["state"] == "missed" and body["end_reason"] == "timeout"


def test_commande_expire_calls_ferme_sonneries_et_appels_trop_longs(settings):
    caller_a, caller_b, caller_c = make_owner(), make_owner(), make_owner()
    old = timezone.now() - timedelta(seconds=settings.CALL_MAX_DURATION + 5)
    now = timezone.now()
    expired = CallSession.objects.create(
        caller=caller_a, room="r1", state="ringing", expires_at=now - timedelta(seconds=2))
    alive = CallSession.objects.create(
        caller=caller_b, room="r2", state="ringing", expires_at=now + timedelta(seconds=20))
    stuck = CallSession.objects.create(
        caller=caller_c, room="r3", state="answered", answered_at=old)
    out = StringIO()
    call_command("expire_calls", stdout=out)
    assert "2 session(s)" in out.getvalue()
    for obj in (expired, alive, stuck):
        obj.refresh_from_db()
    assert (expired.state, expired.end_reason) == ("missed", "timeout")
    assert alive.state == "ringing"
    assert (stuck.state, stuck.end_reason) == ("ended", "too_long")


def test_un_appel_resté_actif_trop_longtemps_ne_bloque_plus_lappelant(settings):
    make_agent()
    caller = make_owner()
    old = timezone.now() - timedelta(seconds=settings.CALL_MAX_DURATION + 5)
    CallSession.objects.create(caller=caller, room="r3", state="answered", answered_at=old)
    assert post_session(client_for(caller)).status_code == 200


def test_les_journaux_ne_contiennent_ni_salle_ni_jeton_ni_secret(caplog, settings):
    logging.disable(logging.NOTSET)
    caplog.set_level(logging.DEBUG)
    agent = make_agent()
    caller = client_for(make_owner(name="Awa"))
    started = post_session(caller, shop().pk).json()
    accepted = client_for(agent).post(
        f"/api/admin/calls/sessions/{started['session_id']}/accept/").json()
    caller.post(url(started["session_id"], "end/"))
    secrets_seen = [started["jitsi"]["room"], started["jitsi"]["jwt"], accepted["jitsi"]["jwt"],
                    settings.JITSI_JWT_SECRET]
    for secret in secrets_seen:
        assert secret not in caplog.text
    # les étapes de l'appel sont bien journalisées (états, agent), sans contenu sensible
    assert "sonnerie lancée" in caplog.text and "répondu par l'agent" in caplog.text


# --- 8b. Point d'accroche du quota -------------------------------------------------------


def test_quota_sans_credits_ne_debite_rien_et_ne_limite_pas_au_dela_du_gratuit(settings):
    settings.CREDITS_ENABLED = False
    make_agent()
    user = make_owner()
    for _ in range(FREE_CALLS_PER_DAY + 1):
        response = post_session(client_for(user))
        assert response.status_code == 200
        CallSession.objects.filter(caller=user).update(state="ended")
    assert set(CallSession.objects.values_list("billing_type", flat=True)) == {BillingType.NONE}


def test_quota_avec_credits_limite_les_appels_gratuits_du_jour(settings):
    settings.CREDITS_ENABLED = True
    make_agent()
    user = make_owner()
    codes = []
    for _ in range(FREE_CALLS_PER_DAY + 1):
        response = post_session(client_for(user))
        codes.append(response.status_code)
        CallSession.objects.filter(caller=user, state="ringing").update(state="ended")
    assert codes == [200] * FREE_CALLS_PER_DAY + [429]
    assert CallSession.objects.filter(billing_type=BillingType.FREE).count() == FREE_CALLS_PER_DAY


def test_la_fonction_unique_est_celle_que_la_creation_appelle(monkeypatch):
    make_agent()
    seen = []

    def refuse(user, now=None):
        seen.append(user.pk)
        raise CallRefused("RATE_LIMITED", "Non.", 429)

    monkeypatch.setattr("apps.calls.services.session_service.caller_may_start_call", refuse)
    user = make_owner()
    assert post_session(client_for(user)).status_code == 429
    assert seen == [user.pk]
    assert caller_may_start_call(make_owner()) == BillingType.NONE


def test_me_ne_renvoie_ni_credits_ni_appel_gratuit():
    body = client_for(make_owner()).get("/api/me/").json()
    assert body.get("free_call_available") is None and body.get("credits_balance") is None
