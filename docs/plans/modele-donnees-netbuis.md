# Modèle de données NetBuis — entités, relations, règles métier

Date : 2026-10-05 (v18 — confirmation avant l'appel = choix de la ligne Orange / MTN, Android uniquement ; v17 : mécanisme d'appel direct, numéro jamais affiché dans NetBuis ; v16 : hiérarchie complète de `Zone` et règle de visibilité sur la carte)

## Reformulation du besoin (pour validation)

Voici ce que je retiens de la description — à corriger si j'ai mal compris un point :

- Tout le monde a un **compte (Account)** de base.
- Un compte peut optionnellement devenir un **compte business** : cette extension est ouverte aussi bien aux **commerçants** (boutiques, entreprises) qu'aux **particuliers** qui veulent vendre quelque chose, et désormais aussi aux **prestataires de services indépendants** (techniciens, enseignants à domicile, professionnels de santé indépendants...) et aux **structures** (supermarché, restaurant, hôtel, centre de santé) — ce n'est donc pas réservé aux pros enregistrés.
- **Seul un compte business peut** : publier des produits dans le catalogue, et publier des contenus (image ou vidéo + légende) — en nombre limité sans abonnement, illimité avec (voir section dédiée plus bas).
- Un compte **simple** (sans extension business) peut : rechercher un produit, voir la liste des comptes business qui le proposent, **appeler** un compte business, et **commander** chez un compte business.
- Un compte simple **ne peut pas appeler un autre compte simple** — seulement un compte business.
- **NetBuis n'affiche jamais le numéro de téléphone d'un autre utilisateur.** Sur Android, un clic sur "Appeler" ouvre une feuille où l'utilisateur **choisit sa ligne (Orange ou MTN)**, puis l'appel est lancé directement ; sur iOS, le système affiche le numéro dans sa propre confirmation, et le choix de ligne ne peut pas être appliqué, en attendant une solution. Le numéro n'est pas pour autant introuvable (écran d'appel et journal d'appels du téléphone) — voir `decision-finale-appels.md` (v2.1) et la remarque technique plus bas.
- Deux vues principales : (1) la **recherche** — on tape un nom de produit, on obtient la liste des comptes business qui le proposent ; (2) l'**exploration par zone** — on choisit une zone géographique, on voit les produits disponibles dans cette zone ainsi que le nom des boutiques/entreprises qui les proposent.
- **Croissance du réseau de comptes business** : NetBuis veut aussi faire grandir activement le nombre de comptes business sur la plateforme via un système de parrainage réservé à une **équipe NetBuis** validée (voir sections dédiées plus bas).
- **À la création d'un compte business, le commerçant doit paramétrer son secteur d'activité** (alimentation, pharmacie, immobilier, services, artisanat...) puis préciser concrètement ce qu'il vend ou propose — par sélection dans une liste et par texte libre — pour alimenter la recherche intelligente (voir section dédiée plus bas).
- **Un compte business non abonné ne peut déclarer que 3 sous-catégories/produits au maximum** à cette étape de paramétrage ; au-delà, l'application propose de souscrire à un abonnement, qui débloque une sélection illimitée (voir section dédiée plus bas).
- **Le type de compte business se décline en cinq formes distinctes : Commerce, Entreprise, Particulier vendeur, Prestataire de service, Structure** — et chacune a son **propre parcours de paramétrage**, parce que ce que ces comptes doivent déclarer n'a rien à voir d'un type à l'autre (voir section dédiée plus bas).
- **Un restaurant ou un hôtel reste une structure à vocation commerciale ; un centre de santé a une vocation davantage sociale** — ce sont des réalités différentes d'un simple "commerce", et le porteur de projet a demandé qu'elles aient leur propre chemin de paramétrage plutôt que d'être réduites au `Secteur` générique (voir section dédiée).
- **Chaque champ de l'écran de paramétrage s'adapte au type de compte choisi**, y compris le libellé du nom et de la photo de la personne derrière le compte — pas de terme générique unique qui ne conviendrait pas à tous les cas (voir section dédiée plus bas).
- **La liste des secteurs et sous-catégories doit être la plus large possible**, pour que le commerçant ait le réflexe de sélectionner plutôt que de toujours devoir écrire lui-même (voir section dédiée plus bas).
- **La carte (écran Carte) doit afficher les commerces/entreprises/structures par rattachement géographique précis** (région, département, arrondissement, ville ou village) **et seulement ceux-là** : un compte business enregistré dans une ville ou un village en particulier apparaît directement sur la carte à cet endroit ; un compte sans rattachement aussi précis n'apparaît pas sur la carte (voir section dédiée sur `Zone`, nouveau en v16).

## Schéma proposé (entités et relations)

