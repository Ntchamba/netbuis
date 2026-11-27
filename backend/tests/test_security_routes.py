"""T121 — énumération de TOUTES les routes du résolveur d'URL.

Règle : sans jeton, toute route répond 401 ou 403, sauf celles de la liste blanche ci-dessous
(routes publiques voulues, écrites une par une). Une nouvelle route non classée fait échouer
le test : il faut la classer ici, en connaissance de cause. Les routes /api/admin/ sont refusées
sans jeton, avec le jeton d'un utilisateur simple et avec celui d'un administrateur sans groupe.
Aucun appel ne doit finir en erreur serveur (5xx). L'admin Django (/django-admin/) renvoie
les anonymes vers sa page de connexion.
"""
import re

import pytest
from django.conf import settings
from django.contrib.auth.models import Group
from django.core.cache import cache
from django.urls import get_resolver
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from tests.factories.user_factory import AdminFactory, UserFactory

pytestmark = pytest.mark.django_db

# Routes PUBLIQUES voulues : route -> méthodes ouvertes sans jeton, avec la raison.
PUBLIC = {
    ("api/health/", "GET"): "sonde de santé",
    ("^media/(?P<path>.*)$", "GET"): "photos PUBLIQUES (MEDIA_ROOT ; jamais le dossier privé)",
    ("api/schema/", "GET"): "schéma de l'API (désactivé en production : test_security_settings)",
    ("api/docs/", "GET"): "documentation de l'API (désactivée en production)",
    ("api/auth/otp/request/", "POST"): "demande de code SMS (limitée par IP et par numéro)",
    ("api/auth/otp/verify/", "POST"): "vérification du code SMS (limitée par IP)",
    ("api/auth/admin/login/", "POST"): "connexion administrateur (limitée par IP et par numéro)",
    ("api/zones/", "GET"): "référentiel public des zones",
    ("api/zones/<int:pk>/", "GET"): "référentiel public des zones",
    ("api/referentials/sectors/", "GET"): "référentiel public",
    ("api/referentials/service-categories/", "GET"): "référentiel public",
    ("api/referentials/structure-types/", "GET"): "référentiel public",
    ("api/catalog/products/", "GET"): "catalogue public de produits (sans commerce)",
}
# Routes qui s'authentifient par autre chose qu'un jeton d'accès (cookie, jeton signé).
SELF_AUTHENTICATED = {
    "api/auth/refresh/": "cookie de rafraîchissement HttpOnly : 401 sans cookie",
    "api/auth/logout/": "cookie de rafraîchissement : 401 sans cookie",
    "api/uploads/local/<str:token>/": "jeton signé dans l'URL (T027) : refusé si invalide",
    "api/admin/private-files/<str:token>/": "jeton signé ET jeton administrateur (T071)",
}
# Photos publiques de MEDIA_ROOT (servies par Django seulement si DEBUG ; jamais l'espace privé).
PUBLIC_PREFIXES = ("media/",)
METHODS = ("get", "post", "put", "patch", "delete")


def walk(patterns, prefix=""):
    for p in patterns:
        route = prefix + str(p.pattern)
        if hasattr(p, "url_patterns"):
            yield from walk(p.url_patterns, route)
        else:
            yield route, p.callback


def concrete(route: str) -> str:
    """Chemin d'essai avec identifiants factices."""
    route = re.sub(r"<int:\w+>", "999999", route)
    route = re.sub(r"<uuid:\w+>", "00000000-0000-0000-0000-000000000000", route)
    route = re.sub(r"<\w+:\w+>|<\w+>", "x", route)
    route = re.sub(r"\(\?P<\w+>([^)|]+)[^)]*\)", r"\1", route)  # (?P<nom>a|b) -> a
    return "/" + route.replace("^", "").replace("$", "")


def methods_of(callback) -> list[str]:
    view_class = getattr(callback, "view_class", None) or getattr(callback, "cls", None)
    if view_class is None:  # vue fonction : GET seulement
        return ["GET"]
    return [m.upper() for m in METHODS if hasattr(view_class, m)]


def all_routes():
    return [(route, cb) for route, cb in walk(get_resolver().url_patterns)]


def api_routes():
    admin_prefix = settings.DJANGO_ADMIN_PATH
    return [(r, cb) for r, cb in all_routes()
            if not (admin_prefix and r.startswith(admin_prefix))
            and not r.startswith(PUBLIC_PREFIXES)]


def django_admin_routes():
    return [(r, cb) for r, cb in all_routes()
            if settings.DJANGO_ADMIN_PATH and r.startswith(settings.DJANGO_ADMIN_PATH)]


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()
    yield
    cache.clear()


def call(client, method, route):
    return getattr(client, method.lower())(concrete(route), {}, format="json")


def bearer(user) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    return client


