"""Parcours de création d'un commerce (T123) : compte → profil → photos par jetons signés →
demande vue par l'administrateur → validation ou refus → visibilité dans la recherche.
"""
import pytest
from django.core.cache import cache
from django.test import override_settings

from apps.admin_panel.models import AuditLog
from apps.business.models import BusinessStatus
from tests.e2e._aides import VALIDATEUR, administrateur, client_de, compte, envoyer_fichier
from tests.factories.business_factory import get_or_make_zone, get_sector, get_service_category

pytestmark = pytest.mark.django_db


@pytest.fixture(autouse=True)
def _isolation(tmp_path):
    cache.clear()
    with override_settings(MEDIA_ROOT=tmp_path / "media",
                           PRIVATE_MEDIA_ROOT=tmp_path / "private_media"):
        yield
    cache.clear()


envoyer_photo = envoyer_fichier


def noms(client, q):
    reponse = client.get("/api/search/", {"q": q})
    assert reponse.status_code == 200
    return [r["name"] for r in reponse.json()["results"]]


def test_boutique_creee_puis_validee_devient_visible_dans_la_recherche():
    zone, secteur = get_or_make_zone(), get_sector()
    visiteur = client_de(compte())  # n'importe quel compte connecté qui cherche
    proprietaire = compte(phone="+237677000111")
    client = client_de(proprietaire)

    # 1. Avant tout : le compte n'a pas de commerce.
    assert client.get("/api/business/me/").status_code == 404

    # 2. Photos de la boutique et du représentant, envoyées par jetons signés.
    photo = envoyer_photo(client, "photo")
    representant = envoyer_photo(client, "representant_photo")

    # 3. Création du profil : il part « en attente de validation ».
    creation = client.post("/api/business/", {
        "type_compte": "boutique", "name": "Quincaillerie Zogo", "zone": zone.pk,
        "secteur": secteur.pk, "photo": photo, "representant_nom": "Paul Zogo",
        "representant_photo": representant}, format="json")
    assert creation.status_code == 201, creation.content
    profil_id = creation.json()["id"]
    assert creation.json()["status"] == "en_attente_validation"

    # 4. En attente : introuvable par la recherche, fiche publique et carte.
    assert noms(visiteur, "zogo") == []
    assert visiteur.get(f"/api/business/{profil_id}/").status_code == 404

    # 5. L'administrateur voit la demande dans sa file.
    admin = administrateur(VALIDATEUR)
    api = client_de(admin)
    file = api.get("/api/admin/requests/", {"type": "business"})
    assert file.status_code == 200
    assert [d["id"] for d in file.json()["results"]] == [profil_id]

    # 6. Il valide : le commerce est actif, l'action est écrite dans l'audit.
    validation = api.post(f"/api/admin/requests/{profil_id}/approve/")
    assert validation.status_code == 200 and validation.json()["status"] == "actif"
    assert AuditLog.objects.filter(admin=admin, action="validation_business",
                                   target_id=profil_id).count() == 1

    # 7. Le propriétaire voit son nouveau statut ; la file est vide.
    assert client.get("/api/business/me/").json()["status"] == "actif"
    assert api.get("/api/admin/requests/", {"type": "business"}).json()["results"] == []

    # 8. Le commerce est trouvé par son nom (sans accents ni casse) et a une fiche publique.
    assert noms(visiteur, "QUINCAILLERIE") == ["Quincaillerie Zogo"]
    fiche = visiteur.get(f"/api/business/{profil_id}/")
    assert fiche.status_code == 200 and fiche.json()["name"] == "Quincaillerie Zogo"
    assert "677000111" not in fiche.content.decode()  # jamais le numéro


def test_prestataire_avec_cni_puis_refus_avec_motif_reste_invisible():
    zone, categorie = get_or_make_zone(), get_service_category()
    visiteur = client_de(compte())
    proprietaire = compte(phone="+237677000222")
    client = client_de(proprietaire)

    # 1. Prestataire : photo, représentant et pièce d'identité (espace privé).
    corps = {
        "type_compte": "prestataire_service", "name": "Électricité Ndi", "zone": zone.pk,
        "categorie_service": categorie.pk, "representant_nom": "Ndi Joseph",
        "photo": envoyer_photo(client, "photo"),
        "representant_photo": envoyer_photo(client, "representant_photo"),
        "cni_photo": envoyer_photo(client, "cni_photo"),
    }
    creation = client.post("/api/business/", corps, format="json")
    assert creation.status_code == 201, creation.content
    profil_id = creation.json()["id"]

    # 2. Sans pièce d'identité, un prestataire est refusé (cas qui échoue, fichiers valides).
    autre = client_de(compte())
    sans_cni = {**corps, "name": "Sans pièce",
                "photo": envoyer_photo(autre, "photo"),
                "representant_photo": envoyer_photo(autre, "representant_photo")}
    sans_cni.pop("cni_photo")
    refus_cni = autre.post("/api/business/", sans_cni, format="json")
    assert refus_cni.status_code == 400 and "cni_photo" in refus_cni.json()["fields"]

    # 3. L'administrateur voit la pièce par un lien signé, jamais par une clé brute.
    api = client_de(administrateur(VALIDATEUR))
    demande = api.get("/api/admin/requests/", {"type": "business"}).json()["results"][0]
    assert demande["id"] == profil_id and demande["cni_url"]
    assert corps["cni_photo"] not in str(demande)

    # 4. Refus SANS motif : impossible, rien ne change.
    assert api.post(f"/api/admin/requests/{profil_id}/reject/", {}, format="json"
                    ).status_code == 400
    assert client.get("/api/business/me/").json()["status"] == "en_attente_validation"

    # 5. Refus avec motif : le propriétaire le lit, l'audit le garde.
    refus = api.post(f"/api/admin/requests/{profil_id}/reject/",
                     {"reason": "CNI illisible"}, format="json")
    assert refus.status_code == 200 and refus.json()["status"] == "rejete"
    moi = client.get("/api/business/me/").json()
    assert moi["status"] == "rejete" and moi["motif_rejet"] == "CNI illisible"
    assert AuditLog.objects.get(action="rejet_business").reason == "CNI illisible"

    # 6. Un commerce refusé reste invisible partout.
    assert noms(visiteur, "electricite") == []
    assert visiteur.get(f"/api/business/{profil_id}/").status_code == 404
    from apps.business.models import BusinessProfile
    assert not BusinessProfile.objects.visible().filter(pk=profil_id).exists()
    assert BusinessProfile.objects.get(pk=profil_id).status == BusinessStatus.REJECTED


def test_photo_d_un_autre_compte_ou_type_interdit_refuses():
    zone, secteur = get_or_make_zone(), get_sector()
    voleur = client_de(compte())
    victime = client_de(compte())
    cle_de_la_victime = envoyer_photo(victime, "photo")

    # Un compte ne peut pas utiliser la clé de fichier d'un autre.
    corps = {"type_compte": "boutique", "name": "Faux Magasin", "zone": zone.pk,
             "secteur": secteur.pk, "photo": cle_de_la_victime, "representant_nom": "X Y",
             "representant_photo": envoyer_photo(voleur, "representant_photo")}
    refus_cle = voleur.post("/api/business/", corps, format="json")
    assert refus_cle.status_code == 400 and "photo" in refus_cle.json()["fields"]

    # Un fichier qui n'est pas une image (HTML) est refusé à la signature.
    refus = voleur.post("/api/uploads/sign/", {
        "kind": "photo", "content_type": "text/html", "size": 30}, format="json")
    assert refus.status_code == 400
