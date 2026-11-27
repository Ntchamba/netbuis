"""Subscription et règle unique `is_subscribed` (T025b)."""
import importlib
import inspect
from datetime import timedelta

import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction
from django.test import Client
from django.utils import timezone

from apps.business.models import BusinessProfile, Subscription, SubscriptionSource
from apps.business.services import subscription as service
from apps.business.services.subscription import (
    active_subscription_queryset,
    annotate_subscribed,
    is_subscribed,
    subscribed_profiles,
)
from tests.factories.business_factory import make_owner, make_profile, make_subscription

pytestmark = pytest.mark.django_db

NOW = timezone.now()


def test_sans_abonnement_pas_abonne():
    assert is_subscribed(make_profile()) is False


def test_profil_none_pas_abonne():
    assert is_subscribed(None) is False


def test_abonnement_actif_abonne():
    profile = make_profile()
    make_subscription(profile)
    assert is_subscribed(profile) is True


def test_abonnement_echu_pas_abonne_et_rien_modifie():
    profile = make_profile()
    sub = make_subscription(profile, start=NOW - timedelta(days=30), end=NOW - timedelta(days=1))
    assert is_subscribed(profile) is False
    sub.refresh_from_db()
    assert sub.status == "actif"  # le service ne modifie rien


def test_abonnement_expire_pas_abonne_meme_dans_la_periode():
    profile = make_profile()
    make_subscription(profile, status="expire")
    assert is_subscribed(profile) is False


def test_abonnement_pas_encore_commence_pas_abonne():
    profile = make_profile()
    make_subscription(profile, start=NOW + timedelta(days=1), end=NOW + timedelta(days=9))
    assert is_subscribed(profile) is False


def test_bornes_debut_inclus_fin_exclue():
    profile = make_profile()
    start, end = NOW, NOW + timedelta(days=10)
    make_subscription(profile, start=start, end=end)
    assert is_subscribed(profile, now=start) is True
    assert is_subscribed(profile, now=end - timedelta(seconds=1)) is True
    assert is_subscribed(profile, now=end) is False
    assert is_subscribed(profile, now=start - timedelta(seconds=1)) is False


def test_un_abonnement_actif_parmi_d_anciens_suffit():
    profile = make_profile()
    make_subscription(profile, start=NOW - timedelta(days=90), end=NOW - timedelta(days=60),
                      status="expire")
    make_subscription(profile)
    assert is_subscribed(profile) is True


def test_abonnement_d_un_autre_profil_ne_compte_pas():
    make_subscription(make_profile())
    assert is_subscribed(make_profile()) is False


def test_une_seule_requete(django_assert_num_queries):
    profile = make_profile()
    make_subscription(profile)
    with django_assert_num_queries(1):
        is_subscribed(profile)


def test_filtre_coherent_avec_is_subscribed():
    actif, echu, expire, aucun = (make_profile() for _ in range(4))
    make_subscription(actif)
    make_subscription(echu, start=NOW - timedelta(days=30), end=NOW - timedelta(days=1))
    make_subscription(expire, status="expire")
    make_subscription(actif, start=NOW - timedelta(days=5), end=NOW + timedelta(days=5))  # doublon
    in_filter = set(subscribed_profiles().values_list("pk", flat=True))
    for profile in (actif, echu, expire, aucun):
        assert (profile.pk in in_filter) == is_subscribed(profile)
    assert in_filter == {actif.pk}
    assert subscribed_profiles().count() == 1  # pas de doublon malgré deux lignes


def test_filtre_accepte_un_queryset_et_now():
    profile = make_profile()
    make_subscription(profile, start=NOW, end=NOW + timedelta(days=10))
    qs = BusinessProfile.objects.all()
    later = NOW + timedelta(days=11)
    assert list(subscribed_profiles(qs, now=NOW + timedelta(days=1))) == [profile]
    assert list(subscribed_profiles(qs, now=later)) == []


def test_annotation_pour_trier_abonnes_d_abord():
    autre = make_profile()
    abonne = make_profile()
    make_subscription(abonne)
    ordered = annotate_subscribed(BusinessProfile.objects.all()).order_by("-is_subscribed", "id")
    assert list(ordered) == [abonne, autre]
    assert [p.is_subscribed for p in ordered] == [True, False]


