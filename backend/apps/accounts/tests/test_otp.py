"""Codes SMS (OTP) : T006. Numéros de test 6 00 00 00 XX (D-18) ; codes générés par le test."""
import hashlib
import hmac
import logging
import os
import re
import subprocess
import sys
import threading
from datetime import timedelta

import pytest
from django.conf import settings as django_settings
from django.core.cache import cache
from django.core.exceptions import ImproperlyConfigured
from django.db import connection
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.models import OtpCode, User
from apps.accounts.services import otp_service
from apps.accounts.services.otp_service import TooManyRequests, request_code
from apps.accounts.sms import ConsoleSmsBackend, RealSmsProvider, SmsBackend, get_sms_provider
from tests.factories.user_factory import UserFactory

pytestmark = pytest.mark.django_db

REQUEST_URL = "/api/auth/otp/request/"
VERIFY_URL = "/api/auth/otp/verify/"
PHONE = "600000001"
E164 = "+237600000001"


@pytest.fixture(autouse=True)
def _dev(settings):
    settings.DEBUG = True  # le fournisseur console l'exige
    settings.SMS_PROVIDER = "console"
    cache.clear()  # compteurs du throttle par IP
    yield
    cache.clear()


@pytest.fixture
def client():
    return APIClient()


def ask_code(client, capsys, phone=PHONE):
    """Demande un code et le lit sur la console du serveur, comme un développeur."""
    capsys.readouterr()
    response = client.post(REQUEST_URL, {"phone": phone}, format="json")
    assert response.status_code == 202, response.data
    return re.search(r"Votre code NetBuis : (\d{6}) \(valable 5 min\)", capsys.readouterr().out)[1]


def verify(client, code, phone=PHONE, **extra):
    return client.post(VERIFY_URL, {"phone": phone, "code": code}, format="json", **extra)


def wrong(code):
    return f"{(int(code) + 1) % 1_000_000:06d}"


# --- Numéro ---------------------------------------------------------------


@pytest.mark.parametrize("phone", ["600000001", "+237600000001", "237 600 00 00 01"])
def test_numero_camerounais_accepte(client, capsys, phone):
    ask_code(client, capsys, phone)
    assert OtpCode.objects.get().phone == E164


@pytest.mark.parametrize(
    "phone", ["700000001", "60000001", "6000000011", "+33600000001", "+237 700000001", "abc"]
)
def test_numero_invalide_refuse(client, phone):
    response = client.post(REQUEST_URL, {"phone": phone}, format="json")
    assert response.status_code == 400
    assert response.data["code"] == "invalid_phone"
    assert "numéro mobile camerounais" in response.data["message"]
    assert not OtpCode.objects.exists()


def test_numero_invalide_refuse_aussi_a_la_verification(client):
    response = verify(client, "123456", phone="700000001")
    assert response.status_code == 400
    assert response.data["code"] == "invalid_phone"


def test_numero_manquant(client):
    response = client.post(REQUEST_URL, {}, format="json")
    assert response.status_code == 400
    assert "phone" in response.data["fields"]


# --- Code -----------------------------------------------------------------


def test_demande_cree_un_code_hache_valable_5_minutes(client, capsys, settings):
    before = timezone.now()
    code = ask_code(client, capsys)
    otp = OtpCode.objects.get()
    # HMAC-SHA256, clé SECRET_KEY, numéro inclus (T006b) ; jamais le code en clair.
    expected = hmac.new(
        settings.SECRET_KEY.encode(), f"{E164}:{code}".encode(), hashlib.sha256
    ).hexdigest()
    assert otp.code_hash == expected and code not in otp.code_hash
    assert otp_service.hash_code("+237600000002", code) != expected  # lié au numéro
    assert before + timedelta(minutes=5) <= otp.expires_at <= timezone.now() + timedelta(minutes=5)
    assert otp.attempts == 0 and otp.used_at is None


