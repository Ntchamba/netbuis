"""Moteur WebRTC (T151, D-31) : réglages, serveurs ICE, identifiants TURN, signalisation.

Les flux SSE et la mesure de latence sont dans `test_webrtc_streams.py`.
"""
import base64
import hashlib
import hmac
import logging
import os
import secrets
import subprocess
import sys
import time

import pytest

from apps.calls.models import MAX_SIGNALS_PER_SESSION, CallSession, CallSignal, SessionState
from apps.calls.services import session_service
from apps.calls.tests.helpers import client_for, make_admin, make_agent, post_session
from tests.factories.business_factory import make_owner

pytestmark = pytest.mark.django_db

ADMIN = "/api/admin/calls/"
STUN = "stun:turn.example.test:3478"
TURN = ["turn:turn.example.test:3478?transport=udp", "turns:turn.example.test:5349"]


@pytest.fixture
def webrtc(settings):
    settings.CALL_ENGINE = "webrtc"
    settings.STUN_URLS = [STUN]
    settings.TURN_URLS = list(TURN)
    settings.TURN_SECRET = secrets.token_urlsafe(48)
    settings.TURN_TTL = 600
    return settings


def start():
    """(agent, client agent, client appelant, session_id) : appel en sonnerie."""
    agent = make_agent()
    caller = client_for(make_owner(name="Awa"))
    return agent, client_for(agent), caller, post_session(caller).json()["session_id"]


def answered():
    agent, agent_client, caller, sid = start()
    assert agent_client.post(f"{ADMIN}sessions/{sid}/accept/").status_code == 200
    return agent, agent_client, caller, sid


def sig(client, sid, kind="candidate", data=None, admin=False):
    base = "/api/admin/calls/sessions" if admin else "/api/calls/sessions"
    body = {"type": kind}
    if data is not None:
        body["data"] = data
    return client.post(f"{base}/{sid}/signal/", body, format="json")


# --- Réglages -------------------------------------------------------------------------------


def _settings_in_subprocess(**env):
    full = {k: v for k, v in os.environ.items()
            if k not in ("CALL_ENGINE", "TURN_TTL", "TURN_URLS", "STUN_URLS", "TURN_SECRET")}
    full.update(env)
    code = ("import config.settings.base as b; "
            "print(b.CALL_ENGINE, b.TURN_TTL, b.TURN_URLS, b.STUN_URLS, bool(b.TURN_SECRET))")
    return subprocess.run([sys.executable, "-c", code], env=full, capture_output=True, text=True,
                          cwd=os.path.dirname(os.path.dirname(os.path.dirname(
                              os.path.dirname(__file__)))))


def test_reglages_par_defaut_et_depuis_l_environnement():
    default = _settings_in_subprocess()
    assert default.returncode == 0, default.stderr
    assert default.stdout.strip() == "jitsi 600 [] [] False"
    configured = _settings_in_subprocess(
        CALL_ENGINE="webrtc", TURN_TTL="90", STUN_URLS="stun:a:3478",
        TURN_URLS="turn:a:3478, turns:a:5349", TURN_SECRET="x" * 40)
    assert configured.stdout.strip() == (
        "webrtc 90 ['turn:a:3478', 'turns:a:5349'] ['stun:a:3478'] True")


def test_moteur_inconnu_refuse_au_demarrage():
    result = _settings_in_subprocess(CALL_ENGINE="sip")
    assert result.returncode != 0 and "CALL_ENGINE" in result.stderr


# --- Création et réponse -------------------------------------------------------------------


def test_creation_webrtc_renvoie_engine_et_ice_servers_sans_jitsi_ni_secret(webrtc):
    make_agent()
    response = post_session(client_for(make_owner()))
    assert response.status_code == 200
    data = response.json()
    assert set(data) == {"session_id", "state", "code", "engine", "webrtc", "ring_seconds"}
    assert data["engine"] == "webrtc" and data["state"] == "ringing"
    stun, turn = data["webrtc"]["ice_servers"]
    assert stun == {"urls": [STUN]}
    assert turn["urls"] == TURN
    assert turn["username"].endswith(f":{data['session_id']}")
    assert webrtc.TURN_SECRET not in response.content.decode()
    assert CallSession.objects.get(pk=data["session_id"]).room not in response.content.decode()


