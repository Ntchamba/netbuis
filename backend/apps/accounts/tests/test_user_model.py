import secrets
from unittest import mock

import pytest
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.utils import timezone

from tests.factories.user_factory import AdminFactory, UserFactory

pytestmark = pytest.mark.django_db
User = get_user_model()


def test_create_user_normalise_le_telephone_sans_mot_de_passe():
    user = User.objects.create_user("699112233")
    assert user.phone == "+237699112233"
    assert user.is_active and not user.is_staff
    assert not user.has_usable_password()
    assert "699112233" not in str(user)


def test_champs_par_defaut():
    user = User.objects.create_user("699112233")
    assert not user.is_admin and not user.is_superuser
    assert not user.is_blocked and user.blocked_reason == "" and user.blocked_at is None
    assert not user.is_deleted and user.deleted_at is None
    assert not hasattr(user, "role")


def test_create_user_refuse_un_numero_invalide():
    with pytest.raises(ValueError):
        User.objects.create_user("12345")


def test_telephone_unique():
    User.objects.create_user("699112233")
    with pytest.raises(Exception):  # noqa: B017 - IntegrityError selon le pilote
        User.objects.create_user("+237699112233")


def test_create_superuser():
    password = secrets.token_urlsafe(16)
    admin = User.objects.create_superuser("677000000", password=password)
    assert admin.is_admin and admin.is_staff and admin.is_superuser
    assert admin.check_password(password)


def test_create_superuser_exige_un_mot_de_passe():
    with pytest.raises(ValueError):
        User.objects.create_superuser("677000000")


class _TTY:
    def isatty(self):
        return True


def test_commande_createsuperuser_mot_de_passe_au_clavier():
    password = secrets.token_urlsafe(16)
    module = "django.contrib.auth.management.commands.createsuperuser"
    with (
        mock.patch("builtins.input", return_value="677000000"),
        mock.patch(f"{module}.getpass.getpass", return_value=password) as saisie,
    ):
        call_command("createsuperuser", interactive=True, stdin=_TTY(), stdout=mock.Mock())
    assert saisie.called  # le mot de passe est demandé au clavier
    admin = User.objects.get(phone="+237677000000")
    assert admin.is_admin and admin.is_staff and admin.is_superuser
    assert admin.check_password(password)


def test_commande_createsuperuser_refuse_le_mot_de_passe_en_argument():
    with pytest.raises(TypeError):
        call_command("createsuperuser", phone="677000000", password="x", interactive=False)
    assert not User.objects.exists()


def test_can_login_compte_normal():
    assert UserFactory().can_login()
    assert AdminFactory().can_login()


@pytest.mark.parametrize(
    "champs",
    [
        {"is_blocked": True, "blocked_reason": "fraude", "blocked_at": timezone.now()},
        {"is_deleted": True, "deleted_at": timezone.now()},
        {"is_active": False},
    ],
)
def test_can_login_refuse_bloque_supprime_inactif(champs):
    assert not UserFactory(**champs).can_login()


def test_fabriques():
    user, admin = UserFactory(), AdminFactory()
    assert not user.is_admin and not user.has_usable_password()
    assert admin.is_admin and not admin.is_staff
