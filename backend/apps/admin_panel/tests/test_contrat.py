"""Contrat de l'API d'administration (T075) : openapi, format d'erreur, numéros, no-store.

Les routes sont déclarées dans `_contrat.py` ; ce fichier n'a pas à changer quand on en ajoute.
"""
import io
import re
from pathlib import Path

import pytest
import yaml
from django.contrib.auth.models import Group
from django.core.cache import cache
from django.core.management import call_command
from rest_framework.test import APIClient

from apps.admin_panel.models import AuditAction, AuditLog
from apps.admin_panel.services import referential_service as svc
from apps.business.models import AccountType, BusinessStatus
from apps.business.services.storage_service import get_storage
from apps.calls.models import CallChannel, CallLog, Platform
from apps.catalog.models import Synonym
from apps.search.models import SearchLog
from tests.factories.business_factory import (
    get_sector,
    get_service_category,
    get_structure_type,
    make_owner,
    make_profile,
    make_subscription,
)
from tests.factories.catalog_factory import make_product, make_subcategory
from tests.factories.storage_factory import make_stored_file
from tests.factories.user_factory import UserFactory

from . import _contrat as c
from ._t074 import COMPLET, VALIDATEUR, api_as

pytestmark = pytest.mark.django_db

OPENAPI = Path(__file__).resolve().parents[4] / "docs" / "api" / "openapi.yaml"
CODE = re.compile(r"^[a-z][a-z0-9_]*$")
# Numéro connu du commerçant de la base peuplée (fabriqué pour ce test).
KNOWN = "+237655012345"


def admin_in(group, **extra):
    """Admin au numéro issu du même compteur que make_owner (pas de collision)."""
    admin = make_owner(is_admin=True, **extra)
    admin.groups.add(Group.objects.get(name=group))
    return admin


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()
    yield
    cache.clear()


def _methods(path_item):
    return {m for m in path_item if m in c.OPENAPI_METHODS}


# --- (a) openapi.yaml décrit toutes les routes -------------------------------------------


def test_openapi_decrit_chaque_route_et_methode_admin():
    spec = yaml.safe_load(OPENAPI.read_text(encoding="utf-8"))
    documentees = {}
    for path, item in spec["paths"].items():
        if path.startswith("/api/admin/"):
            documentees[c.normalised(path)] = _methods(item)
    attendues = {}
    for (method, template) in c.discovered():
        attendues.setdefault(c.normalised("/" + c.PREFIX + template), set()).add(method)
    assert set(attendues) - set(documentees) == set(), "route absente de openapi.yaml"
    assert set(documentees) - set(attendues) == set(), "route documentée mais inexistante"
    for path, methods in attendues.items():
        assert documentees[path] == methods, path


def test_openapi_yaml_identique_a_la_sortie_de_spectacular():
    out = io.StringIO()
    call_command("spectacular", stdout=out)
    assert out.getvalue() == OPENAPI.read_text(encoding="utf-8"), (
        "docs/api/openapi.yaml est périmé : relancer `manage.py spectacular --file ../docs/api/"
        "openapi.yaml`"
    )


# --- (b) format d'erreur commun ----------------------------------------------------------


def _json_or_none(response):
    try:
        return response.json()
    except ValueError:
        return None


def test_toutes_les_erreurs_ont_le_format_commun():
    """Pour chaque route : anonyme, simple, admin sans groupe, Validateur, complet (corps vide,
    id inconnu) et méthode non permise ; toute réponse >= 400 est `{code, message[, fields]}`."""
    clients = {
        "anonyme": APIClient(), "simple": api_as(make_owner()),
        "sans_groupe": api_as(make_owner(is_admin=True)),
        "validateur": api_as(admin_in(VALIDATEUR)), "complet": api_as(admin_in(COMPLET)),
    }
    vus = set()
    for (method, template) in c.discovered():
        path = c.concrete(template)
        for name, client in clients.items():
            kwargs = {"format": "json"} if method != "get" else {}
            body = [{}] if method != "get" else []
            response = getattr(client, method)(path, *body, **kwargs)
            vus.add(response.status_code)
            if response.status_code >= 400:
                data = _json_or_none(response)
                label = (name, method, template, response.status_code)
                assert isinstance(data, dict), label
                assert set(data) <= {"code", "message", "fields"}, label
                assert {"code", "message"} <= set(data), label
                assert CODE.match(data["code"]), label
                assert isinstance(data["message"], str) and data["message"], label
        # méthode non prévue pour cette route -> 405 au même format
        allowed = {m for (m, t) in c.discovered() if t == template}
        other = next(m for m in ("put", "post", "delete") if m not in allowed)
        response = getattr(clients["complet"], other)(path, {}, format="json")
        assert response.status_code == 405, (other, template, response.status_code)
        vus.add(405)
        data = response.json()
        assert set(data) == {"code", "message"} and CODE.match(data["code"])
    assert {401, 403, 404, 405} <= vus  # le test a bien exercé les principaux cas d'erreur


