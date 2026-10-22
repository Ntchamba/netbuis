# Appels par Jitsi vers l'équipe NetBuis (décision D-25, 2026-10-22)

**Cette spécification REMPLACE `docs/spec/APPELS.md` (appel téléphonique au commerçant).** Les tâches T050 à T057 sont conservées comme historique ; leur flux « Appeler » est retiré par T131 (backend) et T133 (mobile).

## Ce qui change
- Le bouton **Appeler** ne compose plus aucun numéro et ne joint pas le commerçant. Il appelle **l'équipe NetBuis** : les comptes administrateurs qui ont le droit « répondre aux appels » et un tableau de bord ouvert. L'appel passe par **Jitsi** (audio d'abord).
- Le commerce que l'utilisateur consultait est transmis **comme contexte** : le membre de l'équipe voit « appel au sujet de [nom du commerce] » et le nom (prénom) de l'appelant. Aucun numéro de commerçant n'est transmis ni affiché.
- **Conséquence sur la règle du numéro** : plus aucune route ne délivre le numéro d'un commerçant (`POST /api/calls/initiate/` disparaît). Le numéro ancré reste en base (données du compte). WhatsApp est inchangé tant que Jeff n'en décide pas autrement (question ouverte Q2).
- Plus de feuille Orange / MTN, plus d'appel direct Android (`CallChannel.kt` retiré en T133), plus d'`ACTION_DIAL`.

## Parcours
1. L'utilisateur (connecté, non bloqué) touche **Appeler**. L'application demande `POST /api/calls/sessions/` (avec `business_id` facultatif).
2. Le serveur crée une `CallSession` en état `ringing`, avec un nom de salle **secret** (au moins 128 bits d'aléa), et publie l'événement aux tableaux de bord connectés. Réponse immédiate : les informations pour rejoindre la salle (domaine Jitsi, salle, jeton court) et la durée de sonnerie.
3. **Sans agent disponible** (aucun administrateur avec le droit et une connexion temps réel active) : réponse immédiate `no_agent_available`, état `unavailable`, l'utilisateur ne patiente pas pour rien.
4. Les tableaux de bord des agents disponibles **sonnent** (fenêtre d'appel entrant + son). Le premier qui répond gagne (`POST …/accept/`, mise à jour atomique `ringing → answered`) ; les autres reçoivent `taken` et arrêtent de sonner. Un agent peut refuser (`decline`) : si tous refusent ou après 30 s : `missed`.
5. L'application de l'utilisateur **rejoint la salle dès l'envoi** (audio seulement, micro actif, vidéo coupée) pour que la liaison audio soit prête quand l'agent arrive. L'agent rejoint à l'acceptation. Fin par l'un des deux (`end`) ou fermeture de la salle.
6. Un appel manqué reste visible dans le tableau de bord (liste « Appels manqués »).

## Objectif de latence (« moins d'une seconde »)
- **Définition mesurable** : délai entre la réception de `POST /api/calls/sessions/` par le serveur et l'affichage de la sonnerie sur un tableau de bord déjà connecté. **Cible : p95 < 1 s** de bout en bout en conditions normales ; **mesure automatisée côté serveur : p95 < 250 ms** (création + diffusion), test T134.
- Moyens : canal temps réel **poussé** (pas de sondage) : flux SSE sur ASGI alimenté par PostgreSQL `LISTEN/NOTIFY` (aucune infrastructure en plus ; fonctionne avec plusieurs processus). Aucune tâche asynchrone lente dans le chemin (pas de mail, pas de calcul), une seule transaction courte. Côté mobile, connexion réseau réchauffée à l'ouverture de la fiche du commerce (évite la poignée de main TLS au moment du clic).
- **Ce qu'on ne peut pas promettre** : le temps du réseau mobile de l'utilisateur (une connexion 3G froide peut dépasser 1 s à elle seule) ; et la **liaison audio** Jitsi (négociation WebRTC : généralement 1 à 3 s) — d'où l'entrée anticipée dans la salle. La sonnerie, elle, doit apparaître en moins d'une seconde.

## Architecture
- `CallSession` : id (UUID), appelant, commerce (facultatif), salle (secrète), état (`ringing`, `answered`, `ended`, `missed`, `declined`, `unavailable`, `cancelled`), horodatages (création, sonnerie, réponse, fin), agent qui a répondu, motif de fin. Remplace l'usage de `CallLog` pour l'historique des appels de l'utilisateur (l'historique de T053 lit les sessions).
- **Présence des agents** : table `AgentPresence` (agent, dernière activité) mise à jour par un battement de cœur ; un agent est « disponible » s'il a un flux ouvert et une activité de moins de ~25 s et a choisi « Disponible » dans le tableau de bord.
- **Flux agent** : `GET /api/admin/calls/stream/` (SSE ; jeton administrateur ; droit « répondre aux appels » relu à chaque connexion) ; à la connexion, rejoue les sessions encore en sonnerie.
- **Flux appelant** : `GET /api/calls/sessions/<id>/events/` (SSE) avec repli par consultation courte.
- **Droit** : nouveau droit `peut_repondre_aux_appels` donné aux groupes « Validateur » et « Administrateur complet » (extension de T070).
- **Limites** : réutilise `limite_appels_par_minute` et `limite_appels_par_jour` (PlatformSetting). Un appelant ne peut avoir qu'une session active.
- **Jitsi** : le serveur de l'application ne transporte JAMAIS l'audio ; il distribue seulement le droit d'entrer dans une salle. Domaine, identifiant d'application et secret de jeton viennent de l'environnement (`JITSI_DOMAIN`, `JITSI_APP_ID`, `JITSI_JWT_SECRET`) ; jeton court (≈ 2 min pour entrer) limité à UNE salle, rôle modérateur pour l'agent, participant pour l'utilisateur ; enregistrement et transcription désactivés.
- **Tableau de bord** : API d'intégration Jitsi (`external_api.js` servi par le domaine Jitsi). **Mobile** : `jitsi_meet_flutter_sdk` (Android API 24 minimum ; l'application a un `minSdk` à vérifier ; le SDK alourdit nettement l'APK, à mesurer en T133).

## Hébergement de Jitsi — DÉCISION DE JEFF NÉCESSAIRE
| Option | Avantages | Limites |
|---|---|---|
| **JaaS (8x8)** | rien à héberger, API d'intégration disponible | gratuit jusqu'à 25 utilisateurs actifs par mois seulement, ensuite 99 $/mois pour 300 (tarifs vus le 2026-10-22, à revérifier) ; un « utilisateur actif » = quelqu'un qui a participé à une réunion avec au moins une autre personne : les appelants comptent |
| **Jitsi auto-hébergé** | coût fixe, pas de limite d'utilisateurs, données chez nous | demande un serveur (VPS) avec TCP 443 et **UDP 10000** ouverts ; Railway n'expose pas de port UDP à notre connaissance (à confirmer) : le Jitsi ne peut donc pas tourner sur Railway ; exploitation et mises à jour à notre charge |
| `meet.jit.si` public | gratuit | **l'intégration dans une page web n'est plus prise en charge** (le tableau de bord ne pourrait pas l'utiliser) ; utile seulement pour essayer le mobile |

Le code est écrit pour fonctionner avec les deux premières options : seuls les noms d'environnement changent. Aucun déploiement n'est fait par ces tâches.

## Sécurité et vie privée
- Salle secrète, jeton signé à usage limité (une salle, courte durée), aucun enregistrement. L'utilisateur est averti que l'appel est avec l'équipe NetBuis (texte à écrire en T133, à valider par Jeff).
- Le tableau de bord montre à l'agent : prénom/nom d'affichage de l'appelant, commerce concerné, durée. Le numéro complet de l'appelant n'est PAS montré dans la fenêtre d'appel (il reste dans le détail du compte, audité, comme T083).
- Chaque appel est journalisé sans contenu (états, horodatages, agent) ; aucun jeton Jitsi ni nom de salle dans les journaux.
- Les nouvelles routes sont couvertes par le test qui énumère toutes les routes (T121) et par les tests de droits.

## Paiements : les packs de crédits via CamPay RESTENT (précisé par Jeff le 2026-10-22)
- Rien dans cette décision ne retire CamPay ni l'achat de **packs de crédits**. Ils restent prévus et **reportés** comme avant (tâche V08, `CREDITS_ENABLED=False` tant que Jeff n'a pas donné son « go » ; code existant dans `backend/apps/payments/`, documentation dans `docs/payments/`). Aucun fichier de paiement n'est touché par la phase 13.
- **Point d'accroche** : l'ancien quota d'appels (appels gratuits par jour, débit d'un crédit par appel, `free_call_available`, `credits_balance`) s'appliquait à `POST /api/calls/initiate/`. Il s'appliquera désormais à la **création d'une session** (`POST /api/calls/sessions/`), au même endroit, derrière le même interrupteur. T131 prévoit ce point d'accroche (une fonction unique « cet appelant a-t-il le droit d'appeler ? ») sans activer aucun débit.
- **Question ouverte Q7 (à décider par Jeff avant V08)** : maintenant que l'appel va vers l'équipe NetBuis et non vers un commerçant, **qu'achète un pack de crédits** ? Pistes : (a) un crédit par appel à l'équipe (comme avant, mais l'équipe répond) ; (b) les packs servent à autre chose (mise en avant, abonnement) et l'appel reste gratuit ; (c) appels gratuits dans la limite quotidienne, crédits au-delà. Défaut retenu : **aucun débit** tant que Jeff n'a pas tranché ; le point d'accroche existe, rien n'est facturé.

## Questions ouvertes (défauts retenus, modifiables)
- **Q1** Hébergement de Jitsi (JaaS ou auto-hébergé) : à décider avant tout essai réel. Défaut : code compatible avec les deux.
- **Q2** WhatsApp reste-t-il (lien `wa.me` vers le commerçant) ? Défaut : inchangé.
- **Q3** Vidéo : audio seul en v1. Défaut : oui.
- **Q4** Qui répond : tous les agents disponibles sonnent, le premier gagne. Défaut : oui.
- **Q5** Durée de sonnerie : 30 s. Défaut : oui.
- **Q7** Que paient les packs de crédits CamPay avec les appels vers l'équipe ? Voir la section « Paiements ». Défaut : aucun débit pour l'instant.
- **Q6** L'appelant sans compte (non connecté) ne peut pas appeler. Défaut : connexion obligatoire (comme avant).