def test_reponse_de_la_demande(client):
    response = client.post(REQUEST_URL, {"phone": PHONE}, format="json")
    assert response.status_code == 202
    assert response.data == {"expires_in": 300}


def test_succes_cree_le_compte(client, capsys):
    response = verify(client, ask_code(client, capsys))
    assert response.status_code == 200
    assert response.data["is_new"] is True
    assert response.data["access"] and response.data["refresh"]
    user = User.objects.get(phone=E164)
    assert not user.has_usable_password() and not user.is_admin
    assert OtpCode.objects.get().used_at is not None


def test_succes_retrouve_le_compte_existant(client, capsys):
    existing = UserFactory(phone=E164)
    response = verify(client, ask_code(client, capsys))
    assert response.status_code == 200
    assert response.data["is_new"] is False
    assert User.objects.get() == existing


def test_code_faux(client, capsys):
    code = ask_code(client, capsys)
    response = verify(client, wrong(code))
    assert response.status_code == 400
    assert response.data["code"] == "otp_invalid"
    assert OtpCode.objects.get().attempts == 1
    assert not User.objects.exists()


def test_sans_code_demande(client):
    response = verify(client, "123456")
    assert response.status_code == 400
    assert response.data["code"] == "otp_invalid"


def test_code_expire(client, capsys):
    code = ask_code(client, capsys)
    OtpCode.objects.update(expires_at=timezone.now() - timedelta(seconds=1))
    response = verify(client, code)
    assert response.status_code == 400
    assert response.data["code"] == "otp_expired"
    assert not User.objects.exists()


def test_code_reutilise(client, capsys):
    code = ask_code(client, capsys)
    assert verify(client, code).status_code == 200
    response = verify(client, code)
    assert response.status_code == 400
    assert response.data["code"] == "otp_invalid"


def test_seul_le_dernier_code_est_valable(client, capsys):
    first = ask_code(client, capsys)
    second = ask_code(client, capsys)
    if first != second:
        assert verify(client, first).data["code"] == "otp_invalid"
    assert verify(client, second).status_code == 200


def test_cinquieme_essai_encore_possible(client, capsys):
    code = ask_code(client, capsys)
    for _ in range(4):
        assert verify(client, wrong(code)).status_code == 400
    assert verify(client, code).status_code == 200


def test_comparaison_en_temps_constant(client, capsys, monkeypatch):
    calls = []
    real = hmac.compare_digest
    monkeypatch.setattr(hmac, "compare_digest", lambda a, b: calls.append(1) or real(a, b))
    code = ask_code(client, capsys)
    assert verify(client, wrong(code)).status_code == 400
    assert verify(client, code).status_code == 200
    assert len(calls) == 2


def test_cinq_codes_faux_bloquent_le_numero_une_heure(client, capsys):
    code = ask_code(client, capsys)
    for _ in range(5):
        assert verify(client, wrong(code)).data["code"] == "otp_invalid"
    response = verify(client, code)  # même le bon code est refusé
    assert response.status_code == 429
    assert response.data["code"] == "too_many_requests"
    assert 3590 <= int(response["Retry-After"]) <= 3600
    # Pendant le blocage, impossible aussi de demander un nouveau code.
    blocked = client.post(REQUEST_URL, {"phone": PHONE}, format="json")
    assert blocked.status_code == 429
    assert 3590 <= int(blocked["Retry-After"]) <= 3600
    assert OtpCode.objects.count() == 1
    assert not User.objects.exists()
    ask_code(client, capsys, phone="600000002")  # un autre numéro n'est pas touché


