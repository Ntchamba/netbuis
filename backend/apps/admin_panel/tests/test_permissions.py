"""Droits d'administration (T070) : groupes, accès, matrice rôle x action, /api/admin/me/.
Numéros de test 6 00 00 00 XX (D-18) ; mots de passe générés par le test, jamais écrits."""
import secrets
from unittest import mock

import pytest
from django.contrib.auth.models import Group
from django.core.cache import cache
from django.core.management import call_command
from django.utils import timezone
from rest_framework.test import APIClient, APIRequestFactory

from apps.accounts.models import User
from apps.accounts.services.token_service import issue_tokens
from apps.admin_panel.permissions import require
from apps.admin_panel.services import rights_service as rights
from tests.factories.user_factory import AdminFactory, UserFactory

pytestmark = pytest.mark.django_db

ME = "/api/admin/me/"
ALL = list(rights.PERMISSION_LABELS)
VALIDATEUR_PEUT = {rights.VOIR_DEMANDES, rights.VOIR_COMPTES, rights.VALIDER_DEMANDE}


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()
    yield
    cache.clear()


def admin_in(group, **extra):
    admin = AdminFactory(**extra)
    admin.groups.add(Group.objects.get(name=group))
    return admin


def api_as(user):
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    return client


# --- Groupes créés par la migration de données ------------------------------------


def test_deux_groupes_avec_les_permissions_de_la_spec():
    assert set(Group.objects.values_list("name", flat=True)) >= {
        "Validateur",
        "Administrateur complet",
    }
    def codes(name):
        return set(Group.objects.get(name=name).permissions.values_list("codename", flat=True))

    assert codes("Validateur") == VALIDATEUR_PEUT
    assert codes("Administrateur complet") == set(ALL)
    assert {"peut_valider_demande", "peut_bloquer_compte", "peut_modifier_reglages",
            "peut_gerer_admins"} <= set(ALL)


# --- Accès : is_admin ET groupe ---------------------------------------------------


def test_admin_avec_groupe_acces_ok():
    assert api_as(admin_in("Validateur")).get(ME).status_code == 200


def test_anonyme_refuse():
    assert APIClient().get(ME).status_code == 401


def test_admin_sans_groupe_403():
    assert api_as(AdminFactory()).get(ME).status_code == 403


def test_superuser_sans_groupe_403():
    admin = AdminFactory(is_staff=True, is_superuser=True)
    assert api_as(admin).get(ME).status_code == 403


def test_groupe_sans_is_admin_403():
    user = UserFactory()
    user.groups.add(Group.objects.get(name="Administrateur complet"))
    assert api_as(user).get(ME).status_code == 403


def test_compte_ordinaire_403():
    assert api_as(UserFactory()).get(ME).status_code == 403


def test_groupe_etranger_ne_donne_pas_acces():
    admin = AdminFactory()
    admin.groups.add(Group.objects.create(name="Autre groupe"))
    assert api_as(admin).get(ME).status_code == 403


@pytest.mark.parametrize(
    "etat", [{"is_blocked": True, "blocked_at": timezone.now()}, {"is_deleted": True,
                                                                  "deleted_at": timezone.now()}]
)
def test_admin_bloque_ou_supprime_perd_l_acces(etat):
    admin = admin_in("Administrateur complet")
    client = api_as(admin)  # jeton valable émis avant le blocage
    assert client.get(ME).status_code == 200
    for champ, valeur in etat.items():
        setattr(admin, champ, valeur)
    admin.save()
    assert client.get(ME).status_code == 403


def test_jeton_d_un_admin_retire_du_groupe_refuse_immediatement():
    admin = admin_in("Administrateur complet")
    client = api_as(admin)
    assert client.get(ME).status_code == 200
    admin.groups.clear()
    assert client.get(ME).status_code == 403


def test_jeton_d_un_admin_sans_is_admin_refuse_immediatement():
    admin = admin_in("Validateur")
    client = api_as(admin)
    User.objects.filter(pk=admin.pk).update(is_admin=False)
    assert client.get(ME).status_code == 403


