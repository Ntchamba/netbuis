# Dashboard d'administration NetBuis — fonctionnalités et modèle de données

Date : 2026-10-04 (v7 — rôles d'administration RBAC, résolution des points I et J)

## Pourquoi ce document

Le porteur de projet a décrit un dashboard d'administration web, séparé de l'application mobile, utilisé par l'équipe NetBuis en interne. Ce dashboard donne en fait une interface concrète à plusieurs processus déjà mentionnés dans `modele-donnees-netbuis.md` mais jamais détaillés côté outillage : qui valide un `BusinessProfile` en attente, qui examine une vidéo de CNI pour une candidature équipe, qui peut bloquer ou supprimer un compte. Ce document formalise ce dashboard comme une surface à part entière du produit.

## Fonctionnalités demandées

1. **Liste de tous les comptes créés**, avec recherche/filtre (par statut, par ville/zone, par type de compte).
2. **File d'attente des demandes de compte business** (`BusinessProfile.status = en_attente_validation`) : l'admin consulte le dossier (photo du propriétaire, photo de la boutique, informations saisies) et valide ou rejette. C'est cette validation qui rend le compte effectif (`status = actif`) — conforme à ce qui est déjà décrit dans `modele-donnees-netbuis.md`. **Depuis cette version, pour un `BusinessProfile` de type `prestataire_service`, ce même dossier inclut aussi la photo de la CNI et, si fournie, du diplôme** (voir section dédiée ci-dessous) : pas de file d'attente séparée, le même écran "Demandes" suffit.
3. **File d'attente des candidatures à l'équipe NetBuis** (`Account.equipe_status = en_attente_validation`) : l'admin visionne la vidéo de la CNI, vérifie qu'elle n'est pas générée par IA ou frauduleuse, et valide ou rejette.
4. **Vue détaillée du profil de n'importe quel compte** (simple, business, équipe NetBuis, ou combinaison) depuis la liste.
5. **Blocage d'un compte** par l'administrateur — l'accès est suspendu sans supprimer les données.
6. **Suppression d'un compte** par l'administrateur.
7. **Suivi des abonnements mensuels** : quels comptes business sont à jour de paiement, lesquels ne le sont pas.
8. **Performance de l'équipe NetBuis** : pour chaque membre, le nombre de comptes business qu'il a fait enregistrer, et la répartition par ville/zone.

## Décisions prises avec le porteur de projet

**L'abonnement mensuel est optionnel, pas une condition de visibilité.** Un `BusinessProfile` validé reste listé et appelable gratuitement, indéfiniment — cohérent avec tout l'effort de vérification déjà en place (photo, revue humaine) : il serait incohérent de faire passer un commerçant par ce processus puis de le masquer faute de paiement.

**Les avantages concrets de l'abonnement sont désormais au nombre de trois** (voir section dédiée ci-dessous) : priorité d'affichage dans les résultats, publications illimitées, et déclaration illimitée de sous-catégories/produits. Documentés en détail dans `modele-donnees-netbuis.md`, résumés ici pour la cohérence du dashboard.

## Vérification de la CNI pour un compte "Prestataire de service" (nouveau)

`modele-donnees-netbuis.md` (v11) ajoute un quatrième type de compte business, `prestataire_service` (technicien, enseignant à domicile, professionnel de santé indépendant...), qui doit fournir une photo de sa CNI (obligatoire) et peut fournir un diplôme/certificat (optionnel) à l'étape de paramétrage de son compte.

**Décision retenue : pas de nouvelle file d'attente dédiée.** La photo de CNI et le diplôme éventuel sont simplement deux pièces supplémentaires du même dossier `BusinessProfile.status = en_attente_validation` déjà traité dans l'onglet "Demandes" du dashboard — au même titre que la photo du propriétaire et la photo de la boutique pour les autres types de compte. L'admin qui valide ou rejette une demande voit ces pièces quand le type de compte est `prestataire_service`.

**Ce que la validation déclenche en plus pour ce type de compte** : quand l'admin valide le dossier (`status` passe à `actif`), il confirme du même geste que la CNI a été examinée, ce qui fait passer `BusinessProfile.cni_verifiee` à `true`. C'est ce booléen — pas la photo elle-même — qui conditionne l'affichage d'un badge "✓ Identité vérifiée par NetBuis" sur le profil public du prestataire (voir le raisonnement complet sur la confidentialité de la CNI dans `modele-donnees-netbuis.md`, point S). **La photo de la CNI elle-même n'est jamais exposée à l'application cliente pour affichage** — elle reste consultable uniquement depuis ce dashboard, par un compte `is_admin = true`, le temps de la revue.

**Point à trancher (nouveau)** : faut-il un motif de rejet spécifique pour une CNI jugée invalide ou suspecte (distinct du motif générique déjà utilisé pour un rejet de `BusinessProfile`), pour garder une trace plus précise dans `AuditLog` ? Pas tranché, proposition simple pour l'instant : réutiliser le champ `motif` déjà existant pour `rejet_business`, avec un texte libre du type "CNI illisible ou suspectée frauduleuse".

## Rôles d'administration (RBAC) — résolution des points I et J (nouveau, v7)

Les points I ("comment devient-on administrateur du dashboard ?") et J ("faut-il plusieurs niveaux d'admin ?") sont restés ouverts depuis la v5. Une recherche sur les méthodes standards de gestion de comptes administrateurs pour ce type de marketplace (voir `recherche-technique-ux-netbuis.md`, section 4) a identifié le pattern **RBAC** (Role-Based Access Control) comme réponse standard, directement actionnable grâce au système de groupes/permissions déjà intégré à Django — pas besoin de bibliothèque tierce pour un besoin de cette taille.

### Décision retenue : deux rôles pour démarrer

**Rôle "Validateur"**
- Accède à l'onglet "Demandes" : peut consulter, valider ou rejeter un dossier `BusinessProfile` en attente (y compris les pièces CNI/diplôme d'un `prestataire_service`), et une candidature à l'équipe NetBuis.
- Accède à la liste des comptes en lecture (recherche, consultation de profil), mais **ne peut pas** bloquer, débloquer ou supprimer un compte.
- N'a pas accès aux réglages de plateforme (`PlatformSetting` — seuils, plafonds) ni à la gestion des autres comptes admin.
- Cas d'usage : un membre junior de l'équipe NetBuis chargé du traitement courant des dossiers, sans droit de bloquer ou de modifier la configuration de l'app.

