"""Parcours d'appel Jitsi vers l'équipe (T123, D-25 / D-30).

Seule la fiche de contexte de l'agent qui a décroché porte les numéros ; le seul autre endroit
possible est le lien WhatsApp (`wa_url`).
"""
from datetime import timedelta
from io import StringIO

import pytest
from django.core.cache import cache
from django.core.management import call_command
from django.utils import timezone

from apps.calls.models import CallSession
from apps.calls.tests.helpers import client_for, make_agent, post_session
from apps.search.tests.helpers import shop
from tests.factories.business_factory import make_owner

pytestmark = pytest.mark.django_db

ADMIN = "/api/admin/calls/"


@pytest.fixture(autouse=True)
def _jitsi(settings):
    import secrets

    settings.JITSI_DOMAIN, settings.JITSI_APP_ID = "jitsi.example.test", "netbuis-test"
    settings.JITSI_JWT_SECRET = secrets.token_urlsafe(48)
    cache.clear()
    yield
    cache.clear()


def chiffres(numero):
    return numero.replace("+237", "")


def test_appel_complet_agent_disponible_fiche_de_contexte_fin_et_aucune_fuite_de_numero():
    commerce = shop("Chez Riz", ["Riz"])
    agent = make_agent(name="Moussa")
    awa = make_owner(name="Awa")
    appelant, agent_api = client_for(awa), client_for(agent)
    vus = []  # corps de toutes les réponses qui ne doivent contenir aucun numéro

    # 1. L'appelant trouve le commerce puis crée la session d'appel.
    vus.append(appelant.get("/api/search/", {"q": "riz"}))
    debut = post_session(appelant, commerce.pk)
    assert debut.status_code == 200 and debut["Cache-Control"] == "no-store"
    session = debut.json()
    assert session["state"] == "ringing" and session["ring_seconds"] == 30
    assert set(session["jitsi"]) == {"domain", "room", "jwt"}
    sid = session["session_id"]

    # 2. Une 2e demande du même appelant est refusée (une seule session active).
    assert post_session(appelant).status_code == 409

    # 3. Le téléphone sonne chez l'agent : il voit la session dans la liste d'appels.
    liste = agent_api.get(ADMIN)
    assert liste.status_code == 200
    vus.append(liste)

    # 4. L'agent accepte : salle + jeton, aucun numéro dans cette réponse.
    accept = agent_api.post(f"{ADMIN}sessions/{sid}/accept/")
    assert accept.status_code == 200 and accept.json()["jitsi"]["jwt"]
    vus.append(accept)

    # 5. L'appelant voit « answered » (consultation courte, sans salle ni jeton).
    etat = appelant.get(f"/api/calls/sessions/{sid}/")
    assert etat.json()["state"] == "answered"
    vus.append(etat)

    # 6. Seul l'agent qui a décroché reçoit la fiche avec LES DEUX numéros.
    fiche = agent_api.get(f"{ADMIN}sessions/{sid}/context/")
    assert fiche.status_code == 200 and fiche["Cache-Control"] == "no-store"
    corps = fiche.json()
    assert corps["caller"] == {"name": "Awa", "phone": awa.phone}
    assert corps["business"]["phone"] == commerce.phone_anchor
    assert corps["business"]["name"] == "Chez Riz"

    # 7. Ni l'appelant, ni un autre agent, ni un simple compte n'y ont accès.
    assert appelant.get(f"{ADMIN}sessions/{sid}/context/").status_code == 403
    assert client_for(make_agent()).get(f"{ADMIN}sessions/{sid}/context/").status_code == 404

    # 8. L'appelant raccroche : la session est terminée pour les deux côtés.
    fin = appelant.post(f"/api/calls/sessions/{sid}/end/")
    assert fin.status_code == 200 and fin.json()["state"] == "ended"
    assert CallSession.objects.get(pk=sid).state == "ended"
    apres = agent_api.get(f"{ADMIN}sessions/{sid}/context/")
    assert apres.status_code == 409 and apres.json()["code"] == "call_not_answered"  # fiche fermée
    assert chiffres(commerce.phone_anchor) not in apres.content.decode()
    vus.append(apres)

    # 9. Historiques, fiche publique, profil et recherche après l'appel : aucun numéro.
    vus += [appelant.get("/api/calls/history/"), appelant.get(f"/api/business/{commerce.pk}/"),
            appelant.get("/api/me/"), appelant.get("/api/search/", {"q": "riz"}),
            agent_api.get(ADMIN)]
    for reponse in vus:
        texte = reponse.content.decode()
        assert chiffres(commerce.phone_anchor) not in texte, reponse.request["PATH_INFO"]
        assert chiffres(awa.phone) not in texte, reponse.request["PATH_INFO"]

    # 10. Le lien WhatsApp est le seul autre endroit où le numéro du commerce apparaît.
    wa = appelant.post("/api/calls/whatsapp/", {"business_id": commerce.pk, "platform": "android"},
                       format="json")
    assert wa.status_code == 200
    assert chiffres(commerce.phone_anchor) in wa.json()["wa_url"]
    assert set(wa.json()) == {"call_id", "wa_url"}


