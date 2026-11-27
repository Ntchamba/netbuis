"""T122 — Pas de N+1 : le nombre de requêtes SQL d'une route de liste ou de consultation ne
dépend pas du nombre de lignes renvoyées.

Méthode : un échauffement (caches de réglages), puis on compte les requêtes avec 1 élément, on
ajoute des éléments (30 au total) et on recompte ; les deux nombres doivent être identiques ET la
réponse doit réellement contenir plus de lignes (sinon le test ne prouverait rien).
"""
from datetime import timedelta
from itertools import count

import pytest
from django.contrib.auth.models import Group
from django.core.cache import cache
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.admin_panel.models import AuditAction, AuditLog
from apps.business.models import BusinessStatus, Offer
from apps.calls.models import CallChannel, CallLog, CallSession, Platform, SessionState
from apps.forum.models import Report
from apps.forum.tests.helpers import make_comment, make_post
from apps.geo.models import ZoneLevel
from apps.search.models import SearchLog
from apps.search.tests.helpers import provider, shop
from apps.trends.models import TrendEntry, TrendKind, TrendSnapshot
from tests.factories.business_factory import make_owner, make_profile, make_subscription
from tests.factories.catalog_factory import make_product
from tests.factories.user_factory import AdminFactory
from tests.factories.zone_factory import make_maroua_chain, make_zone

pytestmark = pytest.mark.django_db

SMALL, BIG = 1, 30
_names = count(1)


@pytest.fixture(autouse=True)
def _clean_cache():
    cache.clear()
    yield
    cache.clear()


def client_of(user) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    return client


def admin_client(group="Administrateur complet") -> APIClient:
    admin = AdminFactory(name="Admin perf")
    admin.groups.add(Group.objects.get(name=group))
    return client_of(admin)


def queries(client, url, method="get", body=None) -> tuple[int, int]:
    """(nombre de requêtes SQL, nombre de lignes de la liste) pour un appel."""
    with CaptureQueriesContext(connection) as ctx:
        response = (client.post(url, body, format="json") if method == "post"
                    else client.get(url))
    assert response.status_code == 200, (url, response.status_code, response.content[:300])
    data = response.json()
    rows = data
    if isinstance(data, dict):  # liste paginée, carte (villes, quartiers) ou tendances
        rows = next(data[key] for key in ("results", "cities", "areas", "products") if key in data)
    return len(ctx), len(rows)


def assert_constant(client, url, grow, *, method="get", body=None):
    """`grow(n)` ajoute n éléments. 1 élément puis 30 : même nombre de requêtes."""
    grow(SMALL)
    queries(client, url, method, body)  # échauffement
    few, few_rows = queries(client, url, method, body)
    grow(BIG - SMALL)
    many, many_rows = queries(client, url, method, body)
    assert many_rows > few_rows, (url, few_rows, many_rows)
    assert many == few, f"{url} : {few} requêtes avec {few_rows} lignes, {many} avec {many_rows}"
    return few


# --- Recherche ------------------------------------------------------------------------------


def _grow_shops(n):
    zones = make_maroua_chain_once()
    for _ in range(n):
        i = next(_names)
        profile = shop(f"Chez Riz {i}", ["Riz parfumé", "Riz local"], zone=zones[4],
                       photo="profils/p.jpg" if i % 2 else "")
        Offer.objects.filter(profile=profile).update(price_fcfa=1000 + i)
        if i % 3 == 0:
            make_subscription(profile)
        if i % 4 == 0:
            provider(f"Dépanneur {i}", category=("technique_reparation", "Technique"))


@pytest.mark.parametrize("url", ["/api/search/?q=riz", "/api/search/"])
def test_recherche_nombre_de_requetes_constant(url):
    assert_constant(client_of(make_owner()), url, _grow_shops)


def test_recherche_vocale_nombre_de_requetes_constant():
    assert_constant(client_of(make_owner()), "/api/search/voice/", _grow_shops, method="post",
                    body={"text": "je cherche du riz"})


def test_suggestions_nombre_de_requetes_constant():
    for i in range(3):  # moins de 8 produits : les deux requêtes (produits, termes) s'exécutent
        make_product(f"Riz variété {i}")

    def grow(n):
        for _ in range(n):
            SearchLog.objects.create(term=f"riz test {next(_names)}", results_count=3)

    client = client_of(make_owner())
    assert_constant(client, "/api/search/suggestions/?q=riz", grow)


