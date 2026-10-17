# Recherche technique & UX — synthèse par thème, avec critique de NetBuis

Date : 2026-10-04 (v2 — chaque critique de la v1 a été traitée et documentée dans le document cible correspondant ; nouvelle recherche cartographique approfondie)

## Ce qui a été complété depuis la v1

Le porteur de projet a demandé de compléter systématiquement les six critiques soulevées en v1. C'est fait : chaque section ci-dessous garde sa synthèse et sa critique d'origine, mais porte désormais une ligne "**Suivi (v2)**" indiquant où la décision a été effectivement actée. Résumé :

1. Recherche intelligente → décision actée dans `modele-donnees-netbuis.md` est **toujours en attente d'un document dédié au mécanisme de recherche** (voir suivi détaillé) — c'est la seule des six critiques qui reste une recommandation à trancher plutôt qu'une décision déjà actée ailleurs, faute d'un document "recherche/API" dédié à ce jour.
2. Bases de données (sauvegarde + migrations) → actée dans `architecture-performance-netbuis.md` (v3), nouvelle section 7.
3. Architecture Django/CI-CD → actée dans `architecture-performance-netbuis.md` (v3), nouvelle section 8.
4. Administration des comptes (RBAC) → actée dans `dashboard-admin-netbuis.md` (v7), points I et J désormais résolus.
5. Psychologie UX → confirmée comme cohérente avec l'existant, pas de nouveau document nécessaire (voir suivi).
6. Cartographie du Cameroun → actée dans `modele-donnees-netbuis.md` (v16, hiérarchie complète de `Zone` + règle de visibilité sur la carte) et dans `Carte.dc.html` (retouchée), avec une recherche complémentaire ci-dessous (communes/arrondissements précisés, couverture Google Maps vérifiée).

---

## 1. Recherche intelligente et flexible (tolérante aux fautes, aux mots mal découpés)

### Synthèse
Pour du texte en français (avec accents) sur une base PostgreSQL, l'outil le plus adapté est l'extension **`pg_trgm`** (trigrammes — compare des groupes de 3 caractères entre le mot tapé et les mots en base) combinée à l'extension **`unaccent`** (normalise les accents : "café" et "cafe" deviennent équivalents). L'approche concrète et déjà documentée :
1. Activer les extensions `pg_trgm` et `unaccent`.
2. Créer une colonne "normalisée" (minuscules, sans accents) sur chaque champ cherchable, avec un index GIN trigramme dessus.
3. Classer les résultats par pertinence décroissante : correspondance exacte → le mot tapé est un préfixe → le mot tapé correspond à un mot entier dans le texte → correspondance floue (trigrammes) en dernier recours.

**Limites honnêtes à connaître** : `pg_trgm` tolère bien les fautes de frappe et les variations d'accent, mais ne fait pas de "stemming" (il ne sait pas que "chercher" et "recherche" sont liés) — pour ça il faudrait la recherche plein texte de PostgreSQL (`tsvector`/`tsquery`) en complément, pas en remplacement. Pour des mots **découpés en plusieurs morceaux** (ex. l'utilisateur tape "riz" et "blanc" séparément, ou dans le désordre), c'est la recherche plein texte (qui raisonne par mots, pas par chaîne continue) qui aide davantage que les trigrammes seuls — les deux techniques sont complémentaires, pas interchangeables.

### Critique appliquée à NetBuis
C'est une décision qui **n'est pas encore prise** dans `modele-donnees-netbuis.md` — la maquette montre une barre de recherche (`Main.dc.html`, avec recherche vocale ajoutée récemment) mais le mécanisme de recherche côté serveur n'est documenté nulle part. C'est un point à trancher avant le développement, pas après : la façon dont NetBuis construit sa recherche va directement déterminer si elle tient la promesse centrale du projet ("même si l'utilisateur fait des fautes, la recherche doit être optimale"). **Recommandation concrète** : combiner trigrammes (pour les fautes de frappe/accents) et recherche plein texte PostgreSQL (pour les mots dans le désordre ou découpés), sur les champs `nom affiché`, `description_activite`, et les libellés de `SousCategorie`/`CategorieService`/`structure_type` — sans dépendre d'Elasticsearch au démarrage (une dépendance supplémentaire à opérer, alors que PostgreSQL seul couvre déjà l'essentiel pour le volume de données attendu au lancement).

