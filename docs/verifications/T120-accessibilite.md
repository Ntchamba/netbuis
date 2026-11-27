# T120 — Accessibilité des écrans mobiles (résumé)
Verdict : **59 écrans / états audités**, 1687 tests mobile verts dont 537 d'accessibilité ; `flutter analyze` sans problème. Grille complète : `logs/T120-audit-accessibilite.md` (non versionné) ; tests : `mobile/test/accessibility/`.

- 360 px, polices ×1,0 / ×1,3 (×2,0 pour 6 écrans critiques), clair + sombre : aucun débordement, aucun défilement horizontal, cibles ≥ 48 dp, étiquettes, contraste ≥ 4,5:1, claviers numériques (téléphone, code SMS, prix, chambres).
- Corrigé (7 familles de défauts) : Accueil trop chargé en grande police (X1) ; cibles de 44 dp (X2) ; zone touchable du Forum sans étiquette (X3) ; contrastes en clair — boutons-texte, curseur, rouge d'erreur, badges (X4) ; débordements de la grille des secteurs, des photos produit et des lignes de réglages (X5) ; boutons sans icône sur écrans sans maquette (X6) ; **photos de la fiche publique qui défilaient horizontalement** (X7).
- Dérogations (maquette qui l'emporte ou donnée à fournir) : D1 à D8 dans la grille. À faire relire par Jeff : rouge d'erreur clair `#C93E28` et fond `#FEF3E2` des badges (extension de D-20).

## Principes × écrans (C conforme · X# corrigé · D# dérogation · – sans objet)
Légende : **C** conforme · **X#** corrigé (voir « Corrections ») · **D#** dérogation justifiée (voir « Dérogations ») · **–** sans objet pour cet écran (le principe ne s'applique pas : pas d'action, de catégorie, de nombre… à cet endroit).

Principes : P1 icône + mot court · P2 recherche vocale · P3 appel en un geste, jamais de numéro · P4 choix visuels plutôt que texte libre · P5 statut par couleur/icône · P6 phrases courtes · P7 navigation icône + mot · P8 photos plutôt que texte · P9 étapes visibles, structure linéaire · P10 écoute à voix haute · P11 pas de défilement horizontal · P12 chiffres plutôt que texte · P13 relais humain visible.

| Écran | Liste | P1 | P2 | P3 | P4 | P5 | P6 | P7 | P8 | P9 | P10 | P11 | P12 | P13 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Splash | spec | D1 | – | – | – | – | C | – | – | – | – | C | – | – |
| Onboarding | spec | D1 | – | – | – | – | C | – | C | – | D4 | C | – | – |
| Connexion | spec | D1 | – | – | C | C | C | – | – | – | – | C | C | – |
| Connexion : code SMS | spec | D1 | – | – | C | C | C | – | – | – | – | C | C | – |
| Carte | spec | D2 | – | – | C | – | C | C | – | – | – | C | C | – |
| Quartier | spec | C | – | C | C | C | C | C | – | – | – | C | C | – |
| Historique | spec | C | – | – | – | C | C | C | – | – | – | C | C | – |
| MesPublications | spec | C | – | – | – | C | C | C | C | – | – | C | – | – |
| Profil | spec | D1 X6 | – | – | – | C | C | C | – | – | – | C | – | C |
| Forum | spec | C | – | – | – | – | C | C | C | – | – | C | C | – |
| Création : Entreprise-Forme | spec | D2 | – | – | C | – | C | – | – | C | – | C | – | – |
| Création : Secteur | spec | C | – | – | C | – | C | – | – | C | – | C | – | – |
| Création : Prestataire-Catégorie | spec | C | – | – | C | – | C | – | C | C | – | C | – | – |
| Création : Structure-Type | spec | C | – | – | C | – | C | – | – | C | – | C | – | – |
| Création : Structure-Détails | spec | D2 | – | – | C | C | C | – | – | C | – | C | C | – |
| Création : Détails | spec | D2 | – | – | C | – | C | – | – | C | – | C | C | – |
| Création : Récap | spec | C | – | – | – | C | C | – | C | C | – | C | – | – |
| Création : Informations | maquette | C | – | – | C D3 | C | C | – | C | C | C | C | – | – |
| Création : Envoyé | maquette | D1 | – | – | – | C | C | – | – | – | – | C | – | – |
| Accueil | maquette | C X6 | C | C | C | C | C | C | – | – | – | C X1 | C | D7 |
| Nom (1re connexion) | sans maquette | X6 | – | – | D3 | – | C | – | – | – | – | C | – | – |
| Création : Informations (entreprise) | maquette | C | – | – | C D3 | C | C | – | C | C | C | C | – | – |
| Création : Informations (prestataire) | maquette | C | – | – | C D3 | C | C | – | C | C | C | C | – | – |
| Création : Structure-Détails (supermarché) | maquette | D2 | – | – | C | C | C | – | – | C | – | C | C | – |
| Création : Structure-Détails (hôtel) | maquette | D2 | – | – | C | C | C | – | – | C | – | C | C | – |
| Création : Structure-Détails (santé) | maquette | D2 | – | – | C | C | C | – | – | C | – | C | C | – |
| Création : Récap (commerce) | maquette | C | – | – | – | C | C | – | C | C | – | C | – | – |
| Création : Récap (prestataire) | maquette | C | – | – | – | C | C | – | C | C | – | C | – | – |
| Création : Récap (restaurant) | maquette | C | – | – | – | C | C | – | C | C | – | C | – | – |
| Création : Récap (hôtel) | maquette | C | – | – | – | C | C | – | C | C | – | C | – | – |
| Choix de ville | sans maquette | C | – | – | C | – | C | – | – | – | – | C | – | – |
| Choix du lieu : ville | sans maquette | C | – | – | C | – | C | – | – | C | – | C | – | – |
| Choix du lieu : quartier | sans maquette | C | – | – | C | – | C | – | – | C | – | C | – | – |
| Recherche | sans maquette | C X6 | C | C | C | C | C | – | – | – | – | C | C | – |
| Recherche : aucun résultat | sans maquette | C X6 | C | C | C | C | C | – | – | – | – | C | C | – |
| Accueil : aucun résultat | sans maquette | C X6 | C | C | C | C | C | C | – | – | – | C X1 | C | D7 |
| Accueil : erreur réseau | sans maquette | C X6 | C | C | C | C | C | C | – | – | – | C X1 | C | D7 |
| Filtres | sans maquette | X6 | – | – | C | – | C | – | – | – | – | C | – | – |
| Secteurs (Accueil) | sans maquette | C | – | – | C | – | C | – | – | – | – | C X5 | – | – |
| Fiche publique | sans maquette | C | – | C | – | C | C | C | C | – | – | X7 | – | C |
| Fiche publique : 3 photos, nom long | sans maquette | C | – | C | – | C | C | C | C | – | – | X7 | – | C |
| Fiche publique : restaurant | sans maquette | C | – | C | – | C | C | C | C | – | – | X7 | – | C |
| Forum : publication | sans maquette | C | – | – | – | C | C | C | C | – | – | C | C | – |
| Forum : publier | sans maquette | D1 | – | – | C | – | C | C | C | – | – | C | C | – |
| Modifier ma boutique | sans maquette | X6 | – | – | C D3 | C | C | C | C | – | – | C | – | – |
| Profil : boutique active (abonnement proposé) | sans maquette | D1 X6 | – | – | – | C | C | C | – | – | – | C | – | C |
| Profil : boutique refusée | sans maquette | D1 X6 | – | – | – | C | C | C | – | – | – | C | – | C |
| Profil : boutique en attente | sans maquette | D1 X6 | – | – | – | C | C | C | – | – | – | C | – | C |
| Mes produits | sans maquette | C | – | – | – | C | C | C | D8 | – | – | C | C | – |
| Mes produits : ajouter | sans maquette | X6 | – | – | C D3 | – | C | – | C | – | – | C | C | – |
| Fiche publique : choix de la ligne | sans maquette | C | – | C | C | C | C | – | – | – | – | C | – | – |
| Fiche publique : signaler (fenêtre) | sans maquette | C | – | – | C | C | C | – | – | – | – | C | – | – |
| Abonnement : bientôt | sans maquette | C | – | – | – | C | C | – | – | – | – | C | – | C |
| Aide | sans maquette | C | – | – | C | – | C | C | – | – | C | C | – | C |
| Réglages | sans maquette | C | – | – | C | C | C | C | – | – | – | C | – | – |
| À propos | sans maquette | C | – | – | – | – | C D5 | C | – | – | – | C | – | – |
| Mentions légales | sans maquette | C | – | – | – | – | C D5 | C | – | – | C | C | – | – |
| Conditions | sans maquette | C | – | – | – | – | C D5 | C | – | – | C | C | – | – |
| Confidentialité | sans maquette | C | – | – | – | – | C D5 | C | – | – | C | C | – | – |

## Corrections
| N° | Défaut relevé par le harnais (écran, taille) | Correction | Preuve |
|---|---|---|---|
| X1 | **Accueil** : à police ×1,3, la zone des résultats tombait à 0 px (en-tête + puces + encart pris tout l'écran) et débordement de 21 px ; à ×2,0 le logo débordait de 40 px et la carte de résultat de 36 px ; le message d'erreur ne défilait pas (débordement de 9 px vu en cas de petite zone) | Dès 115 % de police, l'encart « Aidez NetBuis » défile avec les résultats au lieu de rester collé en bas ; logo réduit au lieu de déborder (`NetBuisLogo` : `FittedBox`) ; « Appeler » / « WhatsApp » l'un sous l'autre dès 150 % ; message d'erreur / vide défilant | `Accueil · … · police ×1.3 / ×2.0`, `Accueil : erreur réseau · … · ×2.0` |
| X2 | Cibles tactiles de 44 dp : onglets **Carte / Liste**, « **Inviter** » (Accueil), **puces de secteur**, « Retirer » des photos produit | 48 dp ; marges de l'Accueil réduites de 8 dp au total pour que la zone des résultats garde sa hauteur | `Carte · … · 780 px`, `Accueil · … · 780 px`, `Mes produits : ajouter` |
| X3 | **Forum** : la zone photo/vidéo de chaque publication était touchable sans étiquette | Étiquette « Ouvrir la publication » (clé `forum.card.open`, fr + en) | `Forum · … · 780 px` (étiquettes) |
| X4 | **Contraste en thème clair** : boutons-texte en orange vif (« Passer » 2,17:1) ; curseur orange (2,2:1) ; texte d'erreur `#D1452F` sur le fond (4,26:1) ; badge WhatsApp de l'Historique (3,89:1) ; badge « Appel » (4,21:1) et étiquette produit du Forum (3,87:1) | Thème : boutons-texte et curseur en `accentText` (`#A85A00`, D-20) ; erreur claire `#C93E28` (4,67:1) ; badge WhatsApp `#1A7A34` (4,77:1) ; badge « Appel » et étiquette produit : texte `accentText` sur fond `#FEF3E2` (4,64:1) | `contrast_tokens_test.dart` (42 paires) ; `Nom (1re connexion) · clair` |
| X5 | Débordements à police agrandie : **grille des secteurs** (5 px à ×1,3), **ajout de photo produit** (42 px à ×1,3), lignes de **Réglages / Profil** avec valeur (21 px à ×2,0) | Cases de grille qui grandissent avec la police ; case photo en hauteur minimale ; valeur de ligne repliable | `Secteurs (Accueil) · ×1.3`, `Mes produits : ajouter · ×1.3`, `Profil · ×2.0` |
| X6 | Principe 1 sur des écrans sans maquette : boutons en mots seuls | Icône ajoutée : « Réessayer » (Accueil, Profil), « Changer de ville », « Voir les résultats », « Enregistrer » (Modifier ma boutique, produit), « Continuer » (saisie du nom), « Supprimer mon compte » | `Accueil : erreur réseau`, `Recherche : aucun résultat`, `Filtres`, `Modifier ma boutique`, `Mes produits : ajouter` |
| X7 | **Fiche publique** : les photos du commerce défilaient **horizontalement** (bande de photos) — non vu avec la fiche de démonstration, qui n'a pas de photo | Photo seule en pleine largeur ; plusieurs photos en grille de 2 colonnes qui passe à la ligne (`PhotoGallery`) | `Fiche publique : 3 photos, nom long · … · ×1.0` (échoue avec l'ancien code : « défilement horizontal trouvé ») |

## Dérogations
| N° | Dérogation | Justification |
|---|---|---|
| D1 | Boutons principaux en mots seuls (« Continuer », « Commencer », « Suivant », « Publier ma demande », « Se déconnecter », « Retour à l'accueil »…) | Les maquettes les dessinent sans icône (la maquette l'emporte) ; ce sont des verbes courts, en bouton pleine largeur à l'accent. |
| D2 | Choix en mots seuls : forme juridique (SARL, GIC…), sous-catégories (Fruits, Légumes…), cuisine, standing, équipements, rayons, spécialités ; onglets « Carte / Liste » | Les maquettes n'ont pas d'icône pour ces choix (sigles ou listes longues, difficiles à illustrer) ; l'état choisi se voit par la coche/le bouton rond **et** la couleur, pas par le texte seul. |
| D3 | Champs de texte libre (nom, repère, description, RCCM, prénom) | Saisie obligatoire de l'inscription, prévue par les maquettes ; la dictée vocale des champs libres est un point ouvert de la spec (hors T120). |
| D4 | Textes longs sans bouton « Écouter » (Découverte, notes de création, feuille d'appel…) | « Écouter » existe sur Informations, Aide et pages légales ; les maquettes n'en prévoient pas ailleurs. À proposer à Jeff. |
| D5 | Pages « À propos / Mentions / Conditions / Confidentialité » : texte provisoire « À REMPLACER » | Texte juridique à fournir par Jeff (D-06) ; la mise en page et le bouton « Écouter » sont prêts. |
| D6 | `textContrastGuideline` ne mesure pas le texte posé sur une photo et se trompe quand un champ est à moitié caché sous le bouton collant | Contraste mesuré seulement « tout déplié » (4000 px) ; les couleurs fixes des écrans (badges, encart, carte schématique, lignes Orange/MTN) sont contrôlées par calcul dans `contrast_tokens_test.dart`. |
| D7 | Relais humain absent de l'Accueil (P13) ; boutons de contact du support grisés tant que les coordonnées sont `À REMPLACER` | Point ouvert de la spec (raccourci « parler à quelqu'un » sur l'Accueil) ; coordonnées à fournir par Jeff (D-06). Le relais reste dans Profil → Aide & support. |
| D8 | Mes produits : pas de vignette photo dans la liste (icône seulement) | Une photo déjà enregistrée n'a pas d'adresse d'affichage côté serveur (limite connue de T081) ; la photo se voit quand on la rajoute. |