def test_codes_faux_repartis_sur_plusieurs_codes_bloquent_le_numero(client, capsys):
    """Contournement : 2 faux, nouveau code, 2 faux, nouveau code, 1 faux = 5 faux."""
    for wrong_count in (2, 2, 1):
        code = ask_code(client, capsys)
        for _ in range(wrong_count):
            assert verify(client, wrong(code)).data["code"] == "otp_invalid"
    response = verify(client, code)  # même le bon code est refusé
    assert response.status_code == 429
    assert response.data["code"] == "too_many_requests"
    assert 3590 <= int(response["Retry-After"]) <= 3600
    blocked = client.post(REQUEST_URL, {"phone": PHONE}, format="json")
    assert blocked.status_code == 429
    assert 3590 <= int(blocked["Retry-After"]) <= 3600
    assert not User.objects.exists()


def test_blocage_leve_apres_une_heure(client, capsys):
    code = ask_code(client, capsys)
    for _ in range(5):
        verify(client, wrong(code))
    OtpCode.objects.update(blocked_until=timezone.now() - timedelta(seconds=1))
    response = verify(client, code)  # le code brûlé reste refusé
    assert response.status_code == 429
    assert "nouveau code" in response.data["message"]
    assert verify(client, ask_code(client, capsys)).status_code == 200


# --- Compte bloqué ou supprimé (can_login) --------------------------------


def test_compte_bloque_refuse(client, capsys):
    UserFactory(phone=E164, is_blocked=True, blocked_at=timezone.now())
    response = verify(client, ask_code(client, capsys))
    assert response.status_code == 403
    assert response.data["code"] == "account_blocked"
    assert "Contactez le support" in response.data["message"]
    assert "access" not in response.data


def test_compte_supprime_refuse(client, capsys):
    UserFactory(phone=E164, is_deleted=True, deleted_at=timezone.now())
    response = verify(client, ask_code(client, capsys))
    assert response.status_code == 403
    assert response.data["code"] == "account_deleted"
    assert response.data["message"] == "Ce compte a été supprimé. Contactez le support."


# --- Limites --------------------------------------------------------------


def test_limite_par_numero(client, capsys):
    for _ in range(3):
        ask_code(client, capsys)
    response = client.post(REQUEST_URL, {"phone": PHONE}, format="json")
    assert response.status_code == 429
    assert response.data["code"] == "too_many_requests"
    assert 1 <= int(response["Retry-After"]) <= 600
    assert OtpCode.objects.count() == 3
    ask_code(client, capsys, phone="600000002")  # un autre numéro n'est pas touché


def test_limite_par_numero_levee_apres_10_minutes(client, capsys):
    for _ in range(3):
        ask_code(client, capsys)
    OtpCode.objects.update(created_at=timezone.now() - timedelta(minutes=10, seconds=1))
    ask_code(client, capsys)


def test_limite_par_ip(client, capsys):
    for i in range(10):
        ask_code(client, capsys, phone=f"6000000{i:02d}")
    response = client.post(REQUEST_URL, {"phone": "600000099"}, format="json")
    assert response.status_code == 429
    assert response.data["code"] == "too_many_requests"
    assert 1 <= int(response["Retry-After"]) <= 3600
    # X-Forwarded-For falsifié : ignoré, toujours limité.
    spoofed = client.post(
        REQUEST_URL, {"phone": "600000099"}, format="json", HTTP_X_FORWARDED_FOR="10.9.9.9"
    )
    assert spoofed.status_code == 429
    # Une autre adresse IP n'est pas touchée.
    other = client.post(REQUEST_URL, {"phone": "600000099"}, format="json", REMOTE_ADDR="10.0.0.2")
    assert other.status_code == 202


def test_limite_par_ip_sur_la_verification(client):
    for i in range(30):
        response = verify(client, "123456", phone=f"6000000{i:02d}")
        assert response.status_code == 400
    response = verify(client, "123456", phone="600000099")
    assert response.status_code == 429
    assert response.data["code"] == "too_many_requests"
    assert 1 <= int(response["Retry-After"]) <= 3600
    other = verify(client, "123456", phone="600000099", REMOTE_ADDR="10.0.0.2")
    assert other.status_code == 400  # une autre adresse IP n'est pas touchée


