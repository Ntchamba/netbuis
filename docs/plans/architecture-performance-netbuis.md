# Fluidité de l'app, code natif (C/assembleur), appels système, et performance API — ce qui est réaliste

Date : 2026-10-04 (v3 — ajout de la politique de sauvegarde/migrations et de l'organisation du code Django/CI-CD, en réponse aux critiques du document de recherche)

## La question posée par le porteur de projet

Pour améliorer la fluidité, la vitesse de calcul et l'utilisation de la mémoire de l'app, le porteur de projet a demandé : peut-on faire des appels système directement depuis l'app (Android/iOS) ? Où peut-on insérer du C ou de l'assembleur dans la pile technique (couche Django côté serveur, couche mobile Flutter) ? Qu'est-ce qu'on peut utiliser en arrière-plan ("background") pour ça ? Et, en suite directe (v2) : qu'est-ce qui améliore concrètement le temps de réponse de l'API Django et l'expérience utilisateur en général ? Et, en v3 (nouveau) : le porteur de projet a demandé de compléter les manquements identifiés par la critique de `recherche-technique-ux-netbuis.md` — en particulier la politique de sauvegarde, la discipline de migration, et l'organisation du code Django/stratégie CI/CD, qui n'étaient documentées nulle part jusqu'ici.

Ce document répond honnêtement à ces questions, avec la recherche faite pour vérifier les pratiques actuelles (2026).

**Hypothèse de pile technique** (à confirmer) : backend Django (Python) + app mobile Flutter. Point de vocabulaire à clarifier avec le porteur de projet : Flutter s'écrit en **Dart**, pas en Python — "Flutter Python" n'existe pas comme combinaison standard. Si l'intention était un framework mobile en Python (Kivy, BeeWare...), c'est un choix nettement moins mature et moins performant que Flutter pour ce type d'app, et la réponse ci-dessous serait différente sur la partie mobile (via `ctypes`/Cython plutôt que du FFI Dart). Pour la suite, ce document part de l'hypothèse Flutter (Dart) + Django, la combinaison la plus standard et la plus documentée.

## 1. Peut-on faire des appels système directement depuis l'app ?

Oui, mais pas de la façon dont le terme le laisse entendre. Une app ne compose jamais un numéro de syscall à la main (`write()`, `read()`, etc. au sens Linux/POSIX) — ce niveau est entièrement géré par le système d'exploitation et le runtime (Dart VM / ART sur Android / le runtime iOS). Ce qu'une app peut réellement faire :

- **Appeler les API natives de l'OS** via les SDK officiels (Android SDK/NDK, iOS SDK) — c'est déjà ce que fait n'importe quelle fonctionnalité "système" de NetBuis (ouvrir le dialer téléphonique avec l'intent `ACTION_DIAL`, voir `decision-finale-appels.md`, en est un exemple direct).
- **Descendre jusqu'au C/C++ natif** via les mécanismes présentés en section 2, qui eux-mêmes appellent les API du système quand c'est nécessaire.

Autrement dit : NetBuis fait déjà des "appels système" dans le seul sens qui existe réellement pour une app mobile (via les Intents Android / URL schemes iOS pour l'appel téléphonique, l'accès à l'appareil photo pour les justificatifs, etc.). Il n'y a pas de niveau "plus bas" accessible ou utile à viser.

## 2. Où peut-on mettre du C — et de l'assembleur — dans la pile Django + Flutter ?

### Côté serveur (Django/Python)
Du C existe déjà massivement sous le capot : CPython lui-même est écrit en C, et des bibliothèques comme NumPy ou les moteurs de base de données (PostgreSQL) le sont aussi. On peut écrire une extension C pour Python (ou passer par Cython) pour accélérer un calcul précis — mais **NetBuis n'a, à ce stade, aucun calcul côté serveur qui le justifierait** (recherche de texte, listes de commerçants, règles de plafond d'abonnement : ce sont des opérations de base de données et de logique simple, pas des calculs numériques intensifs). Ajouter une extension C ici n'apporterait aucun gain mesurable et compliquerait le déploiement pour rien.

