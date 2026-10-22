# Tests à faire par Jeff sur téléphone réel

## T046 — Recherche vocale (téléphone Android)
1. Installer l'appli, aller sur l'Accueil, toucher le bouton micro jaune.
2. Une explication « Utiliser le micro ? » s'affiche. Toucher « Continuer » : Android demande l'autorisation du micro. Accepter.
3. Le bandeau jaune « Je vous écoute... dites le nom d'un produit » apparaît sous la barre de recherche. Dire par exemple « je cherche du riz à Maroua » : le bandeau disparaît et la liste se met à jour avec les commerces trouvés.
4. Refaire en refusant l'autorisation : un message simple apparaît et l'écran de recherche écrite s'ouvre.
5. Refaire en ne disant rien pendant quelques secondes : message « Je n'ai rien compris… » et retour à la recherche écrite.
6. Vérifier que la reconnaissance comprend bien le français (avec et sans réseau, selon le téléphone) et noter le modèle du téléphone.

## T052 — Appel direct Orange / MTN (téléphone Android réel, idéalement avec 2 SIM)
Avant de commencer : installer l'appli, se connecter, choisir Maroua. Pour les essais, utiliser un commerce de démonstration dont le numéro est un numéro de test (`6 00 00 00 XX`, D-18) ou un numéro de Jeff. Noter le modèle du téléphone, la version d'Android et le nom donné à chaque SIM dans Réglages.
1. Téléphone à 2 SIM (Orange + MTN), autorisation « Téléphone » pas encore donnée : sur une carte de résultat, toucher « Appeler ». Une explication « Autoriser l'appel direct ? » s'affiche. Toucher « Continuer » : Android demande l'autorisation. Accepter. La feuille « Avec quelle ligne voulez-vous appeler ? » s'affiche avec le nom du commerce, deux gros boutons Orange et MTN, « Annuler » et le texte honnête sur le numéro. Le numéro du commerce n'apparaît NULLE PART dans l'appli.
2. Toucher « Orange » : « Appel en cours... » et « [nom] · ligne Orange » s'affichent, l'écran d'appel du téléphone s'ouvre. Vérifier dans les réglages d'appel / le journal que l'appel est parti avec la SIM Orange (et pas MTN). L'appli referme sa feuille toute seule.
3. Refaire avec « MTN » : l'appel doit partir avec la SIM MTN. Refaire une 2ᵉ fois sur le même commerce : la feuille redemande la ligne (rien n'est mémorisé).
4. Depuis la fiche d'un commerce (bouton « Appeler » de la fiche) : même feuille, même comportement.
5. Toucher « Appeler » deux fois très vite : une seule feuille, un seul appel. Dans le dashboard (ou la base), un seul appel enregistré.
6. « Annuler » : rien ne part, aucun appel enregistré.
7. Téléphone avec UNE seule SIM : « Appeler » saute la feuille et lance directement l'appel (« Appel en cours... »).
8. Téléphone avec 2 SIM dont l'une n'est ni Orange ni MTN (ex. Camtel) : choisir la ligne absente affiche « Votre téléphone n'a pas de ligne … » et propose l'autre ligne ; rien n'est enregistré tant qu'on ne touche pas « Appeler avec … ».
9. SIM renommée (Réglages > SIM : renommer en « Perso » / « Travail ») ou eSIM : la feuille Orange/MTN est remplacée par la liste des noms de SIM donnés par le système ; choisir une SIM lance l'appel avec cette SIM. Noter si l'opérateur est bien reconnu malgré le renommage.
10. Autorisation refusée : désinstaller / effacer les données, toucher « Appeler », « Continuer », REFUSER dans Android. Un avertissement « Appel par le composeur du téléphone » s'affiche (le numéro sera visible dans le composeur). Toucher « Ouvrir le composeur » : le composeur s'ouvre avec le numéro ; c'est le téléphone qui l'affiche, pas NetBuis. Refaire « Appeler » : Android ne redemande pas, l'avertissement s'affiche directement.
11. Mode avion ou pas de réseau : « Pas de connexion… » s'affiche, aucun appel ne part.
12. Faire plus d'appels que la limite de l'anti-aspiration : message « Vous avez fait beaucoup d'appels… ». Compte bloqué / propre commerce : messages simples.
13. Après un appel, vérifier : le journal d'appels du téléphone montre le numéro (normal, voir le texte honnête D-07) ; rien d'autre dans l'appli (ni Historique, ni capture d'écran de l'appli) ne montre le numéro. Aucun numéro dans `adb logcat` pendant tout le parcours (filtrer sur « netbuis » et sur les derniers chiffres du numéro).
14. Lire une fois le fichier `mobile/android/app/src/main/kotlin/cm/netbuis/netbuis/CallChannel.kt` (zone 🔒) : aucun journal, aucun stockage du numéro.

