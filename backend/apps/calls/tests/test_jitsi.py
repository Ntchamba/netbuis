"""Accès Jitsi (T131 point 3) : salle secrète, jeton HS256 limité à une salle."""
import base64
import json
import time

import jwt
import pytest
from django.conf import settings as django_settings

from apps.calls.models import CallSession
from apps.calls.services import jitsi
from apps.calls.tests.helpers import client_for, make_agent, post_session
from tests.factories.business_factory import make_owner

pytestmark = pytest.mark.django_db


def decode(token, secret=None):
    return jwt.decode(
        token, secret or django_settings.JITSI_JWT_SECRET, algorithms=["HS256"], audience="jitsi"
    )


def test_la_salle_est_secrete_au_moins_128_bits_et_unique():
    rooms = {jitsi.new_room_name() for _ in range(200)}
    assert len(rooms) == 200
    sample = next(iter(rooms))
    raw = base64.urlsafe_b64decode(sample + "=" * (-len(sample) % 4))
    assert len(raw) * 8 >= 128


def test_structure_du_jeton_appelant():
    make_agent()
    started = post_session(client_for(make_owner(name="Awa"))).json()
    token = started["jitsi"]["jwt"]
    assert jwt.get_unverified_header(token)["alg"] == "HS256"
    claims = decode(token)
    assert claims["iss"] == "netbuis-test" and claims["aud"] == "jitsi"
    assert claims["sub"] == "jitsi.example.test"
    assert claims["room"] == started["jitsi"]["room"]  # UNE salle, pas de joker
    assert claims["room"] != "*"
    assert claims["exp"] - int(time.time()) <= django_settings.JITSI_TOKEN_TTL
    assert claims["exp"] - int(time.time()) > 60  # court mais utilisable
    assert claims["context"]["user"]["moderator"] is False
    assert claims["context"]["user"]["name"] == "Awa"
    assert claims["context"]["features"] == {
        "recording": False, "livestreaming": False, "transcription": False,
        "outbound-call": False}


def test_jeton_agent_moderateur_pour_la_meme_salle():
    agent = make_agent(name="Moussa")
    caller = client_for(make_owner())
    started = post_session(caller).json()
    accepted = client_for(agent).post(
        f"/api/admin/calls/sessions/{started['session_id']}/accept/").json()
    agent_claims = decode(accepted["jitsi"]["jwt"])
    assert agent_claims["context"]["user"]["moderator"] is True
    assert agent_claims["room"] == started["jitsi"]["room"] == accepted["jitsi"]["room"]
    assert accepted["jitsi"]["jwt"] != started["jitsi"]["jwt"]


def test_le_jeton_n_est_pas_valable_avec_un_autre_secret_et_ne_contient_aucun_numero():
    make_agent()
    owner = make_owner()
    token = post_session(client_for(owner)).json()["jitsi"]["jwt"]
    with pytest.raises(jwt.InvalidSignatureError):
        decode(token, secret="un-autre-secret-de-plus-de-trente-deux-caracteres")
    payload = base64.urlsafe_b64decode(token.split(".")[1] + "==").decode()
    assert owner.phone not in payload and owner.phone[-8:] not in payload
    assert json.loads(payload)["context"]["user"]["id"] == str(owner.pk)


@pytest.mark.parametrize("name", ["JITSI_JWT_SECRET", "JITSI_APP_ID", "JITSI_DOMAIN"])
def test_configuration_absente_aucun_jeton_emis(settings, name, caplog):
    setattr(settings, name, "")
    assert not jitsi.is_configured()
    with pytest.raises(jitsi.JitsiNotConfigured):
        jitsi.build_join("salle", user_id=1, display_name="x", moderator=False)
    assert "obligatoires" in caplog.text  # la configuration est signalée
    assert not CallSession.objects.exists()


def test_secret_trop_court_est_refuse(settings):
    settings.JITSI_JWT_SECRET = "court"
    assert not jitsi.is_configured()


def test_accept_sans_configuration_est_refuse_et_la_session_reste_en_sonnerie(settings):
    agent = make_agent()
    started = post_session(client_for(make_owner())).json()
    settings.JITSI_JWT_SECRET = ""
    response = client_for(agent).post(
        f"/api/admin/calls/sessions/{started['session_id']}/accept/")
    assert response.status_code == 503 and response.json()["code"] == "jitsi_not_configured"
    assert CallSession.objects.get().state == "ringing"
