"""Moteur WebRTC (T151, D-31) : relais des signaux par les flux SSE et mesure de latence.

`transaction=True` : LISTEN/NOTIFY ne délivre qu'au commit.
"""
import asyncio
import json
import secrets
import statistics
import time

import pytest
from asgiref.sync import async_to_sync, sync_to_async

from apps.calls.services import events, streams
from apps.calls.tests.helpers import client_for, make_agent
from apps.calls.tests.sse import Stream
from tests.factories.business_factory import make_owner

pytestmark = pytest.mark.django_db(transaction=True)

ADMIN = "/api/admin/calls/"
P95_LIMIT_SECONDS = 0.250
SIGNALS = 100


@pytest.fixture(autouse=True)
def webrtc(settings):
    settings.CALL_ENGINE = "webrtc"
    settings.STUN_URLS = ["stun:turn.example.test:3478"]
    settings.TURN_URLS = ["turn:turn.example.test:3478"]
    settings.TURN_SECRET = secrets.token_urlsafe(48)


def run(coro_function):
    async_to_sync(coro_function)()


async def call(client, method, route, body=None):
    from django.db import connection

    def go():
        try:
            if body is None:
                return getattr(client, method)(route)
            return getattr(client, method)(route, body, format="json")
        finally:
            connection.close()

    return await asyncio.to_thread(go)


async def setup(agents=1):
    """Agents (disponibles), client agent, client appelant, appel en sonnerie."""
    users = [await sync_to_async(make_agent)() for _ in range(agents)]
    caller = await sync_to_async(lambda: client_for(make_owner(name="Awa")))()
    clients = [await sync_to_async(client_for)(u) for u in users]
    started = (await call(caller, "post", "/api/calls/sessions/", {})).json()
    return users, clients, caller, started["session_id"]


async def open_agent(user):
    stream = await Stream(user).open()
    await stream.wait_for("presence")
    return stream


async def open_caller(user, sid):
    stream = await Stream(user, f"/api/calls/sessions/{sid}/events/").open()
    await stream.wait_for("state")
    return stream


async def nothing(stream, name="signal", timeout=0.6):
    with pytest.raises(asyncio.TimeoutError):
        await stream.wait_for(name, timeout=timeout)


def test_relais_dans_les_deux_sens_et_seulement_a_l_autre_partie():
    async def main():
        users, clients, caller, sid = await setup(agents=2)
        caller_user = caller.user
        agent_stream = await open_agent(users[0])
        other_stream = await open_agent(users[1])
        # pendant la sonnerie : conservé, pas relayé (aucun agent n'a répondu)
        offer = await call(caller, "post", f"/api/calls/sessions/{sid}/signal/",
                           {"type": "offer", "data": {"sdp": "offre"}})
        assert offer.status_code == 201
        accepted = (await call(clients[0], "post", f"{ADMIN}sessions/{sid}/accept/")).json()
        assert [s["type"] for s in accepted["signals"]] == ["offer"]
        caller_stream = await open_caller(caller_user, sid)
        await call(caller, "post", f"/api/calls/sessions/{sid}/signal/",
                   {"type": "candidate", "data": {"candidate": "c1"}})
        got = await agent_stream.wait_for("signal", session_id=sid)
        assert got["type"] == "candidate" and got["data"] == {"candidate": "c1"}
        assert isinstance(got["signal_id"], int) and set(got) == {
            "session_id", "signal_id", "type", "data"}
        await call(clients[0], "post", f"{ADMIN}sessions/{sid}/signal/",
                   {"type": "answer", "data": {"sdp": "reponse"}})
        back = await caller_stream.wait_for("signal", session_id=sid)
        assert back["type"] == "answer" and back["data"] == {"sdp": "reponse"}
        # ni l'émetteur, ni l'autre agent, ne reçoivent le signal
        await nothing(caller_stream)  # l'appelant ne reçoit pas son propre signal
        await nothing(agent_stream)  # l'agent ne reçoit pas le sien
        await nothing(other_stream)  # un autre agent ne reçoit rien (même pas l'offre)
        for stream in (agent_stream, other_stream, caller_stream):
            await stream.close()
    run(main)


def test_signal_de_16_ko_relaye_intact_au_dela_de_la_limite_notify():
    big = {"sdp": "x" * (16 * 1024 - len('{"sdp":""}'))}

    async def main():
        users, clients, caller, sid = await setup()
        await call(clients[0], "post", f"{ADMIN}sessions/{sid}/accept/")
        agent_stream = await open_agent(users[0])
        response = await call(caller, "post", f"/api/calls/sessions/{sid}/signal/",
                              {"type": "offer", "data": big})
        assert response.status_code == 201
        got = await agent_stream.wait_for("signal", session_id=sid)
        assert got["data"] == big
        await agent_stream.close()
    run(main)