def test_le_resolveur_contient_bien_des_routes():
    routes = api_routes()
    assert len(routes) > 80  # garde-fou : l'énumération voit toute l'API
    assert any(r.startswith("api/admin/") for r, _ in routes)
    assert any(r.startswith("api/calls/sessions") for r, _ in routes)


def test_sans_jeton_toute_route_est_refusee_sauf_la_liste_blanche():
    unclassified, public_seen = [], set()
    for route, cb in api_routes():
        for method in methods_of(cb):
            status = call(APIClient(), method, route).status_code
            assert status < 500, f"{method} {route} : erreur serveur {status}"
            if (route, method) in PUBLIC:
                public_seen.add((route, method))
                continue
            if route in SELF_AUTHENTICATED:
                assert status in (400, 401, 403, 404), f"{method} {route} : {status}"
                continue
            if status not in (401, 403):
                unclassified.append(f"{method} {route} -> {status}")
    assert not unclassified, (
        "Routes ouvertes sans jeton et absentes de la liste blanche (à classer) : "
        + "; ".join(unclassified)
    )
    # Liste blanche sans entrée périmée.
    assert public_seen == set(PUBLIC), set(PUBLIC) - public_seen


def test_les_routes_a_jeton_signe_refusent_un_jeton_invalide():
    c = APIClient()
    assert c.put("/api/uploads/local/faux/", b"x", content_type="image/jpeg").status_code in (
        400, 401, 403, 404)
    assert c.get("/api/admin/private-files/faux/").status_code in (401, 403)
    assert c.post("/api/auth/refresh/").status_code == 401
    assert c.post("/api/auth/logout/").status_code == 401


def test_les_entrees_de_la_liste_self_authenticated_existent():
    routes = {r for r, _ in api_routes()}
    assert set(SELF_AUTHENTICATED) <= routes


def test_aucune_route_publique_ne_sort_une_erreur_serveur_avec_un_jeton_simple():
    user = UserFactory()
    client = bearer(user)
    for route, cb in api_routes():
        for method in methods_of(cb):
            status = call(client, method, route).status_code
            assert status < 500, f"{method} {route} : erreur serveur {status}"


def test_routes_admin_refusees_sans_jeton_avec_utilisateur_simple_et_admin_sans_groupe():
    admin_routes = [(r, cb) for r, cb in api_routes() if r.startswith("api/admin/")]
    assert len(admin_routes) >= 40
    simple = bearer(UserFactory())
    no_group = bearer(AdminFactory())  # is_admin sans groupe : aucun droit
    for route, cb in admin_routes:
        for method in methods_of(cb):
            for who, client, expected in (
                ("sans jeton", APIClient(), (401, 403)),
                ("utilisateur simple", simple, (403,)),
                ("admin sans groupe", no_group, (403,)),
            ):
                status = call(client, method, route).status_code
                assert status in expected, f"{who} : {method} {route} -> {status}"


def test_un_administrateur_complet_passe_bien_la_porte():
    # Contre-épreuve : les refus ci-dessus ne viennent pas d'une route cassée.
    admin = AdminFactory()
    admin.groups.add(Group.objects.get(name="Administrateur complet"))
    client = bearer(admin)
    assert client.get("/api/admin/me/").status_code == 200
    assert client.get("/api/admin/stats/").status_code == 200
    assert client.get("/api/admin/accounts/").status_code == 200


def test_media_public_ne_sert_pas_l_espace_prive():
    client = APIClient()
    for path in ("/media/u1/cni_photo/x.jpg", "/media/../private_media/x.jpg",
                 "/private_media/x.jpg", "/static/../private_media/x"):
        assert client.get(path).status_code in (400, 404)


# --- Admin Django --------------------------------------------------------------------------


def test_admin_django_renvoie_les_anonymes_vers_la_connexion():
    login = f"/{settings.DJANGO_ADMIN_PATH}login/"
    open_pages = {f"{settings.DJANGO_ADMIN_PATH}login/"}  # seule page ouverte : la connexion
    routes = django_admin_routes()
    assert len(routes) > 30
    for route, _cb in routes:
        response = APIClient().get(concrete(route))
        if route in open_pages:
            assert response.status_code == 200, route
        elif route == f"{settings.DJANGO_ADMIN_PATH}logout/":  # anonyme : sans effet
            assert response.status_code == 302 and "/login/" not in response["Location"]
        else:
            assert response.status_code == 302 and response["Location"].startswith(login), (
                route, response.status_code)


def test_admin_django_refuse_un_compte_non_personnel():
    # Un utilisateur simple (ni is_staff, ni is_admin) n'entre pas, même connecté de force.
    from django.test import Client

    for user in (UserFactory(), AdminFactory()):  # AdminFactory : is_admin sans is_staff
        browser = Client()
        browser.force_login(user, backend="django.contrib.auth.backends.ModelBackend")
        response = browser.get(f"/{settings.DJANGO_ADMIN_PATH}")
        assert response.status_code == 302 and "login" in response["Location"]
