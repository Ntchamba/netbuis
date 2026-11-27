"""Flux temps réel SSE sur ASGI + PostgreSQL LISTEN/NOTIFY (T131 points 4 et 5).

`transaction=True` : LISTEN/NOTIFY ne délivre qu'au commit, une transaction de test ne suffit pas.
"""
import asyncio
from datetime import timedelta

import pytest
from asgiref.sync import async_to_sync, sync_to_async
from django.utils import timezone

from apps.calls.models import AgentPresence, CallSession
from apps.calls.services import session_service, streams
from apps.calls.tests.helpers import client_for, make_admin, make_agent, post_session
from apps.calls.tests.sse import Stream
from tests.factories.business_factory import make_owner

pytestmark = pytest.mark.django_db(transaction=True)

ADMIN = "/api/admin/calls/"


def run(coro_function):
    async_to_sync(coro_function)()


async def post(client, business_id=None):
    """Appel du client synchrone dans un fil à part (sa propre connexion à la base)."""
    from django.db import connection

    def call():
        try:
            return post_session(client, business_id)
        finally:
            connection.close()

    return await asyncio.to_thread(call)


async def new_caller(**extra):
    """(utilisateur, client API) créés hors de la boucle d'événements."""
    user = await sync_to_async(make_owner)(**extra)
    return user, await sync_to_async(client_for)(user)


async def client_of(user):
    return await sync_to_async(client_for)(user)


async def api(client, method, route):
    from django.db import connection

    def call():
        try:
            return getattr(client, method)(route)
        finally:
            connection.close()

    return await asyncio.to_thread(call)


def test_flux_agent_refuse_sans_droit_meme_avec_accept_event_stream():
    users = [make_owner(), make_admin(), make_admin("Autre groupe")]

    async def main():
        for user in users:
            stream = await Stream(user).open()
            assert stream.response.status_code == 403
            await stream.close()
    run(main)


def test_ouverture_presence_sonnerie_en_direct_puis_fermeture():
    agent = make_agent(streams=0)  # choisi « Disponible » mais aucun flux ouvert

    async def main():
        _, caller = await new_caller(name="Awa")
        assert (await post(caller)).json()["state"] == "unavailable"
        stream = await Stream(agent).open()
        assert stream.response.status_code == 200
        assert stream.response["Content-Type"] == "text/event-stream"
        assert stream.response["Cache-Control"] == "no-store"
        assert await stream.next_event() == ("retry", {})
        assert await stream.next_event() == ("presence", {"available": True})
        assert (await sync_to_async(AgentPresence.objects.get)(agent=agent)).open_streams == 1
        # l'agent a un flux : l'appel sonne, et l'événement arrive sans sondage
        _, other = await new_caller(name="Moussa")
        started = (await post(other)).json()
        assert started["state"] == "ringing"
        ringing = await stream.wait_for("ringing", session_id=started["session_id"])
        assert ringing["caller_name"] == "Moussa" and ringing["business"] is None
        assert 29 <= ringing["ring_seconds_left"] <= 30
        await stream.close()
        presence = await sync_to_async(AgentPresence.objects.get)(agent=agent)
        assert presence.open_streams == 0
    run(main)


def test_aucun_numero_salle_ni_jeton_dans_les_evenements():
    agent = make_agent()

    async def main():
        from tests.factories.business_factory import make_profile

        profile = await sync_to_async(make_profile)(status="actif", name="Chez Riz")
        caller_user, caller = await new_caller(name="Awa")
        stream = await Stream(agent).open()
        started = (await post(caller, profile.pk)).json()
        event = await stream.wait_for("ringing", session_id=started["session_id"])
        assert event["business"] == {"id": profile.pk, "name": "Chez Riz",
                                     "type_label": profile.get_type_compte_display(),
                                     "kind": "entreprise"}
        text = str(event)
        for secret in (started["jitsi"]["room"], started["jitsi"]["jwt"], caller_user.phone,
                       profile.phone_anchor):
            assert secret not in text
        assert "room" not in event and "jwt" not in event
        await stream.close()
    run(main)