## T054 — WhatsApp et « ça a abouti ? » (téléphone Android réel)
Avant de commencer : installer l'appli, se connecter, choisir Maroua. Utiliser un commerce de démonstration (numéro de test `6 00 00 00 XX`, D-18) ou un numéro de Jeff qui a WhatsApp. Noter le modèle du téléphone et la version d'Android.
1. Sur une carte de résultat (Accueil et Recherche), le bouton « WhatsApp » est à côté d'« Appeler ». Même chose sur la fiche du commerce. Sur un commerce dont WhatsApp est coupé, le bouton est grisé avec « Non disponible ».
2. WhatsApp installé : toucher « WhatsApp ». Une feuille « Ouverture de WhatsApp... » passe très vite, puis WhatsApp s'ouvre directement sur la conversation avec le commerce, message pré-rempli. Vérifier que NetBuis n'affiche NULLE PART le numéro ni le lien (le numéro n'apparaît que dans WhatsApp lui-même). Revenir dans NetBuis : rien d'autre à faire.
3. Toucher « WhatsApp » deux fois très vite : une seule ouverture, une seule ligne dans le journal d'appels côté base (type `whatsapp`).
4. WhatsApp Business seul installé (sans WhatsApp classique) : le lien s'ouvre dans WhatsApp Business.
5. WhatsApp désinstallé : toucher « WhatsApp ». Message « WhatsApp n'est pas installé sur ce téléphone. » avec le bouton « Ce commerce n'a pas WhatsApp » et « Fermer ». Aucun navigateur ne s'ouvre. Toucher « Ce commerce n'a pas WhatsApp » : « Merci, c'est noté. ». Refaire avec 3 comptes différents : WhatsApp doit passer à « Non disponible » pour ce commerce (voir la base / le dashboard).
6. Mode avion : « Pas de connexion… » ; aucun lien reçu, pas de bouton de signalement.
7. Dépasser la limite de contacts de l'anti-aspiration : « Vous avez fait beaucoup de contacts… ». Propre commerce : message simple.
8. Après un APPEL réussi (T052), revenir dans NetBuis depuis l'écran d'appel : une petite feuille « Votre appel à … a-t-il abouti ? » propose 3 gros boutons : Abouti, Pas de réponse, Mauvais numéro. Toucher l'un d'eux : « Merci pour votre réponse. » et la ligne correspondante du journal d'appels côté base a le bon résultat. Refaire en changeant de réponse : le dernier choix est gardé.
9. Même feuille : « Plus tard », ou toucher à côté, ou le bouton Retour d'Android la ferme sans rien envoyer. Elle ne doit jamais bloquer l'appli. Toucher deux fois très vite sur une réponse : un seul envoi.
10. Annuler avant l'appel, ou appel refusé (limite, compte bloqué) : la feuille « ça a abouti ? » n'apparaît pas. Pas de feuille non plus après une ouverture de WhatsApp.
11. Historique de mes appels : une ligne WhatsApp garde le bouton « Rappeler » (appel, feuille Orange / MTN) et a un second bouton WhatsApp qui ouvre WhatsApp.
12. Dans `adb logcat` pendant tout le parcours, filtrer sur « netbuis », « wa.me » et les derniers chiffres du numéro : rien. Lire une fois `mobile/android/app/src/main/kotlin/cm/netbuis/netbuis/CallChannel.kt` (méthode `openWhatsapp`, zone 🔒) : seul `https://wa.me/…` est accepté, ouvert uniquement dans WhatsApp / WhatsApp Business, aucun journal, aucun stockage du lien.

## T091 — Publier et Mes publications (téléphone Android réel, compte business ACTIF)
Avant de commencer : installer l'appli, se connecter avec un compte dont le commerce est validé (actif), brancher l'appli sur le vrai serveur. Noter le modèle du téléphone et la version d'Android.
1. Profil > bloc COMPTE BUSINESS : sous « Mes produits », la ligne « Mes publications → » s'ouvre sur la liste (date « Il y a 2h », « n commentaires », étiquette « Masquée » pour une publication masquée par la modération).
2. « Publier » > la zone en tirets : la feuille propose « Prendre une photo », « Choisir une photo dans la galerie », « Filmer une vidéo », « Choisir une vidéo dans la galerie ». Tester les 4 : l'appareil photo et la caméra s'ouvrent (autorisation demandée la première fois), la galerie aussi. Après la photo, l'aperçu apparaît dans la zone ; après la vidéo, « Vidéo choisie ».
3. Vidéo : filmer plus de 30 secondes (la caméra s'arrête à 30 s). Choisir en galerie une vidéo de plus de 30 Mo : message « trop gros », rien n'est envoyé. Choisir une vidéo qui n'est PAS en MP4 (ex. .mov, .3gp, .webm) : noter si le téléphone la convertit ou si l'appli la refuse (« Ce fichier est refusé »).
4. Photo de plus de 5 Mo (galerie, photo non réduite) : l'appli la réduit (1024 px) ; vérifier que l'envoi passe. Un GIF ou un PDF choisi en galerie : message « Ce fichier est refusé ».
5. Écrire une légende : le compteur « n/500 » monte ; à 501 il devient rouge, le message « 500 caractères au plus » s'affiche et « Publier » est grisé.
6. « Associer un produit » : la liste montre MES produits (pas ceux des autres) ; choisir un produit, puis « Aucun produit » pour l'enlever. Publier avec un produit : l'étiquette du produit apparaît sur la publication dans « Mes publications ».
7. « Publier » : une barre de progression et « Envoi du fichier en cours... » puis « Publication en cours... » ; le bouton est grisé pendant l'envoi (toucher plusieurs fois très vite : une seule publication). Retour sur « Mes publications » avec « Publication envoyée. » et la nouvelle publication en haut.
8. Mode avion avant de toucher « Publier » : après l'échec, « Pas de connexion… Rien n'a été publié » et « Hors connexion » avec « Réessayer » ; « Publier » reste grisé. Couper le mode avion, toucher « Réessayer » : le bouton redevient actif et la publication passe. Dans la base : aucune publication créée par l'essai raté.
9. Publier 5 fois de suite sur le même compte (compte sans abonnement) : à la 6ᵉ, message « maximum de 5 publications actives » avec le bouton « Voir mes publications » (pas de paiement proposé). Supprimer une publication (poubelle > « Supprimer ») : on peut de nouveau publier. Dépasser 5 publications dans la même journée : « limite de 5 publications par jour. Réessayez demain. »
10. Suppression : « Annuler » ne supprime rien ; « Supprimer » retire la publication de la liste et du fil Forum (suppression douce côté serveur).
11. Compte business en attente ou rejeté : « Mes publications » et « Publier » affichent « En attente de validation » (ou « Compte business non actif »), sans formulaire.
12. Dans `adb logcat` pendant le parcours : aucune adresse d'envoi signée (`upload_url`) ni jeton ne doit apparaître.

## T092 — Forum et page d'une publication (téléphone Android réel, vrai serveur, 2 comptes)
Avant de commencer : installer l'appli sur le vrai serveur, avoir au moins une vingtaine de publications de démonstration (`seed_demo`) dans la ville choisie et quelques-unes ailleurs. Se connecter avec un compte ordinaire (A), et avoir un second compte (B) pour le cas « bloqué ». Noter le modèle du téléphone et la version d'Android.
1. Onglet Forum : titre « Forum », « Publications des commerçants » ; chaque carte montre initiales (ou photo) du commerce, nom, « Zone · Il y a 2h », la photo, la légende, l'étiquette du produit si elle existe, « n commentaires · écrire un commentaire ». Aucun numéro de téléphone, aucune étiquette « abonné ».
2. Ville choisie = Maroua : seules les publications de Maroua et de ses quartiers apparaissent. Changer de ville dans Profil, revenir au Forum : le fil change. Une ville sans publication : « Aucune publication dans votre zone ».
3. Faire défiler jusqu'en bas : les publications suivantes se chargent toutes seules (petit cercle en bas). Tirer vers le bas depuis le haut : le fil se rafraîchit.
4. Photos : elles se chargent quand la carte arrive à l'écran (pas toutes d'un coup). Suivre la consommation de données : rien de lourd ne part tant qu'on ne défile pas.
5. Une publication VIDÉO : sur la carte, un bouton « Voir la vidéo », la vidéo ne se lance JAMAIS toute seule (ni sur la carte ni sur la page). Toucher le bouton : la vidéo s'ouvre dans l'application vidéo/navigateur du téléphone. Revenir dans NetBuis : tout est resté en place. Noter si le téléphone sait lire le MP4 envoyé.
6. Toucher la photo ou « n commentaires · écrire un commentaire » : page de la publication (commerce, photo, légende, produit, « Commentaires · n », les commentaires du plus ancien au plus récent, champ « Écrire un commentaire... » en bas). Le bouton « Forum » en haut et le retour d'Android ramènent au fil au même endroit.
7. Écrire un commentaire : compteur « n/300 », impossible de dépasser 300 caractères (coller un long texte : il est coupé à 300). « Envoyer » grisé tant que le champ est vide. Envoyer : le commentaire apparaît tout de suite en bas (« Envoi en cours... »), champ et bouton grisés, puis « Il y a 1 min » ; « Commentaires · n » augmente ; retour au fil : le nombre de commentaires de la carte est à jour. Toucher « Envoyer » très vite deux fois : un seul commentaire côté base.
8. Écrire un texte avec `<b>gras</b>`, `**x**`, un lien https://… et des emojis, en légende (via Publier) et en commentaire : tout s'affiche tel quel, rien n'est interprété ni cliquable.
9. Envoyer plus de 10 commentaires en 10 minutes avec le même compte : le 11ᵉ disparaît de la liste, message « Vous avez écrit trop de commentaires. Patientez… », et le texte revient dans le champ. Bloquer le compte A depuis le dashboard puis envoyer un commentaire : message « Votre compte est bloqué… », le commentaire est retiré.
10. Mode avion pendant que le commentaire s'envoie, ou avant : le commentaire est retiré, « Pas de connexion. Votre commentaire n'a pas été envoyé. », texte conservé ; ensuite « Hors connexion : vous ne pouvez pas commenter pour le moment. » et le champ est grisé. Couper le mode avion puis rouvrir la page : le champ redevient actif.
11. Mode avion puis ouvrir l'onglet Forum : si le fil a déjà été vu sur ce téléphone, il s'affiche avec « Hors connexion : dernières publications enregistrées. » ; sinon « Pas de connexion… » avec « Réessayer ». Se déconnecter puis se reconnecter en mode avion : le dernier fil a été effacé à la déconnexion.
12. Commentaires nombreux (plus de 20 sur une publication) : la suite se charge en fin de liste.
13. Compte business actif : le bouton « + » (en bas à droite du Forum) ouvre « Nouvelle publication » ; il n'existe pas pour un compte sans commerce actif.
14. Dans `adb logcat` pendant le parcours : aucune adresse signée ni jeton, aucun numéro.

## T100 — Réglages : langue, thème, textes légaux, lecture à voix haute (téléphone Android réel)
Noter le modèle du téléphone et la version d'Android. Faire le test deux fois pour la voix : une fois avec une voix française installée (Réglages Android > Synthèse vocale > Google > Français), une fois sans.
1. Profil > « Réglages » : l'écran propose Langue (Français, English), Thème (Clair, Sombre, Automatique), puis À propos, Mentions légales, Conditions d'utilisation, Politique de confidentialité.
2. Choisir « English » : tout passe tout de suite en anglais (Réglages, puis retour sur Profil, Accueil, Carte, Forum, Historique, Connexion après déconnexion). Repérer tout texte resté en français et le noter.
3. Fermer complètement l'appli (la retirer de la liste des applications récentes) et la rouvrir : elle redémarre en anglais, sans éclair de français. Rechoisir « Français » : idem après redémarrage. Premier lancement après une installation neuve : français.
4. Thème : « Sombre » et « Clair » s'appliquent tout de suite et restent après redémarrage. « Automatique » : basculer le mode sombre du téléphone (volet rapide) pendant que NetBuis est ouverte : l'appli suit.
5. « À propos » : nom NetBuis et numéro de version (provisoire, à remplacer) ; « Mentions légales », « Conditions d'utilisation », « Politique de confidentialité » : texte provisoire marqué « À REMPLACER ». Ces deux dernières pages s'ouvrent aussi depuis les liens en bas de l'écran de Connexion (sans être connecté) ; le retour revient à la Connexion.
6. Voix française installée : sur une page légale, le bouton « Écouter » est visible ; il lit le texte à voix haute ; « Arrêter » coupe ; quitter l'écran coupe ; changer la langue de l'appli coupe.
7. Sans voix française (la désinstaller ou prendre un téléphone sans) : le bouton « Écouter » n'apparaît nulle part (aucun bouton muet).
8. Mode avion, stockage presque plein : les réglages restent utilisables.

## T101 — Aide et support (à tester sur téléphone)
1. Ouvrir l'écran Aide (accessible depuis Profil quand T102 sera faite ; en attendant, route `/help`). Trois thèmes : Appels, Compte business, Sécurité. Aucune question sur les crédits ni le parrainage ne doit apparaître. Une seule question ouverte à la fois.
2. « Pourquoi je ne vois pas le numéro du commerçant ? » : la réponse doit être exactement le texte de D-07 (NetBuis n'affiche jamais le numéro… iPhone…).
3. « Comment créer mon compte business ? » cite les 5 types : Commerce, Entreprise, Structure, Particulier vendeur, Prestataire de service.
4. Sans coordonnées fournies (`À REMPLACER`) : WhatsApp, téléphone, e-mail et « Signaler un problème » sont grisés, avec « Coordonnées du support à venir » ; toucher ne fait rien.
5. Quand Jeff fournira les coordonnées (compiler avec `--dart-define=SUPPORT_WHATSAPP=<numéro international> --dart-define=SUPPORT_PHONE=<numéro> --dart-define=SUPPORT_EMAIL=<adresse>`) : « Discuter sur WhatsApp » et « Signaler un problème ou un compte suspect » ouvrent directement WhatsApp (jamais le navigateur) sur la conversation du support ; le signalement arrive avec le message pré-rempli. « Appeler » ouvre le composeur avec le numéro du support ; « Envoyer un e-mail » ouvre la messagerie. Sans WhatsApp installé : message « WhatsApp n'est pas installé ».
6. Voix : avec une voix française, « Écouter » apparaît sous la réponse ouverte et lit la réponse ; fermer la question ou changer d'écran coupe. Passer l'appli en English : le bouton n'apparaît que si le téléphone a une voix anglaise (sinon aucun bouton). Installer une voix (réglages du téléphone) puis revenir dans NetBuis : le bouton apparaît sans redémarrer l'appli.

## T102 — Profil : déconnexion et suppression du compte (téléphone Android réel, serveur branché)
1. Profil : en haut le nom et « +237 6•• •• •• 12 — numéro vérifié » (jamais le numéro entier). Tant que les crédits sont désactivés, aucun bloc « Appel gratuit du jour » ni « Solde de crédits ». Plus bas : Langue (avec « Français » / « English »), Thème (avec le choix en cours), Aide & support, Se déconnecter, puis Supprimer mon compte. Langue et Thème ouvrent les Réglages ; Aide & support ouvre l'aide.
2. Compte sans commerce : l'encart « Vous vendez un produit ou un service ? » est là. Compte avec commerce : l'état (En attente de validation, Actif, ou Rejeté avec le motif) et les lignes Mes produits / Mes publications. « Modifier ma boutique » et « Corriger » n'existent pas encore (tâche T102b).
3. Se déconnecter : retour à l'écran de connexion. Fermer et rouvrir l'appli : on reste à la connexion (jetons effacés). Se reconnecter : on retrouve son profil.
4. Supprimer mon compte, annuler à la première fenêtre, puis à la seconde : rien ne change, on reste connecté.
5. Supprimer mon compte, confirmer deux fois, avec un compte de test : retour à la connexion. Fermer et rouvrir l'appli : toujours la connexion. Se reconnecter avec le même numéro : message « Contactez le support » (compte supprimé, D-09). Vérifier côté dashboard/admin que le compte est marqué supprimé et que son commerce n'apparaît plus dans la recherche.
6. Mode avion puis confirmer la suppression : la seconde fenêtre reste ouverte avec « Pas de connexion. Votre compte n'a pas été supprimé. Réessayez. » ; fermer la fenêtre : toujours connecté. Couper le mode avion puis réessayer : la suppression réussit.