# --- Carte (par zones) ------------------------------------------------------------------------


def _grow_map(n):
    pays, region, departement, ville, quartier = make_maroua_chain_once()
    for _ in range(n):
        i = next(_names)
        area = make_zone(f"Quartier {i}", ZoneLevel.QUARTIER, ville)
        city = make_zone(f"Ville {i}", ZoneLevel.VILLE_VILLAGE, departement)
        shop(f"Boutique {i}", ["Riz"], zone=area)
        shop(f"Boutique ville {i}", ["Pain"], zone=city)
        shop(f"Boutique quartier {i}", ["Sel"], zone=quartier)


def make_maroua_chain_once():
    from apps.geo.models import Zone

    if not Zone.objects.filter(name="Maroua").exists():
        make_maroua_chain()
    zones = {z.level: z for z in Zone.objects.filter(name__in=[
        "Cameroun", "Extrême-Nord", "Diamaré", "Maroua", "Hardé"])}
    return (zones[ZoneLevel.PAYS], zones[ZoneLevel.REGION], zones[ZoneLevel.DEPARTEMENT],
            zones[ZoneLevel.VILLE_VILLAGE], zones[ZoneLevel.QUARTIER])


def test_carte_villes_nombre_de_requetes_constant():
    assert_constant(client_of(make_owner()), "/api/map/cities/", _grow_map)


def test_carte_quartiers_nombre_de_requetes_constant():
    from apps.geo.models import Zone

    _grow_map(1)
    city = Zone.objects.get(name="Maroua")
    assert_constant(client_of(make_owner()), f"/api/map/cities/{city.pk}/areas/", _grow_map)


def test_carte_commerces_d_un_quartier_nombre_de_requetes_constant():
    from apps.geo.models import Zone

    _grow_map(1)
    area = Zone.objects.get(name="Hardé")
    assert_constant(client_of(make_owner()), f"/api/map/areas/{area.pk}/businesses/", _grow_map)


# --- Forum ------------------------------------------------------------------------------------


def _grow_posts(n, subscribed=False):
    for _ in range(n):
        author = make_profile(status=BusinessStatus.ACTIVE, name=f"Auteur {next(_names)}")
        if subscribed:
            make_subscription(author)
        offer = Offer.objects.create(profile=author, name="Riz")
        post = make_post(author, f"p{next(_names)}", offer=offer)
        for _ in range(2):
            make_comment(post, make_owner(name=f"Lecteur {next(_names)}"))


def test_fil_du_forum_nombre_de_requetes_constant():
    reader = client_of(make_owner())
    assert_constant(reader, "/api/forum/posts/?page_size=50", _grow_posts)


def test_fil_du_forum_par_zone_nombre_de_requetes_constant():
    reader = client_of(make_owner())
    pays, region, departement, ville, quartier = make_maroua_chain_once()
    assert_constant(reader, f"/api/forum/posts/?zone={ville.pk}&page_size=50", _grow_posts)


def test_mes_publications_et_commentaires_nombre_de_requetes_constant():
    owner_profile = make_profile(status=BusinessStatus.ACTIVE)
    mine = client_of(owner_profile.owner)
    first = {}

    def grow_mine(n):
        for _ in range(n):
            post = make_post(owner_profile, f"m{next(_names)}")
            first.setdefault("post", post)
            make_comment(post, make_owner(name=f"Lecteur {next(_names)}"))

    assert_constant(mine, "/api/forum/mine/", grow_mine)

    def grow_comments(n):
        for _ in range(n):
            author = make_profile(status=BusinessStatus.ACTIVE, name=f"Com {next(_names)}")
            make_comment(first["post"], author.owner)

    reader = client_of(make_owner())
    url = f"/api/forum/posts/{first['post'].pk}/comments/"
    assert_constant(reader, url, grow_comments)


