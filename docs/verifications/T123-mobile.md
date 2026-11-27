# T123 — Mobile : parcours de bout en bout et couverture

Tout est lancé depuis `mobile/` avec les faux dépôts : `flutter analyze` puis `flutter test --coverage --dart-define=USE_FAKE_API=true`. Sorties : `logs/T123-mobile-analyze.txt` (« No issues found! »), `logs/T123-mobile-test.txt` (1743 tests, « All tests passed! »), `logs/T123-mobile-coverage.txt`.

## Parcours (routeur réel, application complète, faux dépôts)
Fichiers : `mobile/test/integration/{flow_scenarios,domain_scenarios}.dart`, lancés par `search_call_flow_test.dart` et `domain_flow_test.dart` ; les mêmes scénarios sont rejoués sur appareil par `mobile/integration_test/*.dart` (non exécutés ici : pas d'appareil).

| Domaine | Scénario | Ce qu'il prouve |
|---|---|---|
| Appel (Jitsi, D-25) | écrit / vocal | recherche → fiche ou carte → Appeler → salle rejointe (FakeJitsiService) → « Appel en cours » → l'équipe répond → Raccrocher → fin → historique ; aucun numéro à l'écran |
| Appel | équipe indisponible | message exact, aucune salle rejointe |
| Appel | équipe sans réponse | « Personne n'a répondu », salle quittée |
| Appel | annulation | `cancel` envoyé (pas `end`), salle quittée, écran fermé |
| Appel | session impossible (réseau) | message, aucune salle, aucune question de suivi |
| Appel | WhatsApp / WhatsApp absent / hors connexion | lien au canal natif jamais affiché ; bouton grisé ; boutons désactivés hors connexion puis réseau revenu |
| Accès | première ouverture | Lancement → Découverte → numéro → mauvais code refusé → code reçu par SMS → nom (passé) → Accueil ; jetons gardés |
| Accès | session restaurée | « Commencer » mène à l'Accueil sans numéro ; écran protégé ouvert |
| Accès | déconnexion | jetons effacés, Accueil protégé par la garde, nouvelle connexion possible |
| Création de commerce | assistant Commerce | Profil → Informations (vide refusé) → Secteur (refus sans choix) → Détails → Récapitulatif → rien envoyé avant « Publier » → photos signées/envoyées puis demande → « Demande envoyée » → Profil « En attente de validation », brouillon vidé |
| Recherche | par nom du commerce | casse/accents ignorés, un seul commerce trouvé, « Aucun résultat » sur un nom inconnu, fiche |
| Recherche | vocale | texte dit envoyé tel quel, aucun résultat puis résultat |
| Carte | villes → quartiers → commerces → fiche | pins, fil d'Ariane, liste du quartier, fiche, retours |
| Forum | lire, commenter, signaler, publier | commentaire vide impossible ; commentaire ajouté (+1) ; signalement : merci + publication retirée ; publication : refus « limite du jour » puis succès, visible dans Mes publications |
| Compte | modifier ma boutique | repère sans nouvelle validation ; nom : avertissement, refus sans effet, confirmation → « En attente de validation » |
| Compte | suppression | annuler = rien ; réseau coupé = message, jetons et caches gardés ; confirmé = jetons et caches (fil, recherche) vidés, retour à l'écran du numéro, Accueil protégé |

## Couverture globale (lignes, `coverage/lcov.info`, script jetable)
**95,40 %** (11 526 lignes couvertes sur 12 082, 224 fichiers).

Les 10 fichiers les moins couverts :
| % | lignes | fichier |
|---|---|---|
| 0,00 | 0/5 | lib/features/business/data/photo_service.dart |
| 0,00 | 0/6 | lib/features/forum/data/post_media_service.dart |
| 0,00 | 0/26 | lib/features/forum/data/repositories/forum_repository_api.dart |
| 3,70 | 1/27 | lib/features/call/data/jitsi_service.dart |
| 13,79 | 4/29 | lib/features/search/voice_search/data/speech_service.dart |
| 50,00 | 1/2 | lib/core/config/feature_flags.dart |
| 50,00 | 1/2 | lib/core/network/endpoints.dart |
| 50,00 | 2/4 | lib/features/home/data/share_service.dart |
| 55,00 | 11/20 | lib/features/forum/data/repositories/forum_repository_fake.dart |
| 57,14 | 12/21 | lib/core/theme/app_colors.dart |

Lecture : les services natifs (photo, vidéo, Jitsi, reconnaissance vocale, partage) ne sont pas testables sans téléphone (leurs faux sont testés). **Lacune réelle** : `forum_repository_api.dart` (créer / lister / supprimer mes publications) n'a aucun test de dépôt API, contrairement aux autres dépôts.