**Account (compte)**
- Numéro de téléphone vérifié (identifiant unique, voir le flux SMS OTP déjà décrit dans `monetisation-appels-orange-money.md`)
- Nom, date de création
- Compteur d'appels gratuits consommés + solde de crédits (déjà actés dans `monetisation-appels-orange-money.md`)
- `is_equipe_netbuis` (booléen) — indique un membre validé de l'équipe NetBuis, seul habilité à rattacher un code de parrainage à un nouveau `BusinessProfile` (voir section dédiée)
- `equipe_status` : vide (jamais candidat) / `en_attente_validation` / `validée` / `rejetée` — statut de la candidature à l'équipe NetBuis
- `cni_video` (fichier vidéo, requis uniquement pour une candidature à l'équipe NetBuis) — voir section dédiée sur le processus de vetting
- `equipe_validated_at` (date, nullable)
- Relation 1-à-0/1 vers `BusinessProfile` (un compte peut avoir, ou non, un profil business) — **un même compte peut être à la fois membre de l'équipe NetBuis et titulaire d'un compte business** ; les deux rôles ne s'excluent pas (confirmé par le porteur de projet)

**BusinessProfile (compte business)** — extension optionnelle d'un `Account`
- Compte propriétaire (`Account`, OneToOne, nullable uniquement le temps d'un parcours de création par un agent sans smartphone côté commerçant — voir section dédiée ; rempli immédiatement dans le parcours normal, y compris le parcours par QR code)
- Nom affiché (nom du commerce, de l'entreprise, du particulier vendeur, du prestataire de service, ou de l'établissement)
- `type_compte` : `boutique` / `entreprise` / `particulier_vendeur` / `prestataire_service` / `structure` — **identifiants internes inchangés**, mais le premier (`boutique`) est désormais affiché à l'écran sous le libellé **"Commerce"**
- `forme_juridique` (uniquement si `type_compte = entreprise`) : `individuelle` / `sarl` / `sarlu` / `sa` / `gic_cooperative` / `association` / `etablissement_public` / `autre`
- `rccm` (texte, optionnel, uniquement pertinent si `type_compte = entreprise`) — numéro de registre de commerce, facultatif
- `categorie_service` (FK vers une liste dédiée, uniquement si `type_compte = prestataire_service`) — voir section dédiée ; taxonomie séparée de `Secteur`
- `categorie_service_libre` (texte libre, nullable) — rempli quand `categorie_service = Autre`
- `structure_type` (uniquement si `type_compte = structure`) : `supermarche` / `restaurant` / `hotel` / `sante` / `autre` — voir section dédiée ; taxonomie séparée de `Secteur` et de `categorie_service`
- `structure_type_libre` (texte libre, nullable) — rempli quand `structure_type = autre`
- `cni_photo` (fichier image, obligatoire uniquement si `type_compte = prestataire_service`) — photo de la Carte Nationale d'Identité, **jamais affichée publiquement en entier**
- `cni_verifiee` (booléen, défaut `false`) — passe à `true` quand un admin a examiné `cni_photo` lors de la validation du `BusinessProfile`
- `diplome_photo` (fichier image, optionnel, uniquement pertinent si `type_compte = prestataire_service`) — diplôme ou attestation, **celui-ci peut être affiché publiquement** si fourni
- Zone (voir `Zone` ci-dessous) — **obligatoire pour apparaître sur l'écran Carte (voir règle de visibilité, nouveau en v16)**, et doit être rattachée au niveau `Ville_Village` ou `Quartier`, pas seulement à une `Région` ou un `Département`
- Description, photo du commerce
- Nom et photo de la personne qui représente le compte (obligatoire — sert à la vérification humaine anti-faux-compte) — le libellé affiché à l'écran s'adapte aux cinq types de compte (voir section dédiée).
- Numéro de téléphone ancré — **c'est le numéro composé lors d'un appel** ; il n'est jamais inclus dans les réponses de recherche, de carte ou de liste (voir `CallLog` et la remarque technique plus bas). Utile aussi au parcours de secours sans smartphone.
- `status` : `en_attente_validation` / `actif` / `rejeté`
- `created_by` (FK `Account`, nullable) — rempli uniquement dans le parcours de secours
- `claimed_at` (date, nullable) — uniquement pertinent pour le parcours de secours
- Relation vers `Subscription` (voir `dashboard-admin-netbuis.md`)
- Relation vers `Secteur` (FK ; **non pertinent pour `type_compte` = `prestataire_service` ou `structure`**, qui utilisent respectivement `categorie_service` et `structure_type` à la place) et vers `SousCategorie` (plusieurs — **plafonnée à 3 pour un compte sans abonnement actif, illimitée avec abonnement**)
- `secteur_libre` (texte libre, nullable) — rempli uniquement quand `Secteur = Autre`
- `description_activite` (texte libre) — ce que le commerçant a écrit lui-même pour préciser concrètement son activité
- **Champs spécifiques à `structure_type` — détaillés dans la section dédiée ci-dessous** : rayons (supermarché), cuisine/livraison/horaires (restaurant), standing/chambres/équipements (hôtel), spécialités/numéro d'agrément (centre de santé).

**Zone — hiérarchie administrative complète, et base de l'écran Carte (point C résolu, étendu en v16)**
- Nom
- Niveau : `Pays` / `Region` / `Departement` / `Arrondissement` / `Ville_Village` / `Quartier` / `Repere`
- Parent (auto-référence vers le niveau juste au-dessus)
- Code officiel (texte, optionnel, nullable) — pour les niveaux `Region`/`Departement`/`Arrondissement`, qui ont une existence administrative officielle et donc un identifiant stable à conserver si besoin (ex. recoupement avec une source officielle ou OpenStreetMap)

**Pourquoi ce détail de niveaux (v16, en réponse à la demande du porteur de projet de baser la carte sur "les régions, les villes, peut-être les villages, les départements et les arrondissements")** :

La hiérarchie administrative officielle du Cameroun, confirmée par une nouvelle recherche, est : **10 régions** → **58 départements** → **360 arrondissements** (qui ont remplacé les anciens districts) → en parallèle, **374 communes** (14 communautés urbaines, 45 communes d'arrondissement, 315 communes rurales), l'échelon décentralisé à maire élu. **Point important à surveiller** : un projet de réforme évoqué dans la presse camerounaise proposerait de faire passer ce découpage de 58 à 70 départements et de 360 à 400 communes avant les élections de décembre — ce chiffre n'est pas encore acté officiellement au moment de cette recherche, mais confirme que `Zone` doit rester un référentiel modifiable depuis le dashboard admin (pas une liste figée dans le code), pour absorber un futur redécoupage sans nouvelle version de l'application.

En dessous de l'arrondissement/commune, ni la **ville/village**, ni le **quartier** n'ont de liste officielle exhaustive et stable : un village est une réalité reconnue localement à l'intérieur d'une commune rurale, pas une subdivision cartographiée une à une par l'État ; un quartier l'est de la même façon à l'intérieur d'une ville. **Cette limite, déjà documentée en v15 pour le niveau `Quartier`, s'étend donc aussi au niveau `Ville_Village`** : NetBuis doit construire et curer elle-même sa liste de villes/villages et de quartiers desservis, en s'appuyant sur des sources ouvertes comme point de départ (OpenStreetMap/Geofabrik, voir `recherche-technique-ux-netbuis.md` section 6) plutôt que sur un import unique et définitif.

**Sur Google Maps comme source complémentaire (v16)** : une vérification de la couverture officielle de Google Maps Platform confirme que le Cameroun dispose bien de la géolocalisation (Geocoding) et des itinéraires routiers/piétons (Driving/Walking Directions), mais pas de certaines fonctionnalités avancées (cartes 3D, limites de vitesse). Autrement dit, Google Maps peut servir de référence pour **positionner approximativement** une ville ou un grand quartier (via son API de géocodage), mais ne fournit aucune liste exhaustive et fiable de quartiers ou d'établissements pour les villes secondaires camerounaises — ce qui confirme, depuis une deuxième source indépendante d'OpenStreetMap, que la curation manuelle par l'équipe NetBuis reste nécessaire, Google Maps n'étant qu'un repère de positionnement possible, pas une base de données de quartiers prête à l'emploi.

### Règle de visibilité sur l'écran Carte : seuls les comptes rattachés précisément apparaissent (v16)

Le porteur de projet a demandé explicitement que la carte ne montre pas la hiérarchie administrative "à vide" : *"lorsqu'une entreprise, une structure, un commerce est enregistré dans une ville, un village en particulier, il va directement apparaître. Mais sans cela, il n'apparaît pas."* **Décision retenue, formulée comme règle serveur :**

- Un nœud de niveau `Ville_Village` (et, par extension, un `Quartier` à l'intérieur) ne s'affiche comme actif/cliquable sur `Carte.dc.html` que s'il existe au moins un `BusinessProfile` avec `status = actif` rattaché directement à cette `Zone`, ou à l'un de ses `Quartier` enfants.
- Un `Region` ou un `Departement` reste visible comme repère de navigation (c'est le niveau supérieur de la grille), mais ne devient "explorable" (clic qui descend au niveau suivant) que s'il contient, quelque part dans sa descendance, au moins une `Ville_Village` elle-même active au sens ci-dessus.
- À la création d'un `BusinessProfile`, le champ `Zone` reste obligatoire comme aujourd'hui, mais le parcours de paramétrage doit désormais imposer de descendre jusqu'au niveau `Ville_Village` (ou `Quartier` si disponible) — un rattachement arrêté à `Region` ou `Departement` seul ne suffit plus pour que le compte apparaisse sur la carte.
- Cette règle ne change rien à la recherche textuelle (`Main.dc.html`) : un compte business reste trouvable par recherche de produit même si, par erreur, il n'a pas de `Zone` suffisamment précise — seule sa présence sur **la carte** dépend de cette règle. Les deux mécanismes (recherche et carte) restent volontairement indépendants.

**Note d'interprétation à confirmer avec le porteur de projet** : la formulation orale transcrite contenait l'expression "basé sur ceux qui sont en risque", qui ne fait pas sens tel quel dans ce contexte — je l'ai interprétée comme "ceux qui sont **enregistrés**", cohérente avec la suite de la phrase ("lorsqu'une entreprise... est enregistrée... elle apparaît ; sans cela, elle n'apparaît pas"). Si cette interprétation est incorrecte, cette section est à corriger.

**Secteur (secteur d'activité) — nouvelle entité, liste corrigée en v15**
- Nom — **10 secteurs** : Alimentation, Boutique / Supérette, Pharmacie & Santé, Mode & Beauté, Électronique & Informatique, Immobilier, Transport & Livraison, Agriculture & Élevage, Artisanat & Services à domicile, Autre.
- Icône/emoji
- Liste prédéfinie, gérée par l'équipe NetBuis, extensible par un admin. La valeur réservée `Autre` permet un secteur libre (`secteur_libre`).
- **Uniquement utilisé par les types de compte `boutique` (affiché "Commerce"), `entreprise` et `particulier_vendeur`.** Le type `prestataire_service` utilise `categorie_service` à la place, et le type `structure` utilise `structure_type` à la place.
- **Correction par rapport aux versions précédentes (v11 à v14)** : ces versions mentionnaient 14 secteurs, dont Supermarché, Restauration, Hôtellerie et Santé & Centres médicaux. En pratique, seuls les 12 premiers avaient été implémentés dans la maquette (Hôtellerie et Santé & Centres médicaux n'avaient jamais été ajoutés à l'écran `CreationBusiness-Secteur.dc.html`, malgré la documentation). La v15 supprime aussi Supermarché et Restauration de la liste des secteurs : ces quatre réalités (supermarché, restaurant, hôtel, centre de santé) sont désormais couvertes par le type de compte `structure` (voir section dédiée), pas par `Secteur`. La liste des secteurs repasse donc de 14 (documentés, jamais tous implémentés) à **10 secteurs réellement implémentés**.

**SousCategorie (sous-catégorie) — nouvelle entité**
- Secteur parent (FK)
- Nom — liste enrichie par secteur
- Plafonnée à 3 sans abonnement actif, illimité avec abonnement.

**CategorieService (catégorie de service) — nouvelle entité**
- Nom : Enseignement à domicile, Technique & Réparation, Services médicaux indépendants, Beauté & Bien-être à domicile, Juridique & Comptabilité, Événementiel, Autre.
- Icône/emoji
- Parallèle à `Secteur`, réservée aux comptes `prestataire_service`.

**TypeStructure (type d'établissement) — nouvelle entité, v15**
- Nom : Supermarché, Restaurant, Hôtel, Centre de santé, Autre.
- Icône/emoji
- Parallèle à `Secteur` et à `CategorieService`, réservée aux comptes `structure`.

**Product (produit)**
- BusinessProfile propriétaire (FK)
- Nom, description, photo(s), prix
- Compteurs d'activité (vues, appels reçus, commandes)

**Post (publication)**
- BusinessProfile propriétaire (FK) — plafond proposé : 5 publications actives sans abonnement, illimité avec.
- Type (image ou vidéo) + fichier média + légende
- Produit associé (FK vers `Product`, optionnel)
- Date de publication

**Comment (commentaire)**
- Post concerné (FK)
- Auteur (`Account`) — n'importe quel compte peut commenter
- Texte, date

**Order (commande)**
- Acheteur (`Account`)
- BusinessProfile vendeur (FK)
- Lignes de commande (produit + quantité)
- Statut, date

**CallLog (journal d'appels)** — mis à jour en v18
- Compte appelant
- BusinessProfile appelé
- Date, type (gratuit / décompté du pack de crédits)
- `plateforme` : `android` / `ios` (utile pour mesurer l'effet de la différence d'expérience entre les deux)
- `operateur` : `orange` / `mtn` / null (**nouveau, v18**) — la ligne choisie par l'utilisateur dans la feuille de confirmation. Null sur iOS (où le choix ne peut pas être appliqué), sur un téléphone à une seule SIM (choix sauté) et en cas de repli sur le composeur. Utile pour mesurer la répartition Orange/MTN, pas pour facturer.
- **Créé au moment où le serveur délivre le numéro** (voir "Remarque technique" plus bas) : une ligne `CallLog` signifie "un appel a été **lancé**", pas "le commerçant a décroché". NetBuis ne connaît ni l'issue ni la durée de l'appel (voir `decision-finale-appels.md` v2.1).

**Referral (parrainage)**
- Agent (`Account`, `is_equipe_netbuis = true`)
- BusinessProfile parrainé (FK)
- `reward_status` : `en_attente` / `du` / `annulé`
- Montant de la prime, dates

## Type de compte business (révision 5) : Commerce, Entreprise, Particulier vendeur, Prestataire de service, Structure

**`type_compte` prend cinq valeurs : `boutique` / `entreprise` / `particulier_vendeur` / `prestataire_service` / `structure`.** Dans la maquette (`CreationBusiness-Infos.dc.html`), ce choix se fait via cinq boutons (répartis sur deux rangées), et change le libellé du champ "nom", le libellé du champ "propriétaire/responsable", et l'écran suivant dans le parcours :

- **Commerce** (identifiant interne `boutique`) → nom du commerce, propriétaire, photos → direction l'écran Secteur.
- **Entreprise** → nom de l'entreprise → direction **"Forme juridique"** (`CreationBusiness-Entreprise-Forme.dc.html`) → puis Secteur comme un Commerce.
- **Particulier vendeur** → "Comment souhaitez-vous apparaître ?" → direction l'écran Secteur (parcours simplifié).
- **Prestataire de service** → "Comment souhaitez-vous apparaître ?" → direction **"Catégorie de service & vérification d'identité"** (`CreationBusiness-Prestataire-Categorie.dc.html`), qui remplace l'écran Secteur et enchaîne directement vers le Récapitulatif.
- **Structure** (v15) → "Nom de l'établissement" → direction **"Type d'établissement"** (`CreationBusiness-Structure-Type.dc.html`), qui remplace l'écran Secteur et enchaîne vers un écran de détails spécifique au type choisi (`CreationBusiness-Structure-Details.dc.html`), puis le Récapitulatif.

### Pourquoi un cinquième type "Structure" : la nuance entre entreprise commerciale et entreprise sociale

Le porteur de projet a contesté la décision précédente (v11, point R) de classer un restaurant, un hôtel ou un centre de santé comme simple `Secteur` sous Commerce/Entreprise, avec cette remarque : *« un restaurant ou un hôtel est une entreprise commerciale. Un centre de santé est une entreprise sociale. Donc, pour résumer ça en commerce, on ne peut pas résumer un centre de santé à commerce. Ce n'est pas logique. »* Il a demandé l'ajout d'une option (ici nommée "Structure") qui, une fois sélectionnée, propose directement les choix Supermarché, Restaurant, Hôtel, Centre de santé — puis enchaîne sur un **paramétrage à part** pour chacun, plutôt qu'un simple secteur parmi d'autres.

**Décision retenue** : un cinquième `type_compte` nommé **Structure**, avec son propre sous-parcours à deux écrans :

1. **`CreationBusiness-Structure-Type.dc.html`** — grille de 5 choix : Supermarché 🛒, Restaurant 🍲, Hôtel 🏨, Centre de santé 🏥, Autre ✨ (avec texte libre si "Autre"). Un encart explique la nuance commerciale/sociale directement à l'écran, pour rester fidèle à l'intention du porteur de projet.
2. **`CreationBusiness-Structure-Details.dc.html`** — champs spécifiques selon le type choisi (voir ci-dessous).

### Détails par type de structure

- **Supermarché** : sélection de rayons (Alimentation générale, Produits frais, Boissons, Hygiène & Beauté, Entretien & Maison, Bazar & Électroménager, Produits pour bébés, Autre), plafonnée à 3 sans abonnement — même logique que les sous-catégories d'un Commerce.
- **Restaurant** : type de cuisine (Camerounaise, Africaine — autre pays, Fast-food, Pizzeria/Occidentale, Autre), un interrupteur "Service de livraison disponible", horaires d'ouverture (texte).
- **Hôtel** : catégorie/standing (Économique, Standard, Confort, Haut standing), nombre de chambres (texte/nombre), équipements inclus (Petit-déjeuner, Wifi, Parking, Climatisation — sélection multiple).
- **Centre de santé** : numéro d'agrément sanitaire (texte, optionnel), spécialités médicales proposées (Médecine générale, Pédiatrie, Gynécologie, Dentisterie, Laboratoire d'analyses, Pharmacie interne, Autre), plafonnée à 3 sans abonnement — même logique que les rayons d'un supermarché.
- **Commun à tous les types de structure** : description libre de l'établissement (texte, avec un exemple de placeholder différent par type).

**Simplification à noter (point X)** : contrairement à `Entreprise`, le type `Structure` n'a pas aujourd'hui de champ `forme_juridique`/`rccm` — un supermarché ou un hôtel peuvent pourtant être constitués en société (SARL, SA...). Pour l'instant, la maquette ne le demande pas à cette étape. À trancher : faut-il ajouter ce même champ "forme juridique" (optionnel) à l'écran Structure-Details, ou considérer que l'essentiel pour ces structures est le type d'établissement et ses détails opérationnels, la forme juridique restant secondaire ?

### "Boutique" renommé "Commerce" : pour couvrir aussi supérette, boutique de quartier...

Le porteur de projet a soulevé un problème de vocabulaire : le type de compte précédemment affiché "Boutique" devait aussi couvrir des réalités plus larges. **Décision retenue : le type de compte précédemment affiché "Boutique" est renommé "Commerce" à l'écran** — un terme neutre qui couvre une petite boutique de quartier ou une supérette. Depuis la création du type `Structure` (v15), le Commerce n'a plus besoin de couvrir aussi le supermarché, le restaurant, l'hôtel ou le centre de santé — ceux-ci ont désormais leur propre type de compte dédié. L'identifiant interne reste `boutique`, seul le texte affiché change. La frontière avec "Entreprise" ne change pas (question de formalité juridique, pas de taille).

### Un libellé par type de compte pour le "propriétaire"/"responsable"

Le porteur de projet a fait remarquer que le champ "Nom/Photo du propriétaire" ne convenait pas à tous les types — en particulier pour un Prestataire de service (un technicien n'est "propriétaire" de rien) ni pour une Structure (on ne dit pas "propriétaire" d'un hôtel ou d'un centre de santé de la même façon). **Décision retenue :**

- **Commerce** → "Nom du propriétaire" / "Photo du propriétaire" (inchangé).
- **Entreprise** → "Nom du représentant légal" / "Photo du représentant légal", avec le texte d'aide "Gérant, Directeur Général, PDG... selon la forme juridique de votre entreprise."
- **Structure** (v15) → "Nom du responsable" / "Photo du responsable", avec le texte d'aide "Directeur, gérant, responsable de l'établissement..."
- **Particulier vendeur** et **Prestataire de service** → "Votre nom complet" / "Votre photo (vérification)", avec le texte d'aide "Pour la vérification de votre identité — peut différer du nom affiché publiquement ci-dessus."

**Reste à confirmer (point U)** : cette distinction entre nom d'affichage public et nom de vérification convient-elle, ou préférez-vous un seul champ pour Particulier/Prestataire ?

### Entreprise : forme juridique

Écran `CreationBusiness-Entreprise-Forme.dc.html`, affiché uniquement pour `type_compte = entreprise`. Liste à sélection unique : Entreprise individuelle / Auto-entrepreneur, SARL, SARL Unipersonnelle, SA, GIC / Coopérative, Association / ONG, Établissement public ou parapublic, Autre. Plus un champ texte libre optionnel pour le numéro RCCM.

### Prestataire de service : catégorie de service et vérification d'identité

Écran `CreationBusiness-Prestataire-Categorie.dc.html` : grille de catégories de service (Enseignement à domicile, Technique & Réparation, Services médicaux indépendants, Beauté & Bien-être à domicile, Juridique & Comptabilité, Événementiel, Autre), puis CNI (obligatoire, examinée par un admin, jamais affichée publiquement — seul un badge "✓ Identité vérifiée" l'est) et diplôme (optionnel, affiché publiquement s'il est fourni). **À confirmer** (point S).

## Secteurs et sous-catégories : une taxonomie volontairement large (10 secteurs, corrigé en v15)

**Liste des 10 secteurs :** Alimentation 🍌, Boutique / Supérette 🏪, Pharmacie & Santé 💊, Mode & Beauté 👗, Électronique & Informatique 💻, Immobilier 🏠, Transport & Livraison 🛵, Agriculture & Élevage 🌾, Artisanat & Services à domicile 🔧, Autre ✨.

*(Supermarché, Restauration, Hôtellerie et Santé & Centres médicaux — mentionnés dans les versions précédentes — relèvent maintenant du type de compte `structure`, voir plus haut, et non plus de `Secteur`.)*

**Sous-catégories enrichies (déjà intégrées à la maquette, ou documentées ici) :**

- **Alimentation** (12) : Fruits, Légumes, Tubercules, Céréales & Légumineuses, Viande/Volaille & Poisson, Produits laitiers & Œufs, Huiles & Graisses, Épices & Condiments, Boissons, Boulangerie & Pâtisserie, Produits surgelés, Autre.
- **Boutique / Supérette** : Biscuits & Confiseries, Eau & Boissons, Pâtes/Riz & Céréales transformées, Conserves, Produits laitiers emballés, Hygiène & Entretien, Produits pour bébés, Papeterie, Autre.
- **Transport & Livraison** : Moto-taxi, Taxi, Livraison de colis, Transport de marchandises, Location de véhicule, Déménagement, Autre.
- **Pharmacie & Santé**, **Mode & Beauté**, **Électronique & Informatique**, **Immobilier**, **Agriculture & Élevage** : propositions détaillées, voir version précédente (v13) — pas encore démontrées dans la maquette interactive.
- **Artisanat & Services à domicile** : Menuiserie, Plomberie, Électricité, Couture, Maçonnerie, Mécanique, Informatique & Réparation, Coiffure & Beauté, Autre.

**Catégories de service pour les prestataires** : Enseignement à domicile, Technique & Réparation, Services médicaux indépendants, Beauté & Bien-être à domicile, Juridique & Comptabilité, Événementiel, Autre.

**Types d'établissement pour les structures** : Supermarché, Restaurant, Hôtel, Centre de santé, Autre — voir détails des champs par type plus haut.

## Paramétrage à la création d'un compte business : un parcours différent selon le type de compte

**Écrans communs à Commerce, Entreprise et Particulier vendeur :** Informations de base → *(Entreprise uniquement)* Forme juridique → Secteur d'activité → Détails du secteur → Récapitulatif.

**Écrans pour Prestataire de service :** Informations de base → Catégorie de service & vérification d'identité → Récapitulatif.

**Écrans pour Structure (v15) :** Informations de base → Type d'établissement → Détails de l'établissement (spécifiques au type choisi) → Récapitulatif.

**Rattachement géographique (tous les types, précisé en v16)** : quel que soit le type de compte, le choix de `Zone` doit descendre jusqu'au niveau `Ville_Village` (ou `Quartier`) — voir la règle de visibilité de la carte ci-dessus. Ce choix n'a pas encore d'écran dédié dans la maquette actuelle du parcours de création ; à ajouter.

## Limite de sous-catégories/produits déclarables selon l'abonnement

(Inchangé — voir versions précédentes. Plafond de 3 sans abonnement, illimité avec, pour Commerce/Entreprise/Particulier vendeur. Le même plafond de 3 s'applique désormais aussi aux rayons d'un Supermarché et aux spécialités d'un Centre de santé.)

## Classement d'affichage et limite de publications selon l'abonnement

(Inchangé — voir versions précédentes.)

## Le forum : commentaires sous publications (point D résolu)

(Inchangé — voir versions précédentes.)

## Créer un compte business avec un parrain : le QR code comme méthode principale

(Inchangé — voir versions précédentes.)

## Comment devient-on membre de l'équipe NetBuis : processus de candidature (point F résolu)

(Inchangé — voir versions précédentes.)

## Règles métier à faire respecter côté serveur (pas seulement côté UI)

(Inchangé — voir v13 pour la liste complète : appels/commandes réservés aux BusinessProfile actifs, parrainage réservé à l'équipe NetBuis, plafonds de publications/sous-catégories, champs obligatoires par type de compte, confidentialité de `cni_photo`. Le plafond de 3 s'applique aussi aux rayons/spécialités déclarés par une Structure.)

**(v16)** Un `BusinessProfile` n'apparaît sur `Carte.dc.html` que si sa `Zone` descend au moins jusqu'au niveau `Ville_Village` et que `status = actif` — voir la règle de visibilité détaillée dans la section `Zone` ci-dessus. Cette règle est propre à l'écran Carte et ne s'applique pas à la recherche textuelle.

**(v17, précisé en v18)** Le numéro de téléphone d'un `BusinessProfile` **n'est jamais présent dans les réponses de recherche, de carte, de liste ou de profil**. Il n'est délivré que par l'endpoint d'appel (`POST /calls/initiate`), qui, avant de répondre : vérifie que l'appelant est connecté ; vérifie que le `BusinessProfile` est `actif` et non bloqué ; vérifie le quota d'appels gratuits ou le solde de crédits ; applique une limite de fréquence par compte (anti-aspiration de numéros) ; crée la ligne `CallLog`. **(v18)** La requête reçoit la `plateforme` et l'`operateur` choisi (Orange/MTN, ou absent) et les enregistre dans le `CallLog` ; le choix d'opérateur n'a aucun effet sur les règles ci-dessus (même quota, même crédit quelle que soit la ligne). Le plafond exact de la limite de fréquence est à fixer (voir `decision-finale-appels.md`, points à trancher).

## Zone : pourquoi une hiérarchie et pas un champ plat

Voir la section `Zone` détaillée plus haut (entité, niveaux, limites des données officielles, règle de visibilité sur la carte — entièrement réécrite en v16).

## Remarque technique importante : "NetBuis n'affiche jamais le numéro", l'appel direct et le choix de la ligne (mise à jour v18)

Le mécanisme est décrit dans `decision-finale-appels.md` (v2.1). En résumé :

- **Android** : un clic sur "Appeler" ouvre une feuille "Avec quelle ligne voulez-vous appeler ?" avec deux boutons, **Orange** et **MTN** (seuls opérateurs pris en charge pour l'instant, par décision du porteur de projet), plus "Annuler". Le choix de la ligne **est la confirmation** : il lance l'appel immédiatement (`placeCall` avec la SIM/le compte téléphonique correspondant ; permission `CALL_PHONE` demandée une fois). Cette étape protège aussi des clics accidentels, désormais coûteux puisqu'un clic peut déclencher un vrai appel. Le numéro n'est jamais affiché par NetBuis. Si la permission est refusée, repli sur le composeur (numéro visible).
- **Cas particuliers côté Android** : téléphone à une seule SIM → le choix est sauté et l'appel part sur la ligne présente ; ligne choisie non installée (ex. pas de SIM MTN) → message clair et choix de l'autre ligne ; SIM renommée ou eSIM → la correspondance opérateur/SIM peut échouer et doit avoir un repli.
- **iOS** : le système affiche une confirmation contenant le numéro avant l'appel, impossible à contourner avec les API publiques, et l'application ne peut pas désigner la SIM à utiliser. La feuille Orange/MTN n'a donc pas d'équivalent fonctionnel sur iOS. Accepté provisoirement par le porteur de projet.
- **Ce que "jamais affiché" ne garantit pas** : l'écran d'appel et le journal d'appels du téléphone montrent le numéro après coup, et le numéro transite jusqu'à l'appareil pour être composé. Ce n'est donc pas un masquage au sens strict, seulement une absence d'affichage dans NetBuis.
- **Effet sur le suivi** : puisque le numéro est délivré par le serveur à chaque appel, NetBuis sait qu'un appel a été lancé (qui, vers qui, quand, sur quelle ligne) mais pas s'il a abouti ni sa durée.

## L'écran "Aide & support"

Le porteur de projet a demandé ce que je proposais pour la vue "Aide & support", jusqu'ici un simple lien inactif (`href="#"`) sur l'écran Profil. **Décision retenue** : un nouvel écran `Aide.dc.html`, organisé en trois blocs :

1. **Une FAQ groupée par thème**, en accordéon (une question ouverte à la fois) : "Appels & crédits" (appel gratuit du jour, achat d'un pack, pourquoi le numéro du commerçant n'est pas visible), "Compte business & abonnement" (comment créer son compte, pourquoi un compte est en attente de validation, le plafond de 3 produits sans abonnement), "Parrainage & sécurité" (devenir membre de l'équipe NetBuis, comment fonctionne le parrainage, comment signaler un compte suspect). Les questions reprennent volontairement des mécanismes déjà actés dans ce document (appel gratuit, plafond de 3, validation admin, parrainage) plutôt que d'en inventer de nouveaux.
2. **Un bloc "Nous contacter"** : WhatsApp, appel téléphonique au support, e-mail — trois canaux visuels dans la maquette (non fonctionnels, c'est un mockup), cohérent avec le fait que WhatsApp est déjà une brique prévue du projet (mentionnée dans la description d'origine).
3. **Un bouton "Signaler un problème ou un compte suspect"**, distinct de la FAQ — point d'entrée visible plutôt que noyé dans une question, puisque la modération (forum, faux comptes) reste un point ouvert important (voir points H et R/S).

L'écran est accessible depuis `Profil.dc.html` (le lien "Aide & support", auparavant inactif, pointe maintenant vers `Aide.dc.html`).

**Point à trancher (point W)** : le contenu de la FAQ est une proposition de départ construite à partir des mécanismes déjà actés dans ce document — le porteur de projet voudra sans doute l'ajuster ou la compléter (ex. questions sur les commandes, sur le forum) une fois le reste du produit plus avancé. Le numéro de support, l'adresse e-mail (`support@netbuis.cm`, inventée pour la maquette) et les horaires affichés sont des exemples à remplacer par les vraies coordonnées. **(v17, toujours à faire)** La réponse à "pourquoi le numéro du commerçant n'est pas visible" doit être nuancée : vrai dans NetBuis, mais le téléphone peut l'afficher pendant et après l'appel, et sur iPhone il apparaît avant l'appel.

## Points à trancher (questions ouvertes, non bloquantes pour avancer)

**A. Qui peut appeler qui, exactement ?** (inchangé)

**B. Produits et publications : même notion, ou deux choses différentes ?** (inchangé)

**C. Définition d'une "zone".** ~~Résolu~~ — étendu en v16 avec la hiérarchie complète (région/département/arrondissement/ville-village/quartier) et la règle de visibilité sur la carte.

**D. Le forum.** ~~Résolu~~ (modération encore ouverte)

**E. "Produits et particuliers très sollicités".** (inchangé)

**F. Comment devient-on membre de l'équipe NetBuis ?** ~~Résolu~~

**G. Montant définitif de la prime de parrainage et seuil de retrait.** ~~Résolu (montant)~~, seuil à confirmer.

**H. Modération du forum / signalement.** Pas abordé — voir aussi le bouton "Signaler" ajouté sur l'écran Aide.

**L. Plafond exact de publications pour un compte non abonné.** ~~Partiellement résolu~~ (chiffre 5 à confirmer).

**M. Liste exacte des secteurs et sous-catégories.** ~~Corrigé en v15~~ — 10 secteurs réellement implémentés (Supermarché/Restauration/Hôtellerie/Santé déplacés vers le type `structure`).

**N. Alignement entre la taxonomie Secteur/SousCategorie/CategorieService/TypeStructure et le filtre de l'écran d'accueil.** (inchangé)

**O. Secteur/sous-catégories obligatoires ou facultatifs pour valider un `BusinessProfile` ?** (inchangé)

**P. Portée exacte du plafond de 3 sous-catégories/produits.** (inchangé)

**Q. Champs additionnels pour une `entreprise` formelle.** ~~Résolu~~ — `forme_juridique` et `rccm` ajoutés.

**R. Frontière entre `Secteur` (établissement fixe) et `prestataire_service` (professionnel indépendant).** ~~Résolu/superseded par v15~~ — restaurant/hôtel/centre de santé/supermarché relèvent désormais du type `structure`, distinct à la fois de `Secteur` et de `prestataire_service`.

**S. Affichage public de la CNI d'un prestataire : badge plutôt qu'image brute.** À confirmer.

**T. Un prestataire de service peut-il déclarer plusieurs catégories de service ?** Hypothèse de travail : une seule. À confirmer.

**U. Redondance du champ "nom" pour Particulier vendeur et Prestataire de service.** ~~Résolu partiellement~~ — texte d'aide ajouté. À confirmer si suffisant.

**V. Renommage "Boutique" → "Commerce".** Décidé. À confirmer que le terme convient localement.

**W. Contenu définitif de la FAQ "Aide & support" et vraies coordonnées de contact.** La FAQ et les coordonnées (téléphone, e-mail) actuelles sont une proposition de départ à ajuster avec le porteur de projet.

**X. Le type `Structure` doit-il aussi avoir un champ "forme juridique" ?** Contrairement à `Entreprise`, la maquette actuelle ne demande pas la forme juridique à une Structure (supermarché, hôtel...), alors que ces établissements peuvent être constitués en société. À trancher : ajouter ce champ (optionnel) à l'écran Structure-Details, ou le considérer secondaire pour ce type de compte.

**Y. (v16) Confirmer l'interprétation de la règle de visibilité de la carte.** La formulation orale du porteur de projet contenait une expression ambiguë ("basé sur ceux qui sont en risque"), interprétée ici comme "ceux qui sont enregistrés" (voir section `Zone`). À confirmer explicitement, de même que l'écran de choix de `Ville_Village`/`Quartier` doit encore être ajouté au parcours de création de compte business (aucun écran dédié aujourd'hui dans la maquette).

**Z. (v16) Instabilité possible du découpage administratif.** Une réforme évoquée dans la presse camerounaise ferait passer le nombre de départements de 58 à 70 et de communes de 360 à 400 avant les élections de décembre — non confirmée officiellement à ce jour. `Zone` doit rester éditable depuis le dashboard admin pour absorber un tel changement sans nouvelle version de l'application.

**AA. (v17) Appel direct : confirmation avant l'appel.** ~~Résolu en v18~~ — le porteur de projet a tranché : l'utilisateur **confirme en choisissant la ligne** sur laquelle il veut lancer l'appel, **Orange ou MTN seulement pour le moment**. Cette feuille sert à la fois de choix de ligne et de garde-fou contre les clics accidentels. Elle est maquettée sur `Main.dc.html` et `Quartier.dc.html`. Reste ouvert (voir `decision-finale-appels.md`) : mémoriser la dernière ligne ou redemander à chaque fois, plafond d'appels par minute/jour, ajout éventuel de Camtel/Nexttel plus tard.

**AB. (v17) Solution pour iOS.** Le numéro est affiché par le système en attendant, et la feuille Orange/MTN ne peut pas y être appliquée. Pistes : VoIP via CallKit (coût par minute, plus un appel opérateur) ou WhatsApp. Pas tranché, le porteur de projet attend une solution.

## Maquettes UX

Un jeu de maquettes a été produit à partir de ce modèle de données, sur la base d'un gabarit de style fourni par le porteur de projet (fond sombre, accent orange) : Lancement, Connexion (téléphone + OTP), Découverte (carousel de 5 vues), Accueil/recherche, Explorer (carte, retouchée en v16 pour la grille région/ville/village), Détail d'un quartier, Forum, Publication, Nouvelle publication, Mes publications, Profil, Historique de mes appels, Aide & support — trois écrans d'un dashboard d'administration web (`dashboard-admin-netbuis.md`) — et huit écrans de création/paramétrage d'un compte business, ramifiés selon le type de compte :

- `CreationBusiness-Infos.dc.html` — cinq types de compte (Commerce / Entreprise / Structure / Particulier / Prestataire), libellé "propriétaire/responsable" adapté à chaque type.
- `CreationBusiness-Entreprise-Forme.dc.html` — forme juridique, Entreprise uniquement.
- `CreationBusiness-Secteur.dc.html` — grille de 10 secteurs (corrigée en v15).
- `CreationBusiness-Details.dc.html` — sous-catégories, plafond de 3, démontré sur quatre secteurs.
- `CreationBusiness-Prestataire-Categorie.dc.html` — catégorie de service + CNI + diplôme.
- `CreationBusiness-Structure-Type.dc.html` (v15) — grille de 5 types d'établissement (Supermarché / Restaurant / Hôtel / Centre de santé / Autre), avec un encart sur la nuance commerciale/sociale.
- `CreationBusiness-Structure-Details.dc.html` (v15) — champs spécifiques par type d'établissement, démontré sur les quatre types via un sélecteur de démo en haut de l'écran.
- `CreationBusiness-Recap.dc.html` — récapitulatif, commun à tous les parcours.
- `Aide.dc.html` — FAQ par thème en accordéon, contact (WhatsApp/téléphone/e-mail), bouton de signalement. Lié depuis `Profil.dc.html`.

**(v18)** `Main.dc.html` et `Quartier.dc.html` : le bouton "Appeler" ouvre désormais la feuille de choix de ligne Orange / MTN (puis "Appel en cours..." et fermeture automatique) — démonstration Android uniquement.

**Pas encore maquetté** : candidature équipe NetBuis, flux de secours de parrainage, secteurs restants dans Détails, fusion éventuelle des champs "nom" pour Particulier/Prestataire (point U), mise à jour visuelle Accueil/Forum/Mes publications pour le tri par abonnement, vraies coordonnées de contact sur l'écran Aide (point W), éventuel champ "forme juridique" pour Structure (point X), écran de sélection précise `Ville_Village`/`Quartier` dans le parcours de création de compte business (point Y). **(v18)** Restent à faire côté appel : la variante iOS du bouton "Appeler" (sans feuille Orange/MTN, avec la confirmation système qui montre le numéro), la réponse FAQ nuancée sur le numéro (`Aide.dc.html`), et la phrase de la promesse de l'Onboarding ("sans que leur numéro ne s'affiche jamais à l'écran") à nuancer.

## Ce qui reste cohérent avec les décisions déjà actées

- Le compteur d'appels gratuits et le solde de crédits s'appliquent au niveau du compte appelant, quel que soit son `type_compte`.
- **(v17, précisé en v18)** Le mécanisme d'appel est celui de `decision-finale-appels.md` v2.1 : appel opérateur classique (pas de Twilio/VoIP), choix de la ligne Orange/MTN puis lancement direct sur Android, confirmation système (avec numéro visible, sans choix de ligne) sur iOS.
- Le solde de parrainage reste distinct du solde de crédits d'appel.
- La vérification OTP par SMS reste le socle commun de confiance ; la vérification de CNI pour un prestataire s'y ajoute comme couche supplémentaire.
- Le classement par abonnement et les plafonds restent cohérents avec le principe que l'abonnement ne bloque jamais la visibilité de base — le même principe s'applique maintenant aux rayons/spécialités d'une Structure.
- La ramification du parcours par type de compte s'inscrit dans le même flux de création déjà décrit ; l'ajout du type `structure` suit exactement le même schéma (un écran de choix, puis un écran de détails, avant le Récapitulatif commun).
- L'ajout de l'écran Aide & support ne change aucune règle métier serveur — c'est un écran d'information et de contact, pas de donnée nouvelle à persister (hormis, éventuellement, un futur signalement — voir point H).
- **(v16)** La règle de visibilité sur la carte ne change rien à la recherche textuelle ni aux règles d'appel déjà actées — elle ne concerne que l'affichage de `Carte.dc.html`.
- **(v18)** Le choix de la ligne Orange/MTN ne change ni le quota d'appels gratuits, ni le décompte de crédits, ni la visibilité du numéro : c'est une information de lancement de l'appel, enregistrée dans `CallLog.operateur`.
