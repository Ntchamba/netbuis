# Recette manuelle sur téléphone (T124)

À faire par Jeff avant toute mise en service. Les essais automatiques (≈ 4 800 tests, parcours de bout en bout, mesure de l'appel) sont verts mais **ne remplacent pas** un essai sur vrai téléphone : audio, micro, réseau mobile, Jitsi réel, taille et fluidité ne sont pas testables sans appareil. Rien n'est déployé à ce jour.

Les procédures détaillées de chaque fonction sont dans `docs/TESTS_JEFF.md`. **Obsolètes (appel par téléphone supprimé le 2026-10-22, D-25)** : les sections « T052 — Appel direct Orange / MTN » et « T054 — « ça a abouti ? » » — les remplacer par la section T133.

## 0. Avant de commencer
1. Un serveur NetBuis accessible en `https` avec sa base (voir `docs/deployment/DEPLOYMENT.md`) et un serveur Jitsi configuré (`docs/deployment/JITSI.md`, décision D-28 à prendre).
2. Un APK : `cd mobile && flutter build apk --release --dart-define=API_URL=https://VOTRE-SERVEUR/api` (SDK Android requis ; signature de débogage tant qu'aucune vraie clé n'existe). Noter la **taille de l'APK**.
3. Deux comptes de l'équipe (rôle Validateur ou Administrateur complet), un compte client, un compte commerçant avec un commerce actif. Un téléphone modeste de préférence.

## 1. Accès
- Première ouverture : écrans de découverte, numéro, code SMS reçu, nom. Mauvais code refusé.
- Fermer / rouvrir : session conservée. Déconnexion puis reconnexion.

## 2. Recherche
- Écrite : produit, **nom d'un commerce** (casse, accents, petite faute), sans résultat.
- Vocale (micro autorisé) : phrase dite, résultats. Hors connexion : bandeau, pas de plantage.
- Fiche d'un commerce : photos, quartier, abonné d'abord. **Aucun numéro affiché.**

## 3. Appel à l'équipe (le point le plus important)
1. Deux membres de l'équipe connectés au tableau de bord, bouton **Disponible**, son autorisé.
2. Sur le téléphone : fiche d'un commerce → **Appeler** → autoriser le micro → « Appel en cours ».
3. Mesurer : la fenêtre sonne sur le tableau de bord **en moins d'une seconde** après l'appui (chronomètre vidéo conseillé). Noter si > 1 s.
4. **Répondre** sur un tableau de bord : l'autre fenêtre se ferme. On s'entend dans les deux sens. **Voir la fiche** : nom du commerce, numéro du commerce et numéro de l'appelant.
5. Raccrocher des deux côtés, puis vérifier que l'historique de l'appel apparaît dans l'application.
6. Annuler avant réponse. Laisser sonner 30 s (« Personne n'a répondu »). Tous indisponibles : « Personne n'est disponible ».
7. Couper le réseau pendant l'appel puis le rétablir.

## 4. WhatsApp
- Bouton WhatsApp d'une fiche : WhatsApp s'ouvre sur le bon numéro ; commerce sans WhatsApp : bouton grisé.

## 5. Commerce
- Créer un commerce (boutique, puis prestataire avec pièce d'identité) : « En attente de validation ».
- Sur le tableau de bord : voir la demande, ouvrir la pièce, valider ; le commerce devient visible dans la recherche. Refuser avec motif : le commerçant le lit.
- Modifier ma boutique : changer le nom avertit d'une nouvelle validation.

## 6. Forum, tendances, carte
- Lire, publier (commerce actif), commenter, signaler ; la modération masque / restaure.
- Carte : ville → quartier → commerces. « Très demandé près de chez vous ».

## 7. Compte et réglages
- Langue FR/EN, thème clair/sombre, textes légaux, aide et support (coordonnées réelles à fournir), suppression du compte (jetons et données locales effacés).

## 8. Tableau de bord
- Droits : un Validateur ne voit pas Réglages / Administrateurs ; l'Administrateur complet voit tout.
- Blocage d'un compte (motif obligatoire) : son téléphone est déconnecté. Audit : les actions apparaissent. Export des comptes : numéros masqués.

## 9. Performances et taille (à noter)
- Démarrage à froid (secondes), fluidité du défilement des résultats et du forum, taille de l'APK, consommation de données pendant 5 minutes d'appel.

## 9bis. Version web (PWA)
- Ouvrir l'adresse Railway de la PWA sur un téléphone : l'écran de lancement s'affiche ; connexion par SMS et recherche fonctionnent.
- Android (Chrome) : « Installer l'application » → l'icône NetBuis (loupe orange) apparaît ; ouverte, l'application est plein écran, sans barre d'adresse. iPhone (Safari) : Partager → « Sur l'écran d'accueil ».
- Mode avion après une première ouverture : rouvrir l'application installée → l'écran de lancement et les écrans déjà visités s'affichent (les données demandent le réseau).
- Appeler l'équipe et WhatsApp : message « n'est pas disponible dans la version web, utilisez l'application Android » (pas d'erreur, pas de plantage). Partage depuis l'accueil : message d'erreur simple.
- Photos (création de commerce, forum) : choisir une photo dans la galerie, la voir en aperçu, envoyer.
- Noter : durée du premier chargement en 3G/4G, et toute lettre ou icône mal affichée.

## 10. Rapport
Pour chaque point : OK / pas OK + une phrase. Joindre la vidéo de l'appel (point 3). Toute ligne « pas OK » devient une tâche dans `docs/BACKLOG.md`.