def test_webrtc_ne_demande_pas_jitsi(webrtc):
    webrtc.JITSI_DOMAIN = webrtc.JITSI_APP_ID = webrtc.JITSI_JWT_SECRET = ""
    make_agent()
    assert post_session(client_for(make_owner())).status_code == 200


def test_sans_agent_disponible_webrtc_reste_unavailable(webrtc):
    data = post_session(client_for(make_owner())).json()
    assert data["state"] == "unavailable" and data["engine"] == "webrtc"
    assert data["webrtc"] is None and "jitsi" not in data


def test_identifiants_turn_conformes_a_coturn_calcul_de_reference(webrtc):
    make_agent()
    before = int(time.time())
    data = post_session(client_for(make_owner())).json()
    turn = data["webrtc"]["ice_servers"][1]
    expiration, session_id = turn["username"].split(":")
    assert session_id == data["session_id"]
    assert before + 600 <= int(expiration) <= int(time.time()) + 600
    # Calcul de référence indépendant du code testé (algorithme `use-auth-secret` de coturn).
    mac = hmac.new(webrtc.TURN_SECRET.encode(), turn["username"].encode(), hashlib.sha1)
    assert turn["credential"] == base64.b64encode(mac.digest()).decode()
    other = hmac.new(b"un-autre-secret" * 3, turn["username"].encode(), hashlib.sha1)
    assert turn["credential"] != base64.b64encode(other.digest()).decode()


def test_turn_ttl_respecte(webrtc):
    webrtc.TURN_TTL = 90
    make_agent()
    turn = post_session(client_for(make_owner())).json()["webrtc"]["ice_servers"][1]
    assert int(turn["username"].split(":")[0]) - int(time.time()) in range(88, 91)


@pytest.mark.parametrize("secret", ["", "trop-court"])
def test_secret_turn_absent_ou_court_stun_seul_et_erreur_sans_secret(webrtc, caplog, secret):
    webrtc.TURN_SECRET = secret
    make_agent()
    with caplog.at_level(logging.DEBUG):
        data = post_session(client_for(make_owner())).json()
    assert data["webrtc"]["ice_servers"] == [{"urls": [STUN]}]
    errors = [r for r in caplog.records if r.levelno == logging.ERROR]
    assert errors and "TURN_SECRET" in errors[0].getMessage()
    if secret:
        assert secret not in caplog.text


def test_accept_webrtc_renvoie_ice_servers_et_signaux_en_attente(webrtc):
    agent, agent_client, caller, sid = start()
    assert sig(caller, sid, "offer", {"sdp": "v=0 offre"}).status_code == 201
    assert sig(caller, sid, "candidate", {"candidate": "c1"}).status_code == 201
    response = agent_client.post(f"{ADMIN}sessions/{sid}/accept/")
    assert response.status_code == 200
    body = response.json()
    assert set(body) == {"session_id", "caller_name", "business", "engine", "webrtc", "signals"}
    assert body["engine"] == "webrtc"
    assert body["webrtc"]["ice_servers"][1]["username"].endswith(f":{sid}")
    assert [(s["type"], s["data"]) for s in body["signals"]] == [
        ("offer", {"sdp": "v=0 offre"}), ("candidate", {"candidate": "c1"})]
    assert webrtc.TURN_SECRET not in response.content.decode()


def test_moteur_jitsi_inchange_pas_de_cle_webrtc(settings):
    assert settings.CALL_ENGINE == "jitsi"
    agent, agent_client, caller, sid = start()
    body = agent_client.post(f"{ADMIN}sessions/{sid}/accept/").json()
    assert set(body) == {"session_id", "caller_name", "business", "engine", "jitsi"}
    assert body["engine"] == "jitsi"


