# Dettes techniques relevées par les vérificateurs (à traiter en finition, T120-T125)
- **Dashboard : aucune barrière d'erreur globale** (ErrorBoundary). Une exception de rendu sur n'importe quelle page donne un écran blanc ; ex. la Vue d'ensemble plante si /api/admin/stats/ renvoie une réponse incomplète (revenue_month, high_traffic manquants). À ajouter : ErrorBoundary autour des routes + lecture défensive des stats.
- **Dashboard : forum_moderation/api.ts moderate()** construit l'URL sans valider target_type (post|comment|business) ni target_id (entier) : garde de 2 lignes à ajouter.
- **Dashboard : src/modules/forum_moderation/pages/PostDetailPage.tsx** reste un stub « À implémenter » (non importé).
- **Dashboard : src/App.tsx et tests/App.test.tsx** (page provisoire « mode simulé ») ne sont plus utilisés par les routes.
- **Recherche** : le nom du commerce n'est pas cherché (décision produit à prendre).
- **Backend** : limites anti-spam du forum en constantes (pas de clé PlatformSetting car la liste est figée par un test) ; pas de test de concurrence sur les verrous des publications/commentaires.
- **Journaux d'accès du serveur de production** (gunicorn, nginx) : masquer les jetons dans les chemins (/api/admin/private-files/, /api/uploads/local/).
- **Mobile** : bascule clair/sombre absente des écrans (le thème suit le téléphone) ; docs/MODULES.md à mettre à jour avec les nouveaux fichiers (home, call, search, forum, maps).
- **Accueil mobile** : maquette fournie en image (photos sur les cartes, vignettes photo pour les catégories) à confirmer par Jeff.
