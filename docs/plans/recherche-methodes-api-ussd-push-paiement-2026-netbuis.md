# Méthodes 2026 : API backend → push USSD / envoi de fonds (Orange Money, MTN MoMo, Cameroun)

Date : 2026-10-05 (mise à jour n°2 le même jour). Recherche web automatique. Statut : [S] = source consultée, [N] = non confirmé / à vérifier.

## 1. Principe commun (à retenir)

Le « push USSD » n'est pas une requête USSD que le backend lance lui-même. Le backend appelle l'API d'un opérateur ou d'un agrégateur. C'est l'opérateur qui envoie alors une invite officielle sur le téléphone du numéro indiqué. L'utilisateur saisit son code secret dans cette interface opérateur, jamais dans NetBuis. Le résultat revient par webhook (rappel) ou par interrogation du statut. [S: NjokaLab, Notch Pay, MTN MoMo guide]

Flux type : (1) numéro + montant XAF reçus par le serveur ; (2) POST authentifié d'initiation ; (3) invite PIN sur le téléphone en 2 à 5 s ; (4) confirmation → webhook → le serveur crédite. [S: NjokaLab]

## 2. Les méthodes disponibles

### A. API directe MTN MoMo Open API (Collection + Disbursement)
- Collection = `requestToPay` : le payeur reçoit une invite USSD pour son PIN, puis rappel (callback) sur votre URL. [S]
- Disbursement = envoi de fonds vers un portefeuille : exige la mise en liste blanche de l'adresse IP du serveur par MTN. [S]
- Authentification : clé de souscription `Ocp-Apim-Subscription-Key`, utilisateur API + clé (Basic) pour obtenir un jeton, puis Bearer. Un tableau de bord distinct par produit. [S]
- Sandbox → production : demande de chaque produit, identifiants reçus par e-mail. Compte marchand/entreprise nécessaire. [S]
- Réserve : les guides consultés visent le Liberia, la Côte d'Ivoire, le Ghana ; la procédure Cameroun et ses délais restent à confirmer avec MTN Cameroun. [N]

### B. API directe Orange Money
- « Orange Money Web Payment / M Payment » : Cameroun dans la liste des pays, réservé aux marchands enregistrés. Dans ce flux le client génère lui-même un OTP par USSD ; aucun push USSD direct ni payout n'est décrit. [S: developer.orange.com]
- Les offres « collections + payouts, USSD ou QR, webhooks » existent via des intégrateurs sous licence (ex. Boldrails : Cameroun XAF, un seul KYB, 3 à 14 jours, règlement fiat ou stablecoin) : à traiter comme un agrégateur, pas comme l'API Orange officielle. [S: boldrails.com, marketing, à vérifier]
- Conséquence : pour Orange, push PIN + payout passent plus sûrement par un agrégateur ou un contrat négocié avec Orange Cameroun.

### C. Agrégateurs à API unifiée (le plus rapide)
- **Campay** (Cameroun, MTN + Orange uniquement) : documentation Postman publique listant Collect (push USSD), Withdraw/Payout, Balance, Status, Webhook ; jeton permanent ou temporaire ; environnement démo `demo.campay.net`. Codes d'erreur : numéro invalide, opérateur non supporté, montant invalide, solde insuffisant. [S: documenter.getpostman Campay]. Donc Campay couvre à la fois le push USSD et l'envoi de fonds.
- **Notch Pay** : canaux `cm.mtn` et `cm.orange`, confirmation en 5 à 30 s, plafond quotidien 500 000 XAF, webhooks recommandés ; payouts non détaillés dans la page lue. [S/N]
- **CinetPay, Monetbil** : API REST MTN + Orange ; onboarding 1 à 2 jours (NjokaLab) à 3 à 15 jours (comparatif). [S, écarts]
- Frais indicatifs : CinetPay 2,5 à 3,5 %, Flutterwave ~1,4 % local ; non spécifiques au Cameroun. [S, à vérifier]

