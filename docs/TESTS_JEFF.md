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
