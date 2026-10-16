# Configuration CamPay — À FAIRE PLUS TARD, par étapes

Rien ici n'est exécuté pendant le développement initial. Les modules `payments/` restent vides.

1. Créer le compte CamPay (mode DEV d'abord). _(Jeff — pas de carte bancaire nécessaire d'après les échanges, à confirmer sur le site.)_
2. Récupérer l'identifiant et le mot de passe de l'application ; les mettre dans `backend/.env` :
   `CAMPAY_APP_USERNAME`, `CAMPAY_APP_PASSWORD` (jamais dans le code, le dépôt ou une conversation).
3. Déclarer l'URL du webhook (`/api/payments/webhook/`) et noter la clé : `CAMPAY_WEBHOOK_KEY`.
4. Passer `PAYMENT_PROVIDER=campay`, `CAMPAY_ENV=DEV` ; tester avec les numéros de test fournis par CamPay.
5. Valider collect, puis payout, puis seulement activer `CREDITS_ENABLED=True`.
6. Passage en PROD : KYC / frais / limites à confirmer auprès de CamPay.

Points ouverts : noms exacts des variables et format de signature du webhook (à vérifier dans la documentation CamPay au moment de l'étape É6).
