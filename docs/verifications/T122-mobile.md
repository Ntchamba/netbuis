# T122 — Performances mobiles (mesures faisables sans téléphone)

Aucun appareil ni émulateur n'était disponible : tout ce qui suit est lu dans le code ou mesuré
par des tests de widgets sur la machine de développement. Le ressenti réel (démarrage, fluidité,
taille de l'APK) est à mesurer par Jeff : voir la section T122 de `docs/TESTS_JEFF.md`.

| Liste / écran | Constat | Correction | Preuve |
|---|---|---|---|
| Résultats de recherche (`results_screen.dart`) | `ListView.separated` (paresseux), cartes `ResultCard` sans image, pagination par page (`loadMore`), pas de calcul lourd dans `build` | aucune nécessaire | `test/core/perf/list_performance_test.dart` : 500 éléments, moins de 15 cartes construites, y compris après 20 défilements |
| Accueil (`home_screen.dart`) | idem ; la bande « Très demandé » est le premier élément de la liste | aucune | lecture du code |
| Liste des commerces d'un quartier (`area_screen.dart`) | `ListView.separated` paresseux + `loadMore` | aucune | lecture du code |
| Historique d'appels (`call_history_screen.dart`) | `ListView.separated` paresseux + `loadMore` | aucune | lecture du code |
| Fil du forum (`forum_screen.dart`) | `ListView.builder` paresseux, `DateTime.now()` pris une fois par construction de liste (pas par carte), images avec `cacheWidth` 120/780 et repli pendant le chargement | aucune | lecture du code |
| Défilement et en-têtes | le bandeau « hors connexion » est hors de la liste (Column) | aucune | test : 0 reconstruction du bandeau pendant 10 glissements ; moins de 40 reconstructions de cartes |
| Galerie de photos de la fiche commerce (`photo_gallery.dart`) | `Image.network` sans limite de décodage ni indicateur de chargement : une photo d'appareil était décodée en pleine taille | `cacheWidth: 780` et rectangle de la couleur de bordure pendant le chargement (aspect inchangé une fois chargé) | `flutter test` complet vert ; `flutter analyze` sans erreur |
| Autres images (`Image.file` : récapitulatif, champ photo, publication, sélecteur offre ; `Image.network` du forum) | toutes avec `cacheWidth` (112, 168, 780, 120) | aucune | recherche `Image.` dans `lib/` |
| Écran de résultats, 200 éléments | construction mesurée | aucune | test chronométré : 80 à 107 ms sur la machine de test, seuil du test 3 000 ms (généreux : il ne vise que les régressions grossières, pas le téléphone) |
| Fuites : `ScrollController`, `TextEditingController`, `FocusNode` | script de recherche : chaque contrôleur créé dans `lib/` est libéré par `dispose()` dans son fichier | aucune | sortie vide du script (aucun « NO DISPOSE ») |
| Fuites : minuteur et flux de l'appel (`call_controller.dart`) | `_ticker`, `_poller`, `_watch`, `_jitsiEvents` annulés par `_stopWatching()`, appelé à la fin d'appel, au raccrochage et dans `ref.onDispose` | aucune | lecture du code |
| Fuites : recherche et suggestions | minuteurs d'antirebond et de délai annulés dans `ref.onDispose` ; chaque frappe annule le précédent | aucune | lecture du code |
| Fuites : saisie du code SMS, invitation | `Timer` et abonnement SMS annulés dans `dispose()` | aucune | lecture du code |
| Démarrage à froid | avant le premier écran : une seule lecture des réglages (`SharedSettingsStore().load()`), puis chargement du fichier de langue (65 Ko fr, 60 Ko en) décodé sur le fil principal par choix (voir `l10n.dart`). La restauration de session part après le premier affichage (`microtask`). Aucun appel réseau avant l'écran de lancement | aucune : les deux seules attentes sont courtes et dépendent l'une de l'autre dans le cadre de `MaterialApp` ; les paralléliser gagnerait quelques millisecondes pour un risque sur les tests | lecture de `main.dart`, `app.dart`, `auth_controller.dart` |
| Assets | `assets/` pèse 144 Ko (deux fichiers de langue) ; aucune image ni police embarquée (polices du système) | aucune | `du -sh mobile/assets` |

## À noter
- Pas de mesure de fluidité (images par seconde), de démarrage à froid ni de taille d'APK : impossible ici.
- `my_posts_screen.dart` : l'image réseau n'a pas d'indicateur de chargement (repli seulement en cas d'erreur). Non modifié : l'écran n'est pas en liste longue et l'aspect resterait à valider.
- Le SDK Jitsi alourdit l'APK : taille à relever (TESTS_JEFF.md).
