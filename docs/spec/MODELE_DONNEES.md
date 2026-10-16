# Modèle de données et règles métier

## Qui peut faire quoi
- Tout le monde a un **compte** (téléphone vérifié par SMS).
- Un compte peut ouvrir un **compte business** (extension, un seul par compte). Seul un compte business **actif** peut publier des produits et des publications.
- Un compte simple peut : chercher, voir la liste des comptes business, **appeler** un compte business, commenter.
- Un compte simple **ne peut pas appeler** un autre compte simple.
- **NetBuis n'affiche jamais le numéro d'un commerçant.** Il n'est délivré que par `POST /api/calls/initiate/`.

## Entités
**Account** : téléphone (unique, vérifié), nom, langue, `is_admin`, `is_blocked` (+ motif, date), `is_deleted` (+ date) — suppression douce.

**BusinessProfile** (un par compte, au plus) :
- `type_compte` ∈ `boutique` (affiché « Commerce »), `entreprise`, `particulier_vendeur`, `prestataire_service`, `structure`.
- Nom affiché, zone, description, photo, **nom et photo de la personne** qui représente le compte (obligatoires), numéro ancré (jamais exposé), `status` ∈ `en_attente_validation` / `actif` / `rejete`, `motif_rejet`.
- Entreprise : `forme_juridique` ∈ individuelle, sarl, sarlu, sa, gic_cooperative, association, etablissement_public, autre ; `rccm` facultatif.
- Prestataire de service : `categorie_service` (+ texte libre si « Autre »), `cni_photo` **obligatoire** (jamais exposée, jamais affichée en entier), `cni_verifiee` (passe à vrai quand un admin valide), `diplome_photo` facultatif (affichable). Une seule catégorie de service. Pas de secteur ni de sous-catégories.
- Structure : `structure_type` ∈ supermarché, restaurant, hôtel, santé, autre (+ libre) ; détails propres au type (voir plus bas). Pas de secteur.
- Commerce, Entreprise, Particulier vendeur : `secteur` (+ `secteur_libre` si « Autre »), sous-catégories (plafond 3 sans abonnement), `description_activite`.

**Libellés du représentant** : Commerce = « Nom / Photo du propriétaire » · Entreprise = « Nom / Photo du représentant légal » (aide : Gérant, DG, PDG…) · Structure = « Nom / Photo du responsable » (aide : Directeur, gérant…) · Particulier et Prestataire = « Votre nom complet / Votre photo (vérification) » (aide : pour la vérification, peut différer du nom affiché).

**Parcours de création** (linéaire, jamais de menus imbriqués) :
- Commerce / Entreprise / Particulier : Informations → *(Entreprise seulement : Forme juridique)* → Secteur → Détails du secteur → *(lieu précis)* → Récapitulatif.
- Prestataire : Informations → Catégorie de service + CNI + diplôme → *(lieu)* → Récapitulatif.
- Structure : Informations → Type d'établissement → Détails de l'établissement → *(lieu)* → Récapitulatif.

