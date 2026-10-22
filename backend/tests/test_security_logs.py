"""T121 — journaux sans données personnelles, sur un parcours complet :
code SMS -> connexion -> création du commerce -> envoi des photos et de la CNI -> validation par
l'administration -> appel (et WhatsApp) -> forum -> administration.

`caplog` reçoit les enregistrements BRUTS (avant le filtre PersonalDataFilter du gestionnaire
console) : le test prouve donc que le code lui-même n'écrit rien de sensible, et non que le
filtre le cache. Les filtres de lien signé (apps/admin_panel/log_filters.py), eux, sont posés sur
les journaux `django.request` / `django.server` : le test les vérifie aussi.
"""
import logging
import re
import secrets
from pathlib import Path

import pytest
from django.contrib.auth.models import Group
from django.core.cache import cache
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.accounts.services.token_service import issue_tokens
from apps.business.models import BusinessProfile
from apps.business.tests.test_uploads import profile_body, put, sign
from apps.calls.models import AgentPresence
from tests.factories.business_factory import get_service_category, make_owner
from tests.factories.storage_factory import JPEG_BYTES
from tests.factories.user_factory import AdminFactory

pytestmark = pytest.mark.django_db

OWNER_PHONE = "+237655010203"
ANCHOR = "+237677123456"  # numéro du commerce dans profile_body
CALLER_PHONE = "+237655040506"
ADMIN_PHONE = "+237655070809"
NEW_ADMIN_PHONE = "655121314"


watched_jitsi_secret: list[str] = []  # secret Jitsi du test en cours (ne doit pas être journalisé)


def national(phone: str) -> str:
    return re.sub(r"\D", "", phone)[-9:]


@pytest.fixture(autouse=True)
def _env(settings):
    settings.DEBUG = True  # le fournisseur SMS « console » l'exige
    settings.SMS_PROVIDER = "console"
    settings.JITSI_DOMAIN, settings.JITSI_APP_ID = "jitsi.example.test", "netbuis-test"
    settings.JITSI_JWT_SECRET = secrets.token_urlsafe(48)
    watched_jitsi_secret.append(settings.JITSI_JWT_SECRET)
    cache.clear()
    yield
    cache.clear()


def api(token=None) -> APIClient:
    client = APIClient()
    if token:
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
    return client


def read_code(capsys, phone):
    capsys.readouterr()
    response = api().post("/api/auth/otp/request/", {"phone": phone}, format="json")
    assert response.status_code == 202
    out = capsys.readouterr().out
    assert f"finissant par {phone[-2:]}" in out and phone not in out  # même la console masque
    return re.search(r"Votre code NetBuis : (\d{6})", out)[1]