def test_codes_d_erreur_stables_sur_les_cas_courants():
    complet = api_as(admin_in(COMPLET))
    assert APIClient().get("/api/admin/me/").json()["code"] == "not_authenticated"
    assert api_as(make_owner()).get("/api/admin/me/").json()["code"] == "permission_denied"
    assert complet.get("/api/admin/accounts/999999/").json()["code"] == "not_found"
    assert complet.patch("/api/admin/settings/inconnu/", {"value": 1},
                         format="json").json()["code"] == "unknown_setting"
    assert complet.post("/api/admin/requests/999999/reject/", {}, format="json"
                        ).json()["code"] in {"not_found", "reason_required"}


# --- Base peuplée ------------------------------------------------------------------------


@pytest.fixture
def peuplee():
    owner = UserFactory(phone=KNOWN, name="Commerçante")
    profile = make_profile(owner=owner, phone_anchor=KNOWN, name="Boutique connue")
    make_subscription(profile)
    CallLog.objects.create(caller=make_owner(), profile=profile, channel=CallChannel.CALL,
                           platform=Platform.ANDROID)
    SearchLog.objects.create(term="riz", results_count=1)
    prestataire = make_owner()
    other = make_profile(AccountType.PRESTATAIRE_SERVICE, owner=prestataire,
                         photo=make_stored_file(prestataire, "photo"),
                         cni_photo=make_stored_file(prestataire, "cni_photo"))
    complet = admin_in(COMPLET, name="Chef")
    AuditLog.objects.create(admin=complet, action=AuditAction.CONSULTATION_NUMERO,
                            target_type="accounts.user", target_id=owner.pk)
    return {"owner": owner, "profile": profile, "other": other, "admin": complet}


def _fill(template, base):
    """Une URL concrète qui existe pour les routes GET à identifiant."""
    if template.startswith("accounts/<int:pk>/"):
        return c.concrete(template, pk=base["owner"].pk)
    if template.startswith("referentials/") and "<int:pk>" in template:
        slug = template.split("/")[1]
        obj = svc.get_kind(slug).model.objects.first()
        return c.concrete(template, pk=obj.pk if obj else 999999)
    if template.startswith("private-files/"):
        url = get_storage().private_download_url(base["other"].cni_photo, admin_id=base["admin"].pk)
        return url
    return c.concrete(template)


def _text(response) -> str:
    if getattr(response, "streaming", False):
        return b"".join(response.streaming_content).decode("utf-8", "replace")
    return response.content.decode("utf-8", "replace")


# --- (c) aucun numéro complet dans les réponses GET ------------------------------------


def _forbidden_forms():
    digits = KNOWN[1:]  # 237655012345
    return [KNOWN, digits, digits[3:], digits[-8:]]


def test_aucune_reponse_admin_ne_contient_un_numero_complet(peuplee):
    client = api_as(peuplee["admin"])
    gets = [t for (m, t) in c.discovered() if m == "get"]
    assert gets
    for template in gets:
        response = client.get(_fill(template, peuplee))
        text = _text(response)
        label = (template, response.status_code)
        assert response.status_code not in (401, 500), label
        if template in c.FULL_NUMBER_EXCEPTIONS:
            continue
        for form in _forbidden_forms():
            assert form not in text, (label, "numéro complet ou fragment présent")
        assert not re.search(r"\+237\d", text), (label, "+237 suivi de chiffres")
        assert not re.search(r"(?<![\w/.-])6\d{8}(?![\w.-])", text), (label, "numéro à 9 chiffres")


