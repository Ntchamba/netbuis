"""API des agents (T131 points 4, 5 et 6) : droits, présence, accept/decline, liste."""
import threading
from datetime import timedelta

import pytest
from django.contrib.auth.models import Group
from django.db import connection
from django.utils import timezone
from rest_framework.test import APIClient

from apps.calls.models import AgentPresence, CallSession, CallSessionDecline, SessionState
from apps.calls.services import session_service
from apps.calls.services.call_service import CallRefused
from apps.calls.tests.helpers import client_for, make_admin, make_agent, post_session
from tests.factories.business_factory import make_owner

pytestmark = pytest.mark.django_db

ADMIN = "/api/admin/calls/"


def ringing(business=None):
    """Une session en sonnerie ; retourne (client appelant, id)."""
    client = client_for(make_owner(name="Awa"))
    return client, post_session(client, business).json()["session_id"]


# --- Droit « répondre aux appels » ---------------------------------------------------------


@pytest.mark.parametrize("method,route", [
    ("get", ADMIN), ("get", ADMIN + "stream/"), ("post", ADMIN + "presence/"),
    ("post", ADMIN + "sessions/00000000-0000-0000-0000-000000000000/accept/"),
    ("post", ADMIN + "sessions/00000000-0000-0000-0000-000000000000/decline/"),
    ("post", ADMIN + "sessions/00000000-0000-0000-0000-000000000000/end/"),
])
def test_routes_agent_refusees_sans_droit(method, route):
    assert getattr(APIClient(), method)(route).status_code == 401
    assert getattr(client_for(make_owner()), method)(route).status_code == 403  # simple compte
    assert getattr(client_for(make_admin()), method)(route).status_code == 403
    avec_groupe_sans_droit = make_admin("Autre groupe")
    assert getattr(client_for(avec_groupe_sans_droit), method)(route).status_code == 403


def test_le_droit_est_donne_aux_deux_groupes_par_la_migration():
    for name in ("Validateur", "Administrateur complet"):
        codes = Group.objects.get(name=name).permissions.values_list("codename", flat=True)
        assert "peut_repondre_aux_appels" in set(codes), name


@pytest.mark.parametrize("group", ["Validateur", "Administrateur complet"])
def test_les_deux_groupes_peuvent_utiliser_la_presence(group):
    agent = make_admin(group)
    response = client_for(agent).post(ADMIN + "presence/", {"available": True}, format="json")
    assert response.status_code == 200 and response.json() == {"available": True}


def test_le_droit_est_relu_a_chaque_requete():
    agent = make_agent()
    client = client_for(agent)
    assert client.post(ADMIN + "presence/", {}, format="json").status_code == 200
    agent.groups.clear()
    assert client.post(ADMIN + "presence/", {}, format="json").status_code == 403


# --- Présence ------------------------------------------------------------------------------


def test_presence_choix_et_battement_de_coeur():
    agent = make_admin("Validateur")
    client = client_for(agent)
    assert client.post(ADMIN + "presence/", {"available": True}, format="json").json() == {
        "available": True}
    before = AgentPresence.objects.get(agent=agent).last_seen
    # battement de cœur : ne change pas le choix
    assert client.post(ADMIN + "presence/", {}, format="json").json() == {"available": True}
    assert AgentPresence.objects.get(agent=agent).last_seen >= before
    assert client.post(ADMIN + "presence/", {"available": False}, format="json").json() == {
        "available": False}
    assert client.post(ADMIN + "presence/", {"available": "peut-être"}, format="json"
                       ).status_code == 400


def test_disponible_choisi_ne_suffit_pas_sans_flux_ouvert():
    agent = make_admin("Validateur")
    client_for(agent).post(ADMIN + "presence/", {"available": True}, format="json")
    assert post_session(client_for(make_owner())).json()["state"] == "unavailable"


# --- Accept : un seul gagnant ----------------------------------------------------------------


