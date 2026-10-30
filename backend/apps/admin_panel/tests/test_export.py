"""Export CSV des comptes (T074) : droits, contenu, formules, audit, en-têtes."""
import csv
import io

import pytest

from apps.admin_panel.models import AuditAction, AuditLog
from apps.admin_panel.services.export_service import safe_cell
from tests.factories.business_factory import make_owner, make_profile
from tests.factories.user_factory import UserFactory

from ._t074 import COMPLET, admin_in, api_as

pytestmark = pytest.mark.django_db

URL = "/api/admin/export/accounts.csv"


def body(response) -> str:
    return b"".join(response.streaming_content).decode("utf-8")


def rows(response):
    return list(csv.reader(io.StringIO(body(response).lstrip("﻿"))))


def test_permissions():
    # Le flux n'est lu que pour l'Administrateur complet : on vérifie le statut des autres.
    from rest_framework.test import APIClient

    from tests.factories.user_factory import AdminFactory

    from ._t074 import VALIDATEUR

    assert APIClient().get(URL).status_code == 401
    assert api_as(UserFactory()).get(URL).status_code == 403
    assert api_as(AdminFactory()).get(URL).status_code == 403
    assert api_as(admin_in(VALIDATEUR)).get(URL).status_code == 403
    assert AuditLog.objects.count() == 0  # un refus n'exporte ni n'audite
    assert api_as(admin_in(COMPLET)).get(URL).status_code == 200


def test_contenu_en_tetes_numeros_masques_et_audit():
    admin = admin_in(COMPLET, name="Chef")
    owner = make_owner()
    make_profile(owner=owner)
    simple = UserFactory(phone="+237677700042", name="Simple")
    response = api_as(admin).get(URL)
    assert response["Cache-Control"] == "no-store"
    assert response["Content-Type"].startswith("text/csv")
    assert "attachment" in response["Content-Disposition"]
    text = body(response)
    for secret in (owner.phone, owner.phone[4:], simple.phone, simple.phone[4:], admin.phone):
        assert secret not in text
    table = list(csv.reader(io.StringIO(text.lstrip("﻿"))))
    header = table[0]
    assert header[:3] == ["id", "nom", "telephone_masque"]
    assert not {"password", "mot_de_passe", "token", "jeton", "cni"} & set(header)
    by_id = {r[0]: r for r in table[1:]}
    assert by_id[str(simple.pk)][2] == "237 6•• •• •• 42"
    assert by_id[str(simple.pk)][3] == "simple"
    assert by_id[str(owner.pk)][3] == "business"
    assert len(table) - 1 == 3
    log = AuditLog.objects.get(action=AuditAction.EXPORT_COMPTES)
    assert log.admin == admin and "3 lignes" in log.reason
    assert owner.phone[4:] not in log.reason


def test_chaque_export_est_audite():
    admin = admin_in(COMPLET)
    client = api_as(admin)
    body(client.get(URL))
    body(client.get(URL))
    assert AuditLog.objects.filter(action=AuditAction.EXPORT_COMPTES).count() == 2


@pytest.mark.parametrize("start", ["=", "+", "-", "@", "\t", "\r"])
def test_injection_de_formule_neutralisee(start):
    admin = admin_in(COMPLET)
    UserFactory(name=f"{start}CMD|' /C calc'!A0")
    table = rows(api_as(admin).get(URL))
    names = [r[1] for r in table[1:]]
    assert f"'{start}CMD|' /C calc'!A0" in names
    assert not any(n.startswith(("=", "+", "-", "@")) for n in names)


def test_safe_cell():
    assert safe_cell("=1+1") == "'=1+1"
    assert safe_cell("Jean") == "Jean"
    assert safe_cell(None) == ""
    assert safe_cell(12) == "12"