def test_rejeu_des_sonneries_en_cours_a_la_connexion():
    agent = make_agent()
    caller = client_for(make_owner())
    started = post_session(caller).json()  # sonne AVANT que le tableau de bord se connecte
    expired_caller = client_for(make_owner())
    expired = post_session(expired_caller).json()
    CallSession.objects.filter(pk=expired["session_id"]).update(
        expires_at=timezone.now() - timedelta(seconds=1))

    async def main():
        stream = await Stream(agent).open()
        await stream.wait_for("presence")
        replayed = await stream.wait_for("ringing")
        assert replayed["session_id"] == started["session_id"]
        assert 0 < replayed["ring_seconds_left"] <= 30
        with pytest.raises(asyncio.TimeoutError):  # la sonnerie expirée n'est pas rejouée
            await stream.wait_for("ringing", timeout=0.5)
        await stream.close()
    run(main)


def test_trois_agents_sonnent_puis_taken_aux_autres_et_ended():
    agents = [make_agent() for _ in range(3)]

    async def main():
        streams_ = [await Stream(a).open() for a in agents]
        _, caller = await new_caller()
        sid = (await post(caller)).json()["session_id"]
        for s in streams_:
            await s.wait_for("ringing", session_id=sid)
        winner = await client_of(agents[0])
        assert (await api(winner, "post", f"{ADMIN}sessions/{sid}/accept/")).status_code == 200
        for s in streams_:  # tous, y compris le gagnant, voient « pris »
            taken = await s.wait_for("taken", session_id=sid)
            assert taken["state"] == "answered" and taken["agent_id"] == agents[0].pk
        loser = await api(await client_of(agents[1]), "post", f"{ADMIN}sessions/{sid}/accept/")
        assert loser.status_code == 409
        await api(caller, "post", f"/api/calls/sessions/{sid}/end/")
        for s in streams_:
            ended = await s.wait_for("ended", session_id=sid)
            assert ended["reason"] == "caller_hangup"
        for s in streams_:
            await s.close()
    run(main)


def test_annulation_et_sonnerie_expiree_publient_aux_agents():
    agent = make_agent()

    async def main():
        stream = await Stream(agent).open()
        _, cancelling = await new_caller()
        sid = (await post(cancelling)).json()["session_id"]
        await stream.wait_for("ringing", session_id=sid)
        await api(cancelling, "post", f"/api/calls/sessions/{sid}/cancel/")
        assert (await stream.wait_for("cancelled", session_id=sid))["state"] == "cancelled"

        _, timing_out = await new_caller()
        sid2 = (await post(timing_out)).json()["session_id"]
        await stream.wait_for("ringing", session_id=sid2)
        await sync_to_async(CallSession.objects.filter(pk=sid2).update)(
            expires_at=timezone.now() - timedelta(seconds=1))
        await sync_to_async(session_service.expire_stale)()
        missed = await stream.wait_for("missed", session_id=sid2)
        assert missed["reason"] == "timeout"
        await stream.close()
    run(main)


def test_refus_de_tous_publie_declined():
    agent = make_agent()

    async def main():
        stream = await Stream(agent).open()
        _, caller = await new_caller()
        sid = (await post(caller)).json()["session_id"]
        await stream.wait_for("ringing", session_id=sid)
        await api(await client_of(agent), "post", f"{ADMIN}sessions/{sid}/decline/")
        assert (await stream.wait_for("declined", session_id=sid))["reason"] == "all_declined"
        await stream.close()
    run(main)


def test_evenement_non_livre_si_la_transaction_est_annulee():
    """pg_notify est dans la transaction : un appel refusé (429, 409…) ne publie rien."""
    agent = make_agent()
    caller = client_for(make_owner())

    async def main():
        stream = await Stream(agent).open()
        first = (await post(caller)).json()["session_id"]
        await stream.wait_for("ringing", session_id=first)
        assert (await post(caller)).status_code == 409  # déjà un appel actif
        with pytest.raises(asyncio.TimeoutError):
            await stream.wait_for("ringing", timeout=0.5)
        await stream.close()
    run(main)


