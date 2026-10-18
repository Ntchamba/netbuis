"""Commande seed_demo (T028) : commerces fictifs, idempotence, --flush, DEBUG, bornes."""
from io import StringIO
from pathlib import Path

import pytest
from django.core.exceptions import ValidationError
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import override_settings

from apps.accounts.models import User
from apps.business.models import AccountType, BusinessProfile, BusinessStatus
from apps.business.models.profile import STRUCTURE_DETAIL_FIELDS
from apps.business.services import demo_data
from apps.business.services.storage_service import parse_key
from tests.factories.business_factory import make_owner, make_profile

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def referentials(settings):
    settings.DEBUG = True  # pytest-django force DEBUG=False
    call_command("load_zones", stdout=StringIO())
    call_command("seed_referentials", stdout=StringIO())


def run(*args) -> str:
    out = StringIO()
    call_command("seed_demo", *args, stdout=out)
    return out.getvalue()


def demo_profiles():
    return BusinessProfile.objects.filter(name__startswith=demo_data.DEMO_PREFIX)


def test_creates_twenty_fictional_businesses():
    assert "20 créés, 0 déjà présents" in run()
    profiles = demo_profiles()
    assert profiles.count() == BusinessProfile.objects.count() == 20
    for profile in profiles.select_related("owner", "zone"):
        assert profile.owner.phone.startswith("+237600")
        assert profile.phone_anchor.startswith("+237600")
        assert demo_data.is_demo_phone(profile.owner.phone)
        assert demo_data.is_demo_phone(profile.phone_anchor)
        assert "Démo" in profile.representant_nom
        assert "ne correspond à aucun commerce réel" in profile.description
        profile.full_clean(exclude=["owner"])  # clean() + validateurs : profil valide
    assert BusinessProfile.objects.get(phone_anchor="+2376000000" + "01").name.startswith(
        "[DÉMO] "
    )


def test_variety_of_zones_types_and_statuses():
    run()
    profiles = list(demo_profiles().select_related("zone"))
    quartiers = {p.zone.name for p in profiles if p.zone.level == "quartier"}
    assert len(quartiers) >= 3
    assert any(p.zone.name == "Maroua" and p.zone.level == "ville_village" for p in profiles)
    assert {p.type_compte for p in profiles} == set(AccountType.values)
    statuses = {p.status for p in profiles}
    assert statuses == set(BusinessStatus.values)
    assert sum(p.status == BusinessStatus.ACTIVE for p in profiles) > 10  # majorité
    for p in profiles:
        assert bool(p.motif_rejet) == (p.status == BusinessStatus.REJECTED)
    assert len({p.cni_verifiee for p in profiles if p.type_compte == "prestataire_service"}) == 2


def test_type_specific_details_are_valid():
    run("--count", "60")
    for p in demo_profiles().select_related("structure_type", "secteur", "categorie_service"):
        subs = list(p.sous_categories.all())
        assert len(subs) <= 3
        if p.type_compte in ("boutique", "entreprise", "particulier_vendeur"):
            assert subs and all(s.sector_id == p.secteur_id for s in subs)
            assert p.secteur.code != "autre"
        else:
            assert not subs and p.secteur_id is None
        if p.type_compte == "entreprise":
            assert p.forme_juridique
        if p.type_compte == "prestataire_service":
            assert p.categorie_service_id and p.cni_photo
            assert parse_key(p.cni_photo).kind == "cni_photo"
        if p.type_compte == "structure":
            code = p.structure_type.code
            if code == "supermarche":
                assert 1 <= len(p.rayons) <= 3
            elif code == "restaurant":
                assert p.cuisine and p.livraison is not None
            elif code == "hotel":
                assert p.standing
            elif code == "sante":
                assert 1 <= len(p.specialites) <= 3
            assert code in {*STRUCTURE_DETAIL_FIELDS, "autre"}
    codes = set(
        demo_profiles().filter(type_compte="structure")
        .values_list("structure_type__code", flat=True)
    )
    assert codes == {"supermarche", "restaurant", "hotel", "sante", "autre"}


def test_owners_are_fictional_and_cannot_log_in_by_password():
    run()
    owners = User.objects.all()
    assert owners.count() == 20
    for user in owners:
        assert demo_data.is_demo_phone(user.phone)
        assert user.name.startswith(demo_data.OWNER_PREFIX)
        assert not user.has_usable_password()
        assert not (user.is_admin or user.is_staff or user.is_superuser)


def test_photo_keys_have_server_format_and_no_file_is_written(settings, tmp_path):
    settings.MEDIA_ROOT = tmp_path / "media"  # dossiers neufs : les autres tests y écrivent
    settings.PRIVATE_MEDIA_ROOT = tmp_path / "private_media"
    run()
    for p in demo_profiles():
        parsed = parse_key(p.photo)
        assert parsed.owner_id == p.owner_id and parsed.kind == "photo"
        assert parse_key(p.representant_photo).kind == "representant_photo"
    for root in (settings.MEDIA_ROOT, settings.PRIVATE_MEDIA_ROOT):
        assert not [f for f in Path(root).rglob("*") if f.is_file()]


def test_only_active_businesses_are_visible():
    run()
    visible = BusinessProfile.objects.visible()
    assert visible.count() == demo_profiles().filter(status="actif").count() > 0


def test_second_run_creates_nothing():
    run()
    ids = set(BusinessProfile.objects.values_list("pk", flat=True))
    assert "0 créés, 20 déjà présents" in run()
    assert set(BusinessProfile.objects.values_list("pk", flat=True)) == ids
    assert User.objects.count() == 20


