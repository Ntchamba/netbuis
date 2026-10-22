# À relire par Jeff (zones 🔒 passées sans arrêt, sur sa décision du 2026-10-21)
Chaque tâche ci-dessous a été validée par l'agent vérificateur mais pas relue par Jeff. Relecture à faire avant toute mise en service.

## T050 — lancer un appel (le numéro du commerçant)
Fichiers : backend/apps/calls/services/call_service.py (seul endroit qui lit phone_anchor, ordre des contrôles), views/initiate.py (no-store, erreurs d'authentification), services/rate_limit.py, serializers/initiate.py, tests/test_initiate.py (non-fuite dans les logs), models/call_log.py.
Décision à valider : FREE_CALLS_PER_DAY = 3 (valeur d'essai, active seulement si CREDITS_ENABLED=True) ; quota dépassé = 429 RATE_LIMITED ; commerce inexistant = BUSINESS_NOT_ACTIVE.

## T051 — WhatsApp, retour d'appel, historique
Fichiers : backend/apps/calls/services/{whatsapp_service,feedback_service,call_service}.py, views/{feedback,whatsapp_report}.py, tests/e2e/test_flow_search_call.py.
Décisions à valider : message WhatsApp pré-rempli « Bonjour, je vous contacte depuis NetBuis au sujet de « {nom} ». » (prefilled_message) ; seuil de 3 signalements en constante ; le signalement « pas de WhatsApp » exige d'avoir reçu un lien ; « mauvais numéro » n'a pas encore d'effet de masquage (champ needs_fix absent).

## T052 — bouton Appeler, feuille Orange / MTN, appel direct Android
Fichiers à relire ligne par ligne : mobile/android/app/src/main/kotlin/cm/netbuis/netbuis/CallChannel.kt (NON compilé ici : à compiler et essayer sur téléphone), MainActivity.kt, AndroidManifest.xml, mobile/lib/features/call/application/call_controller.dart (_run : seul endroit où passe le numéro), data/call_channel.dart, data/models/call_session.dart, data/repositories/call_repository_api.dart.
À confirmer sur téléphone (docs/TESTS_JEFF.md, 14 étapes) : détection des SIM, simOperatorName = « Orange » / « MTN », clé de compte createForPhoneAccountHandle (API 26), demande de permission, repli composeur.
Décisions à valider : le numéro n'est pas affiché dans l'appli, même dans le repli ACTION_DIAL (visible seulement dans le composeur du système, avec avertissement) ; « Plus tard » sur l'explication annule l'appel.

## T054 — WhatsApp et retour d'appel (mobile)
Fichiers : CallChannel.kt (openWhatsapp : seul https://wa.me accepté, setPackage com.whatsapp / com.whatsapp.w4b, aucun repli navigateur), AndroidManifest.xml (<queries>), mobile/lib/features/call/data/models/call_session.dart (WhatsappLink), application/call_controller.dart (WhatsappFlow._open : seul endroit où le lien passe du dépôt au natif), data/repositories/call_repository_api.dart (initiateWhatsapp), data/call_channel.dart.
À confirmer sur téléphone (docs/TESTS_JEFF.md, 12 points) : WhatsApp installé / Business seul / absent ; moment d'apparition de la feuille « ça a abouti ? ».
Note : le contrat de recherche n'a pas whatsapp_available ; les cartes sont grisées seulement si le serveur l'envoie (sinon CHANNEL_UNAVAILABLE au clic).

## T057 — vérification de tranche critique (recherche → appel) : CONFORME sur le vrai backend
Le BACKLOG demandait « Jeff relit 🔒 appel et valide avant T060 » : non fait, passé sans arrêt sur ta décision. À relire en priorité : T050, T051, T052, T054 ci-dessus. Tests sur téléphone réel : docs/TESTS_JEFF.md (appel Orange T052-2, MTN T052-3, une seule SIM T052-7, permission refusée T052-10, WhatsApp absent T054-5).
Observation : clé de signature des jetons de 31 octets (PyJWT demande ≥ 32) : à renforcer avant la mise en service.

## Décision produit à prendre : la recherche ne trouve pas un commerce par son nom
Constaté en T040 et T063 : taper « Pharmacie du Marché » ne trouve pas le commerce par son nom seul (le critère de T040 ne cite que offres, sous-catégories, produits, secteur, catégories de service). Facile à ajouter (index trigramme sur le nom). À trancher avant la mise en service.

## T070 — droits d'administration et journal d'audit
Fichiers à relire ligne par ligne : backend/apps/admin_panel/services/rights_service.py, permissions.py, migrations/0002_groupes_administration.py, services/audit_service.py, models/audit_log.py, views/me.py, tests/test_permissions.py ; backend/apps/accounts/permissions.py (IsAdminRole, version définitive) ; deux tests réécrits : accounts/tests/test_me.py (fin de fichier) et core/tests/test_bricks.py.
Décisions à valider : les droits viennent uniquement des groupes (is_superuser / is_staff ne donnent rien sous /api/admin/) ; droits relus en base à chaque requête (un admin retiré du groupe est refusé tout de suite) ; permissions ajoutées : peut_voir_demandes, peut_voir_comptes, peut_supprimer_compte, peut_exporter, peut_accorder_abonnement. Pas de test de l'idempotence de la migration ni de la lecture seule de l'AuditLog dans l'admin Django.

## T071 — validation des demandes de compte business (pièces d'identité)
Fichiers à relire ligne par ligne : backend/apps/business/services/storage_service.py (private_download_url / open_private_download, contrôle de l'admin dans le jeton), backend/apps/admin_panel/views/businesses.py (PrivateFileView et permissions), backend/apps/business/services/verification_service.py (changement de statut conditionnel), backend/apps/admin_panel/services/request_service.py, serializers/business.py, log_filters.py + apps.py (masquage des liens signés dans les logs), tests/test_businesses.py.
Décisions : lien signé valable 5 minutes, lié à l'admin et au fichier ; dashboard : ouvrir les pièces par fetch avec le jeton (pas une balise <img>).
À noter : /api/business/me/ renvoie encore au propriétaire la clé de stockage diplome_photo (pas une URL, n'ouvre rien) — à masquer comme la CNI ? ; les journaux d'accès du serveur (gunicorn, nginx) enregistreront le jeton de l'URL : à configurer au déploiement ; le test de concurrence est séquentiel.

## T074 — réglages, création d'administrateurs, export CSV
Fichiers à relire ligne par ligne : backend/apps/admin_panel/services/admin_service.py (création, gardes, retrait de rôle), services/export_service.py (colonnes, neutralisation des formules, audit), services/settings_service.py (bornes), views/admins.py, views/export.py, views/settings.py, serializers/admin.py (seul endroit où apparaît temporary_password), migrations/0004_action_export_comptes.py, tests/test_admins.py, tests/test_export.py.
Décisions à valider : mot de passe temporaire de 16 caractères montré une seule fois à la création d'un administrateur — et il reste valable indéfiniment : aucun changement forcé ni route de changement de mot de passe (à ajouter en T077 / dashboard) ; export CSV avec numéros TOUJOURS masqués ; réglages : minimum 1 (le BACKLOG disait ≥ 0 ; 0 couperait tous les appels) et maximums choisis par c2 (sous-catégories 50, publications 1000, appels par minute 60, par jour 1000, seuil 1000) ; retrait de rôle avec motif obligatoire, retire is_admin et invalide les jetons.

## T077 — connexion de l'administrateur (dashboard)
Fichiers à relire ligne par ligne : dashboard/src/auth/tokenStorage.tsx (jeton en mémoire + compteur de génération de session), src/api/client.ts (un seul refresh en vol, une seule reprise, contrôle de génération), src/auth/AuthProvider.tsx (démarrage, 403, erreur de chargement, logout), src/auth/permissions.tsx, src/modules/auth/pages/LoginPage.tsx, src/modules/auth/errors.ts, src/routes/ProtectedRoute.tsx, tests/auth/auth.test.tsx.
Cette tâche a demandé trois tours de vérification (course entre renouvellement du jeton et déconnexion) : le dernier est CONFORME.
À noter : logout() réinitialise la session après la réponse du POST logout (non atteignable depuis l'interface actuelle) ; le mot de passe temporaire d'un nouvel administrateur (T074) n'a pas de changement forcé à la première connexion ; la lecture de Retry-After par le navigateur suppose que l'API l'expose (Access-Control-Expose-Headers) si le dashboard est sur un autre domaine.

## T082 — Demandes du dashboard (pièces d'identité)
Fichiers à relire ligne par ligne : dashboard/src/modules/businesses/api.ts (privateFilePath, fetchPrivateFile : le jeton admin n'est envoyé qu'à /api/admin/private-files/<jeton>/), hooks.ts (useIdDocument : blob en mémoire seulement, révoqué à la fermeture, réponses tardives ignorées), components/ValidationPanel.tsx (IdDocumentModal), tests/modules/demandes.test.tsx (bloc CNI et tests de sécurité des URL).
À valider : la confirmation de validation/rejet est un toast (la maquette montre une pastille sur la carte) ; la modale de pièce est étroite pour une CNI.

## T083 — Comptes du dashboard (numéro complet, blocage, suppression)
Fichiers à relire ligne par ligne : dashboard/src/modules/users/pages/UserDetailPage.tsx (fonction phoneText : seul endroit où le numéro complet est affiché, uniquement si le serveur l'envoie), hooks.ts (useAccount, ACCOUNT_DETAIL_GC_MS = 30 s), components/AccountActions.tsx (droits Can, motifs obligatoires, verrou anti double envoi, messages d'erreur), src/routes/index.tsx.
À noter : chaque affichage du détail est audité côté serveur, et le détail est rechargé après une action (une consultation de plus dans l'audit) ; une recherche par numéro tapée par l'administrateur part dans le paramètre q de l'API (vérifier côté serveur que q n'est pas journalisé) ; pas de test du non-rechargement au focus.

## T086 — Réglages et Administrateurs du dashboard (mot de passe temporaire)
Fichiers à relire ligne par ligne : dashboard/src/modules/admins/hooks.ts (useCreateAdmin : gcTime 0, onSuccess sans la réponse), components/TemporaryPasswordDialog.tsx (en entier : affiché une seule fois, ne se ferme ni par Échap ni par clic sur le fond), components/CreateAdmin.tsx (le mot de passe ne sort de mutation.data que pour la fenêtre, reset() à la fermeture), le test « mot de passe affiché une seule fois ».
À noter : le mot de passe temporaire reste dans le presse-papiers après « Copier » (sans avertissement) et reste valable jusqu'à son changement (aucune route de changement en v1) ; clic sur le fond de la fenêtre non testé ; le message « La liste a été actualisée » s'affiche pour unknown_setting sans rechargement.

## T089 — administration de bout en bout (conforme, sur vrai serveur et vrai navigateur)
Le BACKLOG demandait « Jeff relit 🔒 connexion admin et droits » : non fait, passé sans arrêt sur ta décision. À relire en priorité : T070, T071, T074, T077, T082, T083, T086 ci-dessus.
Défauts relevés par la vérification et corrigés dans le même commit : la page Demandes (et Comptes, Audit, Référentiels, Administrateurs) gardait une carte traitée quand la dernière page disparaissait (404) ; les jetons de /api/uploads/local/ s'affichaient dans le journal du serveur (masqués maintenant) ; dashboard/.env.example donnait VITE_API_BASE_URL avec /api en trop.
À noter : après blocage, le refresh renvoie 401 token_invalid (jetons révoqués) et non 403 account_blocked ; les journaux d'accès du serveur de production (gunicorn / nginx) devront masquer eux-mêmes les jetons dans les chemins ; les photos du dashboard sont des chemins relatifs /media/… (non résolus en développement d'une autre origine) ; un SMS part vers un numéro bloqué (réponse 202 uniforme).

## T094 — modération du forum (droits)
Fichiers à relire ligne par ligne : backend/apps/admin_panel/services/rights_service.py (MODERER_CONTENU), migrations/0007_moderation.py (permission donnée au seul groupe « Administrateur complet »), views/moderation.py (require(MODERER_CONTENU) sur toutes les vues), services/moderation_service.py (moderate : transaction, verrou, motif obligatoire pour supprimer, audit ; build_rows : aucune identité de signalant ni numéro), backend/apps/forum/services/report_service.py (règle de comptage et verrou du masquage automatique), spam_filter.py.
Décisions à valider : le Validateur NE modère PAS (spec) ; un contenu signalé par 3 comptes distincts valides est masqué (3 faux comptes suffisent à masquer un contenu : un administrateur peut restaurer) ; après restauration il faut 3 NOUVEAUX signalants pour remasquer ; un commerce signalé n'est jamais masqué automatiquement ; spam refusé en 400 sans dire quelle règle ; mots interdits gérés par un petit modèle (CRUD admin) car la liste des réglages est figée ; plus de 2 liens ou le même lien deux fois = refus ; même texte en moins de 10 min = refus.

## T095 — modération du forum (dashboard)
Fichiers à relire : dashboard/src/routes/index.tsx (route gardée par peut_moderer_contenu), src/layouts/nav.ts, src/modules/forum_moderation/components/ModerationActions.tsx (actionsFor, motif obligatoire pour supprimer, verrou anti double clic), components/ReportQueue.tsx (aperçu en texte simple, numéro masqué), types.ts (aucun champ de signalant).

## T120 — Accessibilité : couleurs ajoutées (extension de D-20, à valider)
Pour atteindre le contraste 4,5:1 en thème clair, trois couleurs ont été ajoutées ou modifiées par rapport aux maquettes : rouge d'erreur `#C93E28` (au lieu de `#D1452F`, 4,26:1), fond des badges orange `#FEF3E2` avec texte `#A85A00` (4,64:1), vert du badge WhatsApp de l'Historique `#1A7A34` (4,93:1). À confirmer ou à refuser. Propositions non réalisées (hors maquette) : raccourci « parler à quelqu'un » sur l'Accueil, dictée vocale des champs libres, « Écouter » sur les textes longs restants.

## T131 — appels Jitsi (backend)
- `apps/calls/services/session_service.py` (transitions atomiques, une session active par appelant), `jitsi.py` (jeton), droit `peut_repondre_aux_appels`, absence de numéro dans flux/liste/historique, route `POST /api/calls/whatsapp/`.
- À trancher : JaaS signe en RS256 (pas HS256) — voir D-28.

## T132b — numéros pendant l'appel (D-30)
- `backend/apps/calls/services/context_service.py`, `CallContextView` (views/agent.py), 2 tests ajoutés dans `backend/tests/test_security_phone_leak.py`. Seule route qui délivre les numéros ; lecture auditée (`consultation_numero`).
- Le type « particulier / entreprise » affiché (`kind`) est à confirmer.

## T121 — points ⚠ à décider (mobile et dashboard)
- Sauvegarde Android coupée, trafic en clair interdit, HTTPS imposé en release (mobile/android, lib/core/config/env.dart).
- Retrait des permissions caméra / téléphone / localisation (release, profile, debug) : à revérifier sur un vrai APK avec `aapt2 dump permissions` (le SDK Jitsi n'a pas pu être téléchargé ici).
- Signature de release : clé de débogage pour l'instant → créer une vraie clé hors dépôt (T124).
- Une erreur serveur (5xx) lors du rafraîchissement déconnecte l'utilisateur : à décider (attendre plutôt que déconnecter ?).
- `has_diplome` côté serveur (dette) ; `geolocator` inutilisé dans pubspec ; `Retry-After` à exposer en CORS ; cookie de rafraîchissement si domaines différents.
