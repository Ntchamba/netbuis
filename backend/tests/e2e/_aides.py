"""Aides communes des parcours de bout en bout.

Les fabriques `UserFactory`/`AdminFactory` et `make_owner` numérotent leurs comptes chacune de
leur côté et peuvent produire le même numéro dans un même test : ici, les comptes de parcours
prennent leurs numéros dans une plage réservée (6 05xx xxxx).
"""
from itertools import count

from django.contrib.auth.models import Group
from rest_framework.test import APIClient

from apps.accounts.models import User
from apps.accounts.services.token_service import issue_tokens

VALIDATEUR, COMPLET = "Validateur", "Administrateur complet"
_numeros = count(1)


def prochain_numero() -> str:
    return f"+2376050{next(_numeros):05d}"


def compte(**extra) -> User:
    extra.setdefault("phone", prochain_numero())
    password = extra.pop("password", None)
    user = User.objects.create(**extra)
    if password:
        user.set_password(password)
    else:
        user.set_unusable_password()
    user.save()
    return user


def administrateur(groupe=None, **extra) -> User:
    """Administrateur du groupe donné (sans groupe : aucun droit)."""
    admin = compte(is_admin=True, **extra)
    if groupe:
        admin.groups.add(Group.objects.get(name=groupe))
    return admin


def client_de(user) -> APIClient:
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {issue_tokens(user)['access']}")
    client.user = user
    return client


def envoyer_fichier(client, kind="photo", content_type="image/jpeg", data=None) -> str:
    """Signature puis envoi du fichier avec le jeton signé (sans connexion) ; retourne la clé."""
    from tests.factories.storage_factory import JPEG_BYTES

    data = data or JPEG_BYTES
    reponse = client.post("/api/uploads/sign/", {
        "kind": kind, "content_type": content_type, "size": len(data)}, format="json")
    assert reponse.status_code == 200, reponse.content
    ticket = reponse.json()
    put = APIClient().put(ticket["upload_url"], data=data,
                          content_type=ticket["headers"]["Content-Type"])
    assert put.status_code == 204
    return ticket["key"]
