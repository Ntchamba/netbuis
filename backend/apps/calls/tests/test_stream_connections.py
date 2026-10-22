"""T122 — Un flux inactif ne garde que sa connexion `LISTEN` (pas une seconde connexion Django).

Mesure faite avec un vrai serveur ASGI : avant correction 50 agents = 100 connexions PostgreSQL
(`docs/verifications/T122-backend.md`). Ici : (1) l'aide `_db` ne laisse aucune connexion ouverte
après un appel, (2) trois flux agent ouverts ne tiennent que trois connexions de plus.
"""
import asyncio

import pytest
from asgiref.sync import async_to_sync, sync_to_async
from django.db import connection

from apps.accounts.models import User
from apps.calls.services import streams
from apps.calls.tests.helpers import make_agent
from apps.calls.tests.sse import Stream

pytestmark = pytest.mark.django_db(transaction=True)


def _other_connections() -> int:
    """Connexions ouvertes sur la base de test, sans compter celle qui pose la question."""
    with connection.cursor() as cursor:
        cursor.execute(
            "select count(*) from pg_stat_activity "
            "where datname = current_database() and pid <> pg_backend_pid()")
        return cursor.fetchone()[0]


def test_l_aide_ferme_sa_connexion_apres_chaque_appel():
    async def scenario():
        user = await sync_to_async(make_agent)()
        before = await sync_to_async(_other_connections)()
        found = await streams._db(lambda pk: User.objects.get(pk=pk).phone)(user.pk)
        assert found == user.phone
        await asyncio.sleep(0.2)
        assert await sync_to_async(_other_connections)() == before

    async_to_sync(scenario)()


def test_l_aide_ferme_aussi_sa_connexion_quand_l_appel_echoue():
    async def scenario():
        before = await sync_to_async(_other_connections)()
        with pytest.raises(User.DoesNotExist):
            await streams._db(lambda: User.objects.get(pk=0))()
        await asyncio.sleep(0.2)
        assert await sync_to_async(_other_connections)() == before

    async_to_sync(scenario)()


def test_trois_flux_agent_ouverts_tiennent_trois_connexions_de_plus():
    async def scenario():
        agents = [await sync_to_async(make_agent)() for _ in range(3)]
        before = await sync_to_async(_other_connections)()
        opened = [await Stream(agent).open() for agent in agents]
        try:
            for stream in opened:
                await stream.wait_for("presence")
            await asyncio.sleep(0.5)  # les lectures de départ sont terminées
            assert await sync_to_async(_other_connections)() == before + 3
        finally:
            for stream in opened:
                await stream.close()

    async_to_sync(scenario)()


def _leaks_a_connection(client, route) -> bool:
    """La vue d'un flux rend-elle sa connexion avant de renvoyer la réponse ? (dans ce fil)"""

    def call():
        try:
            response = client.get(route)
            assert response.status_code == 200
            return connection.connection is not None
        finally:
            connection.close()

    return call()


def test_les_vues_de_flux_rendent_la_connexion_de_la_requete():
    from apps.calls.tests.helpers import client_for, post_session
    from tests.factories.business_factory import make_owner

    async def scenario():
        agent = await sync_to_async(make_agent)()
        agent_client = await sync_to_async(client_for)(agent)
        caller_client = await sync_to_async(client_for)(await sync_to_async(make_owner)())
        session_id = (await asyncio.to_thread(post_session, caller_client)).json()["session_id"]
        assert not await asyncio.to_thread(
            _leaks_a_connection, agent_client, "/api/admin/calls/stream/")
        assert not await asyncio.to_thread(
            _leaks_a_connection, caller_client, f"/api/calls/sessions/{session_id}/events/")

    async_to_sync(scenario)()


def test_une_connexion_au_milieu_d_une_transaction_n_est_pas_fermee():
    from django.db import transaction

    with transaction.atomic():
        streams.release_request_connection()
        assert connection.connection is not None
        assert User.objects.count() >= 0  # la transaction continue de fonctionner
    streams.release_request_connection()
    assert connection.connection is None
