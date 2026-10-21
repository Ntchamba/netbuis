import logging

import pytest
from rest_framework import exceptions
from rest_framework.test import APIRequestFactory

from apps.accounts.permissions import IsAdminRole
from apps.core.exceptions import ApiError, api_exception_handler
from apps.core.log_filters import PersonalDataFilter
from apps.core.permissions import IsOwner
from apps.core.utils.money import to_fcfa


def test_erreur_api_au_format_code_message():
    response = api_exception_handler(exceptions.NotAuthenticated(), {})
    assert response.status_code == 401
    assert response.data == {"code": "not_authenticated", "message": "Veuillez vous connecter."}


def test_erreur_de_validation_garde_les_champs():
    response = api_exception_handler(exceptions.ValidationError({"phone": ["invalide"]}), {})
    assert response.status_code == 400
    assert response.data["code"] == "invalid"
    assert response.data["fields"] == {"phone": ["invalide"]}


def test_erreur_non_api_non_traitee():
    assert api_exception_handler(ValueError("x"), {}) is None


def test_journal_masque_les_numeros():
    record = logging.LogRecord("t", logging.INFO, "", 0, "appel de %s", ("+237 699112233",), None)
    PersonalDataFilter().filter(record)
    assert "699112233" not in record.getMessage()
    assert "[numéro masqué]" in record.getMessage()


def test_journal_masque_les_codes_otp():
    record = logging.LogRecord("t", logging.INFO, "", 0, "code %s envoyé", ("482913",), None)
    PersonalDataFilter().filter(record)
    assert record.getMessage() == "code [code masqué] envoyé"


def test_journal_garde_les_autres_nombres():
    record = logging.LogRecord("t", logging.INFO, "", 0, "%s résultats en %s ms", (42, 1234), None)
    PersonalDataFilter().filter(record)
    assert record.getMessage() == "42 résultats en 1234 ms"


def test_erreur_metier_garde_son_message():
    class Exemple(ApiError):
        status_code = 400
        default_code = "exemple"
        default_detail = "Message clair."

    response = api_exception_handler(Exemple(), {})
    assert response.data == {"code": "exemple", "message": "Message clair."}


def test_montant_fcfa_entier():
    assert to_fcfa(1500) == 1500
    for bad in (12.5, -1, True):
        with pytest.raises(ValueError):
            to_fcfa(bad)


class _User:
    is_authenticated = True

    def __init__(self, is_admin=False):
        self.is_admin = is_admin

    def can_login(self):  # comme User.can_login() d'un compte ni bloqué ni supprimé
        return True


def _request(user):
    request = APIRequestFactory().get("/")
    request.user = user
    return request


@pytest.mark.django_db
def test_permission_admin_depend_de_is_admin_et_du_groupe():
    from django.contrib.auth.models import Group

    from tests.factories.user_factory import AdminFactory, UserFactory

    admin = AdminFactory()
    admin.groups.add(Group.objects.get(name="Validateur"))
    assert IsAdminRole().has_permission(_request(admin), None)
    assert not IsAdminRole().has_permission(_request(AdminFactory()), None)  # sans groupe
    assert not IsAdminRole().has_permission(_request(UserFactory()), None)


def test_is_owner():
    user, other = _User(), _User()
    obj = type("Obj", (), {"owner": user})()
    assert IsOwner().has_object_permission(_request(user), None, obj)
    assert not IsOwner().has_object_permission(_request(other), None, obj)