def test_queryset_des_abonnements_actifs():
    actif = make_subscription(make_profile())
    make_subscription(make_profile(), status="expire")
    assert list(active_subscription_queryset()) == [actif]


def test_la_regle_n_est_ecrite_qu_a_un_endroit():
    source = inspect.getsource(service)
    assert source.count("status=SubscriptionStatus.ACTIVE") == 1
    assert source.count("end__gt") == 1


# --- Modèle ----------------------------------------------------------------------------------


def test_defauts_et_noms():
    sub = make_subscription()
    assert sub.status == "actif"
    assert sub.source == SubscriptionSource.MANUAL == "manuel"
    assert sub.granted_by is None
    assert sub.get_status_display() == "Actif"
    assert sub.get_source_display() == "Accordé à la main"
    assert sub.created_at and sub.updated_at


def test_source_n_a_aucune_valeur_de_paiement():
    assert SubscriptionSource.values == ["manuel"]


def test_plusieurs_abonnements_successifs_et_chevauchement_permis():
    profile = make_profile()
    make_subscription(profile)
    make_subscription(profile)
    assert profile.subscriptions.count() == 2


def test_fin_apres_debut_clean_et_save():
    profile = make_profile()
    for end in (NOW, NOW - timedelta(days=1)):
        with pytest.raises(ValidationError) as exc:
            Subscription(profile=profile, start=NOW, end=end).save()
        assert "end" in exc.value.message_dict


def test_fin_apres_debut_contrainte_en_base():
    profile = make_profile()
    with pytest.raises(IntegrityError), transaction.atomic():
        Subscription.objects.bulk_create(
            [Subscription(profile=profile, start=NOW, end=NOW)]
        )


@pytest.mark.parametrize("field,value", [("status", "impaye"), ("source", "campay")])
def test_statut_et_source_valides(field, value):
    sub = Subscription(profile=make_profile(), start=NOW, end=NOW + timedelta(days=1))
    setattr(sub, field, value)
    with pytest.raises(ValidationError) as exc:
        sub.save()
    assert field in exc.value.message_dict


def test_supprimer_l_administrateur_garde_l_abonnement():
    admin = make_owner(is_admin=True, is_staff=True)
    sub = make_subscription(granted_by=admin)
    admin.delete()
    sub.refresh_from_db()
    assert sub.granted_by is None


def test_aucun_lien_avec_le_paiement():
    for module in (service, importlib.import_module("apps.business.models.subscription")):
        assert "payments" not in inspect.getsource(module).replace("paiement", "")


# --- Admin -----------------------------------------------------------------------------------


@pytest.fixture
def admin_client():
    user = make_owner(is_admin=True, is_staff=True, is_superuser=True)
    client = Client()
    client.force_login(user)
    client.user = user
    return client


def test_admin_liste_filtres_et_recherche(admin_client):
    sub = make_subscription(make_profile(name="Chez Awa"))
    make_subscription(make_profile(name="Autre"))
    response = admin_client.get("/django-admin/business/subscription/?q=Awa&status__exact=actif")
    assert response.status_code == 200
    assert list(response.context["cl"].result_list) == [sub]


def test_admin_accorde_a_la_main_avec_administrateur_connecte(admin_client):
    profile = make_profile()
    response = admin_client.post("/django-admin/business/subscription/add/", {
        "profile": profile.pk, "status": "actif", "source": "manuel",
        "start_0": "2026-01-01", "start_1": "00:00:00",
        "end_0": "2026-12-31", "end_1": "00:00:00",
    })
    assert response.status_code == 302
    sub = Subscription.objects.get(profile=profile)
    assert sub.granted_by == admin_client.user


def test_admin_refuse_une_fin_avant_le_debut(admin_client):
    profile = make_profile()
    response = admin_client.post("/django-admin/business/subscription/add/", {
        "profile": profile.pk, "status": "actif", "source": "manuel",
        "start_0": "2026-12-31", "start_1": "00:00:00",
        "end_0": "2026-01-01", "end_1": "00:00:00",
    })
    assert response.status_code == 200
    assert not Subscription.objects.exists()
