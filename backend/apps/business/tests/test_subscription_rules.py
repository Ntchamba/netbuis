"""T110 : expiration des abonnements, garde « une seule règle », proposition d'abonnement.

Les plafonds (sous-catégories, publications) et le tri de la recherche ont leurs cas avec et sans
abonnement dans test_merchant_profile_api, forum/test_limits et search/test_ranking ; ici on
ajoute le cas « échu mais encore marqué actif » pour chacun, et la garde anti-chemin-parallèle.
"""
import re
from datetime import datetime, time, timedelta
from io import StringIO
from pathlib import Path

import pytest
from django.core.management import call_command
from django.utils import timezone
from rest_framework.test import APIClient

from apps.accounts.services.token_service import issue_tokens
from apps.business.models import BusinessStatus, Subscription, SubscriptionStatus
from apps.business.services.subscription_expiry import expire_due_subscriptions
from apps.business.services.subscription_suggestion import suggest_subscription
from apps.calls.models import CallChannel, CallLog, Platform
from apps.core.models.platform_setting import PlatformSetting
from apps.core.services.settings_service import invalidate_setting
from apps.forum.services import post_service
from apps.search.services.search_service import search
from apps.search.tests.helpers import ids, shop
from tests.factories.business_factory import (
    get_sector,
    make_owner,
    make_profile,
    make_subscription,
)
from tests.factories.catalog_factory import make_subcategory

pytestmark = pytest.mark.django_db

NOW = timezone.now()
APPS = Path(__file__).resolve().parents[2]


# --- Expiration ------------------------------------------------------------------------------


def test_expiration_passe_les_echus_en_expire_sans_rien_supprimer():
    echu = make_subscription(make_profile(), start=NOW - timedelta(days=30),
                             end=NOW - timedelta(days=1))
    en_cours = make_subscription(make_profile())
    deja_expire = make_subscription(make_profile(), status=SubscriptionStatus.EXPIRED)
    profiles_before = {s.profile_id for s in Subscription.objects.all()}
    assert expire_due_subscriptions() == 1
    for sub in (echu, en_cours, deja_expire):
        sub.refresh_from_db()
    assert echu.status == SubscriptionStatus.EXPIRED
    assert en_cours.status == SubscriptionStatus.ACTIVE
    assert deja_expire.status == SubscriptionStatus.EXPIRED
    assert Subscription.objects.count() == 3
    assert {s.profile_id for s in Subscription.objects.all()} == profiles_before


def test_expiration_idempotente():
    make_subscription(make_profile(), start=NOW - timedelta(days=30), end=NOW - timedelta(days=1))
    assert expire_due_subscriptions() == 1
    assert expire_due_subscriptions() == 0
    assert Subscription.objects.filter(status=SubscriptionStatus.EXPIRED).count() == 1


def test_expiration_borne_fin_incluse_et_now_fourni():
    sub = make_subscription(make_profile(), start=NOW - timedelta(days=1),
                            end=NOW + timedelta(days=1))
    assert expire_due_subscriptions(now=sub.end - timedelta(seconds=1)) == 0
    assert expire_due_subscriptions(now=sub.end) == 1


def test_commande_expire_subscriptions():
    make_subscription(make_profile(), start=NOW - timedelta(days=30), end=NOW - timedelta(days=1))
    out = StringIO()
    call_command("expire_subscriptions", stdout=out)
    assert "1" in out.getvalue()
    assert Subscription.objects.get().status == SubscriptionStatus.EXPIRED
    out = StringIO()
    call_command("expire_subscriptions", stdout=out)
    assert "0" in out.getvalue()


# --- Échu mais encore marqué « actif » : non abonné partout ----------------------------------


def _echu_encore_actif(profile):
    sub = make_subscription(profile, start=NOW - timedelta(days=30), end=NOW - timedelta(days=1))
    assert sub.status == SubscriptionStatus.ACTIVE  # la commande n'est pas passée
    return sub


def test_plafond_publications_echu_encore_actif_traite_non_abonne():
    from apps.business.services.profile_service import SubscriptionRequired
    from apps.forum.tests.helpers import make_post, payload

    profile = make_profile(status=BusinessStatus.ACTIVE)
    _echu_encore_actif(profile)
    for _ in range(5):
        make_post(profile, age=timedelta(days=2))
    with pytest.raises(SubscriptionRequired):
        post_service.create_post(profile.owner, profile, {
            "media_type": "image", "media": payload(profile.owner)["media"], "caption": "Sixième"})
    make_subscription(profile)  # un vrai abonnement actif : acceptée
    post = post_service.create_post(profile.owner, profile, {
        "media_type": "image", "media": payload(profile.owner)["media"], "caption": "Sixième"})
    assert post.pk


def test_plafond_sous_categories_echu_encore_actif_traite_non_abonne():
    owner = make_owner()
    profile = make_profile(owner=owner)
    _echu_encore_actif(profile)
    secteur = get_sector()
    subs = [make_subcategory(secteur, f"s{i}", f"S{i}").pk for i in range(4)]
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(owner)['access']}")
    response = client.patch("/api/business/me/", {"sous_categories": subs}, format="json")
    assert response.status_code == 400
    assert response.json()["code"] == "SUBSCRIPTION_REQUIRED"
    make_subscription(profile)
    response = client.patch("/api/business/me/", {"sous_categories": subs}, format="json")
    assert response.status_code == 200


def test_tri_recherche_echu_encore_actif_pas_classe_avant():
    echu = shop("Échu", ["Riz"])
    _echu_encore_actif(echu)
    sans = shop("Sans", ["Riz"])
    actif = shop("Actif", ["Riz"], subscribed=True)
    order = ids(search("riz"))
    assert order[0] == actif.pk
    assert order[1:] == sorted(order[1:])  # échu et sans abonnement : même rang, ordre stable
    assert set(order) == {echu.pk, sans.pk, actif.pk}