def test_exception_unique_detail_compte_pour_l_administrateur_complet(peuplee):
    url = c.concrete("accounts/<int:pk>/", pk=peuplee["owner"].pk)
    assert api_as(peuplee["admin"]).get(url).json()["phone"] == KNOWN
    # le Validateur ne le voit jamais, même sur cette route
    reponse = api_as(admin_in(VALIDATEUR)).get(url)
    assert reponse.json()["phone"] is None
    assert all(form not in _text(reponse) for form in _forbidden_forms())
    assert c.FULL_NUMBER_EXCEPTIONS == {"accounts/<int:pk>/"}


def test_validateur_ne_recoit_aucun_numero_complet(peuplee):
    client = api_as(admin_in(VALIDATEUR))
    for (method, template) in c.discovered():
        if method != "get":
            continue
        response = client.get(_fill(template, peuplee))
        if response.status_code == 200:
            text = _text(response)
            assert all(form not in text for form in _forbidden_forms()), template


# --- (e) en-têtes no-store ---------------------------------------------------------------


def test_routes_sensibles_en_no_store(peuplee):
    client = api_as(peuplee["admin"])
    for template in sorted(c.NO_STORE):
        response = client.get(_fill(template, peuplee))
        assert response.status_code == 200, (template, response.status_code)
        assert "no-store" in response.headers.get("Cache-Control", ""), template
        if hasattr(response, "streaming_content"):
            b"".join(response.streaming_content)


def test_creation_d_un_admin_en_no_store():
    response = api_as(admin_in(COMPLET)).post(
        "/api/admin/admins/", {"phone": "+237655099999", "role": COMPLET, "name": "Nouveau"},
        format="json")
    assert response.status_code in (200, 201), response.content[:200]
    assert "no-store" in response["Cache-Control"]


def test_les_routes_no_store_existent_dans_le_registre():
    assert c.NO_STORE <= {t for (_m, t) in c.discovered()}
    assert Group.objects.filter(name=COMPLET).exists()


# --- (f) la forme réelle des réponses GET = les `properties` du schéma openapi.yaml ------

# Réponses qui ne sont pas du JSON objet/liste (fichier) : rien à comparer.
NON_JSON = {"export/accounts.csv", "private-files/<str:token>/"}


def _resolve(spec, schema):
    while "$ref" in schema:
        schema = spec["components"]["schemas"][schema["$ref"].rsplit("/", 1)[1]]
    return schema


def _schema_keys(spec, schema):
    """Clés de l'objet décrit ; pour une liste paginée ou un tableau, celles d'un élément."""
    schema = _resolve(spec, schema)
    if schema.get("type") == "array":
        return _schema_keys(spec, schema["items"])
    props = schema.get("properties", {})
    if "results" in props:
        return _schema_keys(spec, props["results"])
    return set(props)


def _first(data, template):
    if isinstance(data, dict) and "results" in data:
        data = data["results"]
    if isinstance(data, list):
        assert data, f"base peuplée sans élément pour {template}"
        data = data[0]
    return data


def test_forme_des_reponses_get_conforme_au_schema_openapi(peuplee):
    make_subcategory(get_sector())
    get_structure_type()
    get_service_category()
    make_profile(status=BusinessStatus.ACTIVE)
    Synonym.objects.get_or_create(product=make_product("Banane"), term="Dessert")
    spec = yaml.safe_load(OPENAPI.read_text(encoding="utf-8"))
    by_path = {c.normalised(p): item for p, item in spec["paths"].items()}
    client = api_as(peuplee["admin"])
    ecarts = []
    for template in sorted(t for (m, t) in c.discovered() if m == "get"):
        if template in NON_JSON:
            continue
        operation = by_path[c.normalised("/" + c.PREFIX + template)]["get"]
        schema = operation["responses"]["200"]["content"]["application/json"]["schema"]
        response = client.get(_fill(template, peuplee))
        assert response.status_code == 200, (template, response.status_code)
        reel = set(_first(response.json(), template))
        attendu = _schema_keys(spec, schema)
        if reel != attendu:
            ecarts.append((template, "réponse seule", sorted(reel - attendu),
                           "schéma seul", sorted(attendu - reel)))
    assert ecarts == []
