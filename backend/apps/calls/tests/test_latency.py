"""Latence (T131 point 9, D-26) : de la réception du POST /api/calls/sessions/ à la réception de
l'événement `ringing` par un flux agent DÉJÀ connecté. 100 appels, 3 agents connectés.

Mesure faite en local, dans le processus de test (client Django en mémoire, vraie base
PostgreSQL, vrai LISTEN/NOTIFY, vrai flux SSE de l'application). Le temps du réseau mobile et
le chemin HTTP réel ne sont pas inclus : voir docs/verifications/T131.md pour l'essai avec un
vrai serveur ASGI.
"""
import asyncio
import statistics
import time

import pytest
from asgiref.sync import async_to_sync

from apps.calls.tests.helpers import client_for, make_agent, post_session
from apps.calls.tests.sse import Stream
from tests.factories.business_factory import make_owner

pytestmark = pytest.mark.django_db(transaction=True)

CALLS = 100
AGENTS = 3
P95_LIMIT_SECONDS = 0.250


def percentile(values, q):
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(round(q * (len(ordered) - 1))))]


def test_p95_sonnerie_sous_250_ms_sur_100_appels_avec_3_agents(capsys):
    agents = [make_agent() for _ in range(AGENTS)]
    callers = [client_for(make_owner(name=f"Appelant {i}")) for i in range(CALLS)]
    arrivals: list[dict[str, float]] = [{} for _ in range(AGENTS)]

    async def listen(index, stream):
        while True:
            name, data = await stream.next_event(timeout=30)
            if name == "ringing":
                arrivals[index][data["session_id"]] = time.perf_counter()

    def send(client):
        from django.db import connection

        try:
            started = time.perf_counter()
            response = post_session(client)
            return started, response
        finally:
            connection.close()

    async def main():
        streams = [await Stream(a).open() for a in agents]
        for stream in streams:
            await stream.wait_for("presence")
        readers = [asyncio.create_task(listen(i, s)) for i, s in enumerate(streams)]
        latencies = []
        for client in callers:
            started, response = await asyncio.to_thread(send, client)
            assert response.status_code == 200 and response.json()["state"] == "ringing"
            sid = response.json()["session_id"]
            deadline = time.perf_counter() + 5
            while not all(sid in seen for seen in arrivals):
                assert time.perf_counter() < deadline, "événement non reçu en 5 s"
                await asyncio.sleep(0.0005)
            latencies.append(max(seen[sid] for seen in arrivals) - started)
        for reader in readers:
            reader.cancel()
        await asyncio.gather(*readers, return_exceptions=True)
        for stream in streams:
            await stream.close()
        return latencies

    latencies = async_to_sync(main)()
    p50, p95, worst = percentile(latencies, 0.5), percentile(latencies, 0.95), max(latencies)
    with capsys.disabled():
        print(f"\nLATENCE sur {CALLS} appels, {AGENTS} agents (dernier agent atteint) : "
              f"p50={p50 * 1000:.1f} ms  moyenne={statistics.mean(latencies) * 1000:.1f} ms  "
              f"p95={p95 * 1000:.1f} ms  max={worst * 1000:.1f} ms")
    assert len(latencies) == CALLS
    assert p95 < P95_LIMIT_SECONDS, f"p95 = {p95 * 1000:.0f} ms"
