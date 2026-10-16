# Dashboard d'administration (web, interne)

## Fonctions
1. Liste de tous les comptes (recherche, filtres statut / zone / type).
2. File des **demandes de compte business** : l'admin voit le dossier (photos ; pour un prestataire, CNI et diplôme) et **valide** (le compte devient `actif`, et `cni_verifiee=true` pour un prestataire) ou **rejette avec motif**.
3. *(v1.1)* File des candidatures à l'équipe NetBuis (vidéo CNI).
4. Vue détaillée d'un compte.
5. **Blocage / déblocage** (accès suspendu, données gardées). 6. **Suppression douce** et restauration. 7. Suivi des abonnements. 8. *(v1.1)* Performance de l'équipe.
Maquettes : `Dashboard-Vue`, `Dashboard-Demandes`, `Dashboard-Comptes`. Navigation : Vue d'ensemble · Demandes (pastille) · Comptes · Équipe & abonnements.

## Rôles (RBAC, Groupes Django)
- `is_admin=True` donne accès au dashboard ; le **groupe** détermine les actions. Sans `is_admin`, aucun accès, quel que soit le groupe.
- **Validateur** : voit Demandes, valide/rejette un dossier, consulte les comptes en lecture. **Ne peut pas** bloquer, supprimer, changer les réglages, gérer les admins.
- **Administrateur complet** : tout, plus bloquer/débloquer/supprimer, modifier les `PlatformSetting`, exporter, attribuer/retirer les rôles.
- Premier admin créé en ligne de commande ; les suivants **depuis le dashboard**, jamais par auto-inscription.
- Idée future : rôle « modérateur du forum » (pas en v1).

## Entités
- `AuditLog` : admin auteur, type d'action (`validation_business`, `rejet_business`, `blocage_compte`, `deblocage_compte`, `suppression_compte`, `restauration_compte`, `attribution_role`, `retrait_role`, `modification_reglage`, `accord_abonnement`, `moderation_contenu`…), cible, **motif obligatoire pour rejet, blocage, suppression**, date.
- `PlatformSetting` : clé, valeur, modifié par, date. Clés : `seuil_appels_abonnement`, `plafond_publications_non_abonne`, `plafond_sous_categories_non_abonne`, `limite_appels_par_minute`, `limite_appels_par_jour`.
- `Subscription` (voir modèle de données).

## Abonnement
- Optionnel : ne conditionne jamais la visibilité d'un compte actif.
- Trois avantages : priorité d'affichage, publications illimitées, sous-catégories illimitées.
- Seuil d'appels quotidiens : au-delà, l'application **propose** un abonnement (jamais de blocage des appels reçus). **La valeur n'est pas choisie** (D-11).
- Le paiement de l'abonnement est reporté ; en v1 l'abonnement est accordé à la main par un Administrateur complet.

## Règles serveur
Seul un compte `is_admin` (selon son groupe) peut valider/rejeter/bloquer/supprimer ; rejet/blocage/suppression sans motif refusés ; la CNI n'est jamais servie à l'app ; un admin ne se bloque pas lui-même.