def test_le_notify_ne_porte_que_des_identifiants():
    import psycopg

    marker = "MARQUEUR-" + secrets.token_hex(8)

    async def main():
        users, clients, caller, sid = await setup()
        await call(clients[0], "post", f"{ADMIN}sessions/{sid}/accept/")
        with psycopg.connect(streams.listen_conninfo(), autocommit=True) as conn:
            conn.execute(f"LISTEN {events.CHANNEL}")
            await call(caller, "post", f"/api/calls/sessions/{sid}/signal/",
                       {"type": "offer", "data": {"sdp": marker}})
            payloads = [json.loads(n.payload) for n in conn.notifies(timeout=2, stop_after=1)]
        assert payloads == [{"event": "signal", "session_id": sid,
                             "signal_id": payloads[0]["signal_id"]}]
        assert marker not in json.dumps(payloads)
    run(main)


def test_reponse_de_l_agent_rejouee_si_le_flux_de_l_appelant_s_ouvre_apres():
    async def main():
        users, clients, caller, sid = await setup()
        await call(clients[0], "post", f"{ADMIN}sessions/{sid}/accept/")
        sent = await call(clients[0], "post", f"{ADMIN}sessions/{sid}/signal/",
                          {"type": "answer", "data": {"sdp": "reponse"}})
        stream = await Stream(caller.user, f"/api/calls/sessions/{sid}/events/").open()
        got = await stream.wait_for("signal", session_id=sid)
        assert got["signal_id"] == sent.json()["signal_id"] and got["data"] == {"sdp": "reponse"}
        await nothing(stream)  # pas de doublon ensuite
        await stream.close()
    run(main)


def test_un_signal_n_est_plus_relayable_apres_la_fin_de_l_appel():
    async def main():
        users, clients, caller, sid = await setup()
        await call(clients[0], "post", f"{ADMIN}sessions/{sid}/accept/")
        await call(caller, "post", f"/api/calls/sessions/{sid}/signal/",
                   {"type": "offer", "data": {"sdp": "o"}})
        await call(caller, "post", f"/api/calls/sessions/{sid}/end/")
        refused = await call(caller, "post", f"/api/calls/sessions/{sid}/signal/",
                             {"type": "bye"})
        assert refused.status_code == 409
        stream = await Stream(caller.user, f"/api/calls/sessions/{sid}/events/").open()
        name, data = await stream.next_event()  # retry
        name, data = await stream.next_event()
        assert (name, data["state"]) == ("state", "ended")
        with pytest.raises(StopAsyncIteration):
            await stream.next_event()  # fin du flux, aucun signal rejoué
        await stream.close()
    run(main)


def percentile(values, q):
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(round(q * (len(ordered) - 1))))]


def test_latence_du_relais_p95_sous_250_ms_sur_100_signaux(capsys):
    """POST du signal -> réception par le flux SSE de l'autre partie, 100 signaux alternés
    (candidats de l'appelant vers l'agent, de l'agent vers l'appelant), flux déjà connectés.
    Mesure locale : client Django en mémoire, vraie base PostgreSQL, vrai LISTEN/NOTIFY."""
    async def main():
        users, clients, caller, sid = await setup()
        await call(clients[0], "post", f"{ADMIN}sessions/{sid}/accept/")
        agent_stream = await open_agent(users[0])
        caller_stream = await open_caller(caller.user, sid)
        routes = [(caller, f"/api/calls/sessions/{sid}/signal/", agent_stream),
                  (clients[0], f"{ADMIN}sessions/{sid}/signal/", caller_stream)]
        latencies = []
        for i in range(SIGNALS):
            client, route, receiver = routes[i % 2]
            started = time.perf_counter()
            response = await call(client, "post", route,
                                  {"type": "candidate", "data": {"candidate": f"c{i}" * 20}})
            assert response.status_code == 201
            got = await receiver.wait_for("signal", session_id=sid)
            latencies.append(time.perf_counter() - started)
            assert got["signal_id"] == response.json()["signal_id"]
        for stream in (agent_stream, caller_stream):
            await stream.close()
        return latencies

    latencies = async_to_sync(main)()
    p50, p95, worst = percentile(latencies, 0.5), percentile(latencies, 0.95), max(latencies)
    with capsys.disabled():
        print(f"\nLATENCE RELAIS SIGNAL sur {SIGNALS} signaux : "
              f"p50={p50 * 1000:.1f} ms  moyenne={statistics.mean(latencies) * 1000:.1f} ms  "
              f"p95={p95 * 1000:.1f} ms  max={worst * 1000:.1f} ms")
    assert len(latencies) == SIGNALS
    assert p95 < P95_LIMIT_SECONDS, f"p95 = {p95 * 1000:.0f} ms"