**Suivi (v2)** : le porteur de projet a confirmé vouloir cette combinaison (trigrammes + recherche plein texte PostgreSQL sur le nom affiché et les champs associés) comme décision retenue, pas seulement comme recommandation. **Cette confirmation n'a cependant pas encore de document cible propre** : `modele-donnees-netbuis.md` documente les champs texte eux-mêmes (`nom affiché`, `description_activite`...) mais pas le mécanisme de recherche serveur qui les exploite. **Reste à faire, en dehors du périmètre des maquettes visuelles** : créer (ou compléter `architecture-performance-netbuis.md`) avec le détail technique acté — extensions à activer, colonne normalisée, index GIN, ordre de pertinence — au moment où le développement du backend commence réellement. Ce n'est pas bloquant pour la suite des maquettes.

---

## 2. Bases de données : comment bien les gérer

### Synthèse
Les points qui reviennent systématiquement dans les guides de bonnes pratiques PostgreSQL en production : indexer en fonction des requêtes réellement faites (pas par anticipation vague — auditer les scans séquentiels fréquents), utiliser un pool de connexions (PgBouncer) plutôt que de laisser l'app ouvrir une connexion par requête, surveiller la purge automatique (`autovacuum`) sur les tables qui changent souvent, et activer le suivi des requêtes lentes (`pg_stat_statements`) dès le début plutôt qu'en pompier une fois un problème constaté. Pour les apps de type marketplace avec plusieurs types de comptes (ce qui est le cas de NetBuis avec ses 5 `type_compte`), le choix structurant est généralement de garder un schéma unique partagé (pas une base par type de compte) avec des colonnes nullables selon le type — exactement l'approche déjà suivie dans `modele-donnees-netbuis.md` pour `BusinessProfile` (un seul modèle, des champs comme `forme_juridique` ou `structure_type` qui ne s'appliquent que selon `type_compte`).

### Critique appliquée à NetBuis
Le modèle de données déjà construit est globalement sain pour ce stade (entités claires, relations explicites, un seul schéma partagé plutôt que des tables dupliquées par type de compte). Ce qui manquait encore, à ajouter avant la mise en production réelle (pas urgent pour la maquette, mais à ne pas oublier) :
- Les index trigrammes/plein texte de la section 1, sur les bons champs.
- Une politique de sauvegarde (fréquence, rétention) — jamais mentionnée dans aucun document du projet jusqu'ici.
- Une stratégie de migration de schéma documentée (Django gère ça nativement avec ses migrations, mais la discipline — une migration par changement, jamais de modification manuelle en production — doit être actée en équipe).