# --- Signalisation : droits et phases ------------------------------------------------------


def test_appelant_et_agent_s_echangent_des_signaux(webrtc):
    agent, agent_client, caller, sid = answered()
    offer = sig(caller, sid, "offer", {"sdp": "o"})
    answer = sig(agent_client, sid, "answer", {"sdp": "a"}, admin=True)
    assert offer.status_code == answer.status_code == 201
    assert offer.json()["signal_id"] < answer.json()["signal_id"]
    assert offer["Cache-Control"] == "no-store"
    rows = list(CallSignal.objects.filter(session_id=sid).order_by("id"))
    assert [(r.from_role, r.kind) for r in rows] == [("caller", "offer"), ("agent", "answer")]
    assert sig(caller, sid, "bye").status_code == 201  # `data` facultatif


def test_signal_refuse_a_un_tiers_et_a_un_autre_agent(webrtc):
    agent, agent_client, caller, sid = answered()
    stranger = client_for(make_owner())
    assert sig(stranger, sid).status_code == 404  # un autre appelant
    other_agent = client_for(make_agent())
    assert sig(other_agent, sid, admin=True).status_code == 404  # un autre agent
    assert sig(caller, sid, admin=True).status_code == 403  # l'appelant n'a pas le droit agent
    assert sig(client_for(make_admin()), sid, admin=True).status_code == 403  # sans le droit
    assert sig(agent_client, sid).status_code == 404  # l'agent n'est pas l'appelant
    assert CallSignal.objects.count() == 0


def test_agent_ne_peut_signaler_qu_apres_accept(webrtc):
    agent, agent_client, caller, sid = start()
    assert sig(agent_client, sid, "answer", {"sdp": "a"}, admin=True).status_code == 404
    assert CallSignal.objects.count() == 0


def test_non_connecte_refuse(webrtc):
    from rest_framework.test import APIClient

    agent, agent_client, caller, sid = start()
    assert sig(APIClient(), sid).status_code == 401
    assert sig(APIClient(), sid, admin=True).status_code == 401


def test_session_terminee_ou_mauvaise_phase_refusee(webrtc):
    agent, agent_client, caller, sid = answered()
    assert caller.post(f"/api/calls/sessions/{sid}/end/").status_code == 200
    for client, admin in ((caller, False), (agent_client, True)):
        refused = sig(client, sid, admin=admin)
        assert refused.status_code == 409 and refused.json()["code"] == "call_not_active"
    # annulée avant réponse
    caller2 = client_for(make_owner())
    sid2 = post_session(caller2).json()["session_id"]
    assert caller2.post(f"/api/calls/sessions/{sid2}/cancel/").status_code == 200
    assert sig(caller2, sid2).status_code == 409
    # sonnerie expirée (pas encore refermée par le flux)
    caller3 = client_for(make_owner())
    sid3 = post_session(caller3).json()["session_id"]
    CallSession.objects.filter(pk=sid3).update(
        expires_at=CallSession.objects.get(pk=sid3).ringing_at)
    assert sig(caller3, sid3).status_code == 409


def test_signal_pendant_la_sonnerie_accepte_pour_l_appelant(webrtc):
    agent, agent_client, caller, sid = start()
    assert CallSession.objects.get(pk=sid).state == SessionState.RINGING
    assert sig(caller, sid, "offer", {"sdp": "o"}).status_code == 201


def test_signal_refuse_si_le_moteur_est_jitsi(settings):
    agent, agent_client, caller, sid = answered()
    refused = sig(caller, sid)
    assert refused.status_code == 409 and refused.json()["code"] == "webrtc_not_enabled"


# --- Signalisation : validation, taille, quota ---------------------------------------------


