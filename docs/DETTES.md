# Dettes techniques relevées par les vérificateurs (à traiter en finition, T120-T125)
- **Dashboard : aucune barrière d'erreur globale** (ErrorBoundary). Une exception de rendu sur n'importe quelle page donne un écran blanc ; ex. la Vue d'ensemble plante si /api/admin/stats/ renvoie une réponse incomplète (revenue_month, high_traffic manquants). À ajouter : ErrorBoundary autour des routes + lecture défensive des stats.
- **Dashboard : forum_moderation/api.ts moderate()** construit l'URL sans valider target_type (post|comment|business) ni target_id (entier) : garde de 2 lignes à ajouter.
- **Dashboard : src/modules/forum_moderation/pages/PostDetailPage.tsx** reste un stub « À implémenter » (non importé).
- **Dashboard : src/App.tsx et tests/App.test.tsx** (page provisoire « mode simulé ») ne sont plus utilisés par les routes.
- **Recherche** : le nom du commerce n'est pas cherché (décision produit à prendre).
- **Backend** : limites anti-spam du forum en constantes (pas de clé PlatformSetting car la liste est figée par un test) ; pas de test de concurrence sur les verrous des publications/commentaires.
- **Journaux d'accès du serveur de production** (gunicorn, nginx) : masquer les jetons dans les chemins (/api/admin/private-files/, /api/uploads/local/).
- **Mobile** : docs/MODULES.md à mettre à jour avec les nouveaux fichiers (home, call, search, forum, maps).
- **Accueil mobile** : maquette fournie en image (photos sur les cartes, vignettes photo pour les catégories) à confirmer par Jeff.

- T102 : si l'écran Profil disparaît pendant `DELETE /me/` et que l'appel échoue, la 2ᵉ fenêtre de confirmation peut rester affichée sur l'écran de connexion (se ferme par « Annuler ») ; cas limite non testé. Clés `profile.settings*` devenues inutilisées.

- T102b : type de compte, secteur, sous-catégories, forme juridique, RCCM et détails d'établissement non modifiables depuis « Modifier ma boutique » ; un rejet portant sur l'un d'eux ne se corrige pas dans l'application (prévoir un écran de correction réutilisant la création pré-remplie). Pas de test « rejeté + nom changé : aucun avertissement ». `business_edit_screen.dart` > 700 lignes (à découper).

- T104 : `compute_trends` n'est planifiée nulle part (cron quotidien à installer au déploiement, reporté) ; l'API n'a pas de limite d'âge sur l'instantané (utiliser `computed_at`). Les 3 réglages `trends_*` doivent s'afficher sans plantage dans la page Réglages du dashboard (à vérifier en T106). Seuil de 3 appelants distincts aussi appliqué aux commerces.

- T105 : pas de tirer-pour-actualiser sur l'Accueil (tendances rechargées au changement de ville ou à la reprise) ; la bande n'apparaît qu'avec des résultats affichés (pas pendant le chargement ni sans résultat) ; cache des tendances lié à la zone et non à l'utilisateur (sans sensibilité) ; pas de maquette de la bande (placement choisi par b2, à confirmer par Jeff).

- T106 : pages Recherches, Appels, Tendances en version minimale, sans maquette (aucun écran d'analyses dans `docs/design/maquettes/`) ; pas de bouton « Copier » sur les recherches sans résultat, ni « retours utiles » ni signalements WhatsApp (C3.10 complet) ; graphiques faits à la main (barres), aucune bibliothèque. Tendances : le dashboard appelle `GET /api/trends/?zone=<id>` avec le jeton administrateur (permission `IsAuthenticatedNotBlocked`, lue dans le code, non essayée en direct) ; pas de route d'administration dédiée ni de compteurs dans la réponse (classement seulement) ; les villes viennent de `/api/zones/?level=ville_village`. Le serveur écarte déjà les termes de 6 chiffres ou plus ; le dashboard masque aussi tout motif ressemblant à un numéro.

- T106 : aucun test backend n'appelle `GET /api/trends/` avec un compte administrateur (la page Tendances du dashboard en dépend) : à ajouter dans `apps/trends/tests`.