def test_changement_de_groupe_pris_en_compte_sans_nouveau_jeton():
    admin = admin_in("Validateur")
    client = api_as(admin)
    assert rights.BLOQUER_COMPTE not in client.get(ME).json()["permissions"]
    admin.groups.set([Group.objects.get(name="Administrateur complet")])
    assert rights.BLOQUER_COMPTE in client.get(ME).json()["permissions"]


# --- /api/admin/me/ ---------------------------------------------------------------


def test_me_renvoie_identite_et_permissions():
    admin = admin_in("Validateur", name="Awa")
    data = api_as(admin).get(ME).json()
    assert data == {
        "id": admin.pk,
        "name": "Awa",
        "phone_masked": data["phone_masked"],
        "roles": ["Validateur"],
        "permissions": sorted(VALIDATEUR_PEUT),
    }
    assert data["phone_masked"].startswith("+237 6•• ")


def test_me_administrateur_complet_a_toutes_les_permissions():
    data = api_as(admin_in("Administrateur complet")).get(ME).json()
    assert data["roles"] == ["Administrateur complet"]
    assert data["permissions"] == sorted(ALL)


def test_me_ne_contient_jamais_le_numero_complet():
    admin = admin_in("Administrateur complet")
    body = api_as(admin).get(ME).content.decode()
    assert admin.phone not in body
    assert admin.phone[4:] not in body


def test_me_refuse_les_ecritures():
    client = api_as(admin_in("Administrateur complet"))
    for method in (client.post, client.put, client.patch, client.delete):
        assert method(ME).status_code == 405


# --- Matrice rôle x action --------------------------------------------------------


def _can(user, codename):
    request = APIRequestFactory().get("/")
    request.user = user
    return require(codename)().has_permission(request, None)


@pytest.mark.parametrize("codename", ALL)
def test_matrice_validateur(codename):
    assert _can(admin_in("Validateur"), codename) is (codename in VALIDATEUR_PEUT)


@pytest.mark.parametrize("codename", ALL)
def test_matrice_administrateur_complet_peut_tout(codename):
    assert _can(admin_in("Administrateur complet"), codename) is True


@pytest.mark.parametrize("codename", ALL)
def test_matrice_sans_groupe_ou_sans_is_admin_rien(codename):
    assert _can(AdminFactory(), codename) is False
    simple = UserFactory()
    simple.groups.add(Group.objects.get(name="Administrateur complet"))
    assert _can(simple, codename) is False


@pytest.mark.parametrize(
    "codename", [rights.BLOQUER_COMPTE, rights.SUPPRIMER_COMPTE, rights.MODIFIER_REGLAGES,
                 rights.GERER_ADMINS]
)
def test_validateur_ne_peut_ni_bloquer_ni_supprimer_ni_regler_ni_gerer_les_admins(codename):
    assert not _can(admin_in("Validateur"), codename)


def test_require_refuse_une_permission_inconnue():
    with pytest.raises(ValueError):
        require("peut_inventer")


# --- Bout en bout : createsuperuser -> admin/login -> admin/me ----------------------


class _TTY:
    def isatty(self):
        return True


def _create_superuser(password):
    module = "django.contrib.auth.management.commands.createsuperuser"
    with (
        mock.patch("builtins.input", return_value="677000001"),
        mock.patch(f"{module}.getpass.getpass", return_value=password),
    ):
        call_command("createsuperuser", interactive=True, stdin=_TTY(), stdout=mock.Mock())
    return User.objects.get(phone="+237677000001")


def _login(client, password):
    response = client.post(
        "/api/auth/admin/login/", {"phone": "677000001", "password": password}, format="json"
    )
    assert response.status_code == 200
    return {"HTTP_AUTHORIZATION": f"Bearer {response.json()['access']}"}


def test_bout_en_bout_createsuperuser_puis_groupe():
    password = secrets.token_urlsafe(16)
    admin = _create_superuser(password)
    client = APIClient()
    auth = _login(client, password)
    # Sans groupe : connecté, mais 403 sous /api/admin/.
    assert client.get(ME, **auth).status_code == 403
    admin.groups.add(Group.objects.get(name="Administrateur complet"))
    response = client.get(ME, **auth)
    assert response.status_code == 200
    assert response.json()["roles"] == ["Administrateur complet"]
    assert response.json()["permissions"] == sorted(ALL)
    assert "677000001" not in response.content.decode()