**Rôle "Administrateur complet"**
- Tout ce que fait le rôle Validateur, plus : bloquer/débloquer un compte, supprimer un compte, modifier les `PlatformSetting` (seuils d'appels, plafonds de publications/sous-catégories), exporter les données, et **attribuer/retirer le rôle Validateur ou Administrateur complet à un autre compte**.
- Cas d'usage : le porteur de projet lui-même et toute personne de confiance à qui il délègue la responsabilité complète du dashboard.

**Comment c'est techniquement porté (Django)** : `Account.is_admin` reste le booléen qui conditionne l'accès au dashboard lui-même (inchangé) ; l'appartenance à un `Group` Django ("Validateur" ou "Administrateur") détermine ensuite ce que ce compte admin peut faire une fois dans le dashboard, via les permissions standards de Django associées à chaque action (`peut_valider_demande`, `peut_bloquer_compte`, `peut_modifier_reglages`, `peut_gerer_admins`...). Un compte peut en théorie appartenir aux deux groupes, mais en pratique "Administrateur complet" inclut déjà toutes les permissions de "Validateur" — pas besoin de cumuler les deux groupes pour une même personne.

**Qui devient administrateur (point I)** : **décision retenue, à confirmer** — le premier compte Administrateur complet est créé manuellement (par le porteur de projet ou l'équipe technique, en base, au lancement du dashboard — pas via un formulaire d'inscription public). Tout administrateur supplémentaire, Validateur comme Administrateur complet, est ensuite créé **depuis le dashboard lui-même**, par un compte déjà Administrateur complet — jamais par auto-inscription. C'est le pattern standard pour ce type d'outil interne : pas de parcours "devenir admin" côté app mobile.

**Ce que ça ne change pas** : les règles métier déjà actées (un rejet/blocage/suppression exige un motif dans `AuditLog`, seul un compte `is_admin = true` peut toucher au dashboard) restent valables — le RBAC vient préciser *lequel* des deux rôles peut faire *quoi*, pas remettre en cause ces règles de fond.

**Reste ouvert** : une troisième nuance de rôle sera-t-elle nécessaire plus tard (ex. un rôle "modérateur du forum" une fois la file de modération construite, voir point M) ? Pas tranché — les deux rôles ci-dessus couvrent déjà tout ce qui est demandé aujourd'hui ; un rôle supplémentaire pourra être ajouté sans tout redessiner, puisque le système de `Group`/permissions Django est conçu pour ça.

## Déclenchement de la proposition d'abonnement : seuil d'appels quotidiens (mécanisme validé, valeur non confirmée)

Le mécanisme lui-même est acté : tant qu'un compte business reste sous un certain seuil d'appels par jour, l'application ne lui demande rien. Au-delà, l'application lui propose de souscrire à un abonnement. C'est un mécanisme d'incitation, pas une restriction : un compte au-delà du seuil continue de recevoir ses appels normalement, même s'il ne souscrit pas. L'idée est qu'un compte qui reçoit beaucoup d'appels a manifestement une forte demande, et est donc le candidat le plus naturel pour un abonnement payant.

**Important — correction par rapport à une version précédente de ce document :** le chiffre de **10 appels/jour**, évoqué au départ, n'a servi qu'à illustrer comment le mécanisme doit fonctionner. Le porteur de projet a explicitement précisé qu'il ne s'agit pas d'une valeur confirmée. **Le seuil exact reste donc à définir** — ce document ne doit pas être lu comme figeant 10 comme valeur de départ.

**Ce que je propose concrètement :**

- Le seuil reste réglable depuis le dashboard admin via `PlatformSetting`, pour pouvoir l'ajuster sans nouvelle version de l'application une fois une première valeur choisie, ou si l'équipe NetBuis constate qu'elle est mal calibrée.
- Le compte des appels se fait simplement en comptant les lignes `CallLog` du jour pour un `BusinessProfile` donné — pas besoin d'un nouveau compteur dédié, une requête sur les données déjà prévues suffit.
- Quand un compte business franchit le seuil un jour donné, l'application mobile lui montre une proposition dans son propre espace (écran Profil, sur le modèle de la bannière déjà construite pour la croissance du réseau) : quelque chose comme "Vous recevez beaucoup d'appels — un abonnement NetBuis peut vous donner plus de visibilité." Ce n'est qu'une proposition, jamais un blocage.
- Le dashboard admin donne aussi une vue sur ces comptes à fort trafic non abonnés (déjà présente dans la Vue d'ensemble) — utile comme liste de prospects pour une éventuelle relance commerciale, en plus du déclenchement automatique côté application.
- Tant que la valeur exacte n'est pas choisie, les maquettes et ce document utilisent un chiffre à titre d'exemple uniquement.

**Point important à distinguer** : ce seuil d'appels n'est qu'**un** des déclencheurs de proposition d'abonnement. L'écran de paramétrage du secteur d'activité (`CreationBusiness-Details.dc.html`) en déclenche un second, indépendant, quand un compte non abonné tente de déclarer un 4e produit/sous-catégorie. Les deux mécanismes coexistent et ne s'excluent pas.

## Les trois avantages concrets de l'abonnement (point L résolu pour l'essentiel)

Le porteur de projet a précisé trois avantages concrets, qui répondent au point L resté ouvert :

**1. Priorité d'affichage.** Dans les résultats de recherche et l'exploration par zone, un compte business abonné apparaît **avant** les comptes non abonnés. Les non-abonnés restent toujours listés, jamais masqués — mais systématiquement en bas de liste.

**2. Publications illimitées.** Un compte business sans abonnement actif est plafonné dans son nombre de `Post` actifs ; un compte abonné peut publier sans limite. **Je propose un plafond de 5 publications actives** pour un compte non abonné (à confirmer). Si un abonnement expire alors que le compte a plus de publications que ce plafond, je recommande de ne pas les supprimer rétroactivement.

**3. Déclaration illimitée de sous-catégories/produits.** À l'étape de paramétrage du secteur d'activité, un compte business non abonné peut sélectionner **jusqu'à 3** sous-catégories/produits — au-delà, la 4e sélection est bloquée et une interface d'incitation à l'abonnement apparaît. Un compte abonné peut en sélectionner autant qu'il le souhaite. Ce chiffre de 3 a été donné explicitement par le porteur de projet comme valeur de travail. **Ce plafond concerne les types `boutique`, `entreprise` et `particulier_vendeur` ; le type `prestataire_service` déclare une seule `categorie_service` et n'est pas concerné par ce plafond** (voir point T dans `modele-donnees-netbuis.md`).

**Ce qui reste encore ouvert sur les avantages** : faut-il aussi un badge visuel ("Abonné") affiché publiquement sur le profil business, et des statistiques de fréquentation réservées aux abonnés ? Reste également ouvert : le plafond de 3 sous-catégories/produits doit-il aussi s'appliquer au catalogue `Product` complet ? Voir point P dans `modele-donnees-netbuis.md`.

## Maquette visuelle du dashboard — construite

Trois écrans web (format large écran, 1440×900, distincts des maquettes mobiles) ont été ajoutés au même jeu de maquettes cliquables, avec une barre latérale commune (NETBUIS Admin, navigation Vue d'ensemble / Demandes / Comptes / Équipe & abonnements) :

- **Vue d'ensemble** : indicateurs chiffrés, liste des demandes récentes, performance des agents de l'équipe NetBuis, suivi des abonnements, et la liste des comptes à fort trafic non abonnés.
- **Demandes** : deux onglets (comptes business / candidatures équipe NetBuis), chaque dossier affichable avec ses pièces (photos, ou vignette vidéo CNI — et désormais, pour un dossier `prestataire_service`, la photo de CNI et le diplôme éventuel), et des boutons Valider/Rejeter.
- **Comptes** : liste filtrable (Tous/Simple/Business/Équipe NetBuis/Bloqués) avec actions Bloquer/Débloquer et Supprimer par ligne.

L'écran "Équipe & abonnements" dédié n'est pas encore construit. Les maquettes mobiles (Accueil, Forum, Mes publications) n'illustrent pas encore visuellement le tri par abonnement ni le compteur de publications. **La maquette de paramétrage du compte business (`CreationBusiness-Details.dc.html`), elle, illustre déjà le plafond de 3 sous-catégories/produits**, et le nouvel écran `CreationBusiness-Prestataire-Categorie.dc.html` illustre la collecte de la CNI et du diplôme (voir `modele-donnees-netbuis.md`) — mais l'écran "Demandes" du dashboard admin n'a pas encore été mis à jour visuellement pour afficher ces nouvelles pièces d'un dossier `prestataire_service`, ni pour distinguer visuellement ce qu'un rôle Validateur peut faire par rapport à un rôle Administrateur complet (ex. bouton Bloquer/Supprimer grisé pour un Validateur) : documenté ici comme décision, pas encore construit dans la maquette.

## Nouveaux éléments du modèle de données

**Account — champs supplémentaires**
- `is_admin` (booléen) — accès au dashboard d'administration. Distinct de `is_equipe_netbuis`.
- Appartenance à un `Group` Django ("Validateur" / "Administrateur") — détermine les actions précises autorisées une fois dans le dashboard (nouveau, v7 — voir section RBAC ci-dessus).
- `is_blocked` (booléen), `blocked_reason` (texte), `blocked_at` (date).
- `is_deleted` (booléen), `deleted_at` (date) — voir la recommandation ci-dessous sur la suppression douce.

**Recommandation sur la suppression de compte : suppression douce (soft delete), pas suppression définitive.** (inchangé, voir raisonnement complet en v5 — toujours à confirmer avec le porteur de projet)

**Subscription (abonnement) — nouvelle entité**
- BusinessProfile concerné (FK)
- Période couverte (mois/année)
- Montant payé
- Statut : `actif` / `expiré` / `impayé`
- Date de paiement, date d'expiration
- Moyen de paiement (Mobile Money)
- Avantages associés tant que `statut = actif` : priorité d'affichage, publications `Post` illimitées, sélection illimitée de `SousCategorie`

**AuditLog (journal d'audit) — nouvelle entité**
- Admin auteur de l'action (`Account`)
- Type d'action (`validation_business`, `rejet_business`, `validation_equipe`, `rejet_equipe`, `blocage_compte`, `deblocage_compte`, `suppression_compte`, `attribution_role`, `retrait_role`, ...) — **deux nouveaux types d'action ajoutés en v7** pour tracer les changements de rôle RBAC.
- Compte ou profil concerné
- Motif (texte, obligatoire pour un rejet, un blocage ou une suppression)
- Date

**PlatformSetting (paramètres de plateforme) — nouvelle entité**
- Clé (ex. `seuil_appels_abonnement`, `plafond_publications_non_abonne`, `plafond_sous_categories_non_abonne`)
- Valeur
- Modifié par (`Account`), date de modification

## Fonctionnalités supplémentaires proposées

1. **Vue d'ensemble / tableau de bord chiffré** — ~~construit dans la maquette~~.
2. **File de modération du forum** — pas encore maquetté.
3. **Détail du solde de parrainage par agent** — résumé déjà présent sur la Vue d'ensemble.
4. **Gestion des rôles admin** — ~~résolu~~ : voir section RBAC ci-dessus (v7). Reste à construire visuellement dans la maquette.
5. **Export des données** (comptes, revenus, parrainages) en CSV — réservé au rôle Administrateur complet (v7).
6. **Réglage du seuil d'appels et des plafonds de publications/sous-catégories** — réservé au rôle Administrateur complet (v7).
7. **Rapport des secteurs "Autre" les plus fréquents** — idée, pas encore demandée explicitement ni maquettée.

## Règles métier à faire respecter côté serveur

- Un compte avec `is_blocked = true` ne peut pas se connecter, ni être appelé, ni apparaître dans les résultats de recherche.
- Un compte avec `is_deleted = true` est retiré de toutes les interfaces, mais ses données historiques restent en base.
- Un rejet de demande, un blocage ou une suppression de compte exige un motif, enregistré dans `AuditLog`.
- Seul un compte avec `is_admin = true` peut accéder au dashboard, valider/rejeter des demandes, bloquer ou supprimer un compte.
- **(nouveau, v7)** Seul un compte appartenant au groupe "Administrateur complet" peut bloquer/débloquer/supprimer un compte, modifier un `PlatformSetting`, exporter des données, ou attribuer/retirer un rôle à un autre compte. Un compte du groupe "Validateur" peut uniquement consulter et valider/rejeter une demande.
- Un `Subscription` actif ne change rien à la visibilité de base d'un `BusinessProfile` déjà `actif`.
- Quand le nombre de lignes `CallLog` du jour pour un `BusinessProfile` dépasse le seuil défini dans `PlatformSetting`, l'application propose un abonnement à ce compte, sans jamais bloquer les appels entrants.
- Quand un `BusinessProfile` non abonné tente d'associer une 4e `SousCategorie`, la création est refusée côté serveur.
- Le tri des listes de résultats place systématiquement les `BusinessProfile` avec `Subscription` actif avant les autres.
- **(nouveau)** Seul un compte avec `is_admin = true` peut faire passer `BusinessProfile.cni_verifiee` à `true`, et uniquement dans le cadre de la validation d'une demande (`status` passant à `actif`).
- **(nouveau)** `BusinessProfile.cni_photo` n'est jamais renvoyé par l'API consultée par l'app cliente pour affichage ; seul un compte `is_admin = true` peut le consulter via le dashboard.

## Points à trancher (questions ouvertes)

**I. Comment devient-on administrateur du dashboard ?** ~~Résolu (v7)~~ — premier compte créé manuellement, les suivants créés depuis le dashboard par un compte déjà Administrateur complet. Voir section RBAC.

**J. Faut-il plusieurs niveaux d'admin ?** ~~Résolu (v7)~~ — deux rôles RBAC : Validateur et Administrateur complet. Voir section RBAC.

**K. Suppression douce vs suppression définitive.** (inchangé, voir v5)

**L. Détail des avantages de l'abonnement mensuel.** ~~Résolu pour l'essentiel~~

**M. Modération du forum depuis le dashboard.** (inchangé, voir v5) — pourrait justifier un futur troisième rôle RBAC ("modérateur"), non tranché.

**N. Valeur exacte du seuil d'appels quotidiens.** Rouvert — pas de valeur confirmée.

**O. Plafond exact de publications pour un compte non abonné.** Proposition : 5. À confirmer.

**P. Plafond de sous-catégories/produits : 3 confirmé comme valeur de travail, mais portée à préciser.** (inchangé, voir v5)

**Q. (nouveau) Motif de rejet spécifique pour une CNI de prestataire jugée invalide.** Pas tranché, proposition simple ci-dessus (réutiliser le motif générique de rejet).

**R. (nouveau, v7) Un troisième rôle RBAC sera-t-il nécessaire (modérateur forum, etc.) ?** Pas tranché — les deux rôles actuels couvrent tout ce qui est demandé aujourd'hui.

## Ce qui reste cohérent avec les décisions déjà actées

- Ce dashboard est l'outil qui exécute les étapes de revue déjà décrites dans `modele-donnees-netbuis.md` pour les `BusinessProfile` en attente (y compris, désormais, la vérification de la CNI d'un prestataire de service) et les candidatures équipe NetBuis.
- Le solde de parrainage et son seuil de retrait restent gérés comme déjà décrit.
- L'abonnement mensuel est un nouveau flux de paiement Mobile Money, distinct des packs de crédits d'appel.
- Le déclenchement par seuil d'appels et les trois avantages de l'abonnement ne remettent pas en cause la décision que l'abonnement reste optionnel.
- L'ajout du type de compte `prestataire_service` et de sa vérification de CNI ne crée pas de nouvelle file d'attente admin : il s'intègre dans le processus de validation `BusinessProfile` déjà en place.
- **(nouveau, v7)** Le RBAC ne remplace pas `is_admin` : il vient préciser, pour un compte déjà admin, ce qu'il peut faire. Un compte sans `is_admin = true` n'accède pas au dashboard, quel que soit son `Group`.

## Prochaine étape

Choisir la valeur exacte du seuil d'appels quotidiens (point N), confirmer le point O (plafond de publications), le point P (portée exacte du plafond de 3 sous-catégories/produits), le montant de l'abonnement lui-même, les points R/S/T soulevés dans `modele-donnees-netbuis.md` (frontière Secteur/Prestataire, affichage de la CNI, multi-catégories pour un prestataire) — puis mettre à jour visuellement l'écran "Demandes" pour refléter les nouvelles pièces d'un dossier prestataire, et refléter visuellement la distinction Validateur/Administrateur complet (point R ci-dessus) dans la maquette du dashboard.