def test_detail_d_une_publication_nombre_de_requetes_constant():
    author = make_profile(status=BusinessStatus.ACTIVE)
    post = make_post(author)

    def grow(n):
        for _ in range(n):
            writer = make_profile(status=BusinessStatus.ACTIVE, name=f"Com {next(_names)}")
            make_comment(post, writer.owner)

    reader = client_of(make_owner())
    url = f"/api/forum/posts/{post.pk}/"
    grow(1)
    queries_before = _count_detail(reader, url)
    grow(29)
    assert _count_detail(reader, url) == queries_before


def _count_detail(client, url):
    client.get(url)  # échauffement
    with CaptureQueriesContext(connection) as ctx:
        assert client.get(url).status_code == 200
    return len(ctx)


# --- Tendances --------------------------------------------------------------------------------


def test_tendances_nombre_de_requetes_constant():
    pays, region, departement, ville, quartier = make_maroua_chain_once()
    snapshot = TrendSnapshot.objects.create(
        zone=ville, period_end=timezone.localdate(), window_days=7)

    def grow(n):
        for _ in range(n):
            i = next(_names)
            profile = shop(f"Tendance {i}", ["Riz"], zone=quartier)
            product = make_product(f"Produit tendance {i}")
            rank = TrendEntry.objects.filter(snapshot=snapshot).count() + 1
            TrendEntry.objects.create(snapshot=snapshot, kind=TrendKind.PRODUCT, rank=rank,
                                      product=product, hits=10, accounts=5)
            TrendEntry.objects.create(snapshot=snapshot, kind=TrendKind.BUSINESS, rank=rank,
                                      profile=profile, hits=10, accounts=5)

    client = client_of(make_owner())
    url = f"/api/trends/?zone={ville.pk}"
    grow(1)
    queries(client, url)
    few, _ = queries(client, url)
    grow(14)  # l'API plafonne à 10 lignes par liste : on dépasse largement le plafond
    many, _ = queries(client, url)
    assert many == few
    data = client.get(url).json()
    assert len(data["products"]) == 10 and len(data["businesses"]) == 10


# --- Historique d'appels ------------------------------------------------------------------------


def test_historique_d_appels_nombre_de_requetes_constant():
    caller = make_owner(name="Awa")
    pays, region, departement, ville, quartier = make_maroua_chain_once()

    def grow(n):
        for i in range(n):
            business = shop(f"Commerce {next(_names)}", ["Riz"], zone=quartier)
            CallSession.objects.create(
                caller=caller, business=business, room=f"salle-{next(_names)}-x{i}",
                state=SessionState.ENDED)
            CallLog.objects.create(caller=caller, profile=business, channel=CallChannel.WHATSAPP,
                                   platform=Platform.ANDROID)

    assert_constant(client_of(caller), "/api/calls/history/", grow)


# --- Administration ---------------------------------------------------------------------------


def test_admin_comptes_nombre_de_requetes_constant():
    def grow(n):
        for _ in range(n):
            i = next(_names)
            make_profile(status=BusinessStatus.ACTIVE, name=f"Compte {i}")
            make_owner(name=f"Simple {i}")

    assert_constant(admin_client(), "/api/admin/accounts/", grow)
    assert_constant(
        admin_client(), "/api/admin/accounts/?type=business&q=Compte&page_size=50", grow)


def test_admin_demandes_nombre_de_requetes_constant():
    def grow(n):
        for _ in range(n):
            make_profile(status=BusinessStatus.PENDING, name=f"Demande {next(_names)}")

    assert_constant(admin_client(), "/api/admin/requests/?type=business", grow)


def test_admin_appels_nombre_de_requetes_constant():
    agent = AdminFactory(name="Agent")

    def grow(n):
        for i in range(n):
            business = shop(f"Commerce {next(_names)}", ["Riz"])
            CallSession.objects.create(
                caller=make_owner(name=f"Appelant {i}"), business=business, agent=agent,
                room=f"salle-{next(_names)}-y{i}", state=SessionState.ENDED,
                answered_at=timezone.now(), ended_at=timezone.now())

    assert_constant(admin_client(), "/api/admin/calls/", grow)
    assert_constant(admin_client(), "/api/admin/calls/?state=ended,missed&page_size=50", grow)


def test_admin_audit_nombre_de_requetes_constant():
    def grow(n):
        for _ in range(n):
            admin = AdminFactory(name=f"Admin {next(_names)}")
            AuditLog.objects.create(admin=admin, action=AuditAction.BLOCAGE_COMPTE,
                                    target_type="accounts.user", target_id=1, reason="test")

    assert_constant(admin_client(), "/api/admin/audit/", grow)