@pytest.mark.parametrize("body", [
    {"type": "hello", "data": {}}, {}, {"type": "offer", "data": "texte"},
    {"type": "offer", "data": [1, 2]},
])
def test_corps_invalide_refuse(webrtc, body):
    agent, agent_client, caller, sid = answered()
    response = caller.post(f"/api/calls/sessions/{sid}/signal/", body, format="json")
    assert response.status_code == 400
    assert CallSignal.objects.count() == 0


def test_taille_limitee_a_16_ko(webrtc):
    agent, agent_client, caller, sid = answered()
    limit = 16 * 1024
    just_ok = {"sdp": "x" * (limit - len('{"sdp":""}'))}
    assert sig(caller, sid, "offer", just_ok).status_code == 201
    too_big = sig(caller, sid, "offer", {"sdp": "x" * (limit - len('{"sdp":""}') + 1)})
    assert too_big.status_code == 413 and too_big.json()["code"] == "signal_too_large"
    assert CallSignal.objects.filter(session_id=sid).count() == 1


def test_au_plus_200_signaux_par_session(webrtc):
    agent, agent_client, caller, sid = answered()
    CallSignal.objects.bulk_create([
        CallSignal(session_id=sid, from_role="caller", kind="candidate", data={})
        for _ in range(MAX_SIGNALS_PER_SESSION - 1)])
    assert sig(caller, sid, "candidate", {"c": 1}).status_code == 201  # le 200e
    refused = sig(caller, sid, "candidate", {"c": 2})
    assert refused.status_code == 429 and refused.json()["code"] == "signal_quota_exceeded"
    assert sig(agent_client, sid, "answer", {}, admin=True).status_code == 429  # quota commun
    assert CallSignal.objects.filter(session_id=sid).count() == MAX_SIGNALS_PER_SESSION


# --- Fin de session et journaux ------------------------------------------------------------


def test_signaux_supprimes_a_la_fin_de_la_session(webrtc):
    # fin par raccrocher
    agent, agent_client, caller, sid = answered()
    sig(caller, sid, "offer", {"sdp": "o"})
    assert CallSignal.objects.filter(session_id=sid).count() == 1
    assert agent_client.post(f"{ADMIN}sessions/{sid}/end/").status_code == 200
    assert CallSignal.objects.filter(session_id=sid).count() == 0
    # annulation
    caller2 = client_for(make_owner())
    sid2 = post_session(caller2).json()["session_id"]
    sig(caller2, sid2, "offer", {"sdp": "o"})
    caller2.post(f"/api/calls/sessions/{sid2}/cancel/")
    assert CallSignal.objects.filter(session_id=sid2).count() == 0
    # sonnerie expirée
    caller3 = client_for(make_owner())
    sid3 = post_session(caller3).json()["session_id"]
    sig(caller3, sid3, "offer", {"sdp": "o"})
    CallSession.objects.filter(pk=sid3).update(
        expires_at=CallSession.objects.get(pk=sid3).ringing_at)
    session_service.expire_stale()
    assert CallSignal.objects.filter(session_id=sid3).count() == 0
    assert CallSignal.objects.count() == 0


def test_aucun_contenu_de_signal_dans_les_journaux(webrtc, caplog):
    marker = "MARQUEUR-SDP-" + secrets.token_hex(8)
    with caplog.at_level(logging.DEBUG):
        agent, agent_client, caller, sid = start()
        sig(caller, sid, "offer", {"sdp": marker})
        accepted = agent_client.post(f"{ADMIN}sessions/{sid}/accept/")
        sig(agent_client, sid, "answer", {"sdp": marker}, admin=True)
        sig(caller, sid, "candidate", {"candidate": marker})
        sig(caller, sid, "offer", {"sdp": marker * 5000})  # refusé : trop gros
    assert accepted.json()["signals"][0]["data"] == {"sdp": marker}
    assert marker not in caplog.text
    assert webrtc.TURN_SECRET not in caplog.text