def test_deux_agents_sonnent_un_seul_gagne_l_autre_est_informe():
    premier, second = make_agent(name="Premier"), make_agent(name="Second")
    appelant = client_for(make_owner())
    sid = post_session(appelant).json()["session_id"]

    # 1. Les deux agents voient la sonnerie.
    for agent in (premier, second):
        assert client_for(agent).get(ADMIN).status_code == 200
    # 2. Le premier à répondre gagne ; le second reçoit « déjà pris » (409).
    assert client_for(premier).post(f"{ADMIN}sessions/{sid}/accept/").status_code == 200
    perdu = client_for(second).post(f"{ADMIN}sessions/{sid}/accept/")
    assert perdu.status_code == 409 and perdu.json()["code"] == "call_taken"
    # 3. Le perdant ne peut ni lire la fiche ni raccrocher à la place du gagnant.
    assert client_for(second).get(f"{ADMIN}sessions/{sid}/context/").status_code == 404
    assert client_for(second).post(f"{ADMIN}sessions/{sid}/end/").status_code != 200
    assert CallSession.objects.get(pk=sid).agent_id == premier.pk


def test_aucun_agent_disponible_reponse_immediate_sans_salle():
    make_agent(available=False)
    appelant = client_for(make_owner())

    # 1. Aucune salle, aucun jeton : « unavailable » tout de suite.
    reponse = post_session(appelant)
    assert reponse.status_code == 200
    corps = reponse.json()
    assert (corps["state"], corps["code"], corps["jitsi"]) == (
        "unavailable", "no_agent_available", None)
    # 2. L'appelant n'est pas bloqué : il peut réessayer.
    make_agent()
    assert post_session(appelant).json()["state"] == "ringing"
    # 3. Un compte sans connexion ne peut pas appeler.
    from rest_framework.test import APIClient

    assert post_session(APIClient()).status_code == 401


def test_annulation_avant_reponse_puis_l_agent_ne_peut_plus_decrocher():
    agent = make_agent()
    appelant = client_for(make_owner())
    sid = post_session(appelant).json()["session_id"]

    # 1. L'appelant raccroche avant la réponse.
    annule = appelant.post(f"/api/calls/sessions/{sid}/cancel/")
    assert annule.status_code == 200 and annule.json()["state"] == "cancelled"
    # 2. L'agent arrive trop tard : 409.
    tard = client_for(agent).post(f"{ADMIN}sessions/{sid}/accept/")
    assert tard.status_code == 409 and tard.json()["code"] == "call_not_ringing"
    # 3. Un autre compte ne peut pas annuler la session de quelqu'un d'autre.
    sid2 = post_session(appelant).json()["session_id"]
    assert client_for(make_owner()).post(f"/api/calls/sessions/{sid2}/cancel/").status_code == 404


def test_expiration_de_la_sonnerie_par_la_commande_expire_calls(settings):
    agent = make_agent()
    appelant = client_for(make_owner())
    sid = post_session(appelant).json()["session_id"]

    # 1. La sonnerie dure 30 s ; on vieillit la session au-delà.
    CallSession.objects.filter(pk=sid).update(expires_at=timezone.now() - timedelta(seconds=1))
    # 2. La commande planifiée la passe en « missed / timeout ».
    sortie = StringIO()
    call_command("expire_calls", stdout=sortie)
    assert "1 session(s)" in sortie.getvalue()
    session = CallSession.objects.get(pk=sid)
    assert (session.state, session.end_reason) == ("missed", "timeout")
    # 3. L'agent ne peut plus répondre, l'appelant voit « manqué » et peut rappeler.
    assert client_for(agent).post(f"{ADMIN}sessions/{sid}/accept/").status_code == 409
    assert appelant.get(f"/api/calls/sessions/{sid}/").json()["state"] == "missed"
    assert post_session(appelant).status_code == 200

    # 4. Un appel resté « en cours » trop longtemps est aussi fermé.
    vieux = CallSession.objects.create(
        caller=make_owner(), room="salle-test-longue", state="answered",
        answered_at=timezone.now() - timedelta(seconds=settings.CALL_MAX_DURATION + 5))
    call_command("expire_calls", stdout=StringIO())
    vieux.refresh_from_db()
    assert (vieux.state, vieux.end_reason) == ("ended", "too_long")