def test_larger_count_adds_only_the_difference():
    run()
    assert "10 créés, 20 déjà présents" in run("--count", "30")
    assert BusinessProfile.objects.count() == User.objects.count() == 30


def test_rerun_does_not_overwrite_admin_changes():
    run()
    profile = BusinessProfile.objects.get(phone_anchor=demo_data.demo_phone(3))
    BusinessProfile.objects.filter(pk=profile.pk).update(
        name="[DÉMO] Nom modifié dans l'admin", status="rejete", motif_rejet="Autre motif"
    )
    run()
    profile.refresh_from_db()
    assert profile.name == "[DÉMO] Nom modifié dans l'admin"
    assert profile.motif_rejet == "Autre motif"
    assert BusinessProfile.objects.count() == 20


def test_same_data_after_flush_and_rerun():
    run()
    first = list(demo_profiles().order_by("phone_anchor").values_list(
        "phone_anchor", "name", "type_compte", "status", "zone__name"))
    run("--flush")
    run()
    again = list(demo_profiles().order_by("phone_anchor").values_list(
        "phone_anchor", "name", "type_compte", "status", "zone__name"))
    assert first == again


def test_five_hundred_businesses():
    assert "500 créés" in run("--count", "500")
    assert demo_profiles().count() == 500
    assert BusinessProfile.objects.get(owner__phone=demo_data.demo_phone(500))
    assert demo_data.is_demo_phone(demo_data.demo_phone(demo_data.MAX_COUNT))


def test_phone_format_for_first_and_larger_indexes():
    assert demo_data.demo_phone(7) == "+2376000000" + "07"
    assert demo_data.demo_phone(100) == "+2376000001" + "00"
    with pytest.raises(ValueError):
        demo_data.demo_phone(0)
    with pytest.raises(ValueError):
        demo_data.demo_phone(demo_data.MAX_COUNT + 1)


@pytest.mark.parametrize("bad", ["0", "-3", "5001"])
def test_count_out_of_range_is_refused(bad):
    with pytest.raises(CommandError, match="entre 1 et 5000"):
        run("--count", bad)
    assert BusinessProfile.objects.count() == 0


def test_refused_when_debug_is_false():
    with override_settings(DEBUG=False):
        with pytest.raises(CommandError, match="DEBUG=False"):
            run()
        with pytest.raises(CommandError, match="DEBUG=False"):
            run("--flush")
    assert BusinessProfile.objects.count() == 0 and User.objects.count() == 0


def test_flush_refused_when_debug_is_false_keeps_data():
    run()
    with override_settings(DEBUG=False), pytest.raises(CommandError):
        run("--flush")
    assert BusinessProfile.objects.count() == 20


def test_missing_referentials_give_a_clear_error():
    from apps.geo.models import Zone

    BusinessProfile.objects.all().delete()
    Zone.objects.filter(level="quartier").delete()
    with pytest.raises(CommandError, match="Lancez d'abord load_zones et seed_referentials"):
        run()
    assert User.objects.count() == 0


def test_flush_removes_only_demo_data():
    run()
    real_owner = User.objects.create(phone="+2376" + "50000002", name="Vraie personne")
    real = make_profile(owner=real_owner, name="Boutique réelle")
    # Nom « [DÉMO] » mais propriétaire hors du bloc réservé : jamais supprimé.
    fake_name_owner = User.objects.create(phone="+2376" + "50000001")
    fake_name = make_profile(owner=fake_name_owner, name="[DÉMO] Imitation")
    # Propriétaire du bloc réservé mais nom sans préfixe : jamais supprimé.
    block_owner = User.objects.create(phone=demo_data.demo_phone(4000))
    block = make_profile(owner=block_owner, name="Commerce sans préfixe")

    assert "20 commerces, 20 comptes" in run("--flush")
    surviving = set(BusinessProfile.objects.values_list("pk", flat=True))
    assert surviving == {real.pk, fake_name.pk, block.pk}
    assert set(User.objects.values_list("pk", flat=True)) == {
        real_owner.pk, fake_name_owner.pk, block_owner.pk}


def test_flush_keeps_an_admin_owner_account():
    run()
    admin = User.objects.get(phone=demo_data.demo_phone(1))
    User.objects.filter(pk=admin.pk).update(is_admin=True)
    run("--flush")
    assert User.objects.filter(pk=admin.pk).exists()
    assert not BusinessProfile.objects.filter(owner=admin).exists()
    assert User.objects.count() == 1


def test_flush_keeps_an_account_with_other_data():
    from rest_framework_simplejwt.token_blacklist.models import OutstandingToken

    run()
    user = User.objects.get(phone=demo_data.demo_phone(2))
    OutstandingToken.objects.create(
        user=user, jti="demo-jti", token="x", expires_at="2099-01-01T00:00:00Z"
    )
    run("--flush")
    assert User.objects.filter(pk=user.pk).exists() and User.objects.count() == 1


def test_flush_then_run_again_recreates():
    run()
    run("--flush")
    assert BusinessProfile.objects.count() == 0
    assert "20 créés" in run()


def test_invalid_profile_cannot_be_built_by_the_helper():
    refs = demo_data.load_referentials()
    values, _ = demo_data.demo_profile_values(1, refs)
    values["photo"] = ""
    profile = BusinessProfile(owner=make_owner(), **values)
    with pytest.raises(ValidationError):
        profile.clean()