# --- Garde : aucun chemin parallèle à is_subscribed -------------------------------------------

# Seuls fichiers de production autorisés à toucher au modèle Subscription / à son statut.
ALLOWED = {
    "business/models/__init__.py", "business/models/subscription.py",
    "business/services/subscription.py",         # la règle unique
    "business/services/subscription_expiry.py",  # le rangement (ne décide aucun plafond)
    "business/services/demo_data.py",            # données fictives
    "business/admin.py",                         # saisie à la main
    "admin_panel/services/subscription_service.py",  # route d'administration (accorder)
}
FORBIDDEN = re.compile(
    r"\bSubscription\b|\bSubscriptionStatus\b|\.subscriptions\.(?:filter|all|exclude|get|exists)"
    r"|subscriptions__|\bis_premium\b|\bpremium\b|end__gt|end__gte|end__lt"
)


def _production_files():
    for path in APPS.rglob("*.py"):
        rel = path.relative_to(APPS).as_posix()
        if "/tests/" in f"/{rel}" or "/migrations/" in rel or rel.endswith("conftest.py"):
            continue
        yield rel, path


def test_garde_aucun_chemin_parallele_a_is_subscribed():
    offenders = []
    for rel, path in _production_files():
        if rel in ALLOWED:
            continue
        text = path.read_text(encoding="utf-8")
        for number, line in enumerate(text.splitlines(), start=1):
            code = line.split("#", 1)[0]
            if FORBIDDEN.search(code):
                offenders.append(f"{rel}:{number}: {line.strip()}")
    assert not offenders, (
        "Plafonds et tri doivent passer par business.services.subscription : "
        + "; ".join(offenders)
    )


def test_garde_detecte_un_chemin_parallele():
    assert FORBIDDEN.search("if profile.is_premium:")
    assert FORBIDDEN.search("Subscription.objects.filter(profile=p, end__gt=now)")
    assert not FORBIDDEN.search("from apps.business.services.subscription import is_subscribed")


def test_les_plafonds_et_le_tri_utilisent_la_regle_unique():
    expected = {
        "business/services/profile_service.py": "is_subscribed(profile)",
        "forum/services/post_service.py": "is_subscribed(profile, now)",
        "search/services/search_service.py": "subscribed_profiles(",
    }
    for rel, needle in expected.items():
        assert needle in (APPS / rel).read_text(encoding="utf-8"), rel


# --- suggest_subscription ---------------------------------------------------------------------


def _calls(profile, n, when=None):
    caller = make_owner()
    for _ in range(n):
        log = CallLog.objects.create(
            caller=caller, profile=profile, channel=CallChannel.CALL, platform=Platform.ANDROID)
        if when is not None:
            CallLog.objects.filter(pk=log.pk).update(created_at=when)


def _midnight():
    local = timezone.localtime(timezone.now())
    return timezone.make_aware(datetime.combine(local.date(), time.min), local.tzinfo)


def _set_threshold(value):
    PlatformSetting.objects.update_or_create(
        key="seuil_appels_abonnement", defaults={"value": value})
    invalidate_setting("seuil_appels_abonnement")


@pytest.fixture(autouse=True)
def _reset_threshold():
    invalidate_setting("seuil_appels_abonnement")
    yield
    invalidate_setting("seuil_appels_abonnement")


def test_suggestion_sous_egal_et_au_dessus_du_seuil():
    profile = make_profile()
    _set_threshold(3)
    _calls(profile, 2)
    assert suggest_subscription(profile) is False
    _calls(profile, 1)  # 3 = seuil : pas strictement au-dessus
    assert suggest_subscription(profile) is False
    _calls(profile, 1)  # 4
    assert suggest_subscription(profile) is True


def test_suggestion_faux_pour_un_abonne_meme_au_dessus_du_seuil():
    profile = make_profile()
    _set_threshold(1)
    _calls(profile, 5)
    assert suggest_subscription(profile) is True
    make_subscription(profile)
    assert suggest_subscription(profile) is False


def test_suggestion_abonnement_echu_encore_actif_compte_comme_non_abonne():
    profile = make_profile()
    _set_threshold(1)
    _calls(profile, 2)
    _echu_encore_actif(profile)
    assert suggest_subscription(profile) is True


def test_suggestion_les_appels_d_hier_ne_comptent_pas():
    profile = make_profile()
    _set_threshold(2)
    _calls(profile, 5, when=_midnight() - timedelta(minutes=1))
    assert suggest_subscription(profile) is False
    _calls(profile, 3)
    assert suggest_subscription(profile) is True


def test_suggestion_les_appels_d_un_autre_commerce_ne_comptent_pas():
    profile = make_profile()
    _set_threshold(1)
    _calls(make_profile(), 5)
    assert suggest_subscription(profile) is False


def test_suggestion_suit_le_reglage_de_la_plateforme():
    profile = make_profile()
    _calls(profile, 4)
    _set_threshold(10)
    assert suggest_subscription(profile) is False
    _set_threshold(3)
    assert suggest_subscription(profile) is True


def test_api_me_renvoie_suggest_subscription_sans_donnee_d_appelant():
    owner = make_owner()
    profile = make_profile(owner=owner)
    _set_threshold(2)
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(owner)['access']}")
    assert client.get("/api/business/me/").json()["suggest_subscription"] is False
    _calls(profile, 3)
    response = client.get("/api/business/me/")
    assert response.json()["suggest_subscription"] is True
    caller = CallLog.objects.first().caller
    assert caller.phone not in response.content.decode()
    make_subscription(profile)
    assert client.get("/api/business/me/").json()["suggest_subscription"] is False