def test_flux_appelant_etat_initial_changements_et_fin_du_flux():
    agent = make_agent()

    async def main():
        caller_user, caller = await new_caller()
        started = (await post(caller)).json()
        sid = started["session_id"]
        watching = await Stream(caller_user, f"/api/calls/sessions/{sid}/events/").open()
        assert watching.response.status_code == 200
        await watching.next_event()  # retry
        assert await watching.next_event() == (
            "state", {"session_id": sid, "state": "ringing", "reason": ""})
        # la session d'un autre appelant n'est pas diffusée ici
        await post((await new_caller())[1])
        agent_client = await client_of(agent)
        await api(agent_client, "post", f"{ADMIN}sessions/{sid}/accept/")
        answered = await watching.wait_for("state")
        assert answered["state"] == "answered" and "room" not in answered
        await api(agent_client, "post", f"{ADMIN}sessions/{sid}/end/")
        ended = await watching.wait_for("state")
        assert ended["state"] == "ended" and ended["reason"] == "agent_hangup"
        with pytest.raises(StopAsyncIteration):  # le flux se termine à l'état final
            await watching.next_event()
        await watching.close()
    run(main)


def test_flux_appelant_d_une_session_terminee_et_d_un_autre_compte():
    make_agent()
    owner = make_owner()
    done = CallSession.objects.create(caller=owner, room="r-done", state="ended",
                                      end_reason="caller_hangup")
    stranger_user = make_owner()

    async def main():
        finished = await Stream(owner, f"/api/calls/sessions/{done.pk}/events/").open()
        await finished.next_event()
        assert (await finished.next_event())[1]["state"] == "ended"
        with pytest.raises(StopAsyncIteration):
            await finished.next_event()
        stranger = await Stream(
            stranger_user, f"/api/calls/sessions/{done.pk}/events/").open()
        assert stranger.response.status_code == 404
        await finished.close()
    run(main)


def test_flux_appelant_voit_la_sonnerie_expiree_sans_evenement_externe(monkeypatch):
    monkeypatch.setattr(streams, "TICK_SECONDS", 0.3)
    make_agent()

    async def main():
        caller_user, caller = await new_caller()
        sid = (await post(caller)).json()["session_id"]
        watching = await Stream(caller_user, f"/api/calls/sessions/{sid}/events/").open()
        await watching.wait_for("state")
        await sync_to_async(CallSession.objects.filter(pk=sid).update)(
            expires_at=timezone.now() - timedelta(seconds=1))
        missed = await watching.wait_for("state", timeout=3)
        assert (missed["state"], missed["reason"]) == ("missed", "timeout")
        await watching.close()
    run(main)


def test_battement_commentaire_et_fermeture_si_le_droit_est_retire(monkeypatch):
    monkeypatch.setattr(streams, "TICK_SECONDS", 0.2)
    agent = make_agent()

    async def main():
        stream = await Stream(agent).open()
        await stream.wait_for("presence")
        assert (await stream.next_event())[0] == "comment"  # `: keepalive`
        await sync_to_async(agent.groups.clear)()
        closed = await stream.wait_for("closed", timeout=3)
        assert closed == {"reason": "permission_removed"}
        with pytest.raises(StopAsyncIteration):
            await stream.next_event()
        await stream.close()
    run(main)


def test_le_battement_garde_l_agent_disponible_et_ferme_les_sonneries(monkeypatch):
    monkeypatch.setattr(streams, "TICK_SECONDS", 0.2)
    agent = make_agent()
    AgentPresence.objects.filter(agent=agent).update(
        last_seen=timezone.now() - timedelta(seconds=20))

    async def main():
        stream = await Stream(agent).open()
        await stream.wait_for("presence")
        assert (await stream.next_event())[0] == "comment"  # au moins un battement a eu lieu
        refreshed = await sync_to_async(AgentPresence.objects.get)(agent=agent)
        assert (timezone.now() - refreshed.last_seen).total_seconds() < 2
        await stream.close()
    run(main)