**Suivi (v2)** : ~~résolu~~ — `architecture-performance-netbuis.md` (v3), nouvelle section 7, documente une politique de sauvegarde concrète (quotidienne, rétention 7+4+3, stockage séparé, test de restauration obligatoire avant lancement) et la discipline de migration (une migration par changement, jamais de modification manuelle en production, test sur une base représentative avant d'appliquer en production).

---

## 3. Architecture Django et méthodes d'ingénierie courantes sur le marché

### Synthèse
Pour une app de la taille de NetBuis à son lancement, la recommandation qui revient systématiquement est de **démarrer en monolithe Django/DRF**, pas en microservices — les microservices ajoutent une charge opérationnelle réelle (plusieurs services à déployer, surveiller, faire communiquer) qui ne se justifie qu'à partir d'une échelle ou d'une taille d'équipe que NetBuis n'a pas encore. Un monolithe bien structuré (apps Django séparées par domaine : comptes, business, forum, appels...) peut être découpé plus tard si le besoin apparaît réellement — c'est un chemin réversible, l'inverse (partir en microservices puis regretter) coûte beaucoup plus cher à corriger. Côté méthode, les pratiques standards du marché pour ce type de produit : intégration continue (tests automatiques à chaque changement de code), déploiement automatisé, et des environnements de test distincts de la production — à mettre en place dès les premières semaines de développement, pas après coup.

### Critique appliquée à NetBuis
Aucun document du projet ne mentionne encore l'organisation du code Django lui-même (apps, découpage) ni une stratégie de CI/CD — c'est normal à ce stade (le travail jusqu'ici a porté sur le produit et les maquettes, pas sur le code), mais c'est un point à poser explicitement avant que le développement ne démarre, pour éviter qu'un monolithe Django parte "en vrac" sans découpage par domaine dès le premier commit.

**Suivi (v2)** : ~~résolu~~ — `architecture-performance-netbuis.md` (v3), nouvelle section 8, propose un découpage concret en 8 apps Django alignées sur les entités déjà actées (`accounts`, `business`, `geo`, `forum`, `calls`, `billing`, `referral`, `admin_panel`) et une stratégie CI/CD de départ (tests automatiques, trois environnements, déploiement automatisé).

---

## 4. Gestion et administration des comptes utilisateurs

### Synthèse
Pour un marketplace avec des vendeurs/prestataires à vérifier (exactement le cas de NetBuis), le vocabulaire standard du secteur est **KYC** (Know Your Customer — vérifier l'identité d'une personne, ce que NetBuis fait déjà avec la CNI des prestataires) et **KYB** (Know Your Business — vérifier une entreprise, pertinent pour le type `entreprise` avec sa forme juridique/RCCM). Côté administration, le pattern standard pour un panneau d'admin avec plusieurs niveaux de droits est le **RBAC** (Role-Based Access Control) : des rôles définis (ex. modérateur, validateur de comptes, administrateur complet) avec des permissions précises par rôle, plutôt qu'un statut binaire "admin ou pas admin". Django a un système de groupes/permissions intégré qui correspond directement à ce pattern, sans bibliothèque tierce nécessaire pour un besoin de cette taille.

### Critique appliquée à NetBuis
C'est une découverte utile et directement actionnable : `dashboard-admin-netbuis.md` a un point ouvert de longue date, **"qui devient admin, niveaux d'admin"**, jamais tranché. La réponse standard du marché — RBAC via les groupes/permissions Django — est une base toute prête pour trancher ce point : par exemple un rôle "validateur" (peut approuver/rejeter un `BusinessProfile` en attente, voir les demandes) distinct d'un rôle "administrateur" (accès complet, gestion des autres admins). Ce que NetBuis fait déjà pour les prestataires (CNI vérifiée par un admin) est déjà, sans le nommer, une démarche KYC standard — juste à formaliser le vocabulaire et, pour le type `entreprise`, envisager un contrôle KYB équivalent sur le RCCM si NetBuis veut aller plus loin (actuellement `rccm` est un champ texte libre optionnel, jamais vérifié).

**Suivi (v2)** : ~~résolu~~ — `dashboard-admin-netbuis.md` (v7) tranche définitivement les points I et J avec deux rôles concrets (Validateur / Administrateur complet), portés par les groupes Django, avec des règles serveur explicites sur qui peut bloquer/supprimer/modifier les réglages/gérer les autres admins. Le contrôle KYB sur le RCCM d'une `entreprise` reste, lui, non tranché — resté ouvert volontairement, ce n'est pas une urgence produit identifiée par le porteur de projet.

---

## 5. Psychologie UX : besoins, goûts, agacements des utilisateurs

### Synthèse
Les causes les plus citées d'une interface perçue comme "encombrée" (touffue) : trop d'actions proposées sur un même écran, une hiérarchie visuelle faible (tout a le même poids), et des cibles tactiles trop petites ou trop serrées — la règle couramment citée est un minimum de 44 pixels pour toute zone cliquable, pour éviter les erreurs de doigt. Les corrections qui reviennent : la "divulgation progressive" (montrer seulement l'essentiel, cacher le secondaire derrière un geste supplémentaire), une hiérarchie typographique claire, et l'usage de l'espace vide comme outil pour guider l'œil plutôt que comme un "gaspillage" à combler. Côté couleur, le orange (déjà choisi comme couleur d'accent de NetBuis) est associé dans la littérature design à l'énergie, à l'accessibilité financière perçue et à l'appel à l'action — un choix cohérent avec un marketplace local, pas un hasard à remettre en question.

### Critique appliquée à NetBuis
Ce thème rejoint directement le travail déjà fait dans `accessibilite-analphabetisme-netbuis.md` (minimalisme, icône + mot, éviter le jargon) — les mêmes causes de confusion identifiées par cette recherche (hiérarchie faible, surcharge) sont déjà adressées par les principes déjà actés, donc pas de contradiction, plutôt une confirmation. Un point concret à vérifier avant le développement réel : la rangée de 5 boutons de type de compte sur `CreationBusiness-Infos.dc.html` (icône + mot empilés, 3 boutons sur une ligne de ~114px de large chacun) — la hauteur totale du bouton doit être vérifiée contre la règle des 44px minimum une fois implémentée en vrai (la maquette donne une impression visuelle, pas une mesure de développement exacte) ; à garder en tête côté développeur mobile plutôt qu'à corriger maintenant dans la maquette.

**Suivi (v2)** : pas de nouveau document nécessaire — cette critique confirmait la cohérence avec `accessibilite-analphabetisme-netbuis.md` plutôt que de signaler un manque. Le seul point concret (vérification des 44px) reste, comme noté en v1, une tâche de développement mobile réelle, pas une décision à documenter davantage au stade de la maquette.

---

## 6. Cartographie du Cameroun pour l'écran "Carte"

### Synthèse (v1)
Il existe déjà des données ouvertes exploitables : **OpenStreetMap** a un projet dédié au Cameroun ("GeoCameroun"/WikiProject Cameroon), avec un export téléchargeable complet via Geofabrik, et un jeu de données structuré (OSM2IGEO Cameroun) publié sur data.gouv.fr. Point important à noter : il n'existe **pas de niveau "quartier" officiel et standardisé** dans la hiérarchie administrative — un quartier est une réalité locale reconnue par les habitants, pas une subdivision administrative formelle avec des frontières officielles.

Sur la "cartographie en repères orthogonaux" demandée : ça correspond exactement à un pattern de conception bien établi, celui des **cartes schématiques de type "plan de métro"** (schematic/metro maps) — des cartes qui ne respectent pas les distances géographiques réelles mais organisent les lieux sur une grille simplifiée, lisible d'un coup d'œil.

### Recherche complémentaire (nouveau, v2)

Le porteur de projet a demandé d'aller plus loin : rechercher aussi les données disponibles via **Google Maps** (quartiers, villes, hôtels), et préciser les niveaux administratifs exacts (régions, départements, arrondissements, villes/villages) pour construire la règle d'affichage de la carte.

**Hiérarchie administrative précisée** : 10 régions → 58 départements → **360 arrondissements** (qui ont remplacé les anciens districts, chiffre confirmé par une nouvelle vérification) → en parallèle, **374 communes** (14 communautés urbaines à statut spécial, 45 communes d'arrondissement, 315 communes rurales), l'échelon décentralisé à maire élu. **Point à surveiller** : la presse camerounaise évoque un projet de réforme qui ferait passer ce découpage à 70 départements et 400 communes avant les élections de décembre — non confirmé officiellement au moment de cette recherche, mais suffisant pour recommander que `Zone` reste un référentiel éditable depuis le dashboard admin plutôt qu'une liste figée dans le code (voir `modele-donnees-netbuis.md`, point Z).

**Couverture Google Maps au Cameroun, vérifiée directement sur la documentation officielle Google Maps Platform** : le Cameroun dispose de la géolocalisation (Geocoding), des tuiles de carte 2D, et des itinéraires routiers/piétons — mais pas des cartes 3D, ni des limites de vitesse, ni des itinéraires cyclables. Autrement dit, Google Maps peut servir de **repère de positionnement approximatif** pour une ville ou un grand quartier (via son API de géocodage), mais ne fournit, comme OpenStreetMap, **aucune liste exhaustive et fiable de quartiers ou d'établissements** pour les villes secondaires camerounaises — deux sources indépendantes confirment donc la même limite : il n'existe pas de base de données de quartiers "clé en main" pour le Cameroun, Google Maps inclus. La curation par l'équipe NetBuis elle-même reste nécessaire, Google Maps et OpenStreetMap servant tout au plus de repères de départ pour les grandes villes (Yaoundé, Douala, Maroua...).

### Critique appliquée à NetBuis (v1, maintenue)
Le choix de repères orthogonaux plutôt qu'une carte GPS réaliste est cohérent avec deux choses déjà actées dans ce projet : l'accessibilité pour les non-lecteurs et la contrainte réseau faible déjà documentée.

**Suivi (v2)** : ~~résolu~~ — `modele-donnees-netbuis.md` (v16) documente désormais la hiérarchie complète de `Zone` (`Region`/`Departement`/`Arrondissement`/`Ville_Village`/`Quartier`), confirme la limite déjà identifiée en v1 (ni quartier ni ville/village n'ont de liste officielle exhaustive, Google Maps compris) et ajoute une règle de visibilité demandée explicitement par le porteur de projet : **un `BusinessProfile` n'apparaît sur la carte que s'il est rattaché à une ville/village précis où au moins un compte business actif existe** — sans ce rattachement précis, il reste trouvable par la recherche textuelle mais n'apparaît pas sur `Carte.dc.html`. `Carte.dc.html` elle-même a été retouchée pour illustrer cette grille région/ville-village (voir la maquette). Point encore ouvert : l'interprétation de la formulation orale ("basé sur ceux qui sont en risque", comprise comme "ceux qui sont enregistrés") reste à confirmer explicitement par le porteur de projet — voir point Y dans `modele-donnees-netbuis.md`.

---

## Prochaines étapes proposées (mises à jour, v2)

1. **Seule critique encore sans document cible propre** : écrire le détail technique du mécanisme de recherche (trigrammes + plein texte) dans un document dédié au moment où le développement backend démarre réellement — ce n'est pas bloquant pour la suite des maquettes.
2. Confirmer l'interprétation de la règle de visibilité de la carte (point Y, `modele-donnees-netbuis.md`) et ajouter l'écran de sélection précise `Ville_Village`/`Quartier`, absent du parcours de création de compte business actuel.
3. Garder un œil sur la réforme administrative évoquée (58→70 départements, 360→400 communes) sans y réagir avant confirmation officielle.
4. Continuer l'audit d'accessibilité sur les écrans encore non revus (voir la liste dans `accessibilite-analphabetisme-netbuis.md`).

## Sources consultées

### v1
- [Fuzzy search in Postgres with pg_trgm — multilingue, tolérant aux fautes](https://dev.to/thiagolongom/fuzzy-search-in-postgres-with-pgtrgm-and-supabase-multilingual-typo-tolerant-2ipf)
- [Postgres pg_trgm: Fast Fuzzy Text Search](https://chat2db.ai/resources/blog/postgres-pg-trgm-fuzzy-text-search)
- [PostgreSQL Performance Tuning Checklist 2026](https://dev.to/_d7eb1c1703182e3ce1782/postgresql-performance-tuning-checklist-2026-complete-guide-65a)
- [Multi-Tenant Database Design Patterns](https://daily.dev/blog/multi-tenant-database-design-patterns-2024/)
- [Scaling a Monolithic Django Project — Without Microservices](https://itnext.io/how-to-scale-a-monolithic-django-project-6a8394c23fe8)
- [CI/CD for Mobile Applications: Complete 2026 Guide](https://www.gitnexa.com/blogs/mobile-app-cicd-pipeline-guide)
- [Marketplace Identity Verification: Build Trust & Stop Fraud (KYC/KYB)](https://appscrip.com/blog/marketplace-identity-verification/)
- [Role-Based Access Control (RBAC) in Django](https://www.permit.io/blog/how-to-implement-role-based-access-control-rbac-into-a-django-application)
- [How to Fix a Cluttered Mobile App Interface Design](https://flowmazeux.com/mobile-app-interface-design-clutter-fixes/)
- [How to Choose a Color Scheme for Your App: Psychology, Process, and Examples](https://www.uxpin.com/studio/blog/color-schemes-for-apps/)
- [WikiProject Cameroon — OpenStreetMap](https://wiki.openstreetmap.org/wiki/WikiProject_Cameroon)
- [Download OpenStreetMap for Cameroon — Geofabrik](https://download.geofabrik.de/africa/cameroon.html)
- [OSM2IGEO Cameroun — data.gouv.fr](https://www.data.gouv.fr/datasets/osm2igeo-cameroun)
- [Subdivisions of Cameroon — Wikipedia](https://en.wikipedia.org/wiki/Subdivisions_of_Cameroon)
- [Metro Maps on Octilinear Grid Graphs — cartographie schématique](https://onlinelibrary.wiley.com/doi/10.1111/cgf.13986)

### v2 (nouveau)
- [Détails de la couverture Google Maps Platform](https://developers.google.com/maps/coverage)
- [Subdivision territoriale du Cameroun — Wikipédia](https://fr.wikipedia.org/wiki/Subdivision_territoriale_du_Cameroun)
- [Les CTDs — Mairies & Communes du Cameroun](https://www.mairies.cm/about/ctds)
- [Cameroun : de 58 à 70 départements et de 360 à 400 communes avant les élections de décembre](https://www.camerounweb.com/CameroonHomePage/NewsArchive/Cameroun-de-58-70-d-partements-et-de-360-400-communes-avant-les-lections-de-d-cembre-Raoul-Christophe-Bia-r-v-le-le-plan-792521)
- [Les communes du Cameroun — Osidimbea](https://www.osidimbea.cm/collectivites/liste-communes/)
- [Tous les Villages - Quartiers Cameroun — localités du monde](https://localitesdumonde.com/localites.php?t=2-villages-quartiers&p=1-cameroun)