### Côté mobile (Flutter/Dart)
Deux mécanismes officiels permettent de descendre en C/C++ :
- **Dart FFI (Foreign Function Interface)** — Dart appelle directement une fonction C compilée (bibliothèque `.so`/`.dylib`), sans passer par un pont Android/iOS intermédiaire. C'est le mécanisme recommandé en 2026 pour intégrer une bibliothèque C existante (voir sources).
- **Platform Channels** — pour du code spécifique à une plateforme (Kotlin/Swift), qui peut lui-même appeler du C via le NDK (Android) ou directement (iOS, Objective-C/C++ est natif).

**Et l'assembleur ?** En pratique, personne n'écrit d'assembleur à la main pour une app de ce type en 2026 — et ce n'est pas un choix "trop prudent", c'est un choix techniquement juste : un compilateur C/C++ moderne (Clang, utilisé par Android NDK et iOS) génère déjà un code machine mieux optimisé qu'un développeur humain pour la quasi-totalité des cas, y compris les boucles chaudes. L'assembleur manuel ne se justifie que dans des cas extrêmement spécifiques (codecs vidéo/audio, cryptographie bas niveau) — et même là, les bibliothèques déjà utilisées par Flutter/Android/iOS (libvpx, libaom, les bibliothèques crypto du système) contiennent déjà cet assembleur optimisé, écrit et maintenu par des équipes spécialisées. **NetBuis en bénéficie automatiquement, sans avoir à en écrire une ligne.**

### Ce que NetBuis utilise déjà, sans s'en rendre compte, qui est déjà du C/C++ natif
- **Le moteur de rendu de Flutter** (Impeller, ou Skia sur les versions antérieures) est écrit en C++ — c'est ce qui rend Flutter aussi fluide qu'une app native à la base, sans rien à faire côté NetBuis.
- **SQLite** (base de données locale, utile pour la mise en cache côté mobile) est écrit en C.
- **Les décodeurs d'image** (JPEG/PNG/WebP pour les photos de boutique, de CNI, de produits) sont en C/C++ sous le capot des SDK Android/iOS.

## 3. Ce qui améliore réellement la fluidité pour une app comme NetBuis — vue d'ensemble

Le constat honnête : **les ralentissements d'une app comme NetBuis ne viendront presque jamais du calcul CPU brut** (ce pour quoi C/assembleur aide), **mais du réseau et de l'attente** (appels à l'API Django, chargement d'images, zones à connectivité faible — un sujet déjà bien identifié pour le Cameroun dans `comparatif-solutions-telecom-appels.md`). Écrire du C/assembleur n'adresserait pas ce problème. Les sections suivantes détaillent, couche par couche, ce qui l'adresse réellement : le serveur Django, le réseau mobile, le client Flutter, et (nouveau, v3) l'organisation du code et des données elles-mêmes.

## 4. Côté serveur : optimiser l'API Django

**Méthode d'abord, outils ensuite** : profiler avant d'optimiser (Django Debug Toolbar en développement, logging des requêtes SQL), pour ne jamais deviner où est le vrai ralentissement.

- **Éliminer le problème N+1 avec `select_related` / `prefetch_related`.** C'est le gain le plus net pour NetBuis : une recherche de produit qui renvoie une liste de `BusinessProfile` avec leur `Secteur`, leurs `SousCategorie` et leur `Account` associé fera naturellement beaucoup de requêtes séparées si on n'y fait pas attention (une requête par commerçant pour charger son secteur, une autre pour son compte...). `select_related` (relations ForeignKey/OneToOne — `Secteur`, `Account`) fait une jointure SQL unique ; `prefetch_related` (relations multiples — `SousCategorie`, `Product`) regroupe les requêtes. À appliquer en priorité sur l'endpoint de recherche (le cœur de l'app) et sur la liste de produits d'une zone.
- **Toujours paginer les listes.** Recherche de produits, fil du Forum, historique d'appels, liste de commerçants dans une zone : aucun de ces endpoints ne doit renvoyer "tout" d'un coup. Django REST Framework a des classes de pagination intégrées — à activer par défaut sur tous les endpoints de liste, pas seulement ceux qui semblent déjà volumineux.
- **Mettre en cache les données qui changent rarement.** La liste des `Secteur`, `CategorieService`, `TypeStructure` (voir `modele-donnees-netbuis.md`) ne change presque jamais — ce sont des candidats parfaits pour un cache (Redis, ou même le cache par vue de Django `@cache_page`) plutôt que de retaper la base de données à chaque ouverture de l'écran de création de compte business. Les résultats de recherche eux-mêmes sont plus volatils (nouveaux commerçants, mise à jour de stock) et se cachent avec plus de précaution (durée courte, invalidation au bon moment).
- **Charger les tests avant la mise à l'échelle réelle.** Mesurer le temps de réponse avant/après chaque optimisation, pas seulement en développement local — un test de charge simple suffit à valider qu'un changement aide vraiment.