def test_accept_renvoie_salle_jeton_et_contexte_sans_numero():
    agent = make_agent()
    from tests.factories.business_factory import make_profile

    profile = make_profile(status="actif", name="Chez Riz")
    caller, sid = ringing(profile.pk)
    response = client_for(agent).post(f"{ADMIN}sessions/{sid}/accept/")
    assert response.status_code == 200 and response["Cache-Control"] == "no-store"
    data = response.json()
    assert data["caller_name"] == "Awa"
    assert data["business"] == {"id": profile.pk, "name": "Chez Riz",
                                "type_label": profile.get_type_compte_display(),
                                "kind": "entreprise"}
    assert set(data["jitsi"]) == {"domain", "room", "jwt"}
    text = response.content.decode()
    assert profile.phone_anchor not in text and caller.user.phone not in text
    session = CallSession.objects.get(pk=sid)
    assert (session.state, session.agent_id) == (SessionState.ANSWERED, agent.pk)
    assert session.answered_at is not None


def test_le_second_agent_recoit_409_taken():
    first, second = make_agent(), make_agent()
    _, sid = ringing()
    assert client_for(first).post(f"{ADMIN}sessions/{sid}/accept/").status_code == 200
    loser = client_for(second).post(f"{ADMIN}sessions/{sid}/accept/")
    assert loser.status_code == 409 and loser.json()["code"] == "call_taken"
    assert CallSession.objects.get(pk=sid).agent_id == first.pk


def test_accept_inconnu_expire_ou_deja_termine():
    agent = make_agent()
    client = client_for(agent)
    assert client.post(f"{ADMIN}sessions/00000000-0000-0000-0000-000000000000/accept/"
                       ).status_code == 404
    _, sid = ringing()
    CallSession.objects.filter(pk=sid).update(expires_at=timezone.now() - timedelta(seconds=1))
    response = client.post(f"{ADMIN}sessions/{sid}/accept/")
    assert response.status_code == 409 and response.json()["code"] == "call_not_ringing"
    _, other = ringing()
    CallSession.objects.filter(pk=other).update(state="cancelled")
    assert client.post(f"{ADMIN}sessions/{other}/accept/").status_code == 409


@pytest.mark.django_db(transaction=True)
def test_deux_agents_simultanes_un_seul_gagnant():
    agents = [make_agent(), make_agent()]
    _, sid = ringing()
    barrier = threading.Barrier(2)
    results = []

    def attempt(agent):
        try:
            barrier.wait(timeout=5)
            session_service.accept(agent, sid)
            results.append(("gagne", agent.pk))
        except CallRefused as refusal:
            results.append((refusal.get_codes(), agent.pk))
        finally:
            connection.close()

    threads = [threading.Thread(target=attempt, args=(a,)) for a in agents]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=10)
    kinds = sorted(kind for kind, _ in results)
    assert kinds == ["call_taken", "gagne"], results
    winner = next(pk for kind, pk in results if kind == "gagne")
    assert CallSession.objects.get(pk=sid).agent_id == winner


# --- Decline -----------------------------------------------------------------------------------


def test_refus_tous_les_agents_disponibles_donne_declined_avec_trace():
    first, second = make_agent(), make_agent()
    caller, sid = ringing()
    r1 = client_for(first).post(f"{ADMIN}sessions/{sid}/decline/")
    assert r1.status_code == 200 and r1.json()["state"] == "ringing"  # le second peut répondre
    r2 = client_for(second).post(f"{ADMIN}sessions/{sid}/decline/")
    assert r2.json()["state"] == "declined"
    assert set(CallSessionDecline.objects.values_list("agent_id", flat=True)) == {
        first.pk, second.pk}
    body = caller.get(f"/api/calls/sessions/{sid}/").json()
    assert body["state"] == "declined" and body["end_reason"] == "all_declined"


