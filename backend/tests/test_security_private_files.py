"""T121 — la CNI (et les pièces privées) ne sortent que par la route d'administration à jeton
signé lié à l'administrateur (T071).

Preuves ailleurs : détecteur de sérialiseurs (apps/business/tests/test_profile_model.py,
test_aucun_serialiseur_n_expose_le_numero_ancre_ni_la_cni) ; lien lié à l'admin, expiré,
falsifié (apps/admin_panel/tests/test_businesses.py). Ici : le parcours global.
"""
from pathlib import Path

import pytest
from django.conf import settings
from django.contrib.auth.models import Group
from django.core.cache import cache
from django.urls import get_resolver
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.business.models import AccountType, BusinessStatus
from apps.business.services.storage_service import get_storage
from tests.factories.business_factory import make_owner, make_profile
from tests.factories.storage_factory import make_stored_file
from tests.factories.user_factory import AdminFactory
from tests.test_security_phone_leak import fill, get_routes
from tests.test_security_routes import walk

pytestmark = pytest.mark.django_db


def client_of(user) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    return client


@pytest.fixture
def provider():
    owner = make_owner()
    return make_profile(
        AccountType.PRESTATAIRE_SERVICE, owner=owner, status=BusinessStatus.ACTIVE,
        cni_photo=make_stored_file(owner, "cni_photo"),
        diplome_photo=make_stored_file(owner, "diplome_photo"),
    )


def crawl_for(client, needles, ids):
    """Chemins des routes GET (hors admin) dont la réponse contient l'une des chaînes."""
    hits = []
    for route in get_routes(prefix_out=("api/admin/",)):
        for pk in (ids if "<int:" in route else [0]):
            cache.clear()
            response = client.get(fill(route, pk), {"q": ""})
            text = response.content.decode("utf-8", "replace") + str(dict(response.headers))
            hits += [(route, n) for n in needles if n in text]
    return hits


def test_l_espace_prive_est_hors_de_l_espace_public():
    private = Path(settings.PRIVATE_MEDIA_ROOT).resolve()
    public = Path(settings.MEDIA_ROOT).resolve()
    assert private != public and public not in private.parents and private not in public.parents
    from config.settings import base  # valeurs de production et de développement

    private, public = base.PRIVATE_MEDIA_ROOT.resolve(), base.MEDIA_ROOT.resolve()
    assert private != public and public not in private.parents and private not in public.parents
    assert base.PRIVATE_DOWNLOAD_URL_PREFIX.startswith("/api/admin/")


def test_aucune_route_ne_sert_de_fichiers_hors_de_l_espace_public():
    # Seule route de fichiers : `static()` de config/urls.py, limitée à MEDIA_ROOT (public).
    served = []
    for route, callback in walk(get_resolver().url_patterns):
        if getattr(callback, "__module__", "") == "django.views.static":
            served.append(route)
    for route in served:
        assert route.startswith(settings.MEDIA_URL), route
    from django.conf.urls.static import static

    for pattern in static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT):
        assert pattern.callback.__module__ == "django.views.static"
    assert settings.STATIC_ROOT != settings.PRIVATE_MEDIA_ROOT


def test_la_cni_n_est_servie_par_aucune_url_publique(provider):
    key = provider.cni_photo
    assert get_storage().exists(key)
    anonymous = APIClient()
    for path in (f"/media/{key}", f"/private_media/{key}", f"/static/{key}",
                 f"/api/media/{key}", f"/media/../private_media/{key}"):
        assert anonymous.get(path).status_code in (400, 401, 403, 404), path
    assert get_storage().public_url  # l'API publique existe, mais refuse une pièce privée
    from apps.business.services import storage_service

    with pytest.raises(storage_service.PrivateKey):
        get_storage().public_url(key)


def test_aucune_route_hors_admin_ne_renvoie_la_cni_ni_un_lien_prive(provider):
    ids = sorted({provider.pk, provider.zone_id, provider.owner_id})
    needles = [provider.cni_photo, "cni_url", "/api/admin/private-files/"]
    viewer = make_owner()
    assert crawl_for(client_of(viewer), needles + [provider.diplome_photo], ids) == []
    assert crawl_for(client_of(provider.owner), needles, ids) == []
    assert crawl_for(APIClient(), needles, ids) == []


def test_diplome_ecart_connu_visible_du_seul_proprietaire_sur_business_me(provider):
    # ⚠ Écart documenté (docs/verifications/T121-backend.md) : `diplome_photo` (clé de stockage,
    # pas une URL : elle n'ouvre rien) est renvoyée au propriétaire par GET /api/business/me/
    # parce que le mobile la lit (business.dart : hasDiplome = diplome_photo renseigné).
    # Personne d'autre ne la reçoit.
    ids = sorted({provider.pk, provider.zone_id})
    hits = crawl_for(client_of(provider.owner), [provider.diplome_photo], ids)
    assert hits == [("api/business/me/", provider.diplome_photo)]
    assert crawl_for(client_of(make_owner()), [provider.diplome_photo], ids) == []


def test_seule_la_route_admin_lie_a_l_admin_sert_la_cni(provider):
    admin = AdminFactory()
    admin.groups.add(Group.objects.get(name="Validateur"))
    other = AdminFactory()
    other.groups.add(Group.objects.get(name="Validateur"))
    url = get_storage().private_download_url(provider.cni_photo, admin_id=admin.pk)
    assert client_of(admin).get(url).status_code == 200
    assert client_of(other).get(url).status_code == 403
    assert client_of(provider.owner).get(url).status_code == 403
    assert APIClient().get(url).status_code in (401, 403)
    # Un jeton sans administrateur n'ouvre rien non plus (sert seulement à un usage interne).
    unbound = get_storage().private_download_url(provider.cni_photo)
    assert client_of(admin).get(unbound).status_code == 403
