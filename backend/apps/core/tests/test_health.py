from unittest import mock

import pytest
from django.db import OperationalError


@pytest.mark.django_db
def test_health_ok(client):
    response = client.get("/api/health/")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "db": "ok"}


def test_health_base_indisponible(client):
    with mock.patch(
        "apps.core.health.views.connection.ensure_connection", side_effect=OperationalError
    ):
        response = client.get("/api/health/")
    assert response.status_code == 503
    assert response.json()["db"] == "error"