## 5. Côté réseau mobile : s'adapter à une connectivité faible ou instable

Ce point rejoint directement ce qui a déjà été identifié pour le Cameroun dans `comparatif-solutions-telecom-appels.md` (2G/3G fréquent, coupures) :

- **Cache local des données stables** (secteurs, catégories, dernières recherches, commerçants déjà consultés) pour un affichage instantané même hors ligne ou en réseau très faible, avec un rafraîchissement discret en arrière-plan dès que le réseau le permet.
- **Regrouper les requêtes non urgentes** plutôt que de multiplier les petits appels réseau — chaque établissement d'une connexion radio a un coût, en latence et en batterie.
- **Reporter les synchronisations non critiques** (ex. mise à jour du solde de parrainage, statistiques de vues d'un produit) via `WorkManager`/`BGTaskScheduler` (voir section 3) plutôt que de les faire en temps réel — elles peuvent attendre une connexion Wi-Fi ou un réseau meilleur.
- **Adapter le comportement selon la qualité réseau détectée** : par exemple, charger des photos en plus basse résolution par défaut en 2G/3G, et ne précharger agressivement des images supplémentaires qu'en bon réseau.
- **Une logique de nouvelle tentative (retry) robuste** pour les requêtes échouées, plutôt que de faire simplement échouer l'action visible à l'écran — avec un message clair et non technique (cohérent avec le travail déjà fait sur l'accessibilité, voir `accessibilite-analphabetisme-netbuis.md`, principe 6 : pas de jargon).
- **Découpler l'interface du réseau** : l'appui sur un bouton doit réagir visuellement en quelques centaines de millisecondes (changement d'état, indicateur de chargement) même si la requête réseau elle-même prend plus de temps — l'utilisateur doit toujours sentir que l'app a "entendu" son geste immédiatement, même si le résultat met du temps à arriver. C'est un principe de fluidité perçue indépendant de la vitesse réelle du réseau.

## 6. Côté client Flutter : optimisations concrètes

- **`ListView.builder` (ou `SliverList`) pour toute liste** : résultats de recherche, fil du Forum, liste de commerçants — ne jamais construire tous les éléments d'un coup, charger à la demande au défilement.
- **`cached_network_image` (ou équivalent) pour toutes les photos** : photos de boutique, de produits, de profil, de CNI/diplôme côté admin — NetBuis est une app très visuelle par nature (voir la recommandation déjà actée de privilégier les photos pour l'accessibilité), donc la mise en cache d'image est un levier de fluidité direct, pas un détail.
- **Compresser et redimensionner les images avant upload** (déjà recommandé en section 3) — en plus de réduire le temps d'envoi en réseau faible, ça réduit aussi le volume de stockage côté serveur.
- **Widgets `const` et découpage des `build()`** pour limiter les reconstructions inutiles de l'interface à chaque changement d'état (pertinent pour les écrans à démo multiple déjà construits dans la maquette, type `CreationBusiness-Structure-Details.dc.html`, où plusieurs sections changent selon le type sélectionné).
- **Isolates (`compute`) pour tout calcul ponctuel lourd côté téléphone**, déjà couvert en section 3.
- **Builds réduits par architecture (`--split-per-abi`)** pour que le fichier d'installation téléchargé par l'utilisateur soit le plus léger possible — pertinent pour un public avec un forfait data limité.

## 7. Base de données : politique de sauvegarde et discipline de migration (nouveau, v3)

Ce point avait été identifié comme manquant par la critique de `recherche-technique-ux-netbuis.md` (section 2) : aucun document du projet ne traitait jusqu'ici de la sauvegarde ni de la discipline de migration de schéma, deux sujets distincts du modèle de données lui-même (déjà bien traité dans `modele-donnees-netbuis.md`).

### Politique de sauvegarde (proposition de départ, à valider avant la mise en production réelle)

- **Sauvegardes automatiques quotidiennes** de la base PostgreSQL (`pg_dump` planifié, ou la fonctionnalité de sauvegarde automatique si l'hébergeur en propose une — la plupart des hébergeurs cloud PostgreSQL le font nativement).
- **Rétention proposée : 7 sauvegardes quotidiennes + 4 hebdomadaires + 3 mensuelles** — un compromis standard entre coût de stockage et capacité à revenir loin en arrière si un problème n'est détecté que tardivement (ex. une erreur de migration qui corrompt des données silencieusement).
- **Sauvegardes stockées hors du serveur de production lui-même** (stockage objet séparé), pour survivre à une panne complète du serveur, pas seulement à une erreur applicative.
- **Un test de restauration réel, au moins une fois avant le lancement**, et périodiquement ensuite — une sauvegarde jamais testée en restauration n'est une garantie que sur le papier. C'est le piège le plus courant des politiques de sauvegarde "de façade".
- Les fichiers médias (photos de boutique, CNI, diplômes, vidéos de candidature équipe) suivent une politique séparée mais parallèle : ils sont probablement déjà sur un stockage objet (S3 ou équivalent) qui a sa propre redondance, mais la rétention/versioning de ce stockage est à vérifier explicitement, pas supposée.

### Discipline de migration de schéma

Django gère déjà nativement les migrations de schéma (`makemigrations`/`migrate`) — l'outil n'est pas le sujet, la discipline d'équipe l'est :

- **Une migration par changement de modèle, jamais de modification manuelle du schéma en production** (pas de `ALTER TABLE` tapé à la main en urgence, même pour un correctif rapide) — toute modification passe par une migration versionnée, relue comme le reste du code.
- **Les migrations sont testées sur une copie de la base de production (ou un jeu de données représentatif) avant d'être appliquées en production**, pas seulement sur une base de développement vide — une migration qui ajoute une colonne `NOT NULL` sans valeur par défaut, par exemple, échoue différemment selon qu'il y a zéro ligne ou cent mille lignes déjà en base.
- **Les migrations qui modifient une grande table en production restent une opération surveillée**, pas lancée puis oubliée — pertinent dès que `BusinessProfile`, `Product` ou `CallLog` grossissent significativement.
- Ce sujet rejoint directement le point Z nouvellement ajouté dans `modele-donnees-netbuis.md` (v16) : si le découpage administratif camerounais change (58→70 départements évoqués), ce sera une migration de données sur `Zone`, pas seulement un changement de contenu — à anticiper avec la même discipline.

## 8. Organisation du code Django et stratégie CI/CD (nouveau, v3)

Deuxième manquement identifié par la critique de `recherche-technique-ux-netbuis.md` (section 3) : aucun document ne traitait encore de l'organisation du code Django lui-même, ni d'une stratégie d'intégration/déploiement continu — normal au stade actuel (travail porté sur le produit et les maquettes), mais à poser explicitement avant que le développement ne démarre.

### Organisation en apps Django, par domaine métier

Recommandation : démarrer en **monolithe Django/DRF** (pas en microservices, voir section recommandation ci-dessous), mais structuré dès le premier commit en **apps Django séparées par domaine**, pas un seul gros dossier fourre-tout. Découpage proposé, directement aligné sur les entités déjà actées dans `modele-donnees-netbuis.md` :

- `accounts` — `Account`, authentification/OTP, candidature équipe NetBuis.
- `business` — `BusinessProfile`, `Secteur`/`SousCategorie`/`CategorieService`/`TypeStructure`, `Product`.
- `geo` — `Zone` et sa hiérarchie (nouveau, v16 de `modele-donnees-netbuis.md`), logique de visibilité sur la carte.
- `forum` — `Post`, `Comment`.
- `calls` — `CallLog`, intégration Twilio/dialer natif (voir `decision-finale-appels.md`).
- `billing` — `Subscription`, crédits d'appel, intégration Mobile Money (voir `monetisation-appels-orange-money.md`).
- `referral` — `Referral`, logique de parrainage.
- `admin_panel` — vues et permissions du dashboard admin, `AuditLog`, `PlatformSetting`, groupes RBAC (voir `dashboard-admin-netbuis.md`, v7).

Chaque app a ses propres modèles, vues, sérialiseurs et tests — ce découpage est réversible et n'empêche rien : si une partie (ex. `calls`, le plus consommateur d'appels externes Twilio) doit un jour devenir un service séparé, elle est déjà isolée proprement, ce qui rend l'extraction bien moins coûteuse que si tout était mélangé dans un seul module.

### Stratégie CI/CD (intégration et déploiement continus)

- **Tests automatiques à chaque changement de code** (au minimum : tests unitaires sur les règles métier critiques déjà actées — plafonds d'abonnement, visibilité carte, règles d'appel — et tests d'intégration sur les endpoints principaux), exécutés automatiquement avant toute fusion de code, pas seulement en local par habitude individuelle.
- **Au moins trois environnements distincts** : développement (local), test/staging (environnement de démonstration, données factices), production — jamais de test manuel directement en production.
- **Déploiement automatisé** une fois les tests passés, plutôt qu'une mise en production manuelle sujette à l'oubli d'une étape.
- **Ce sujet est à mettre en place dès les premières semaines de développement**, pas une fois l'app déjà volumineuse — c'est systématiquement plus coûteux à ajouter après coup qu'à poser dès le départ.

## Recommandation

Ne pas investir de temps d'ingénierie dans l'écriture de C ou d'assembleur pour NetBuis — ce serait un effort mal placé par rapport aux vrais goulots d'étranglement de ce type d'app (réseau, attente, pas calcul). Les gains réels viendront, dans l'ordre d'impact probable pour NetBuis : (1) éliminer les N+1 et paginer côté API Django — le socle, à faire dès le départ, pas en rattrapage ; (2) cache local + adaptation au réseau faible côté mobile — le point le plus spécifique au contexte camerounais ; (3) les optimisations Flutter classiques (listes virtualisées, cache d'image, isolates) — qui viennent presque gratuitement si on suit les patterns standards de Flutter dès le départ, sans code natif à écrire soi-même ; (4) **(nouveau, v3)** poser l'organisation du code par domaine et la discipline CI/CD/sauvegarde/migration dès les premiers commits — ce n'est pas un sujet de performance au sens strict, mais son absence coûte toujours plus cher à corriger plus tard qu'à poser dès le départ.

**Point à clarifier avec le porteur de projet** : confirmer la pile mobile réelle (Flutter/Dart, ou autre) — la mention "Flutter Python" laisse un doute qui change une partie de cette réponse.

## Sources consultées

- [Dart FFI — intégration de bibliothèques C/C++ dans Flutter](https://dev.to/vmodal_ai/flutter-ffi-tutorial-integrating-native-c-and-c-libraries-2ol9)
- [Dart FFI tutorial — calling C from Dart](https://zetcode.com/dart/ffi/)
- [How To Use Dart FFI For High-Performance Flutter Integrations](https://vibe-studio.ai/insights/how-to-use-dart-ffi-for-high-performance-flutter-integrations)
- [Flutter Background Execution — WorkManager (Android) & BGTaskScheduler (iOS)](https://medium.com/@priya.prajapati/flutters-background-work-that-survives-os-sleep-ee2397a40652)
- [Flutter WorkManager — package pub.dev](https://pub.dev/packages/workmanager)
- [Flutter WorkManager Scheduled Tasks: The Complete, Practical Guide (2026)](https://asoasis.tech/articles/2026-05-07-2054-flutter-workmanager-scheduled-tasks/)
- [How to Optimize Django REST APIs for Performance: Profiling, Caching, and Scaling (freeCodeCamp)](https://www.freecodecamp.org/news/how-to-optimize-django-rest-apis-for-performance/)
- [Django Performance Optimization: 25 Proven Tips (2026) — Inexture](https://www.inexture.com/blog/django-performance-optimization)
- [Scaling Django APIs: Reducing Database Load with Redis and Optimized Queries](https://dev.to/kabasele754/scaling-django-apis-how-i-reduced-database-load-by-80-with-redis-and-optimized-queries-g5j)
- [Mobile App Network Optimization: Best Practices (2025)](https://digitalfractal.com/mobile-app-network-optimization-best-practices-2025/)
- [Flutter Performance Optimization 2026 — make your app 10x faster](https://dev.to/techwithsam/flutter-performance-optimization-2026-make-your-app-10x-faster-best-practices-2p07)
- [Scaling a Monolithic Django Project — Without Microservices](https://itnext.io/how-to-scale-a-monolithic-django-project-6a8394c23fe8)
- [CI/CD for Mobile Applications: Complete 2026 Guide](https://www.gitnexa.com/blogs/mobile-app-cicd-pipeline-guide)