def test_refus_repete_est_compte_une_fois_et_refus_apres_reponse_refuse():
    first, second = make_agent(), make_agent()
    _, sid = ringing()
    client_for(first).post(f"{ADMIN}sessions/{sid}/decline/")
    client_for(first).post(f"{ADMIN}sessions/{sid}/decline/")
    assert CallSessionDecline.objects.count() == 1
    assert CallSession.objects.get(pk=sid).state == "ringing"
    client_for(second).post(f"{ADMIN}sessions/{sid}/accept/")
    late = client_for(first).post(f"{ADMIN}sessions/{sid}/decline/")
    assert late.status_code == 409 and late.json()["code"] == "call_not_ringing"


def test_seul_l_agent_qui_a_repondu_peut_raccrocher():
    first, second = make_agent(), make_agent()
    _, sid = ringing()
    client_for(first).post(f"{ADMIN}sessions/{sid}/accept/")
    assert client_for(second).post(f"{ADMIN}sessions/{sid}/end/").status_code == 404
    assert CallSession.objects.get(pk=sid).state == "answered"


# --- Listes -------------------------------------------------------------------------------------


def test_liste_admin_filtres_pagination_et_aucun_numero():
    agent, other = make_agent(name="Moussa"), make_agent()
    from tests.factories.business_factory import make_profile

    profile = make_profile(status="actif", name="Chez Riz")
    answered_caller, answered = ringing(profile.pk)
    client_for(agent).post(f"{ADMIN}sessions/{answered}/accept/")
    answered_caller.post(f"/api/calls/sessions/{answered}/end/")
    missed_caller, missed = ringing()
    CallSession.objects.filter(pk=missed).update(expires_at=timezone.now() - timedelta(seconds=1))
    session_service.expire_stale()
    reader = client_for(other)
    everything = reader.get(ADMIN)
    assert everything.status_code == 200 and everything["Cache-Control"] == "no-store"
    assert everything.json()["count"] == 2
    only_missed = reader.get(ADMIN, {"state": "missed,declined"}).json()
    assert [r["session_id"] for r in only_missed["results"]] == [missed]
    by_agent = reader.get(ADMIN, {"agent": agent.pk}).json()
    (row,) = by_agent["results"]
    assert row["session_id"] == answered and row["agent"] == {"id": agent.pk, "name": "Moussa"}
    assert row["caller_name"] == "Awa" and row["business"]["name"] == "Chez Riz"
    assert row["duration_seconds"] is not None
    text = everything.content.decode()
    for secret in (answered_caller.user.phone, missed_caller.user.phone, profile.phone_anchor,
                   CallSession.objects.get(pk=answered).room):
        assert secret not in text
    assert reader.get(ADMIN, {"state": "n'importe quoi"}).json()["count"] == 2


def test_historique_de_l_appelant_sessions_et_whatsapp_sans_numero():
    from apps.calls.models import CallLog
    from tests.factories.business_factory import make_profile

    make_agent()
    profile = make_profile(status="actif", name="Chez Riz")
    user = make_owner()
    client = client_for(user)
    started = post_session(client, profile.pk).json()
    log = CallLog.objects.create(caller=user, profile=profile, channel="whatsapp",
                                 platform="android")
    client_for(make_owner())  # un autre compte : ses lignes ne doivent pas apparaître
    post_session(client_for(make_owner()))
    response = client.get("/api/calls/history/")
    assert response.status_code == 200 and response["Cache-Control"] == "no-store"
    body = response.json()
    assert body["count"] == 2
    kinds = {r["type"]: r for r in body["results"]}
    assert kinds["call"]["session_id"] == started["session_id"] and kinds["call"]["id"] is None
    assert kinds["call"]["state"] == "ringing" and kinds["call"]["business_name"] == "Chez Riz"
    assert kinds["whatsapp"]["id"] == log.pk and kinds["whatsapp"]["state"] is None
    text = response.content.decode()
    assert profile.phone_anchor not in text and started["jitsi"]["room"] not in text
    assert started["jitsi"]["jwt"] not in text
    assert APIClient().get("/api/calls/history/").status_code == 401


def test_historique_session_sans_commerce():
    make_agent()
    client = client_for(make_owner())
    post_session(client)
    (row,) = client.get("/api/calls/history/").json()["results"]
    assert row["business_id"] is None and row["business_name"] is None and row["zone"] is None
