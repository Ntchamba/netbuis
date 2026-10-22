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
