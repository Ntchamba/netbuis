"""Journal d'audit (T070) : service unique, motif obligatoire."""
import pytest

from apps.admin_panel.models import AuditAction, AuditLog
from apps.admin_panel.services.audit_service import (
    InvalidAuditEntry,
    ReasonRequired,
    record_action,
)
from tests.factories.user_factory import AdminFactory, UserFactory

pytestmark = pytest.mark.django_db

AVEC_MOTIF = [AuditAction.REJET_BUSINESS, AuditAction.BLOCAGE_COMPTE,
              AuditAction.SUPPRESSION_COMPTE]
SANS_MOTIF = [a for a in AuditAction if a not in AVEC_MOTIF]


def test_ecrit_admin_action_cible_motif_date():
    admin, cible = AdminFactory(), UserFactory()
    entry = record_action(admin, "blocage_compte", cible, "  Fraude constatée ")
    entry.refresh_from_db()
    assert entry.admin == admin
    assert entry.action == AuditAction.BLOCAGE_COMPTE
    assert (entry.target_type, entry.target_id) == ("accounts.user", cible.pk)
    assert entry.reason == "Fraude constatée"
    assert entry.created_at is not None


@pytest.mark.parametrize("action", AVEC_MOTIF)
@pytest.mark.parametrize("motif", ["", "   ", "\n\t", None])
def test_sans_motif_refuse_et_rien_ecrit(action, motif):
    with pytest.raises(ReasonRequired) as erreur:
        record_action(AdminFactory(), action, UserFactory(), motif)
    assert erreur.value.status_code == 400
    assert not AuditLog.objects.exists()


@pytest.mark.parametrize("action", AVEC_MOTIF)
def test_avec_motif_accepte(action):
    assert record_action(AdminFactory(), action, UserFactory(), "Motif").reason == "Motif"


@pytest.mark.parametrize("action", SANS_MOTIF)
def test_autres_actions_sans_motif_acceptees(action):
    assert record_action(AdminFactory(), action, UserFactory()).reason == ""


def test_motif_trop_long_refuse():
    with pytest.raises(ReasonRequired):
        record_action(AdminFactory(), "blocage_compte", UserFactory(), "x" * 1001)


def test_action_inconnue_refusee():
    with pytest.raises(InvalidAuditEntry):
        record_action(AdminFactory(), "pirater", UserFactory(), "x")


def test_auteur_non_admin_refuse():
    with pytest.raises(InvalidAuditEntry):
        record_action(UserFactory(), "deblocage_compte", UserFactory())
    with pytest.raises(InvalidAuditEntry):
        record_action(None, "deblocage_compte", UserFactory())
    assert not AuditLog.objects.exists()


def test_cible_non_enregistree_refusee():
    with pytest.raises(InvalidAuditEntry):
        record_action(AdminFactory(), "deblocage_compte", UserFactory.build())
    with pytest.raises(InvalidAuditEntry):
        record_action(AdminFactory(), "deblocage_compte", "user-1")


def test_le_journal_ne_garde_aucun_numero():
    cible = UserFactory()
    entry = record_action(AdminFactory(), "deblocage_compte", cible)
    assert cible.phone not in repr(entry.__dict__)