**Zone** : nom, niveau (`pays`, `region`, `departement`, `arrondissement`, `ville_village`, `quartier`, `repere`), parent, code officiel facultatif. Référentiel **modifiable depuis le dashboard** (le découpage administratif peut changer : 10 régions, 58 départements, 360 arrondissements aujourd'hui, réforme possible). Au-dessous de l'arrondissement, les listes ne sont pas officielles : NetBuis les construit et les met à jour.

**Règle de visibilité de la carte** : un commerce n'apparaît sur l'écran Carte que s'il est `actif` **et** rattaché à une `ville_village` ou un `quartier`. Une ville/un village n'est actif que s'il a au moins un tel commerce (directement ou par un quartier enfant). Région et département restent visibles comme repères mais ne sont « explorables » que s'ils contiennent une ville active. À la création, le choix du lieu doit descendre jusqu'à `ville_village` (ou `quartier`). **La recherche textuelle ne dépend pas de cette règle.**

**Secteur** (10) : Alimentation 🍌 · Boutique / Supérette 🏪 · Pharmacie & Santé 💊 · Mode & Beauté 👗 · Électronique & Informatique 💻 · Immobilier 🏠 · Transport & Livraison 🛵 · Agriculture & Élevage 🌾 · Artisanat & Services à domicile 🔧 · Autre ✨.
Sous-catégories connues :
- Alimentation (12) : Fruits, Légumes, Tubercules, Céréales & Légumineuses, Viande/Volaille & Poisson, Produits laitiers & Œufs, Huiles & Graisses, Épices & Condiments, Boissons, Boulangerie & Pâtisserie, Produits surgelés, Autre.
- Boutique / Supérette : Biscuits & Confiseries, Eau & Boissons, Pâtes/Riz & Céréales transformées, Conserves, Produits laitiers emballés, Hygiène & Entretien, Produits pour bébés, Papeterie, Autre.
- Transport & Livraison : Moto-taxi, Taxi, Livraison de colis, Transport de marchandises, Location de véhicule, Déménagement, Autre.
- Artisanat & Services à domicile : Menuiserie, Plomberie, Électricité, Couture, Maçonnerie, Mécanique, Informatique & Réparation, Coiffure & Beauté, Autre.
- Les autres secteurs : **liste à compléter par Jeff** (ne pas inventer ; mettre « Autre »).

**CategorieService** (7) : Enseignement à domicile · Technique & Réparation · Services médicaux indépendants · Beauté & Bien-être à domicile · Juridique & Comptabilité · Événementiel · Autre.

**TypeStructure** (5) : Supermarché 🛒 · Restaurant 🍲 · Hôtel 🏨 · Centre de santé 🏥 · Autre ✨. Un encart explique la nuance : restaurant et hôtel = vocation commerciale ; centre de santé = vocation plutôt sociale.
Détails par type :
- Supermarché : rayons (Alimentation générale, Produits frais, Boissons, Hygiène & Beauté, Entretien & Maison, Bazar & Électroménager, Produits pour bébés, Autre), **3 maximum sans abonnement**.
- Restaurant : cuisine (Camerounaise, Africaine — autre pays, Fast-food, Pizzeria/Occidentale, Autre), livraison oui/non, horaires (texte).
- Hôtel : standing (Économique, Standard, Confort, Haut standing), nombre de chambres, équipements (Petit-déjeuner, Wifi, Parking, Climatisation).
- Centre de santé : numéro d'agrément sanitaire (facultatif), spécialités (Médecine générale, Pédiatrie, Gynécologie, Dentisterie, Laboratoire d'analyses, Pharmacie interne, Autre), **3 maximum sans abonnement**.
- Commun : description libre avec exemple propre au type.

**Product / Offre** : profil, nom, description, photos, prix, compteurs (vues, appels, commandes).
**Post** : profil, type image/vidéo, média, légende, produit associé facultatif, date. **5 actifs maximum sans abonnement.**
**Comment** : post, auteur (tout compte), texte, date.
**CallLog** : appelant, profil appelé, date, type (gratuit / crédit / whatsapp), `plateforme` (android/ios), `operateur` (orange/mtn/null). Créé quand le serveur délivre le numéro : « un appel a été **lancé** », pas « le commerçant a décroché ».
**Subscription** : profil, période, statut `actif`/`expiré`/`impayé`, dates. Avantages tant qu'actif : priorité d'affichage, publications illimitées, sous-catégories illimitées. **L'abonnement ne conditionne jamais la visibilité de base.**
**Order**, **Referral**, équipe NetBuis : voir backlog V01–V02 (reportés).

## Règles à faire respecter par le serveur (jamais seulement par l'écran)
1. Appels réservés aux profils `actif` non bloqués.
2. Un compte `is_blocked` ne peut ni se connecter ni être appelé ni apparaître dans la recherche. Un compte `is_deleted` est retiré partout, ses données restent.
3. Plafonds : 3 sous-catégories (et rayons, spécialités), 5 publications ; la 4ᵉ/6ᵉ est refusée avec `SUBSCRIPTION_REQUIRED`. Un abonnement expiré ne supprime rien.
4. Tri des résultats : abonnés d'abord, les autres toujours listés.
5. Champs obligatoires et interdits selon `type_compte`.
6. `cni_photo` jamais renvoyée à l'application ; seul un admin la consulte (URL temporaire).
7. Le numéro n'est dans aucune réponse de recherche, carte, liste, fiche ou profil, ni dans un log.
8. L'envoi des appels applique une limite par compte (anti-aspiration).