def test_admin_signalements_nombre_de_requetes_constant():
    author = make_profile(status=BusinessStatus.ACTIVE)

    def grow(n):
        for _ in range(n):
            post = make_post(author, f"s{next(_names)}")
            comment = make_comment(post, make_owner(name=f"Auteur {next(_names)}"))
            for target, kind in ((post, "post"), (comment, "comment")):
                Report.objects.create(reporter=make_owner(), target_type=kind, reason="spam",
                                      **{kind: target})
        for _ in range(n):
            Report.objects.create(reporter=make_owner(), target_type="business",
                                  reason="arnaque", business=make_profile(
                                      status=BusinessStatus.ACTIVE))

    assert_constant(admin_client(), "/api/admin/reports/?page_size=50", grow)


def test_admin_abonnements_nombre_de_requetes_constant():
    def grow(n):
        for _ in range(n):
            profile = make_profile(status=BusinessStatus.ACTIVE, name=f"Abo {next(_names)}")
            make_subscription(profile, start=timezone.now() - timedelta(days=1))
            CallLog.objects.create(caller=make_owner(), profile=profile,
                                   channel=CallChannel.WHATSAPP, platform=Platform.ANDROID)

    assert_constant(admin_client(), "/api/admin/subscriptions/", grow)


# --- Fiche d'un commerce ------------------------------------------------------------------------


def test_fiche_commerce_nombre_de_requetes_constant_avec_les_offres():
    profile = shop("Fiche test", ["Riz"])
    reader = client_of(make_owner())
    url = f"/api/business/{profile.pk}/"

    def measure():
        reader.get(url)  # échauffement
        with CaptureQueriesContext(connection) as ctx:
            assert reader.get(url).status_code == 200
        return len(ctx)

    few = measure()
    for i in range(29):
        Offer.objects.create(profile=profile, name=f"Offre {i}", price_fcfa=500)
    assert len(reader.get(url).json()["offers"]) >= 30
    assert measure() == few


# --- Index ajoutés par T122 -----------------------------------------------------------------


@pytest.mark.parametrize("table,index", [
    ("calls_callsession", "calls_session_recent_idx"),
    ("accounts_user", "accounts_user_recent_idx"),
])
def test_index_des_listes_recentes_presents_et_utilisables(table, index):
    with connection.cursor() as cursor:
        cursor.execute("select indexdef from pg_indexes where indexname = %s", [index])
        (definition,) = cursor.fetchone()
        assert "created_at DESC, id DESC" in definition
        # Le planificateur le choisit pour « les 20 plus récents » (la table de test est petite :
        # on lui interdit le balayage complet pour prouver que l'index sert bien à cet ordre).
        cursor.execute("set local enable_seqscan = off")
        cursor.execute(
            f"explain select id from {table} order by created_at desc, id desc limit 20")
        plan = "\n".join(row[0] for row in cursor.fetchall())
    assert index in plan, plan


def test_fil_du_forum_pages_successives_sans_doublon_abonnes_d_abord():
    subscribed = make_profile(status=BusinessStatus.ACTIVE, name="Abonné")
    make_subscription(subscribed)
    plain = make_profile(status=BusinessStatus.ACTIVE, name="Simple")
    old = [make_post(subscribed, f"a{i}", age=timedelta(days=5 + i)) for i in range(3)]
    recent = [make_post(plain, f"b{i}", age=timedelta(minutes=i)) for i in range(4)]
    reader = client_of(make_owner())
    seen, names = [], []
    for page in (1, 2, 3, 4):
        data = reader.get(f"/api/forum/posts/?page_size=2&page={page}").json()
        assert data["count"] == 7
        seen += [row["id"] for row in data["results"]]
        names += [row["author"]["name"] for row in data["results"]]
    assert len(seen) == len(set(seen)) == 7
    assert names == ["Abonné"] * 3 + ["Simple"] * 4
    assert seen[:3] == [p.pk for p in old]  # plus récentes d'abord parmi les abonnés
    assert seen[3:] == [p.pk for p in recent]
    assert reader.get("/api/forum/posts/?page_size=2&page=5").status_code == 404
