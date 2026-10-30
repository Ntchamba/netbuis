# T123 — Tests de bout en bout du backend (vérification)

Date : 2026-10-22 · Dossier : `backend/tests/e2e/` (autorisation exceptionnelle de l'orchestrateur)
Moyens : API réelle (`APIClient`), vraie base PostgreSQL, SMS « console ». Aucun secret écrit.

## Scénarios (un test = un parcours, étapes commentées en français)
| Fichier | Test | Ce qu'il prouve |
|---|---|---|
| `test_flow_access.py` | `test_code_sms_verification_me_rafraichissement_deconnexion` | code SMS lu sur la console → mauvais code refusé → vérification → code à usage unique → `/api/me/` (numéro masqué) → rafraîchissement (ancien jeton mort) → déconnexion |
| | `test_connexion_admin_mot_de_passe_cookie_de_rafraichissement` | connexion admin : accès dans le corps, rafraîchissement en cookie HttpOnly seulement, cookie tourné, rejeu refusé et effacé, déconnexion |
| | `test_un_compte_sms_ne_peut_pas_entrer_par_le_mot_de_passe_admin` | cas qui échoue |
| `test_flow_business_creation.py` | `test_boutique_creee_puis_validee_…` | photos par jetons signés → création (en attente) → invisible → l'admin voit la demande → valide (audit) → trouvé par nom, fiche publique sans numéro |
| | `test_prestataire_avec_cni_puis_refus_avec_motif_…` | prestataire avec pièce (lien signé pour l'admin) ; sans pièce = 400 ; refus sans motif = 400 ; refus avec motif lu par le propriétaire ; invisible partout |
| | `test_photo_d_un_autre_compte_ou_type_interdit_refuses` | clé de fichier d'autrui refusée ; HTML refusé |
| `test_flow_search.py` | `test_recherche_ecrite_nom_voix_suggestions_zones_et_commerce_masque` | produit, nom (D-27, accents, faute), vocale, suggestions, filtres de zone, journal, commerce bloqué / en attente / rejeté introuvable |
| | `test_recherche_exige_une_connexion_…` | 401 sans connexion, 403 compte bloqué |
| `test_flow_call.py` | `test_appel_complet_…_aucune_fuite_de_numero` | session Jitsi → 409 si 2e session → agent accepte → fiche avec les deux numéros → refus à l'appelant et à un autre agent → fin → fiche fermée (409) → aucun numéro dans 9 autres réponses → numéro seulement dans `wa_url` |
| | `test_deux_agents_sonnent_un_seul_gagne_…` | 409 `call_taken` pour le perdant |
| | `test_aucun_agent_disponible_…` | `unavailable`, sans salle ni jeton ; 401 sans connexion |
| | `test_annulation_avant_reponse_…` | annulation, agent trop tard (409), autre compte 404 |
| | `test_expiration_de_la_sonnerie_par_la_commande_expire_calls` | `missed/timeout`, appel trop long fermé |
| `test_flow_map.py` | `test_villes_puis_quartiers_puis_commerces_…` | villes → quartiers (compteurs) → commerces, sans numéro ; validation ajoute, blocage retire |
| `test_flow_forum.py` | `test_publication_commentaire_signalement_masquage_et_restauration` | publication, commentaire, signalement (doublon 409, signaleur ne le voit plus), masquage auto au 3e signaleur, file de modération réservée à l'Administrateur complet, restauration, masquage, suppression, audit |
| | `test_limites_publications_et_commentaires_429` | 6e publication du jour 429 ; 11e commentaire 429 (par compte) |
| | `test_regles_d_acces_…` | sans commerce 404, en attente 403, compte bloqué 403 |
| `test_flow_admin.py` | `test_droits_par_groupe_…` | simple / sans groupe / Validateur / Complet sur les routes admin |
| | `test_blocage_d_un_compte_ses_jetons_ne_marchent_plus_…` | blocage (motif obligatoire) → accès et rafraîchissement refusés, audit, déblocage |
| | `test_export_des_comptes_numeros_masques_et_audite` | CSV en pièce jointe, numéros masqués, export audité |

Aides : `tests/e2e/_aides.py` (comptes à numéros réservés 6 05xx xxxx, client connecté, envoi de fichier par jeton signé).

## Couverture (`pytest --cov=apps --cov-report=term-missing:skip-covered`)
pytest-cov 7.1.0 est installé. **Couverture globale : 99 %** (17 803 instructions, 166 non couvertes ; le calcul inclut les fichiers de tests).
Modules sous 70 % :
- `apps/core/utils/time.py` : 0 % (5 instructions) — `now_douala()` n'est utilisée nulle part (code mort).
- `apps/business/migrations/0005_nom_normalise.py` : 67 % — migration de données (branche de retour arrière).
Journal complet : `logs/T123-pytest-cov.txt`.

## Résultats
`ruff check .` : All checks passed · `makemigrations --check --dry-run` : No changes detected · `pytest -q` : **1699 passed** (157 s).
