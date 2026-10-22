"""T121 / T131 — plus aucune route ne délivre le numéro d'un commerçant (D-25), sauf le lien
WhatsApp (`wa_url` de POST /api/calls/whatsapp/, inchangé).

Jeu de données : `seed_demo` (20 commerces fictifs, publications, commentaires) + un appel
réel + les tendances. On parcourt TOUTES les routes GET de l'API (identifiants réels
substitués) en tant que visiteur simple, que commerçant, puis que administrateur complet, et on
cherche dans le corps ET les en-têtes chaque numéro (forme nationale à 9 chiffres, avec ou sans
+237, espaces, points, tirets). Seule exception admin : le détail d'un compte (audité).
"""
import re
import secrets
from io import StringIO
from pathlib import Path

import pytest
import yaml
from django.contrib.auth.models import Group
from django.core.cache import cache
from django.core.management import call_command
from django.urls import get_resolver
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.accounts.services.token_service import issue_tokens
from apps.business.models import BusinessProfile, BusinessStatus
from apps.calls.models import CallLog, CallSession
from apps.calls.tests.helpers import make_agent
from apps.forum.models import Post
from tests.factories.user_factory import AdminFactory
from tests.test_security_routes import walk

pytestmark = pytest.mark.django_db

OPENAPI = Path(__file__).resolve().parents[2] / "docs" / "api" / "openapi.yaml"
SEPARATORS = re.compile(r"[\s.\-  ]")
ADMIN_PHONES = (f"+2376999999{n:02d}" for n in range(10, 99))  # hors des numéros de seed_demo
TERMS = ["", "riz", "démo", "pharmacie", "6", "coiffure", "boutique"]


def national(phone: str) -> str:
    return re.sub(r"\D", "", phone)[-9:]


def leaks(text: str, numbers: set[str]) -> set[str]:
    compact = SEPARATORS.sub("", text)
    return {n for n in numbers if n in compact}


def client_of(user) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    return client


@pytest.fixture
def world(settings):
    settings.DEBUG = True  # seed_demo l'exige (pytest-django force DEBUG=False)
    call_command("load_zones", stdout=StringIO())
    call_command("seed_referentials", stdout=StringIO())
    call_command("seed_demo", stdout=StringIO())
    profiles = list(BusinessProfile.objects.select_related("owner", "zone"))
    active = [p for p in profiles if p.status == BusinessStatus.ACTIVE]
    viewer = User.objects.create(phone="+237699999901", name="Visiteur Essai")
    numbers = {national(p.phone_anchor) for p in profiles}
    numbers |= {national(p.owner.phone) for p in profiles}
    numbers.add(national(viewer.phone))
    zone_ids = set()
    for p in profiles:
        zone = p.zone
        while zone is not None:
            zone_ids.add(zone.pk)
            zone = zone.parent
    ids = sorted(
        {p.pk for p in profiles} | set(Post.objects.values_list("pk", flat=True))
        | zone_ids | set(User.objects.values_list("pk", flat=True))
    )
    return {"profiles": profiles, "active": active, "viewer": viewer, "numbers": numbers,
            "ids": ids}


# Flux SSE (T131) : réponse sans fin, couverte par apps/calls/tests/test_streams.py.
STREAM_ROUTES = {"api/admin/calls/stream/"}


def get_routes(prefix_in=None, prefix_out=()):
    routes = []
    for route, cb in walk(get_resolver().url_patterns):
        view_class = getattr(cb, "view_class", None)
        if view_class is None or not hasattr(view_class, "get"):
            continue
        if route.startswith(("django-admin/", "api/schema/", "api/docs/", "media/")):
            continue
        if route.startswith(prefix_out) or route in STREAM_ROUTES:
            continue
        if prefix_in is None or route.startswith(prefix_in):
            routes.append(route)
    return routes


def fill(route: str, pk: int) -> str:
    path = re.sub(r"<int:\w+>", str(pk), route)
    path = re.sub(r"<uuid:\w+>", "00000000-0000-0000-0000-000000000000", path)
    return "/" + re.sub(r"<\w+:\w+>|<\w+>", "x", path)


def crawl(client, routes, ids, numbers, allow=lambda route, number: False):
    """Appelle chaque route GET (chaque identifiant, chaque terme) ; renvoie les fuites."""
    found, calls, ok = [], 0, 0
    for route in routes:
        takes_id = "<int:" in route
        for pk in (ids if takes_id else [0]):
            for term in (TERMS if "search" in route else [""]):
                cache.clear()  # limites de débit : hors sujet ici
                response = client.get(fill(route, pk), {"q": term} if term else {})
                calls += 1
                ok += response.status_code == 200
                body = (b"".join(response.streaming_content) if response.streaming
                        else response.content)
                text = body.decode("utf-8", "replace")
                text += " ".join(f"{k}: {v}" for k, v in response.headers.items())
                for number in leaks(text, numbers):
                    if not allow(route, number):
                        found.append((route, pk, term, number))
    return found, calls, ok


def test_le_detecteur_voit_les_formes_courantes_du_numero():
    for forme in ("+237 6 00 00 00 01", "237600000001", "6.00.00.00.01", "600-000-001",
                  "+237 600 000 001", '{"phone":"+237600000001"}'):
        assert leaks(forme, {"600000001"}), forme
    assert not leaks("+237 6•• •• •• 01", {"600000001"})  # forme masquée : autorisée