@pytest.mark.django_db(transaction=True)
def test_limite_par_numero_tenue_meme_en_simultane():
    """8 demandes lancées en même temps pour un numéro : 3 codes au plus."""
    barrier = threading.Barrier(8)
    results = []

    def ask():
        try:
            barrier.wait()
            request_code(E164)
            results.append("ok")
        except TooManyRequests:
            results.append("429")
        finally:
            connection.close()

    threads = [threading.Thread(target=ask) for _ in range(8)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    assert sorted(results) == ["429"] * 5 + ["ok"] * 3
    assert OtpCode.objects.filter(phone=E164).count() == 3


# --- Réglages -------------------------------------------------------------


def test_database_url_obligatoire():
    """Sans DATABASE_URL, les réglages refusent de démarrer (aucune base par défaut)."""
    env = {k: v for k, v in os.environ.items() if k != "DATABASE_URL"}
    script = (
        "import environ; environ.Env.read_env = lambda *a, **k: None; "  # ignore backend/.env
        "import config.settings.base"
    )
    result = subprocess.run(
        [sys.executable, "-c", script],
        cwd=django_settings.BASE_DIR,
        env=env,
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
    assert "Set the DATABASE_URL environment variable" in result.stderr


def test_plus_de_mode_test_otp(settings):
    assert not hasattr(settings, "OTP_TEST_MODE")


# --- Fournisseur SMS ------------------------------------------------------


def test_interface_sms_abstraite():
    with pytest.raises(TypeError):
        SmsBackend()


def test_console_refuse_sans_debug(settings):
    settings.DEBUG = False
    with pytest.raises(ImproperlyConfigured):
        ConsoleSmsBackend()


def test_demande_echoue_sans_enregistrer_de_code_si_le_sms_ne_part_pas(settings):
    settings.DEBUG = False
    client = APIClient(raise_request_exception=False)
    response = client.post(REQUEST_URL, {"phone": PHONE}, format="json")
    assert response.status_code == 500
    assert not OtpCode.objects.exists()


def test_choix_du_fournisseur(settings, monkeypatch):
    assert isinstance(get_sms_provider(), ConsoleSmsBackend)
    settings.SMS_PROVIDER = "real"
    monkeypatch.setenv("SMS_API_KEY", "cle-de-test-factice")
    assert isinstance(get_sms_provider(), RealSmsProvider)
    settings.SMS_PROVIDER = "inconnu"
    with pytest.raises(ImproperlyConfigured):
        get_sms_provider()


def test_fournisseur_reel_non_choisi_echoue_proprement(settings, monkeypatch):
    settings.SMS_PROVIDER = "real"
    monkeypatch.setenv("SMS_API_KEY", "cle-de-test-factice")
    with pytest.raises(ImproperlyConfigured, match="D-02"):
        get_sms_provider().send(E164, "message de test")
    client = APIClient(raise_request_exception=False)
    response = client.post(REQUEST_URL, {"phone": PHONE}, format="json")
    assert response.status_code == 500
    assert not OtpCode.objects.exists()  # rien d'enregistré, rien d'envoyé


def test_fournisseur_reel_sans_cle(settings, monkeypatch):
    settings.SMS_PROVIDER = "real"
    monkeypatch.delenv("SMS_API_KEY", raising=False)
    with pytest.raises(ImproperlyConfigured, match="SMS_API_KEY"):
        get_sms_provider()


# --- Journaux -------------------------------------------------------------


def test_ni_code_ni_numero_dans_les_journaux(client, capsys, caplog):
    caplog.set_level(logging.DEBUG)
    code = ask_code(client, capsys)
    verify(client, wrong(code))
    verify(client, code)
    assert code not in caplog.text
    assert "600000001" not in caplog.text


def test_journal_configure_avec_le_filtre(settings):
    assert "personal_data" in settings.LOGGING["handlers"]["console"]["filters"]
