"""Parcours du forum (T123) : publication, commentaire, signalement, masquage par la
modération, limites (429).
"""
import pytest
from django.core.cache import cache
from django.test import override_settings

from apps.admin_panel.models import AuditLog
from apps.business.models import BusinessStatus
from apps.forum.models import ContentStatus, Post
from apps.forum.tests.helpers import payload
from apps.search.tests.helpers import shop
from tests.e2e._aides import (
    COMPLET,
    VALIDATEUR,
    administrateur,
    client_de,
    compte,
    envoyer_fichier,
)
from tests.factories.business_factory import make_subscription

pytestmark = pytest.mark.django_db

POSTS = "/api/forum/posts/"


@pytest.fixture(autouse=True)
def _isolation(tmp_path):
    cache.clear()
    with override_settings(MEDIA_ROOT=tmp_path / "media",
                           PRIVATE_MEDIA_ROOT=tmp_path / "private_media"):
        yield
    cache.clear()


def ids_du_fil(client):
    reponse = client.get(POSTS)
    assert reponse.status_code == 200
    return [p["id"] for p in reponse.json()["results"]]


def signaler(client, cible, identifiant, motif="spam"):
    return client.post("/api/reports/", {
        "target_type": cible, "target_id": identifiant, "reason": motif}, format="json")


def test_publication_commentaire_signalement_masquage_et_restauration():
    commerce = shop("Chez Riz")
    marchand = client_de(commerce.owner)
    lecteur = client_de(compte(name="Sali Abdou"))

    # 1. Le commerçant publie une photo envoyée par jeton signé.
    media = envoyer_fichier(marchand, "post_image")
    cree = marchand.post(POSTS, {"media": media, "caption": "Riz frais arrivé"}, format="json")
    assert cree.status_code == 201, cree.content
    post_id = cree.json()["id"]
    assert cree.json()["author"]["business_id"] == commerce.pk

    # 2. Un lecteur le voit dans le fil et dans la fiche de la publication.
    assert post_id in ids_du_fil(lecteur)
    assert lecteur.get(f"{POSTS}{post_id}/").json()["comments_count"] == 0

    # 3. Il commente ; le commentaire apparaît, son nom est abrégé.
    com = lecteur.post(f"{POSTS}{post_id}/comments/", {"text": "Vous livrez ?"}, format="json")
    assert com.status_code == 201 and com.json()["author"]["name"] == "Sali A."
    liste = lecteur.get(f"{POSTS}{post_id}/comments/").json()["results"]
    assert [c["text"] for c in liste] == ["Vous livrez ?"]
    assert lecteur.get(f"{POSTS}{post_id}/").json()["comments_count"] == 1

    # 4. Signalement : un même compte ne compte qu'une fois, son identité n'est jamais montrée.
    premier = signaler(lecteur, "post", post_id)
    assert premier.status_code == 201 and "Sali" not in premier.content.decode()
    assert signaler(lecteur, "post", post_id).status_code == 409  # doublon refusé
    assert post_id not in ids_du_fil(lecteur)  # le signaleur ne le voit plus (côté serveur)
    passant = client_de(compte())
    assert post_id in ids_du_fil(passant)  # les autres le voient encore
    # Signalement invalide : cible inconnue.
    assert signaler(lecteur, "post", 999999).status_code == 404

    # 5. Deux autres comptes signalent : au 3e signaleur distinct, le serveur masque seul.
    for _ in range(2):
        signaler(client_de(compte()), "post", post_id, "arnaque")
    assert Post.objects.get(pk=post_id).status == ContentStatus.HIDDEN
    assert post_id not in ids_du_fil(passant)
    assert passant.get(f"{POSTS}{post_id}/").status_code == 404
    mine = {p["id"]: p["status"] for p in marchand.get("/api/forum/mine/").json()["results"]}
    assert mine[post_id] == "masque"  # l'auteur le voit, marqué masqué

    # 6. La file de modération le montre à l'Administrateur complet seulement.
    validateur = client_de(administrateur(VALIDATEUR))
    assert validateur.get("/api/admin/reports/").status_code == 403
    chef = administrateur(COMPLET)
    moderation = client_de(chef)
    file = moderation.get("/api/admin/reports/").json()["results"]
    assert [(r["target_type"], r["target_id"]) for r in file] == [("post", post_id)]
    assert file[0]["reporters_count"] == 3
    assert "Sali" not in str(file)  # pas d'identité des signaleurs

    # 7. La restauration remet la publication en ligne, avec une trace d'audit.
    rest = moderation.post(f"/api/admin/reports/post/{post_id}/restore/", {}, format="json")
    assert rest.status_code == 200
    assert post_id in ids_du_fil(passant)

    # 8. Masquage manuel puis suppression par la modération : traces dans l'audit.
    assert moderation.post(f"/api/admin/reports/post/{post_id}/hide/", {}, format="json"
                           ).status_code == 200
    assert post_id not in ids_du_fil(passant)
    suppr = moderation.post(f"/api/admin/reports/post/{post_id}/delete/",
                            {"reason": "Contenu trompeur"}, format="json")
    assert suppr.status_code == 200
    assert Post.objects.get(pk=post_id).status == ContentStatus.DELETED
    actions = AuditLog.objects.filter(admin=chef, action="moderation_contenu")
    assert actions.count() >= 3


def test_limites_publications_et_commentaires_429():
    commerce = shop("Chez Riz")
    marchand = client_de(commerce.owner)
    make_subscription(commerce)  # abonné : seule la limite du jour s'applique

    # 1. Cinq publications par jour passent, la sixième est refusée (429).
    for _ in range(5):
        assert marchand.post(POSTS, payload(commerce.owner), format="json").status_code == 201
    sixieme = marchand.post(POSTS, payload(commerce.owner), format="json")
    assert sixieme.status_code == 429 and sixieme.json()["code"] == "daily_post_limit"
    assert Post.objects.filter(profile=commerce).count() == 5

    # 2. Dix commentaires en dix minutes passent, le onzième est refusé (429).
    post_id = Post.objects.filter(profile=commerce).first().pk
    lecteur = client_de(compte())
    for i in range(10):
        assert lecteur.post(f"{POSTS}{post_id}/comments/", {"text": f"Message {i}"},
                            format="json").status_code == 201
    onzieme = lecteur.post(f"{POSTS}{post_id}/comments/", {"text": "Encore"}, format="json")
    assert onzieme.status_code == 429 and onzieme.json()["code"] == "comment_rate_limit"
    # La limite est propre à chaque compte.
    autre = client_de(compte())
    assert autre.post(f"{POSTS}{post_id}/comments/", {"text": "Bonjour"},
                      format="json").status_code == 201


def test_regles_d_acces_publication_reservee_aux_commerces_actifs():
    # 1. Un compte sans commerce ou avec un commerce en attente ne publie pas.
    simple = compte()
    assert client_de(simple).post(POSTS, payload(simple), format="json").status_code == 404
    attente = shop("En attente", status=BusinessStatus.PENDING)
    refus = client_de(attente.owner).post(POSTS, payload(attente.owner), format="json")
    assert refus.status_code == 403 and refus.json()["code"] == "business_not_active"
    # 2. Un compte bloqué ne peut plus lire le fil.
    bloque = compte()
    api = client_de(bloque)
    assert api.get(POSTS).status_code == 200
    bloque.is_blocked = True
    bloque.save()
    assert api.get(POSTS).status_code == 403