def test_aucune_route_ne_donne_le_numero_avant_pendant_ni_apres_un_appel_a_l_equipe(
        world, settings):
    settings.JITSI_DOMAIN, settings.JITSI_APP_ID = "jitsi.example.test", "netbuis-test"
    settings.JITSI_JWT_SECRET = secrets.token_urlsafe(48)
    viewer = client_of(world["viewer"])
    shop = world["active"][0]
    # L'ancienne route qui livrait le numéro n'existe plus.
    gone = viewer.post("/api/calls/initiate/", {
        "business_id": shop.pk, "channel": "call", "platform": "android"}, format="json")
    assert gone.status_code == 404
    assert national(shop.phone_anchor) not in SEPARATORS.sub("", gone.content.decode())
    # Un agent disponible, un appel qui sonne, une réponse : aucun numéro nulle part.
    agent = make_agent()
    started = viewer.post("/api/calls/sessions/", {"business_id": shop.pk}, format="json")
    assert started.status_code == 200 and started.json()["state"] == "ringing"
    accepted = client_of(agent).post(
        f"/api/admin/calls/sessions/{started.json()['session_id']}/accept/")
    assert accepted.status_code == 200
    for response in (started, accepted):
        assert not leaks(response.content.decode(), world["numbers"])
    assert CallSession.objects.filter(business=shop).count() == 1
    assert not CallLog.objects.exists()  # plus de numéro délivré, donc plus de journal « appel »
    call_command("compute_trends", stdout=StringIO())

    found, calls, ok = crawl(
        viewer, get_routes(prefix_out=("api/admin/",)), world["ids"], world["numbers"]
    )
    assert calls > 150 and ok > 50  # le parcours touche vraiment des réponses 200
    assert not found, found[:5]


def test_le_contrat_ne_decrit_aucune_route_qui_livre_le_numero_d_un_commercant():
    spec = yaml.safe_load(OPENAPI.read_text(encoding="utf-8"))
    assert "/api/calls/initiate/" not in spec["paths"]
    names = set()

    def collect(node):
        if isinstance(node, dict):
            names.update(node.get("properties", {}))
            for value in node.values():
                collect(value)
        elif isinstance(node, list):
            for value in node:
                collect(value)

    collect(spec)
    assert "phone_anchor" not in names
    assert "phone" not in spec["components"]["schemas"].get("WhatsAppResponse", {}).get(
        "properties", {})
    assert set(spec["components"]["schemas"]["WhatsAppResponse"]["properties"]) == {
        "call_id", "wa_url"}


def test_aucune_route_n_expose_le_numero_a_un_commercant(world):
    owner_profile = world["active"][1]
    owner = owner_profile.owner
    client = client_of(owner)
    # Le numéro de connexion du compte peut revenir sur GET /api/me/ (c'est le sien) ; jamais
    # ailleurs. Le numéro d'ancrage du commerce, jamais : seulement masqué (phone_masked).
    own = national(owner.phone)
    found, calls, ok = crawl(
        client, get_routes(prefix_out=("api/admin/",)), world["ids"], world["numbers"],
        allow=lambda route, number: route == "api/me/" and number == own,
    )
    assert calls > 150 and ok > 50
    assert not found, found[:5]
    me = client.get("/api/business/me/")
    assert me.status_code == 200 and me.json()["phone_masked"].count("•") >= 5


def test_recherche_vocale_et_historique_sans_numero(world):
    viewer = client_of(world["viewer"])
    cache.clear()
    voice = viewer.post("/api/search/voice/", {"text": "je cherche du riz"}, format="json")
    assert voice.status_code == 200 and not leaks(voice.content.decode(), world["numbers"])


def test_administration_aucun_numero_complet_sauf_le_detail_d_un_compte(world):
    admin = AdminFactory(phone=next(ADMIN_PHONES))
    admin.groups.add(Group.objects.get(name="Administrateur complet"))
    client = client_of(admin)
    call_command("compute_trends", stdout=StringIO())
    routes = get_routes(prefix_in="api/admin/", prefix_out=("api/admin/private-files/",))
    assert len(routes) > 20
    found, calls, ok = crawl(
        client, routes, world["ids"], world["numbers"],
        allow=lambda route, number: route == "api/admin/accounts/<int:pk>/",
    )
    assert calls > 150 and ok > 20
    assert not found, found[:5]


def test_detail_de_compte_admin_est_la_seule_exception_et_elle_est_auditee(world):
    from apps.admin_panel.models import AuditLog

    admin = AdminFactory(phone=next(ADMIN_PHONES))
    admin.groups.add(Group.objects.get(name="Administrateur complet"))
    target = world["active"][2].owner
    before = AuditLog.objects.count()
    response = client_of(admin).get(f"/api/admin/accounts/{target.pk}/")
    assert response.status_code == 200
    assert national(target.phone) in SEPARATORS.sub("", response.content.decode())
    assert AuditLog.objects.count() == before + 1  # chaque consultation est journalisée
    validator = AdminFactory(phone=next(ADMIN_PHONES))
    validator.groups.add(Group.objects.get(name="Validateur"))
    masked = client_of(validator).get(f"/api/admin/accounts/{target.pk}/")
    assert masked.status_code == 200
    assert national(target.phone) not in SEPARATORS.sub("", masked.content.decode())
