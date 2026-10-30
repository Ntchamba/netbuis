"""Parcours d'administration (T123) : droits par groupe, blocage d'un compte (ses jetons ne
marchent plus), audit des actions, export des comptes.
"""
import csv
import io

import pytest
from django.core.cache import cache

from apps.admin_panel.models import AuditLog
from apps.admin_panel.services import rights_service as rights
from tests.e2e._aides import COMPLET, VALIDATEUR, administrateur, client_de, compte
from tests.factories.business_factory import make_profile
from tests.factories.storage_factory import make_stored_file

pytestmark = pytest.mark.django_db

COOKIE = "netbuis_refresh"


@pytest.fixture(autouse=True)
def _cache():
    cache.clear()
    yield
    cache.clear()


def test_droits_par_groupe_sur_les_routes_d_administration():
    simple = client_de(compte())
    sans_groupe = client_de(administrateur())
    validateur = client_de(administrateur(VALIDATEUR))
    complet = client_de(administrateur(COMPLET))
    cible = compte()

    # 1. Un simple compte et un administrateur sans groupe n'ont accès à rien.
    for client in (simple, sans_groupe):
        for chemin in ("/api/admin/me/", "/api/admin/accounts/", "/api/admin/audit/"):
            assert client.get(chemin).status_code == 403, chemin
    # 2. Le Validateur lit les comptes et l'audit, mais ne bloque pas, n'exporte pas, ne
    #    modifie pas les réglages ni les administrateurs.
    assert validateur.get("/api/admin/accounts/").status_code == 200
    assert validateur.get("/api/admin/audit/").status_code == 200
    assert validateur.post(f"/api/admin/accounts/{cible.pk}/block/", {"reason": "x"},
                           format="json").status_code == 403
    assert validateur.get("/api/admin/export/accounts.csv").status_code == 403
    assert validateur.get("/api/admin/settings/").status_code == 403
    assert validateur.get("/api/admin/admins/").status_code == 403
    cible.refresh_from_db()
    assert cible.is_blocked is False
    # 3. L'Administrateur complet a tous ces droits ; /me/ les annonce.
    droits = complet.get("/api/admin/me/").json()
    assert droits["roles"] == [COMPLET]
    assert {rights.BLOQUER_COMPTE, rights.EXPORTER, rights.MODIFIER_REGLAGES} <= set(
        droits["permissions"])
    assert rights.BLOQUER_COMPTE not in validateur.get("/api/admin/me/").json()["permissions"]
    assert complet.get("/api/admin/settings/").status_code == 200
    assert complet.get("/api/admin/admins/").status_code == 200
    # 4. Sans connexion, rien.
    from rest_framework.test import APIClient

    assert APIClient().get("/api/admin/accounts/").status_code == 401


def test_blocage_d_un_compte_ses_jetons_ne_marchent_plus_audit_et_deblocage():
    from rest_framework.test import APIClient

    victime = compte(name="Compte à bloquer")
    chef = administrateur(COMPLET, name="Chef")
    api = client_de(chef)

    # 1. Le compte se connecte : accès et rafraîchissement valides.
    sien = client_de(victime)
    from apps.accounts.services.token_service import issue_tokens

    jetons = issue_tokens(victime)
    assert sien.get("/api/me/").status_code == 200

    # 2. Blocage sans motif refusé ; avec motif accepté.
    assert api.post(f"/api/admin/accounts/{victime.pk}/block/", {}, format="json"
                    ).status_code == 400
    assert sien.get("/api/me/").status_code == 200
    bloc = api.post(f"/api/admin/accounts/{victime.pk}/block/", {"reason": "Fraude"},
                    format="json")
    assert bloc.status_code == 200

    # 3. Aussitôt : le jeton d'accès déjà émis est refusé (403 account_blocked).
    refus = sien.get("/api/me/")
    assert refus.status_code == 403 and refus.json()["code"] == "account_blocked"
    # 4. Le jeton de rafraîchissement ne donne plus de nouveau jeton.
    rafraichi = APIClient().post("/api/auth/refresh/", {"refresh": jetons["refresh"]},
                                 format="json")
    assert rafraichi.status_code in (401, 403)
    assert "access" not in rafraichi.json()
    # 5. Un administrateur bloqué est aussi coupé de l'administration.
    autre_admin = administrateur(COMPLET)
    autre_api = client_de(autre_admin)
    assert autre_api.get("/api/admin/accounts/").status_code == 200
    api.post(f"/api/admin/accounts/{autre_admin.pk}/block/", {"reason": "Départ"}, format="json")
    assert autre_api.get("/api/admin/accounts/").status_code in (401, 403)

    # 6. L'audit garde les deux blocages avec l'auteur et le motif.
    journal = api.get("/api/admin/audit/", {"action": "blocage_compte"})
    assert journal.status_code == 200
    lignes = journal.json()["results"]
    assert {(ligne["target_id"], ligne["reason"], ligne["admin_id"]) for ligne in lignes} == {
        (victime.pk, "Fraude", chef.pk), (autre_admin.pk, "Départ", chef.pk)}
    assert api.get("/api/admin/audit/", {"action": "inconnue"}).status_code == 400

    # 7. Déblocage : l'accès revient (même jeton), l'audit le note.
    assert api.post(f"/api/admin/accounts/{victime.pk}/unblock/").status_code == 200
    assert sien.get("/api/me/").status_code == 200
    assert AuditLog.objects.filter(admin=chef, action="deblocage_compte").count() == 1


def test_export_des_comptes_numeros_masques_et_audite():
    chef = administrateur(COMPLET, name="Chef")
    api = client_de(chef)
    simple = compte(name="Simple", phone="+237677700042")
    commerce = make_profile(photo=make_stored_file(simple, "photo"))

    # 1. L'export est du CSV en téléchargement, jamais mis en cache.
    reponse = api.get("/api/admin/export/accounts.csv")
    assert reponse.status_code == 200
    assert reponse["Content-Type"].startswith("text/csv")
    assert "attachment" in reponse["Content-Disposition"] and reponse["Cache-Control"]
    texte = b"".join(reponse.streaming_content).decode("utf-8")

    # 2. Aucun numéro en clair, aucun mot de passe ni jeton dans les colonnes.
    for numero in (simple.phone, simple.phone[4:], commerce.owner.phone, chef.phone):
        assert numero not in texte
    table = list(csv.reader(io.StringIO(texte.lstrip("﻿"))))
    assert table[0][:3] == ["id", "nom", "telephone_masque"]
    assert not {"password", "mot_de_passe", "token", "jeton"} & set(table[0])
    par_id = {ligne[0]: ligne for ligne in table[1:]}
    assert par_id[str(simple.pk)][2] == "237 6•• •• •• 42"

    # 3. L'export est écrit dans l'audit, sans numéro dans le motif.
    entree = AuditLog.objects.get(action="export_comptes")
    assert entree.admin == chef and "lignes" in entree.reason
    assert simple.phone[4:] not in entree.reason
    lu = api.get("/api/admin/audit/", {"action": "export_comptes"}).json()["results"]
    assert len(lu) == 1 and lu[0]["admin_id"] == chef.pk
