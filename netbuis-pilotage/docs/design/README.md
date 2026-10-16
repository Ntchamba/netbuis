# Maquettes NetBuis — guide pour les agents « front »

Les 24 écrans HTML et `canvas.json` sont dans `docs/design/maquettes/`.
Ce sont des **maquettes cliquables** (format `.dc.html`, syntaxe `{{variable}}`) : on les **ouvre dans un navigateur** ou on lit leur source pour voir la structure, les textes, les couleurs et les états. On ne les copie pas telles quelles dans le code : on les **reproduit** en Flutter (mobile) ou en React (dashboard).

## Règle d'or

> **Les maquettes l'emportent sur tout texte qui les contredit** (couleurs, libellés, onglets, ordre des écrans, champs), sauf si `docs/DECISIONS_JEFF.md` dit autrement.
> Si un écran n'est pas maquetté, l'agent applique les principes de `docs/spec/ACCESSIBILITE.md` et les jetons ci-dessous, puis le signale dans son rapport (« écran non maquetté : choix fait = … »).

## Jetons visuels (extraits des maquettes)

| Jeton | Sombre (défaut) | Clair |
|---|---|---|
| Fond | `#0D0D0F` | `#F7F7F8` |
| Carte / surface | `#1B1B1E` | blanc |
| Bordure | `#2A2A2E` | gris très clair |
| Texte principal | `#FFFFFF` | quasi noir |
| Texte secondaire | `#9A9A9E` | gris moyen |
| **Accent** | **`#F2942E` (orange)** | identique |
| Texte sur accent | `#1A1200` | identique |

- Logo-texte : `NET` en couleur de texte + `BUIS` en accent, graisse 800.
- Cadre mobile : 390 × 844. Cadre dashboard : 1440 × 900.
- Bouton d'action : fond accent, texte `#1A1200`, rayon 12–14 px, icône + mot.
- Barre du bas (4 onglets, icône + mot) : **Accueil · Carte · Forum · Profil**. L'onglet actif est en accent.
- **Thème clair (D-20)** : l'accent `#F2942E` ne contraste que 2,2:1 sur le fond clair. Texte et icônes d'accent y utilisent `#A85A00` (4,75:1) et le texte secondaire `#6B6B70` ; les boutons gardent le fond `#F2942E` avec le texte `#1A1200` (8:1).
- Bascule clair / sombre : le thème est une propriété de la maquette ; l'application suit le réglage du téléphone et propose une bascule dans Profil.
- Les maquettes proposent d'autres couleurs d'accent (ex. turquoise `#2EC4B6`) **uniquement comme options d'édition** : l'accent officiel est l'orange.

## Correspondance écran → tâche du backlog

| Maquette | Contenu clé | Tâches (`docs/BACKLOG.md`) |
|---|---|---|
| `Splash` | Logo, slogan, bouton Commencer, version | T010 |
| `Onboarding` | 5 diapositives, Passer / Suivant | T010 |
| `Connexion` | Numéro +237, code SMS, Renvoyer le code | T011 |
| `Main` | Recherche écrite + micro, puces de catégorie (qui s'enroulent, pas de défilement), résultats, bannières « Aidez NetBuis à grandir », feuille Orange / MTN | T040–T046, T052 |
| `Carte` | Villes/villages actifs, bascule Carte / Liste, quartiers | T060–T062 |
| `Quartier` | Liste des commerçants d'un quartier + appel | T062 |
| `Forum` | Fil des publications | T090–T093 |
| `Publication` | Une publication + commentaires | T092 |
| `Publier` | Photo ou vidéo, légende, produit associé | T091 |
| `MesPublications` | Mes publications | T091 |
| `Profil` | Numéro vérifié, appel gratuit du jour, solde, compte business, langue, aide, déconnexion | T102 |
| `Historique` | Appels passés | T053 |
| `Aide` | FAQ en accordéon + écoute, contact, signalement | T101 |
| `CreationBusiness-Infos` | 5 types de compte, libellés adaptés | T030 |
| `CreationBusiness-Entreprise-Forme` | Forme juridique + RCCM | T030 |
| `CreationBusiness-Secteur` | 10 secteurs | T031 |
| `CreationBusiness-Details` | Sous-catégories, plafond de 3, « Autre » | T031, T111 |
| `CreationBusiness-Prestataire-Categorie` | Catégorie de service, CNI, diplôme | T032 |
| `CreationBusiness-Structure-Type` | Supermarché / Restaurant / Hôtel / Centre de santé / Autre | T033 |
| `CreationBusiness-Structure-Details` | Champs propres à chaque type | T033 |
| `CreationBusiness-Recap` | Récapitulatif, envoi, écran « Demande envoyée » | T035 |
| `Dashboard-Vue` | Chiffres, demandes récentes, équipe, abonnements | T081 |
| `Dashboard-Demandes` | 2 onglets, pièces, Valider / Rejeter avec motif | T082 |
| `Dashboard-Comptes` | Liste filtrable, Bloquer / Supprimer / Restaurer | T083 |

## Écrans à créer SANS maquette (à traiter avec les jetons ci-dessus)

Choix de la ville / du village / du quartier dans la création de compte business (T035) · version iOS du bouton Appeler · écran « Équipe & abonnements » du dashboard · pages dashboard Forum, Paramètres, Référentiels, Audit, Administrateurs · réglages (langue, thème). Chaque tâche concernée le rappelle.

## Rappels qui viennent des maquettes (à ne pas casser)

- Aucun numéro de téléphone de commerçant n'apparaît dans un écran, jamais.
- Aucune rangée à défilement horizontal : les grilles passent à la ligne.
- Chaque choix de catégorie = icône + mot court.
- Le dashboard n'est pas concerné par les principes d'accessibilité (outil interne, texte classique).
- Le texte de l'Onboarding « sans que leur numéro ne s'affiche jamais à l'écran » doit être nuancé (voir D-07 dans `docs/DECISIONS_JEFF.md`).