### D. pawaPay (dépôts ET paiements sortants)
- Cameroun : `MTN_MOMO_CMR` et `ORANGE_CMR`, XAF sans décimales, dépôts et payouts via la même Merchant API, autorisation `PROVIDER_AUTH` (confirmation sur téléphone), endpoint « predict provider » (déduit l'opérateur depuis le numéro), bac à sable. [S: docs.pawapay.io]

### E. Flutterwave
- Documentation Cameroun consultée = virements bancaires XAF ; collecte/payout mobile money Cameroun non confirmés. [S/N]

## 3. Ce qui ne se fait PAS
- Ne jamais demander ni transmettre le PIN Mobile Money dans l'app (vol de PIN, violation des conditions marchand). Cohérent avec `monetisation-appels-orange-money.md`.
- Ne pas faire confiance à la confirmation côté client.
- Aucun prélèvement récurrent avec une seule saisie de PIN confirmé au Cameroun : garder le modèle « pack de crédits ».

## 4. Exigences d'ingénierie communes
1. Webhook HTTPS avec signature HMAC SHA-256 vérifiée. [S]
2. Idempotence : identifiant de transaction unique, crédit ajouté une seule fois. [S]
3. Relance par tâche de fond si pas de webhook après ~90 s ; jusqu'à ~3 % des transactions à rapprocher. [S: NjokaLab]
4. État « paiement en attente » visible, bouton « j'ai payé » avec preuve.
5. Liste blanche d'IP pour les payouts ; secrets en variables d'environnement.
6. Compte marchand/entreprise obligatoire ; limites et KYC BEAC. [S: Krexora]
7. Montant minimum Orange 50 FCFA, donc packs de crédits.
8. Contrôle du solde du compte de payout avant chaque envoi (endpoint Balance Campay) et plafonds par utilisateur/jour contre la fraude.

## 5. Cadre réglementaire (nouveau, à valider par un juriste)
- Le 25 septembre 2026, la COBAC a soulevé publiquement la question des fonds clients transitant par les comptes des agrégateurs : pistes évoquées = comptes dédiés, cantonnement des fonds, rapprochements fréquents, clarification du statut des agrégateurs, renforcement LCB-FT (règlement COBAC R-2023/01). [S: notreafrik.com ; article secondaire, texte officiel non lu]
- Conséquence pour NetBuis : si l'app ne fait que déclencher des paiements via un agrégateur agréé, le risque réglementaire reste chez l'agrégateur ; si NetBuis détient ou redistribue des fonds (portefeuille, reversements aux commerçants), un statut d'établissement de paiement CEMAC peut s'imposer. [N : pages cabinet Kalieu-Elongo et simiz.io non lisibles ce jour]
- Recommandation : n'utiliser que des agrégateurs ou contrats directs qui encaissent et reversent eux-mêmes, ne jamais conserver de fonds clients sur un compte NetBuis.

## 6. Recommandation pour NetBuis
- MVP : un agrégateur unifié. Campay ou pawaPay si l'envoi de fonds est nécessaire ; Notch Pay/CinetPay pour la collecte seule. Couche d'abstraction `PaymentProvider` côté Django.
- Ensuite : contrats directs MTN (Collection/Disbursement) et Orange pour réduire les frais, quand le volume le justifie.
- Deux opérateurs dès le pilote ; commencer en sandbox (demo.campay.net, bac à sable pawaPay).

## 7. Non établi / à faire
- Procédure et délais exacts d'accès production MTN MoMo Cameroun et Orange Money Cameroun.
- Frais précis par agrégateur pour le Cameroun (collecte et payout), plafonds de payout.
- Texte officiel COBAC/CEMAC sur les agrégateurs et statut requis pour NetBuis : avis juridique.
- Pages inaccessibles ce jour (robots/timeout) : beonweb.cm, kalieu-elongo.com, simiz.io.

## Sources
- [MTN MoMo API sandbox→production](https://cleverengineer.substack.com/p/going-live-with-mtn-momo-api-in-2025)
- [Orange Money Web Payment API](https://developer.orange.com/apis/om-webpay)
- [Intégration MTN MoMo & Orange Money Cameroun (NjokaLab)](https://www.njokalab.com/insights/how-to-integrate-mtn-momo-orange-money-cameroon-api/)
- [CamPay API (Postman)](https://documenter.getpostman.com/view/2391374/T1LV8PVA)
- [Notch Pay Mobile Money](https://developer.notchpay.co/accept-payments/mobile-money)
- [pawaPay providers](https://docs.pawapay.io/v2/docs/providers)
- [Flutterwave Cameroun](https://developer.flutterwave.com/docs/cameroon)
- [Boldrails Orange Money API](https://boldrails.com/payments/orange-money-api)
- [COBAC mobile money agrégateurs (NotreAfrik)](https://notreafrik.com/cobac-mobile-money-agregateurs/)
- [Comparatif agrégateurs 2026 (Kolonell)](https://kolonell.com/en/blog/pan-african-payment-aggregator-comparison-2026)
- [Paiement mobile Cameroun 2026 (Krexora)](https://krexora.com/blog/paiement-mobile-cameroun-guide-technique-2026/)
