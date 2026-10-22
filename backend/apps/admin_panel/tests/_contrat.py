"""Registre central du contrat /api/admin/ (T075).

POUR AJOUTER UNE ROUTE (T094 modération, T110…) : ajouter UNE ligne dans `ROUTES` (ou une
entrée dans `NO_STORE` / `GET_FIXTURES` si besoin) ; la logique des tests ne change pas.
Une route présente dans le résolveur Django mais absente d'ici fait échouer
`test_contrat.py::test_toutes_les_routes_admin_sont_dans_le_registre`.
"""
import re

from django.urls import URLPattern, URLResolver, get_resolver

from apps.admin_panel.services import rights_service as r

PREFIX = "api/admin/"
OPENAPI_METHODS = ("get", "post", "put", "patch", "delete")

# Droits du Validateur d'après docs/spec/DASHBOARD_ADMIN.md (écrits en dur, indépendants du code).
VALIDATEUR_PEUT = {r.VOIR_DEMANDES, r.VOIR_COMPTES, r.VALIDER_DEMANDE}

REF_SLUGS = ("zones", "sectors", "subcategories", "service-categories", "structure-types",
             "products", "synonyms")
REF_WITH_TOGGLE = ("zones", "sectors", "subcategories", "service-categories",
                   "structure-types", "products", "synonyms")

# (méthode, route sans le préfixe « api/admin/ ») -> permission exigée (None : tout admin actif).
ROUTES: dict[tuple[str, str], str | None] = {
    ("get", "me/"): None,
    ("get", "stats/"): r.VOIR_COMPTES,
    ("get", "requests/"): r.VOIR_DEMANDES,
    ("post", "requests/<int:pk>/approve/"): r.VALIDER_DEMANDE,
    ("post", "requests/<int:pk>/reject/"): r.VALIDER_DEMANDE,
    ("get", "accounts/"): r.VOIR_COMPTES,
    ("get", "accounts/<int:pk>/"): r.VOIR_COMPTES,
    ("delete", "accounts/<int:pk>/"): r.SUPPRIMER_COMPTE,
    ("post", "accounts/<int:pk>/block/"): r.BLOQUER_COMPTE,
    ("post", "accounts/<int:pk>/unblock/"): r.BLOQUER_COMPTE,
    ("post", "accounts/<int:pk>/restore/"): r.SUPPRIMER_COMPTE,
    ("get", "settings/"): r.MODIFIER_REGLAGES,
    ("patch", "settings/<str:key>/"): r.MODIFIER_REGLAGES,
    ("get", "admins/"): r.GERER_ADMINS,
    ("post", "admins/"): r.GERER_ADMINS,
    ("patch", "admins/<int:pk>/"): r.GERER_ADMINS,
    ("delete", "admins/<int:pk>/"): r.GERER_ADMINS,
    ("get", "analytics/searches/"): r.VOIR_COMPTES,
    ("get", "analytics/calls/"): r.VOIR_COMPTES,
    ("get", "subscriptions/"): r.VOIR_COMPTES,
    ("post", "subscriptions/"): r.ACCORDER_ABONNEMENT,
    ("get", "audit/"): r.VOIR_COMPTES,
    ("get", "export/accounts.csv"): r.EXPORTER,
    ("get", "referentials/free-values/"): r.GERER_REFERENTIELS,
    ("get", "private-files/<str:token>/"): r.VOIR_DEMANDES,
    ("get", "reports/"): r.MODERER_CONTENU,
    ("post", "reports/<str:target_type>/<int:pk>/hide/"): r.MODERER_CONTENU,
    ("post", "reports/<str:target_type>/<int:pk>/restore/"): r.MODERER_CONTENU,
    ("post", "reports/<str:target_type>/<int:pk>/delete/"): r.MODERER_CONTENU,
    ("get", "forbidden-words/"): r.MODERER_CONTENU,
    ("post", "forbidden-words/"): r.MODERER_CONTENU,
    ("delete", "forbidden-words/<int:pk>/"): r.MODERER_CONTENU,
}
for _slug in REF_SLUGS:
    ROUTES[("get", f"referentials/{_slug}/")] = r.GERER_REFERENTIELS
    ROUTES[("post", f"referentials/{_slug}/")] = r.GERER_REFERENTIELS
    ROUTES[("get", f"referentials/{_slug}/<int:pk>/")] = r.GERER_REFERENTIELS
    ROUTES[("patch", f"referentials/{_slug}/<int:pk>/")] = r.GERER_REFERENTIELS
    if _slug in REF_WITH_TOGGLE:
        ROUTES[("post", f"referentials/{_slug}/<int:pk>/deactivate/")] = r.GERER_REFERENTIELS
        ROUTES[("post", f"referentials/{_slug}/<int:pk>/reactivate/")] = r.GERER_REFERENTIELS

# Seule route admin autorisée à renvoyer un numéro complet (Administrateur complet seulement).
FULL_NUMBER_EXCEPTIONS = {"accounts/<int:pk>/"}

# Routes dont la réponse DOIT porter `Cache-Control: no-store` (route GET -> peut être complétée).
NO_STORE = {
    "me/", "accounts/<int:pk>/", "export/accounts.csv", "settings/", "admins/",
    "private-files/<str:token>/", "reports/", "forbidden-words/",
}


def _walk(patterns, prefix=""):
    for p in patterns:
        route = prefix + str(p.pattern)
        if isinstance(p, URLResolver):
            yield from _walk(p.url_patterns, route)
        elif isinstance(p, URLPattern):
            yield route, p


def discovered() -> dict[tuple[str, str], str]:
    """(méthode, route) -> nom d'URL, pour toutes les routes sous /api/admin/ (hors schéma)."""
    found = {}
    for route, pattern in _walk(get_resolver().url_patterns):
        if not route.startswith(PREFIX):
            continue
        cls = getattr(pattern.callback, "cls", None)
        for method in getattr(cls, "http_method_names", []):
            if method not in OPENAPI_METHODS or not hasattr(cls, method):
                continue
            found[(method, route[len(PREFIX):])] = pattern.name
    return found


def concrete(route: str, pk=999999, key="inconnu", piece="piece-inconnue") -> str:
    route = route.replace("<int:pk>", str(pk)).replace("<str:key>", key)
    route = route.replace("<str:target_type>", "post")
    return "/" + PREFIX + route.replace("<str:token>", piece)


def normalised(route: str) -> str:
    """`/api/admin/x/<int:pk>/` et `/api/admin/x/{id}/` -> même clé."""
    return re.sub(r"<[^>]+>|\{[^}]+\}", "{}", route)