def test_parcours_complet_aucune_donnee_personnelle_dans_les_journaux(caplog, capsys):
    caplog.set_level(logging.DEBUG)
    secrets_seen: dict[str, str] = {}  # nom -> valeur qui ne doit apparaître nulle part

    def watch(name, value):
        assert value, name
        secrets_seen[name] = str(value)

    # 1. Code SMS -> connexion (avec une erreur de code, puis le bon code).
    code = read_code(capsys, OWNER_PHONE)
    watch("code SMS", code)
    wrong = f"{(int(code) + 1) % 1_000_000:06d}"
    assert api().post("/api/auth/otp/verify/", {"phone": OWNER_PHONE, "code": wrong},
                      format="json").status_code == 400
    verify = api().post("/api/auth/otp/verify/", {"phone": OWNER_PHONE, "code": code},
                        format="json")
    assert verify.status_code == 200, verify.content
    access = verify.json()["access"]
    watch("jeton d'accès", access)
    refresh = verify.cookies.get("netbuis_refresh") or verify.json().get("refresh")
    if refresh is not None:
        watch("jeton de rafraîchissement", getattr(refresh, "value", refresh))
    owner = User.objects.get(phone=OWNER_PHONE)
    client = api(access)

    # 2. Création du commerce (prestataire) avec photos et CNI envoyées.
    keys = {}
    for kind in ("photo", "representant_photo", "cni_photo", "diplome_photo"):
        ticket = sign(client, kind).json()
        watch(f"lien d'envoi {kind}", ticket["upload_url"])
        watch(f"clé {kind}", ticket["key"])
        assert put(ticket, JPEG_BYTES).status_code == 204
        keys[kind] = ticket["key"]
    body = profile_body(owner, type_compte="prestataire_service",
                        categorie_service=get_service_category().pk, **keys)
    body.pop("secteur")
    created = client.post("/api/business/", body, format="json")
    assert created.status_code == 201, created.content
    profile = BusinessProfile.objects.get(owner=owner)
    watch("numéro du commerce", national(ANCHOR))
    watch("numéro du compte", national(OWNER_PHONE))
    # Quelques erreurs à journaliser : jeton falsifié, jeton d'envoi inconnu.
    assert api("eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoxfQ.signature").get("/api/me/").status_code == 401
    assert api().put("/api/uploads/local/jeton-inconnu/", b"x",
                     content_type="image/jpeg").status_code in (400, 401, 403, 404)

    # 3. Administration : mot de passe, validation, pièce privée (lien signé), détail, export.
    admin_password = secrets.token_urlsafe(14)
    boss = AdminFactory(phone=ADMIN_PHONE, password=admin_password)
    boss.groups.add(Group.objects.get(name="Administrateur complet"))
    bad = api().post("/api/auth/admin/login/",
                     {"phone": ADMIN_PHONE, "password": admin_password + "x"}, format="json")
    assert bad.status_code == 401
    login = api().post("/api/auth/admin/login/",
                       {"phone": ADMIN_PHONE, "password": admin_password}, format="json")
    assert login.status_code == 200, login.content
    watch("mot de passe administrateur", admin_password)
    admin_access = login.json()["access"]
    watch("jeton administrateur", admin_access)
    admin = api(admin_access)
    listing = admin.get("/api/admin/requests/").json()["results"][0]
    watch("lien signé de la CNI", listing["cni_url"])
    token = listing["cni_url"].rstrip("/").rsplit("/", 1)[1]
    watch("jeton signé de la CNI", token)
    assert admin.get(listing["cni_url"]).status_code == 200
    assert admin.get(listing["cni_url"][:-4] + "xxx/").status_code == 403  # lien falsifié
    assert admin.post(f"/api/admin/requests/{profile.pk}/approve/").status_code == 200
    assert admin.get(f"/api/admin/accounts/{owner.pk}/").status_code == 200
    assert admin.get("/api/admin/export/accounts.csv").status_code == 200
    created_admin = admin.post(
        "/api/admin/admins/",
        {"phone": NEW_ADMIN_PHONE, "name": "Awa", "role": "Validateur"}, format="json")
    assert created_admin.status_code == 201, created_admin.content
    watch("mot de passe temporaire", created_admin.json()["temporary_password"])
    watch("numéro du nouvel administrateur", NEW_ADMIN_PHONE)

    # 4. Un visiteur cherche, appelle (téléphone et WhatsApp), puis écrit sur le forum.
    caller = make_owner()
    caller.phone = CALLER_PHONE
    caller.save()
    watch("numéro du visiteur", national(CALLER_PHONE))
    visitor = api(issue_tokens(caller)["access"])
    term = "terme-" + secrets.token_hex(5)
    visitor.get("/api/search/", {"q": term})
    visitor.post("/api/search/voice/", {"text": term + " voix"}, format="json")
    watch("texte de recherche", term)
    # Appel à l'équipe (D-25) : l'administrateur est disponible, répond, puis l'appelant raccroche.
    AgentPresence.objects.create(agent=boss, available=True, open_streams=1,
                                 last_seen=timezone.now())
    ringing = visitor.post("/api/calls/sessions/", {"business_id": profile.pk}, format="json")
    assert ringing.status_code == 200 and ringing.json()["state"] == "ringing", ringing.content
    watch("salle Jitsi", ringing.json()["jitsi"]["room"])
    watch("jeton Jitsi de l'appelant", ringing.json()["jitsi"]["jwt"])
    watch("secret Jitsi", watched_jitsi_secret[-1])
    answered = admin.post(f"/api/admin/calls/sessions/{ringing.json()['session_id']}/accept/")
    assert answered.status_code == 200, answered.content
    watch("jeton Jitsi de l'agent", answered.json()["jitsi"]["jwt"])
    assert visitor.post(
        f"/api/calls/sessions/{ringing.json()['session_id']}/end/").status_code == 200
    # WhatsApp (inchangé) : le lien porte le numéro, qui ne doit pas être journalisé.
    done = visitor.post("/api/calls/whatsapp/", {
        "business_id": profile.pk, "platform": "android"}, format="json")
    assert done.status_code == 200, done.content
    watch("numéro (réponse WhatsApp)", national(ANCHOR))

    merchant = api(issue_tokens(owner)["access"])
    caption = "annonce-" + secrets.token_hex(6)
    post_media = sign(merchant, "post_image").json()
    assert put(post_media, JPEG_BYTES).status_code == 204
    watch("clé de la photo d'annonce", post_media["key"])
    post = merchant.post("/api/forum/posts/", {"media": post_media["key"], "caption": caption},
                         format="json")
    assert post.status_code == 201, post.content
    watch("texte d'annonce", caption)
    comment_text = "commentaire-" + secrets.token_hex(6)
    commented = visitor.post(f"/api/forum/posts/{post.json()['id']}/comments/",
                             {"text": comment_text}, format="json")
    assert commented.status_code == 201, commented.content
    watch("texte de commentaire", comment_text)
    visitor.get("/api/forum/posts/", {"q": caption})
    # Texte refusé par le filtre anti-spam : le texte refusé ne doit pas être journalisé.
    refused = "http://a.cm http://b.cm http://c.cm " + secrets.token_hex(4)
    spam = visitor.post(f"/api/forum/posts/{post.json()['id']}/comments/", {"text": refused},
                        format="json")
    assert spam.status_code == 400, spam.content
    watch("texte refusé", refused)
    reported = visitor.post(
        "/api/reports/",
        {"target_type": "post", "target_id": post.json()["id"], "reason": "spam"}, format="json")
    assert reported.status_code in (200, 201)
    admin.post(f"/api/admin/reports/post/{post.json()['id']}/hide/", {}, format="json")

    # Le parcours a bien tout fait avant de lire les journaux. Les journaux de l'outil de
    # fabrication des comptes de test (« factory ») ne sont pas ceux de l'application.
    records = [r for r in caplog.records if not r.name.startswith(("factory", "faker"))]
    assert len(records) >= 6  # les erreurs 4xx de django.request sont journalisées
    haystack = "\n".join(r.getMessage() for r in records)
    haystack += "".join(str(r.__dict__) for r in records)
    out = capsys.readouterr()
    console = "".join(
        line for line in (out.out + out.err).splitlines(keepends=True)
        if not line.startswith("[SMS console]")
    )
    haystack += console
    compact = re.sub(r"[\s.\- ]", "", haystack)
    leaked = []
    for name, value in secrets_seen.items():
        if value in haystack or (value.isdigit() and value in compact):
            leaked.append(name)
    assert not leaked, f"données sensibles retrouvées dans les journaux : {leaked}"
    # Aucun jeton JWT, quelle que soit sa provenance.
    assert not re.search(r"eyJ[\w-]+\.[\w-]+\.[\w-]*", haystack)
    # Le seul endroit qui connaisse le numéro complet en clair est la console de développement
    # du fournisseur SMS, qui n'écrit que les deux derniers chiffres (vérifié dans read_code).
    assert "/api/admin/private-files/[lien masqué]/" in haystack
    assert Path(__file__).exists()
