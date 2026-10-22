"""Fiche de l'appel en cours (T132b, D-30) : seule route qui renvoie les numéros."""
import logging

import pytest
from rest_framework.test import APIClient

from apps.admin_panel.models import AuditAction, AuditLog
from apps.calls.models import CallSession, SessionState
from apps.calls.services import events, session_service
from apps.calls.tests.helpers import client_for, make_admin, make_agent, post_session
from tests.factories.business_factory import make_owner, make_profile, make_subscription

pytestmark = pytest.mark.django_db

ADMIN = "/api/admin/calls/"


def url(session_id):
    return f"{ADMIN}sessions/{session_id}/context/"


def answered_call(business=None, agent=None):
    """Appel décroché ; retourne (client appelant, id, client agent, agent)."""
    agent = agent or make_agent(name="Moussa")
    caller = client_for(make_owner(name="Awa"))
    session_id = post_session(caller, business.pk if business else None).json()["session_id"]
    agent_client = client_for(agent)
    assert agent_client.post(f"{ADMIN}sessions/{session_id}/accept/").status_code == 200
    return caller, session_id, agent_client, agent


def test_l_agent_qui_a_repondu_recoit_les_deux_numeros_et_la_fiche():
    profile = make_profile(status="actif", name="Chez Riz")
    make_subscription(profile)
    caller, session_id, agent_client, _ = answered_call(profile)
    response = agent_client.get(url(session_id))
    assert response.status_code == 200 and response["Cache-Control"] == "no-store"
    body = response.json()
    assert body["session_id"] == session_id and body["state"] == "answered"
    assert body["caller"] == {"name": "Awa", "phone": caller.user.phone}
    card = body["business"]
    assert card["phone"] == profile.phone_anchor and card["name"] == "Chez Riz"
    assert card["kind"] == "entreprise" and card["type_label"]
    assert card["zone_name"] and card["status"] == "actif"
    assert card["subscription"]["active"] is True
    assert card["reports_count"] == 0 and isinstance(card["history"], list)


def test_particulier_et_appel_sans_commerce():
    profile = make_profile("particulier_vendeur", status="actif")
    _, session_id, agent_client, _ = answered_call(profile)
    assert agent_client.get(url(session_id)).json()["business"]["kind"] == "particulier"
    _, other_id, other_client, _ = answered_call(None, agent=make_agent())
    body = other_client.get(url(other_id)).json()
    assert body["business"] is None and body["caller"]["phone"]


def test_un_autre_agent_recoit_404_sans_numero():
    profile = make_profile(status="actif")
    caller, session_id, _, _ = answered_call(profile)
    other = client_for(make_agent(group="Administrateur complet"))
    response = other.get(url(session_id))
    assert response.status_code == 404
    text = response.content.decode()
    assert caller.user.phone not in text and profile.phone_anchor not in text


def test_appel_en_sonnerie_refuse_avec_409():
    profile = make_profile(status="actif")
    make_agent()
    caller = client_for(make_owner(name="Awa"))
    session_id = post_session(caller, profile.pk).json()["session_id"]
    agent = make_agent(name="Autre")
    CallSession.objects.filter(pk=session_id).update(agent=agent)  # même s'il était assigné
    response = client_for(agent).get(url(session_id))
    assert response.status_code == 409 and response.json()["code"] == "call_not_answered"
    assert profile.phone_anchor not in response.content.decode()


@pytest.mark.parametrize("fin", ["agent", "appelant"])
def test_appel_termine_refuse_avec_409(fin):
    profile = make_profile(status="actif")
    caller, session_id, agent_client, _ = answered_call(profile)
    assert agent_client.get(url(session_id)).status_code == 200
    if fin == "agent":
        agent_client.post(f"{ADMIN}sessions/{session_id}/end/")
    else:
        caller.post(f"/api/calls/sessions/{session_id}/end/")
    assert CallSession.objects.get(pk=session_id).state == SessionState.ENDED
    response = agent_client.get(url(session_id))
    assert response.status_code == 409 and response.json()["code"] == "call_not_answered"
    assert profile.phone_anchor not in response.content.decode()


def test_sans_droit_ou_sans_connexion():
    _, session_id, _, agent = answered_call(make_profile(status="actif"))
    assert APIClient().get(url(session_id)).status_code == 401
    assert client_for(make_owner()).get(url(session_id)).status_code == 403
    assert client_for(make_admin()).get(url(session_id)).status_code == 403
    agent.groups.clear()  # droit retiré : l'agent qui a répondu ne lit plus rien
    assert client_for(agent).get(url(session_id)).status_code == 403


def test_session_inconnue_404():
    agent_client = client_for(make_agent())
    assert agent_client.get(url("00000000-0000-0000-0000-000000000000")).status_code == 404


def test_chaque_lecture_est_tracee_sans_numero_dans_le_journal(caplog):
    profile = make_profile(status="actif")
    caller, session_id, agent_client, agent = answered_call(profile)
    with caplog.at_level(logging.DEBUG):
        agent_client.get(url(session_id))
        agent_client.get(url(session_id))
    session = CallSession.objects.get(pk=session_id)
    assert session.context_views == 2 and session.context_viewed_at is not None
    assert any("fiche lue" in r.getMessage() for r in caplog.records)
    assert AuditLog.objects.filter(
        admin=agent, action=AuditAction.CONSULTATION_NUMERO).count() == 2
    for record in caplog.records:
        text = record.getMessage()
        assert profile.phone_anchor not in text and caller.user.phone not in text


def test_les_numeros_ne_sortent_ni_de_la_sonnerie_ni_de_la_liste_ni_de_l_historique():
    profile = make_profile(status="actif", name="Chez Riz")
    caller, session_id, agent_client, agent = answered_call(profile)
    numbers = {profile.phone_anchor, caller.user.phone, profile.owner.phone}
    session = CallSession.objects.get(pk=session_id)
    ring = events.state_payload(session)
    replay = session_service.ringing_sessions()
    accepted_like = [
        agent_client.get(ADMIN).content.decode(),
        caller.get("/api/calls/history/").content.decode(),
        caller.get(f"/api/calls/sessions/{session_id}/").content.decode(),
        str(ring), str(replay),
    ]
    for text in accepted_like:
        for number in numbers:
            assert number not in text
    # Lecture de la fiche après coup : la liste et l'historique restent propres.
    agent_client.get(url(session_id))
    for text in (agent_client.get(ADMIN).content.decode(),
                 caller.get("/api/calls/history/").content.decode()):
        for number in numbers:
            assert number not in text


def test_la_fiche_ne_donne_jamais_les_pieces_privees():
    profile = make_profile("prestataire_service", status="actif")
    _, session_id, agent_client, _ = answered_call(profile)
    text = agent_client.get(url(session_id)).content.decode()
    assert "cni_url" not in text and "diplome" not in text
