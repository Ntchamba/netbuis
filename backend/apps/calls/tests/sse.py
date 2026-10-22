"""Lecteur SSE pour les tests : ouvre un flux avec le client asynchrone de Django, lit les
événements, puis ferme comme un navigateur qui se déconnecte (annulation de la lecture, comme le
fait le serveur ASGI) : la connexion LISTEN et la présence de l'agent sont alors libérées."""
import asyncio
import json
import time

from asgiref.sync import sync_to_async
from django.test import AsyncClient

from apps.accounts.services.token_service import issue_tokens

_END = object()


class Stream:
    def __init__(self, user, path="/api/admin/calls/stream/"):
        self.user, self.path = user, path
        self.response = None
        self._queue: asyncio.Queue = asyncio.Queue()
        self._task = None
        self._buffer = ""

    async def open(self):
        token = (await sync_to_async(issue_tokens)(self.user))["access"]
        self.response = await AsyncClient().get(
            self.path, headers={"Authorization": f"Bearer {token}",
                                "Accept": "text/event-stream"},
        )
        if self.response.status_code == 200:
            self._task = asyncio.create_task(self._pump())
        return self

    async def _pump(self):
        try:
            async for chunk in self.response.streaming_content:
                await self._queue.put(chunk)
        finally:
            await self._queue.put(_END)

    async def next_event(self, timeout=5.0):
        """(nom, données) du prochain événement ; commentaires et `retry` sont rendus sous leur
        nom. `StopAsyncIteration` quand le serveur a terminé le flux."""
        deadline = time.monotonic() + timeout
        while "\n\n" not in self._buffer:
            chunk = await asyncio.wait_for(
                self._queue.get(), max(0.01, deadline - time.monotonic()))
            if chunk is _END:
                await self._queue.put(_END)
                raise StopAsyncIteration
            self._buffer += chunk.decode()
        block, self._buffer = self._buffer.split("\n\n", 1)
        if block.startswith(":"):
            return "comment", {}
        if block.startswith("retry:"):
            return "retry", {}
        name = block.split("\n")[0].removeprefix("event: ")
        data = json.loads(block.split("\n")[1].removeprefix("data: "))
        return name, data

    async def wait_for(self, name, timeout=5.0, session_id=None):
        """Lit jusqu'à l'événement `name` (pour `session_id` si donné) et le retourne."""
        deadline = time.monotonic() + timeout
        while True:
            got, data = await self.next_event(max(0.01, deadline - time.monotonic()))
            if got == name and (session_id is None or data.get("session_id") == session_id):
                return data

    async def close(self):
        if self._task is not None:
            self._task.cancel()
            await asyncio.gather(self._task, return_exceptions=True)
