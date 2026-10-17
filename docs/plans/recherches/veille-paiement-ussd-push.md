# Veille : méthodes d'API USSD push / paiement 2026 (addenda)

> Regroupement automatique (2026-10-17) de 219 fichiers de veille produits par les routines du Projet Claude, du plus ancien au plus récent. Historique seulement : en cas de contradiction, `docs/DECISIONS_JEFF.md` et `docs/BACKLOG.md` font foi.


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-2-netbuis.md -->

# Addendum n°4 — Méthodes API → push USSD / envoi de fonds (Cameroun) — 2026-10-06

Complète `recherche-methodes-api-ussd-push-paiement-2026-netbuis.md` (référence) et l'addendum n°3. Recherche automatique ; [S] = source lue, [N] = non confirmé.

## Verdict de cette passe
Aucune méthode fondamentalement nouvelle par rapport au 05/10. Les 3 familles restent : (1) API directe opérateur (MTN MoMo Open API ; Orange Money Web Payment), (2) agrégateur unifié (Campay, pawaPay, Notch Pay, CinetPay, Monetbil), (3) intégrateur local sous licence Orange (USSD/API locale). Principe inchangé : le backend appelle une API, l'opérateur envoie l'invite PIN, le résultat revient par webhook ; le PIN n'est jamais saisi dans NetBuis.

## Nouveaux acteurs repérés
- **PayUnit** : passerelle locale Cameroun, MTN + Orange, présentée comme adaptée aux PME/marchands, onboarding simple. [S: dusupay.com, comparatif ; frais non donnés]
- **MMGate** : passerelle revendiquant push USSD, payouts/disbursement, transferts MTN↔Orange, webhooks, intégration « en un jour ». [N : seul le résumé de la page a été lu, contenu complet non obtenu]
- **DusuPay** (multi-pays) et **Flutterwave** (panafricain) : cités pour la collecte mobile money ; payout Cameroun toujours non confirmé. [S/N]
- **CamerPay** (camerpay.biz) : page MTN MoMo en 403 ce jour. [N]

## Toujours non établi
- Procédure/délais d'accès production direct MTN MoMo Cameroun et Orange Money Cameroun (les ressources trouvées visent Ghana, Côte d'Ivoire, Ouganda).
- Frais exacts par agrégateur au Cameroun hors Campay (≈2 % collecte / 1 % payout, déclaré).
- Statut réglementaire COBAC/CEMAC si NetBuis touche aux fonds : avis juridique.
- Pages illisibles : y-note.cm, paynote.africa, simiz.io, beonweb.cm, camerpay.biz.

## Recommandation (inchangée)
Couche `PaymentProvider` abstraite ; MVP via Campay ou pawaPay (collecte + payout, MTN + Orange) ; webhook signé HMAC, idempotence, rapprochement ; ne jamais conserver de fonds clients ; contrats directs plus tard pour réduire les frais.

## Sources
- [DusuPay — Top Payment Gateways in Cameroon](https://www.dusupay.com/post/top-payment-gateways-in-cameroon)
- [MMGate — API Mobile Money Cameroun](https://www.mmgate.org/int/blog/api-mobile-money-cameroun)
- [NjokaLab — Intégration MTN MoMo & Orange Money](https://www.njokalab.com/insights/how-to-integrate-mtn-momo-orange-money-cameroon-api/)
- [Notch Pay — Mobile Money](https://developer.notchpay.co/accept-payments/mobile-money)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-3-netbuis.md -->

# Addendum n°5 — Méthodes API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (2e passe)

Complète la référence et les addenda précédents. [S] = source lue, [N] = non confirmé.

## Verdict
Pas de méthode fondamentalement nouvelle. Les 3 familles restent : API directe opérateur, agrégateur unifié, intégrateur local Orange. Principe : le backend appelle l'API → l'opérateur envoie l'invite PIN au client → résultat par webhook ; le PIN n'est jamais saisi dans NetBuis.

## Nouvelles confirmations
- **Orange Money Web Payment / M Payment** : la FAQ officielle Orange Developer liste explicitement le **Cameroun** parmi les pays supportés (avec Mali, Sénégal, Madagascar, Côte d'Ivoire, etc.). Passage en production : après phase de tests, détails envoyés par e-mail ; coûts/délais via l'opérateur local Orange. Payout/cashout : **non documenté** sur cette page. [S: developer.orange.com/apis/om-webpay/faq]
- **Moneroo** : agrégateur listant MTN MoMo Cameroun, Orange Money Cameroun et cartes Visa/MasterCard XAF ; collecte vs payout et frais non précisés. [S: moneroo.io/en/coverage]
- **BoldRails** : API unifiée pay-in + payout, MTN MoMo et Orange Money couvrant le Cameroun, règlement local/USD/USDT, approbation 3-14 jours ; cible surtout e-commerce/fintech/profils à risque élevé — prudence de conformité. [S: boldrails.com/payments/mobile-money]
- **MoniTrack** (monitrack.tech) : service de transfert/recharge mobile money Cameroun. [N : page non lue]

## Toujours non établi
Procédure d'accès production direct MTN MoMo Cameroun (portail momodeveloper.mtn.com : pays Cameroun à vérifier à l'inscription) ; frais exacts hors Campay (~2 % collecte / 1 % payout, déclaré) ; statut COBAC/CEMAC si NetBuis manipule des fonds (avis juridique) ; payout Orange direct.

## Recommandation (inchangée)
Couche `PaymentProvider` abstraite ; MVP via Campay ou pawaPay (collecte + payout MTN + Orange) avec Moneroo comme secours ; contrat direct Orange WebPay à engager en parallèle (Cameroun confirmé) ; webhook signé HMAC, idempotence, rapprochement ; ne jamais détenir de fonds clients.

## Sources
- [Orange Money Web Payment — FAQ](https://developer.orange.com/apis/om-webpay/faq)
- [Moneroo — Coverage](https://moneroo.io/en/coverage)
- [BoldRails — Mobile Money API](https://boldrails.com/payments/mobile-money)
- [MoMo Developer Portal](https://momodeveloper.mtn.com/)
- [MoniTrack](https://monitrack.tech/en)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-4-netbuis.md -->

# Addendum n°6 — Méthodes API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (3e passe)

[S] = source lue, [N] = non confirmé. Complète la référence et les addenda précédents.

## Verdict
Aucune méthode nouvelle. Le schéma reste : backend → API → l'opérateur envoie l'invite PIN (STK/USSD push) au client → résultat par webhook. Le PIN n'est jamais saisi dans NetBuis.

## Nouvelles confirmations
- **pawaPay (docs v2)** : Cameroun = 2 opérateurs, **MTN_MOMO_CMR** et **ORANGE_CMR**, devise XAF, **dépôts ET payouts** pris en charge, autorisation `PROVIDER_AUTH` (le client valide chez l'opérateur), **pas de décimales** dans les montants. L'endpoint « active configuration » donne la disponibilité réelle par compte. [S: docs.pawapay.io/v2/docs/providers]
- **Incident pawaPay avril 2026** : dégradation de performance signalée sur les services MTN Cameroun → prévoir fallback (second agrégateur) et statut « pending » côté UI. [S titre: isdown.app / status.pawapay.io, page non lue]
- **Guide NjokaLab** : agrégateurs (Campay, CinetPay, Notch Pay, Monetbil) intégrables en 1–2 jours ; invite PIN reçue en 2–5 s ; jusqu'à ~3 % de transactions avec latence ; bonnes pratiques : webhook signé HMAC SHA-256, contrôle d'idempotence par ID de transaction, polling de rattrapage si pas de webhook sous 90 s, écran « en attente » + support WhatsApp. [S: njokalab.com]
- **Orange Money Cameroun** : pages officielles « Orange Money API » (orangemoneybusiness.orange.cm) et Orange Developer existent ; contenu non lisible (robots/SSL), donc conditions de payout direct **[N]**. Guides tiers évoquent une « API locale/USSD » via intégrateurs (paynote.africa) **[N]**.
- **MTN MoMo direct** : API Collections (requestToPay), Disbursements, Remittances ; clients open-source PHP/Node existent (GitHub lepresk/momo-api, ogwok/mtn-momo). Disponibilité production Cameroun à confirmer à l'inscription sur momodeveloper.mtn.com **[N]**.

## Toujours non établi
Accès production direct MTN Cameroun ; payout Orange direct ; frais exacts hors Campay ; statut COBAC/CEMAC si NetBuis touche des fonds (avis juridique requis).

## Recommandation (inchangée)
Couche `PaymentProvider` abstraite ; MVP via pawaPay ou Campay (collecte + payout MTN + Orange), second agrégateur en secours (Moneroo/CinetPay) ; démarches directes Orange/MTN en parallèle ; webhook HMAC + idempotence + rapprochement ; ne jamais détenir de fonds clients ; montants entiers XAF.

## Sources
- [pawaPay — Providers](https://docs.pawapay.io/v2/docs/providers)
- [pawaPay — Status](https://status.pawapay.io/)
- [NjokaLab — Intégrer MTN MoMo & Orange Money](https://www.njokalab.com/insights/how-to-integrate-mtn-momo-orange-money-cameroon-api/)
- [Orange Money API Cameroun](https://orangemoneybusiness.orange.cm/services/om-api)
- [Orange Developer — Web Payment](https://developer.orange.com/apis/om-webpay)
- [paynote — API locale/USSD Orange Money](https://www.paynote.africa/integration-de-lapi-local-orange-money/)
- [lepresk/momo-api](https://github.com/lepresk/momo-api)
- [MoMo Developer Portal](https://momodeveloper.mtn.com/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-5-netbuis.md -->

# Addendum n°7 — Méthodes API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (4e passe)

[S] = source lue, [N] = non confirmé.

## Verdict
Toujours aucune méthode fondamentalement nouvelle. Deux architectures seulement : (1) API REST agrégateur ou opérateur → l'opérateur pousse l'invite PIN (STK/USSD push) chez le client → webhook ; (2) USSD « manuel » (*126# etc.), inadapté à l'intégration backend sans accord opérateur. Le PIN n'est jamais saisi dans NetBuis.

## Nouveau
- **PayDunya — API Disbursement (« API PUSH »)** : supporte les payouts au Cameroun **MTN uniquement** (`withdraw_mode: "mtn-cameroun"`), pas Orange Cameroun. Flux en 3 appels : `/api/v2/disburse/get-invoice` (jeton) → `/api/v2/disburse/submit-invoice` → `/api/v2/disburse/check-status`; auth par 3 en-têtes (MASTER-KEY, PRIVATE-KEY, TOKEN); `callback_url` obligatoire; montants en entiers (pas de décimales). Utile comme fallback payout MTN, pas pour Orange. [S: developers.paydunya.com/doc/EN/api_deboursement]
- **Guide Krexora 2026** : confirme le modèle « API REST = le site initie le paiement, le client reçoit une notification push et valide » ; l'USSD seul n'est pas intégrable en e-commerce sans accord opérateur ; **accord marchand obligatoire** avec l'opérateur pour paiements directs ; KYC géré par l'opérateur ; plafonds journaliers/par transaction à afficher à l'utilisateur ; recommandations : variables d'environnement pour les clés, file d'attente de webhooks (Redis/BD), logs structurés, sandbox avant production. Pas de détail sur frais ni payout. [S: krexora.com]
- **MTN MoMo** : bibliothèques tierces supplémentaires (sparkplug/momoapi-php, patricpoba/mtn-momo-api-php) ; fil communautaire « API Production sign-up process » sur momodevelopercommunity.mtn.com (procédure de passage en production, non lue) **[N]**.
- **Orange** : Orange Developer « Web Payment / M Payment » ; Y-Note propose « Orange Money Cashout » (remboursement/payout via intégrateur) ; Paynote « API Local/USSD Orange Money » **[N]** (conditions non lues). beonweb.cm illisible (robots).

## Toujours non établi
Production directe MTN Cameroun ; payout Orange direct ; frais hors Campay ; statut COBAC/CEMAC si NetBuis touche des fonds.

## Recommandation (inchangée)
Interface `PaymentProvider` abstraite ; MVP via pawaPay ou Campay (collecte + payout MTN + Orange) ; secours : PayDunya (payout MTN) / Moneroo / CinetPay ; démarches directes Orange/MTN en parallèle ; webhook HMAC + idempotence + polling de rattrapage + rapprochement ; ne jamais détenir de fonds clients ; montants entiers XAF.

## Sources
- [PayDunya — API Disbursement](https://developers.paydunya.com/doc/EN/api_deboursement)
- [Krexora — guide technique 2026](https://krexora.com/blog/paiement-mobile-cameroun-guide-technique-2026/)
- [Y-Note — Orange Money Cashout](https://www.y-note.cm/api-orange-money-une-solution-de-rembousement-securise/)
- [Paynote — API Local/USSD Orange Money](https://www.paynote.africa/quest-ce-que-lapi-local-ussd-orange-money/)
- [Orange Developer — Web Payment FAQ](https://developer.orange.com/apis/om-webpay/faq)
- [MoMo community — Production sign-up](https://momodevelopercommunity.mtn.com/momo-api-production-q-a-7/api-production-sign-up-process-477)
- [sparkplug/momoapi-php](https://github.com/sparkplug/momoapi-php)
- [NjokaLab guide](https://www.njokalab.com/insights/how-to-integrate-mtn-momo-orange-money-cameroon-api/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-6-netbuis.md -->

# Addendum n°8 — Méthodes API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (5e passe, run planifié)

[S] = source lue, [N] = non confirmé.

## Verdict
Aucune méthode nouvelle. Les deux architectures restent : (1) API REST agrégateur/opérateur → invite PIN poussée chez le client → webhook ; (2) USSD manuel (*126#, #150#), non intégrable côté backend sans accord opérateur. Le PIN n'est jamais saisi dans NetBuis.

## Nouveau / précisions
- **Incident pawaPay du 19 avril 2026** : panne d'environ 4 h des services MTN Cameroun (Web Deposit + Payout), cause non précisée. Conséquence : prévoir un repli (second agrégateur), un polling de rattrapage et des statuts « en attente » côté UI. [S: isdown.app, page d'incident pawaPay]
- **Changelog pawaPay** : aucune entrée 2026 visible ; dernières évolutions utiles = signature des requêtes financières, métadonnées de paiement, requête de solde wallet via API, 2FA portail, amélioration des motifs d'échec MTN/Orange Cameroun (2024). Pas de nouveau mécanisme de push/USSD. [S: pawapay.io/changelog]
- **Plateforme d'agrégation USSD nationale #237#** (Campost, lancée nov. 2019) : code unique remplaçant *126# (MTN) et #150# (Orange) ; les tarifs des intégrateurs doivent être validés par les autorités. Ancienne, mais seul « point d'accès USSD unifié » ; accès réservé aux prestataires agréés, pas une API ouverte. [S: businessincameroon.com]
- Pistes listées, non lues [N] : boldrails.com (Orange Money API collections/payouts), dusupay.com (comparatif passerelles Cameroun), lepresk/momo-api (client PHP MTN MoMo collections/disbursements/remittances), kkiapay (Afrique de l'Ouest — Cameroun non confirmé), beonweb.cm (illisible).

## Toujours non établi
Production directe MTN Cameroun ; payout Orange direct ; frais hors Campay ; statut COBAC/CEMAC si NetBuis manipule des fonds ; accès réel au #237# pour un tiers.

## Recommandation (inchangée)
Interface `PaymentProvider` abstraite ; MVP via pawaPay ou Campay (collecte + payout MTN + Orange) ; secours PayDunya (payout MTN)/Moneroo/CinetPay ; démarches Orange/MTN directes en parallèle ; webhook signé HMAC + idempotence + polling + rapprochement ; ne jamais détenir de fonds clients ; montants entiers XAF ; surveiller les pages de statut des agrégateurs.

## Sources
- [pawaPay — incident avril 2026](https://isdown.app/status/pawapay/incidents/573171-performance-degradation-affecting-cameroon-mtn-services)
- [pawaPay — changelog](https://www.pawapay.io/changelog)
- [Business in Cameroon — plateforme USSD #237#](https://www.businessincameroon.com/economy/2711-9717-cameroon-launches-mobile-money-services-aggregation-platform-to-boost-financial-inclusion)
- [Boldrails — Orange Money API](https://boldrails.com/payments/orange-money-api)
- [Dusupay — passerelles Cameroun](https://www.dusupay.com/post/top-payment-gateways-in-cameroon)
- [lepresk/momo-api](https://github.com/lepresk/momo-api)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-7-netbuis.md -->

# Addendum n°9 — Méthodes API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (6e passe, run planifié)

[S] = source lue, [N] = non confirmé.

## Verdict
Aucune méthode nouvelle. Les deux architectures restent valides : (1) API REST agrégateur ou opérateur → invite PIN poussée sur le téléphone du client → webhook ; (2) USSD manuel (*126#, #150#), non intégrable côté backend sans accord opérateur. Le PIN n'est jamais saisi dans NetBuis.

## Confirmations
- Deux voies : API directes opérateurs (contrats MTN et Orange séparés, pas de frais d'agrégateur, deux codebases) ou agrégateurs unifiés (Campay, CinetPay, Notch Pay, Monetbil), mise en route en 1-2 jours. [S: njokalab.com]
- Flux push : POST authentifié (numéro + montant XAF) → invite officielle de l'opérateur en 2-5 s → saisie du PIN → webhook. [S: njokalab.com]
- Bonnes pratiques : ne jamais marquer « payé » sur une simple redirection client ; signature HMAC SHA-256 ; stocker les IDs de transaction (idempotence) ; worker de polling si webhook absent après ~90 s. [S: njokalab.com]
- Orange : API officielle « Orange Money Web Payment / M Payment » sur developer.orange.com (redirection vers page de paiement Orange, pas de push direct documenté pour le Cameroun) [N : détails Cameroun non lus].
- beonweb.cm (blog paiement en ligne Cameroun 2026) : illisible (robots.txt). Boldrails, Dusupay, lepresk/momo-api : déjà listés, non relus.

## Toujours non établi
Production directe MTN Cameroun ; payout Orange direct ; frais hors Campay ; statut COBAC/CEMAC si NetBuis manipule des fonds ; accès réel à #237# pour un tiers.

## Recommandation (inchangée)
Interface `PaymentProvider` abstraite ; MVP via pawaPay ou Campay ; secours PayDunya/Moneroo/CinetPay/Notch Pay ; démarches Orange/MTN directes en parallèle ; webhook signé + idempotence + polling + rapprochement ; ne jamais détenir de fonds clients ; montants entiers XAF.

## Sources
- [NjokaLab — intégrer MTN MoMo & Orange Money](https://www.njokalab.com/insights/how-to-integrate-mtn-momo-orange-money-cameroon-api/)
- [Orange Money Web Payment API](https://developer.orange.com/apis/om-webpay)
- [Boldrails](https://boldrails.com/payments/orange-money-api)
- [Dusupay](https://www.dusupay.com/post/top-payment-gateways-in-cameroon)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-8-netbuis.md -->

# Addendum — Méthodes API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (passe suivante, run planifié)

## Verdict
Aucune méthode nouvelle. Les deux architectures restent valides : (1) API REST agrégateur ou opérateur → invite PIN poussée sur le téléphone du client → webhook ; (2) USSD manuel (*126#, #150#), non intégrable côté backend sans accord opérateur. Le PIN n'est jamais saisi dans NetBuis.

## Confirmations de cette passe
- Krexora (guide technique 2026) : l'USSD est une initiation par code côté client ; pour un marchand en ligne, l'API REST recommandée = le backend initie le paiement, le client reçoit une notification push et valide. Parts de marché citées : MTN ~55 %, Orange ~45 % ; 15 M+ comptes ; mise en route double opérateur 3-5 jours ; idempotence webhook + files Redis/BD + logs par transaction. Frais et plafonds non précisés ; KYC géré par les opérateurs ; accord marchand requis. [S: krexora.com]
- PawaPay : 3 milliards de transactions (juin 2026), licence Kenya (sept. 2026) ; pages de statut signalent des incidents ponctuels début octobre 2026 → prévoir un fournisseur de secours. [S: techcabal.com, techmoran.com ; incidents : sources communautaires, [N]]
- camerpay.biz : 403, non lu. beonweb.cm, mmgate.org (1Flow QR) : non relus.

## Toujours non établi
Production directe MTN Cameroun ; payout Orange direct ; frais hors Campay ; statut COBAC/CEMAC si NetBuis manipule des fonds ; accès réel à #237# pour un tiers.

## Recommandation (inchangée)
Interface `PaymentProvider` abstraite ; MVP via pawaPay ou Campay ; secours PayDunya/Moneroo/CinetPay/Notch Pay ; webhook signé + idempotence + polling + rapprochement ; ne jamais détenir de fonds clients ; montants entiers XAF.

## Sources
- [Krexora — paiement mobile Cameroun 2026](https://krexora.com/blog/paiement-mobile-cameroun-guide-technique-2026/)
- [TechCabal — PawaPay 3 milliards](https://techcabal.com/2026/06/16/pawapay-reaches-3-billion-transactions/)
- [TechMoran — PawaPay licence Kenya](https://techmoran.com/2026/09/27/pawapay-secures-kenya-payments-licence-after-3-billion-mobile-money-transactions/)
- [NjokaLab](https://www.njokalab.com/insights/how-to-integrate-mtn-momo-orange-money-cameroon-api/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-9-netbuis.md -->

# Addendum 9 — Méthodes API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (run planifié)

## Verdict
Aucune méthode nouvelle. Architectures inchangées : (1) API REST agrégateur/opérateur → invite PIN poussée sur le téléphone du client → webhook ; (2) USSD manuel (*126#, #150#), non intégrable côté backend sans accord opérateur. Le PIN n'est jamais saisi dans NetBuis.

## Points de cette passe
- Flutterwave : une page support intitulée « About The Payout Pause In Cameroon » existe dans les résultats de recherche, mais elle renvoie 404 → contenu, date et portée NON vérifiés [N]. À traiter comme signal de risque : ne pas dépendre de Flutterwave pour les payouts au Cameroun sans confirmation directe.
- PayAtlas (maj. 26 janv. 2026) : MTN MoMo + Orange Money > 70 % des paiements numériques ; frais transaction typiques 2,5–4 % ; frais payout XAF 500–2 000 ; onboarding 4–8 semaines (KYC manuel) ; supervision BEAC/CENTIF ; loi 2010/012 sur les données. Chiffres génériques, non contractuels.
- Nouveaux résultats de recherche non lus : repo GitHub lepresk/momo-api (client PHP MTN MoMo collections/disbursements), boldrails.com (Orange Money API), mobileonnet.com, monitrack.tech, ntas-server.com, dusupay.com.

## Toujours non établi
Production directe MTN Cameroun ; payout Orange direct ; statut COBAC/CEMAC si NetBuis manipule des fonds ; accès à #237# pour un tiers.

## Recommandation (inchangée)
Interface `PaymentProvider` abstraite ; MVP pawaPay ou Campay ; secours PayDunya/Moneroo/CinetPay/Notch Pay ; webhook signé + idempotence + polling + rapprochement ; ne jamais détenir de fonds clients ; montants entiers XAF.

## Sources
- [PayAtlas — Cameroun](https://payatlas.com/countries/cameroon-cm)
- [Flutterwave — payout pause Cameroun (404)](https://flutterwave.com/us/support/general/about-the-payout-pause-in-cameroon)
- [NjokaLab](https://www.njokalab.com/insights/how-to-integrate-mtn-momo-orange-money-cameroon-api/)
- [lepresk/momo-api](https://github.com/lepresk/momo-api)
- [PawaPay Status](https://status.pawapay.io/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-10-netbuis.md -->

# Addendum 10 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (run planifié)

## Verdict
Aucune méthode nouvelle. Architectures inchangées : API agrégateur/opérateur → invite PIN poussée sur le téléphone du client → webhook. Le PIN n'est jamais saisi dans NetBuis.

## Vérifications de cette passe
- Flutterwave « payout pause Cameroun » : la page renvoie toujours 404 → contenu et date non vérifiables. Risque à garder en tête : ne pas dépendre de Flutterwave pour les payouts au Cameroun sans confirmation directe.
- Klasha MOMO Payout API (5 août 2025) : payouts mobile money (MTN, Airtel, Orange) en XOF, XAF, UGX, ZMW, KES… ; le Cameroun n'est pas nommé explicitement → couverture à confirmer auprès de Klasha. Option de secours potentielle, non retenue.
- Résultats déjà connus (CamerPay, BeOnWeb, NjokaLab, Dusupay, BoldRails, mobileonnet) : rien de nouveau.

## Recommandation (inchangée)
Interface `PaymentProvider` abstraite ; MVP pawaPay ou Campay ; secours PayDunya/Moneroo/CinetPay/Notch Pay ; webhook signé + idempotence + polling + rapprochement ; ne jamais détenir de fonds clients ; montants entiers XAF.

## Sources
- [Flutterwave — payout pause (404)](https://flutterwave.com/us/support/general/about-the-payout-pause-in-cameroon)
- [Klasha MOMO Payout API](https://www.klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [BeOnWeb 2026](https://www.beonweb.cm/en/blog/paiement-en-ligne-cameroun-mtn-orange-money-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-11-netbuis.md -->

# Addendum 11 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (run planifié)

## Verdict
Aucune méthode nouvelle. Deux recherches (collecte MTN/Orange 2026, API Orange Money marchand) ne remontent que des guides d'agrégateurs déjà connus ou redondants (Krexora, Simiz, MMGate, Kolonell, Paynote/Y-Note, CamerPay, BoldRails, NjokaLab). Architecture inchangée : API agrégateur/opérateur → invite PIN poussée sur le téléphone du client → webhook. Le PIN n'est jamais saisi dans NetBuis.

## Faits relevés (Krexora, guide 2026, source secondaire)
- Deux voies : USSD (code composé par le client, ex. *126#, pour terminaux/SMS, pas pour l'intégration web directe) et API REST (initiation programmatique + notification push de validation) — la voie API REST est la norme e-commerce/app.
- Accès USSD direct = accord marchand/passerelle opérateur ; KYC côté opérateur ; plafonds selon niveau de vérification.
- Répartition indicative Orange/MTN ~45/55 % ; intégration Orange+MTN estimée 3–5 jours via agrégateur.
- Camtel prévoit d'entrer sur le marché MoMo en 2026 (Business in Cameroon) — déjà suivi dans le projet.
- Page Paynote « API local / USSD Orange Money » non lisible (robots.txt 503) → non vérifiée.

## Recommandation (inchangée)
Interface `PaymentProvider` abstraite ; MVP pawaPay ou Campay ; secours PayDunya/Moneroo/CinetPay/Notch Pay ; webhook signé + idempotence + polling + rapprochement ; ne jamais détenir de fonds clients ; montants entiers XAF.

## Sources
- [Krexora — guide technique 2026](https://krexora.com/blog/paiement-mobile-cameroun-guide-technique-2026/)
- [Camtel MoMo 2026](https://www.businessincameroon.com/public-management/0312-15437-camtel-plans-to-enter-momo-market-in-2026)
- [Paynote — API local Orange Money](https://www.paynote.africa/integration-de-lapi-local-orange-money/)
- [CamerPay](https://camerpay.biz/blog/accepter-orange-money-site-web-cameroun)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-12-netbuis.md -->

# Addendum 12 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (run planifié)

## Verdict
Aucune méthode nouvelle. Architecture inchangée : API agrégateur/opérateur (pawaPay, Campay, etc.) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis.

## Vérifié ce passage
- Recherche « Cameroon mobile money API collection USSD push 2026 » : uniquement guides Kolonell (déjà connus) et un article Digital Business Africa sur un « code USSD unique » — daté du 28/11/2019, donc ancien, sans impact sur l'intégration API.
- Recherche pawaPay/Campay/Flutterwave payouts : docs pawaPay, SDK Campay (PyPI), pages d'incidents pawaPay ; pas d'annonce nouvelle.
- Payfonte : la doc de test ne mentionne pas le Cameroun (Côte d'Ivoire, Ghana, Afrique de l'Est seulement) → non retenu, couverture Cameroun non démontrée.

## Recommandation (inchangée)
Interface `PaymentProvider` abstraite ; MVP pawaPay ou Campay ; secours PayDunya/Moneroo/CinetPay/Notch Pay ; idempotence + polling + rapprochement ; ne jamais détenir de fonds clients ; montants entiers XAF.

## Sources
- [Digital Business Africa — code unique (2019)](https://www.digitalbusiness.africa/cameroun-bientot-un-code-unique-pour-lacces-aux-services-financiers-mobiles)
- [Payfonte docs](https://docs.payfonte.com/guides/introductions/testing)
- [pawaPay docs](https://docs.pawapay.io/)
- [Campay PyPI](https://pypi.org/project/campay/1.0.1/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-13-netbuis.md -->

# Addendum 13 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (run planifié)

## Verdict
Aucune méthode nouvelle. Architecture inchangée : API agrégateur/opérateur (pawaPay, Campay, etc.) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis.

## Vérifié ce passage
- « Cameroon MTN MoMo Orange Money API collection disbursement 2026 » : seulement guides Kolonell (déjà connus), un package PHP lepresk/momo-api v1.2.0 (wrapper communautaire MTN MoMo, à évaluer seulement si backend PHP).
- « pawaPay Cameroon 2026 » : article pawaPay at PROMOTE 2026, TechCabal (3 Md$ de transactions, juin 2026), pages d'incidents ; « Pawa » d'Orange Cameroun = fonctionnalité de connectivité data, sans rapport avec les paiements.
- Aucune annonce d'API nouvelle ni de changement de mécanisme USSD push.

## Recommandation (inchangée)
Interface `PaymentProvider` abstraite ; MVP pawaPay ou Campay ; secours PayDunya/Moneroo/CinetPay/Notch Pay ; idempotence + polling + rapprochement ; ne jamais détenir de fonds clients ; montants entiers XAF.

## Sources
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [lepresk/momo-api](https://phpfreaks.com/news/20216)
- [pawaPay at PROMOTE 2026](https://pawapay.io/blog/pawapay-at-promote-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-14-netbuis.md -->

# Addendum 14 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (run planifié)

## Verdict
Aucune nouveauté. Architecture inchangée : API agrégateur/opérateur (pawaPay, Campay, etc.) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis.

## Vérifié ce passage
- Recherches « Cameroon mobile money API USSD push collection disbursement » et « Orange Money Web Payment / MTN MoMo Collection API changes 2026 » : uniquement guides Kolonell et page produit MTN MoMo API Cameroon Collection (déjà connus).
- Plateforme d'agrégation USSD unique #237# (Campost/ART) : article de 2019, sans API développeur — hors sujet.

## Recommandation (inchangée)
Interface `PaymentProvider` abstraite ; MVP pawaPay ou Campay ; secours PayDunya/Moneroo/CinetPay/Notch Pay ; idempotence + polling + rapprochement ; ne jamais détenir de fonds clients ; montants entiers XAF.

## Sources
- [MTN MoMo API Cameroon Collection](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Business in Cameroon — plateforme #237# (2019)](https://www.businessincameroon.com/economy/2711-9717-cameroon-launches-mobile-money-services-aggregation-platform-to-boost-financial-inclusion)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-15-netbuis.md -->

# Addendum 15 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (run planifié)

## Verdict
Aucune nouveauté. Les recherches « Cameroon mobile money API USSD push collection disbursement 2026 » et « pawaPay / Campay / Notch Pay Cameroon announcement » ne renvoient que des pages déjà connues (MTN MoMo API Cameroon Collection, guides Kolonell, blog/incidents pawaPay sans changement d'API).

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay…) → invite PIN poussée (USSD push) sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider` abstraite, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [MTN MoMo API Cameroon Collection](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [pawaPay — Company News](https://pawapay.io/blog-categories/company-news)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-16-netbuis.md -->

# Addendum 16 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (run planifié)

## Verdict
Aucune nouveauté d'architecture. Les recherches « Cameroon mobile money API USSD push collection disbursement 2026 » et « pawaPay / Campay / Notch Pay / Flutterwave Cameroon » renvoient les mêmes pages que les addenda précédents (MTN MoMo API Cameroon Collection, guides Kolonell). Seul rappel : Flutterwave dispose d'une licence de paiement au Cameroun (annonce de juin 2025, reprises en 2026) → option agrégateur supplémentaire, à garder derrière l'interface `PaymentProvider`.

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, Flutterwave, MTN MoMo API direct) → invite PIN poussée (USSD push) sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider` abstraite, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [MTN MoMo API Cameroon Collection](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Flutterwave — licence au Cameroun](https://fintech.global/2025/06/27/flutterwave-expands-licensed-payments-in-cameroon/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-17-netbuis.md -->

# Addendum 17 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (run planifié)

## Verdict
Aucune nouveauté. Recherches « Cameroon mobile money API collection disbursement USSD push … » et « Orange Money Cameroon Web Payment API » : mêmes sources que les addenda 1–16 (guides Kolonell, developer.orange.com/apis/om-webpay, MTN MoMo API). L'article sur le « code USSD unique » Mobile Money est de 2019 (chantier gouvernemental depuis 2017), sans impact sur les intégrations API actuelles. Un SDK PHP communautaire (camerpay/php-sdk, Packagist) existe : à évaluer seulement comme référence, pas en dépendance de production.

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, Flutterwave, MTN MoMo API direct, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [Orange Money Web Payment](https://developer.orange.com/apis/om-webpay)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Code USSD unique (2019)](https://www.digitalbusiness.africa/cameroun-bientot-un-code-unique-pour-lacces-aux-services-financiers-mobiles)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-18-netbuis.md -->

# Addendum 18 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (run planifié)

## Verdict
Aucune nouveauté. Deux recherches (collection/disbursement MTN MoMo + Orange Money Cameroun ; pawaPay/Campay changements) ne renvoient que les mêmes sources que les addenda 1–17 : guides Kolonell, SDK communautaires (campay sur PyPI, laravel-mobile-money sur Packagist — références seulement, pas de dépendance de production) et des pages d'incidents pawaPay (dégradations ponctuelles côté Orange Cameroun → justifie polling + rapprochement et bascule de fournisseur via l'interface `PaymentProvider`).

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, Flutterwave, MTN MoMo direct, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Idempotence, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money API Cameroun 2026](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)
- [pawaPay incident Orange Cameroun](https://isdown.app/status/pawapay/incidents/653290-performance-degradation-affecting-cameroon-orange-services)
- [campay (PyPI)](https://pypi.org/project/campay)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-19-netbuis.md -->

# Addendum 19 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (run planifié)

## Verdict
Aucune nouveauté structurante. Deux recherches (changements pawaPay/Campay/MTN/Orange ; nouvelles API push-USSD/décaissement Afrique) renvoient les mêmes sources que les addenda 1–18 (changelog pawaPay, pages d'incidents, guides Kolonell).

## Seule mention marginale
Klasha annonce une « MoMo Payout API » (décaissements mobile money multi-pays). À traiter comme option de décaissement alternative derrière l'interface `PaymentProvider`, sans changement d'architecture. Couverture Cameroun non vérifiée.

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, Flutterwave, MTN MoMo direct, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Idempotence, montants entiers XAF, ne jamais détenir de fonds clients, polling + rapprochement.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Klasha MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-20-netbuis.md -->

# Addendum 20 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (run planifié)

## Verdict
Aucune nouveauté structurante. Le changelog pawaPay n'affiche aucune entrée récente (dernière : juillet 2024 ; entrées Cameroun MTN/Orange = précision des motifs d'échec, 2024). Architecture inchangée par rapport aux addenda 1–19.

## Signaux marginaux (veille marché, non bloquants)
- Camtel prépare son entrée dans le mobile money (concurrent de MTN/Orange) : à surveiller comme futur fournisseur derrière l'interface `PaymentProvider`; aucune API publique vérifiée.
- Articles de presse sur Orange Money Cameroun (tarifs, plafonds de retrait, ouverture aux clients de réseaux concurrents) : impact possible sur les limites de montants à paramétrer, pas sur l'intégration.

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, Flutterwave, MTN MoMo direct, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Idempotence, montants entiers XAF, ne jamais détenir de fonds clients, polling + rapprochement.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Camtel et le mobile money](https://www.camer.be/93232/11:1/camtel-prepare-son-entree-dans-le-mobile-money-et-bouscule-mtn-et-orange-au-cameroun-cameroon.html)
- [Orange Money Cameroun tarifs/plafonds](https://ecomatin.net/mobile-money-orange-cameroun-abaisse-ses-tarifs-et-releve-les-plafonds-de-retrait)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-21-netbuis.md -->

# Addendum 21 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-06 (run planifié)

## Verdict
Aucune nouveauté. Le changelog pawaPay reste inchangé (dernière entrée 23 juillet 2024 ; entrées Cameroun : mai et février 2024, précision des motifs d'échec). La recherche web ne remonte aucune nouvelle méthode d'intégration par rapport aux addenda 1–20.

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, Flutterwave, Moneroo, MTN MoMo Collections direct, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Idempotence, montants entiers XAF, ne jamais détenir de fonds clients, polling + rapprochement.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Moneroo — méthodes disponibles](https://docs.moneroo.io/fr/payments/methodes-disponibles)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-22-netbuis.md -->

# Addendum 22 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (run planifié)

## Verdict
Aucune nouveauté. Le changelog pawaPay reste inchangé (dernière entrée 23 juillet 2024 ; Cameroun : Orange mai 2024, MTN février 2024, précision des motifs d'échec ; aucune dépréciation). La recherche web ne remonte que les mêmes sources (MTN MoMo API Cameroon Collections, Kolonell) : aucune nouvelle méthode par rapport aux addenda 1–21.

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, Flutterwave, Moneroo, MTN MoMo Collections/Disbursements direct, Orange Money Web Payment) → invite PIN poussée (USSD/STK) sur le téléphone du client → webhook signé (vérifier la signature). Le PIN n'est jamais saisi dans NetBuis. Idempotence (référence unique), montants entiers XAF, ne jamais détenir de fonds clients, polling + rapprochement en secours.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-23-netbuis.md -->

# Addendum 23 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (run planifié)

## Verdict
Aucune nouveauté. Le changelog pawaPay est inchangé (dernière entrée 23 juillet 2024 ; entrées Cameroun : février et mai 2024, précision des motifs d'échec). La recherche web ne remonte que les sources déjà connues (page produit MTN MoMo Cameroon Collections, guides Kolonell, paquet communautaire laravel mobile money) : aucune nouvelle méthode par rapport aux addenda 1–22.

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, Flutterwave, Moneroo, MTN MoMo Collections direct, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Packagist — laravel mobile money](https://packagist.org/packages/catidegla/laravel-mobile-money)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-24-netbuis.md -->

# Addendum 24 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (run planifié)

## Verdict
Aucune nouveauté. Le changelog pawaPay reste inchangé (dernière entrée 23 juillet 2024 ; entrées Cameroun : février et mai 2024). La recherche web ne remonte que des sources déjà connues (guides Kolonell Orange Money Web Payment / MTN MoMo Cameroun / paysage paiement, paquet Laravel communautaire, simulateur lefisk.cm) : aucune nouvelle méthode par rapport aux addenda 1–23.

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, Flutterwave, Moneroo, MTN MoMo Collections direct, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — Orange Money Web Payment Douala 2026](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-25-netbuis.md -->

# Addendum 25 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (run planifié, 2e passage)

## Verdict
Aucune nouveauté. Changelog pawaPay inchangé (dernière entrée 23 juillet 2024 ; Cameroun : fév. et mai 2024 ; aucune entrée USSD). La recherche web ne remonte que les sources déjà connues (Kolonell, lefisk.cm, paquets communautaires). Aucune nouvelle méthode par rapport aux addenda 1–24.

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, Flutterwave, Moneroo, MTN MoMo Collections direct, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-26-netbuis.md -->

# Addendum 26 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (run planifié, 3e passage)

## Verdict
Aucune nouveauté. Le changelog pawaPay reste inchangé (dernière entrée 23 juillet 2024 ; Cameroun : fév. et mai 2024 ; aucune entrée USSD). La recherche web ne remonte que des sources déjà connues (paquets communautaires Campay/PayUnit, page de statut pawaPay MTN USSD deposit). Aucune nouvelle méthode par rapport aux addenda 1–25.

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, Flutterwave, Moneroo, MTN MoMo Collections, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [pawaPay statut MTN USSD deposit](https://statusgator.com/services/pawapay/mtn--ussd-deposit)
- [Campay (PyPI)](https://pypi.org/project/campay)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-27-netbuis.md -->

# Addendum 27 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (run planifié, 4e passage)

## Verdict
Aucune nouveauté. Les recherches (pawaPay USSD/Cameroun, Orange Money Cameroun API) ne remontent que des sources déjà connues : pages de statut pawaPay (MTN/Yas/Vodacom USSD deposit), blog Kolonell (guides d'intégration Orange Money Web Payment / MTN MoMo), portail développeur Orange Money Business. Aucune nouvelle méthode par rapport aux addenda 1–26.

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, Flutterwave, Moneroo, MTN MoMo Collections, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [pawaPay statut MTN USSD deposit](https://statusgator.com/services/pawapay/mtn--ussd-deposit)
- [Orange Money Business API](https://developer.orange.com/apis/orange-money-business-api-discover)
- [Kolonell — Orange Money API Cameroun 2026](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-28-netbuis.md -->

# Addendum 28 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (run planifié, 5e passage)

## Verdict
Aucune nouveauté. Recherches pawaPay (changelog, SDK Node/PHP), Campay (SDK PyPI), Orange Money Cameroun (guides Kolonell, camerpay php-sdk) : uniquement des sources déjà connues. Aucune nouvelle méthode par rapport aux addenda 1–27.

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, Flutterwave, Moneroo, MTN MoMo Collections, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [pawaPay changelog](https://pawapay.io/changelog)
- [Campay (PyPI)](https://pypi.org/project/campay)
- [Kolonell — Orange Money Web Payment Douala 2026](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [camerpay php-sdk](https://packagist.org/packages/camerpay/php-sdk)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-29-netbuis.md -->

# Addendum 29 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (run planifié, 6e passage)

## Verdict
Aucune nouveauté. Recherche web (pawaPay, Campay, MTN MoMo, Orange Money Cameroun) : uniquement des sources déjà connues (guides Kolonell Orange Money Web Payment / MTN MoMo Cameroun 2026, eversend, Tsapa). Le changelog pawaPay accessible n'affiche aucune entrée récente exploitable (dernières entrées 2024). Aucune nouvelle méthode par rapport aux addenda 1–28.

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, Flutterwave, Moneroo, MTN MoMo Collections/Disbursements, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [pawaPay changelog](https://pawapay.io/changelog)
- [Kolonell — Orange Money Web Payment Douala 2026](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Eversend — MTN Mobile Money](https://eversend.co/platform/rails/mtn-mobile-money)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-30-netbuis.md -->

# Addendum 30 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (run planifié, 7e passage)

## Verdict
Aucune nouveauté. Deux recherches web (écosystème pawaPay/Campay/Orange Money/MTN MoMo Cameroun ; changements MTN MoMo collections/disbursements) ne remontent que des sources déjà connues : guides Kolonell (Orange Money Web Payment, MTN MoMo Cameroun, paysage paiement mobile Douala), Eversend, page MTN MoMo API « Cameroon Collections Widget », add-on MoMo Bedigit. Aucune nouvelle méthode par rapport aux addenda 1–29.

## Architecture (inchangée)
API agrégateur/opérateur → invite PIN poussée sur le téléphone du client (USSD push / widget) → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [MTN MoMo API — Cameroon Collections Widget](https://momoapi.mtn.com/Cameroon_Widget_productDetails)
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money Web Payment 2026](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Kolonell — Paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Eversend — MTN Mobile Money](https://eversend.co/platform/rails/mtn-mobile-money)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-31-netbuis.md -->

# Addendum 31 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (run planifié, 8e passage)

## Verdict
Aucune nouveauté. Deux recherches (écosystème pawaPay/Campay/Orange Money/MTN MoMo Cameroun ; changelog MTN MoMo disbursements) ne remontent que des sources déjà connues : guides Kolonell, pages pawaPay (frais, PROMOTE 2026, page d'incident), paquets communautaires (pypi mtnmomo, lepresk/momo-api v1.2.0, add-on Bedigit, plugin Laravel). Aucune nouvelle méthode par rapport aux addenda 1–30.

## Architecture (inchangée)
API agrégateur/opérateur → invite PIN poussée sur le téléphone du client (USSD push / widget) → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [pawaPay — frais](https://pawapay.io/fees)
- [pawaPay at PROMOTE 2026](https://pawapay.io/blog/pawapay-at-promote-2026)
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Paysage paiement mobile Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [mtnmomo (PyPI)](https://pypi.org/project/mtnmomo/)
- [lepresk/momo-api v1.2.0](https://phpfreaks.com/news/20216)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-32-netbuis.md -->

# Addendum 32 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (run planifié, 9e passage)

## Verdict
Aucune nouvelle méthode. Deux recherches (collecte/décaissement USSD push Cameroun ; Orange Money Web Payment / nouveautés dev) ne remontent que des sources déjà connues (guides Kolonell, developer.orange.com om-webpay, pages Orange Money SA établissement de paiement) et quelques paquets communautaires de wrappers PHP/Laravel (catidegla/laravel-mobile-money, camerpay/php-sdk, zaz-aangaraa/pay) — simples enveloppes des mêmes API, non recommandées pour la prod sans audit.

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, MTN MoMo Collection/Disbursement, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client (USSD push / widget) → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money Cameroun API/webhook](https://kolonell.com/en/blog/orange-money-cameroon-api-webhook-integration-2026)
- [Orange Developer — Web Payment FAQ](https://developer.orange.com/apis/om-webpay/faq)
- [Orange Money SA — établissement de paiement](https://www.teamfrance-export.fr/infos-sectorielles/20250/20250-orange-money-sa-devient-le-tout-premier-etablissement-de-paiement-au-cameroun)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [catidegla/laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-33-netbuis.md -->

# Addendum 33 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (run planifié, 10e passage)

## Verdict
Aucune nouvelle méthode. Deux recherches (pawaPay/Campay/MTN MoMo/Orange Money ; Orange Money Cameroun API collecte/décaissement) ne remontent que des sources déjà connues : guides Kolonell (MTN MoMo, Orange Money Web Payment, coûts, paysage), packages communautaires (camerpay/php-sdk, zaz-aangaraa/pay), annonce Orange Money SA établissement de paiement, pages d'incidents pawaPay (statut). 

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, MTN MoMo Collection/Disbursement, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [Kolonell — Orange Money Web Payment Douala 2026](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Kolonell — Orange Money API boutique Cameroun 2026](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)
- [Kolonell — Paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [Orange Money agrément établissement de paiement](https://osiris.sn/orange-money-decroche-le-tout-premier-agrement-d-etablissement-de-paiement-au.html)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-34-netbuis.md -->

# Addendum 34 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (run planifié, 11e passage)

## Verdict
Une seule vraie nouveauté mineure : **Cauris** (SDK Python alpha v0.2.1, 14 avril 2026, MIT, Python ≥3.10) — agrégateur couvrant Cameroun, Sénégal, Congo-Brazzaville, RDC, Ouganda, Bénin, Guinée, Gabon (Orange Money + MTN ; XAF/XOF/CDF/UGX/GNF). Fonctions : création de charge par **push USSD** (le client confirme avec son PIN), vérification de statut (success/pending/failed), webhooks + metadata. Encaissement seulement documenté ; pas de décaissement mentionné. Statut alpha → à surveiller, non recommandé en production sans due diligence (agrément, SLA, sécurité).

Le reste des résultats = sources déjà connues (guides Kolonell, pawaPay, Campay, incidents pawaPay). L'article osiris sur l'agrément MTN date de 2022 (pas nouveau).

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, MTN MoMo Collection/Disbursement, Orange Money Web Payment, éventuellement Cauris) → invite PIN poussée sur le téléphone → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Sources
- [Cauris (PyPI)](https://pypi.org/project/cauris/)
- [Kolonell — Paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell — MTN MoMo Cameroun intégration](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Campay (PyPI)](https://pypi.org/project/campay)
- [osiris — MTN agrément (2022)](https://osiris.sn/Cameroun-MTN-en-passe-de-rejoindre.html)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-35-netbuis.md -->

# Addendum 35 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (run planifié, 12e passage)

## Verdict
Aucune nouveauté significative. Trois recherches (push USSD Cameroun, agrégateurs/payout, Cauris) ne renvoient que des sources déjà connues : guides Kolonell (Orange Money Web Payment, MTN MoMo, choix d'agrégateur multi-canal, coût d'intégration), documentation pawaPay, incidents Flutterwave Cameroun (perturbations intermittentes mobile money), Cauris (PyPI, alpha, déjà traité en addendum 34).

Seule entrée "nouvelle" : **SopraEnt** — plateforme de facturation pour FAI africains qui *intègre* PawaPay/Paystack/Flutterwave/PesaPal etc. Ce n'est pas une API de paiement autonome, rien sur le Cameroun, Orange/MTN ni push USSD → hors sujet pour NetBuis.

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, MTN MoMo Collection/Disbursement, Orange Money Web Payment, Flutterwave, éventuellement Cauris) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients. Prévoir un fournisseur de repli vu les incidents Flutterwave Cameroun.

## Sources
- [Kolonell — agrégateur unique Wave/OM/MTN/Moov](https://kolonell.com/fr/blog/agregateur-unique-wave-om-mtn-moov-integration-2026)
- [Kolonell — Orange Money Web Payment Douala](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [pawaPay docs](https://docs.pawapay.io/)
- [Flutterwave — incident Cameroun (isdown)](https://isdown.app/status/flutterwave/incidents/645592-cameroon-service-alert-intermittent-mobile-money-service-disruption)
- [Cauris (PyPI)](https://pypi.org/project/cauris/)
- [SopraEnt payments](https://sopraent.com/docs/payments)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-36-netbuis.md -->

# Addendum 36 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (run planifié, 13e passage)

## Verdict
Aucune nouveauté. Deux recherches (push USSD/Orange/MTN Cameroun ; pawaPay/Campay/Flutterwave payout) ne renvoient que des sources déjà traitées : guides Kolonell (MTN MoMo, Orange Money, coûts d'intégration, paysage paiement mobile Douala), Cauris (PyPI), docs pawaPay (payouts v2), incidents Flutterwave Cameroun, SopraEnt (hors sujet).

Entrées marginales non exploitées : un plugin Laravel « zaz-aangaraa/pay » (laraplugins.io, wrapper communautaire, à ne pas retenir sans audit) et un article osiris.sn « MTN en passe de rejoindre… » (titre seul, non lu).

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, MTN MoMo Collection/Disbursement, Orange Money Web Payment, Flutterwave) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients, fournisseur de repli.

## Recommandation
Rappel de l'audit v39 : suspendre cette routine (ou la passer en hebdomadaire) et passer au jalon 0 (30 commerçants dans un quartier pilote).

## Sources
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money API boutique](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [pawaPay — payouts](https://docs.pawapay.io/v2/docs/payouts.md)
- [Flutterwave — incident Cameroun](https://isdown.app/status/flutterwave/incidents/645593-cameroon-service-alert-intermittent-mobile-money-service-disruption)
- [Cauris (PyPI)](https://pypi.org/project/cauris/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-37-netbuis.md -->

# Addendum 37 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (14e passage)

## Verdict
Aucune nouveauté. Deux recherches (MTN MoMo / Orange Money push USSD et disbursement ; pawaPay / Campay / Flutterwave payout) renvoient les mêmes sources que l'addendum 36 : guides Kolonell, docs pawaPay (payouts v2, changelog), incidents Flutterwave Cameroun, SopraEnt (hors sujet), laraplugins (wrapper communautaire, non retenu). Seule entrée récente : allAfrica (31/03/2026) sur l'inclusion financière de MTN Cameroun, sans impact technique.

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, MTN MoMo Collection/Disbursement, Orange Money Web Payment, Flutterwave) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients, fournisseur de repli.

## Recommandation
Comme l'audit v39 : suspendre cette routine (ou la passer en hebdomadaire) et lancer le jalon 0 (30 commerçants dans un quartier pilote).

## Sources
- [Kolonell — paysage paiement mobile](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [pawaPay — payouts](https://docs.pawapay.io/v2/docs/payouts.md)
- [pawaPay — changelog](https://pawapay.io/changelog)
- [allAfrica — MTN Cameroun inclusion financière](https://fr.allafrica.com/stories/202603310593.html)
- [Flutterwave — incident Cameroun](https://isdown.app/status/flutterwave/incidents/645593-cameroon-service-alert-intermittent-mobile-money-service-disruption)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-38-netbuis.md -->

# Addendum 38 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-07 (15e passage)

## Verdict
Aucune nouveauté. Deux recherches (MTN MoMo / Orange Money collection-disbursement ; pawaPay / Campay / Flutterwave payout) renvoient les mêmes sources que l'addendum 37 : guides Kolonell, portail MTN MoMo Cameroon Collections, changelog et incidents pawaPay, incidents Flutterwave Cameroun, article sur l'agrément BEAC de Flutterwave (déjà connu).

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers, ne pas détenir de fonds clients, fournisseur de repli.

## Recommandation
Identique à l'audit v39 : suspendre cette routine ou la passer en hebdomadaire, lancer le jalon 0 (30 commerçants, quartier pilote).

## Sources
- [MTN MoMo Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — coût intégration MoMo/Orange Money](https://kolonell.com/fr/blog/cout-integration-mtn-momo-orange-money-douala-2026)
- [pawaPay — changelog](https://pawapay.io/changelog)
- [Flutterwave — BEAC Cameroun](https://osiris.sn/flutterwave-obtient-le-feu-vert-de-la-beac-pour-operer-au-cameroun.html)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-39-netbuis.md -->

# Addendum 39 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (MTN MoMo/Orange Money API payout Cameroun ; pawaPay/Campay nouveautés) ne remontent que des sources déjà connues : guides Kolonell (paysage paiement mobile Cameroun, coût d'intégration, coût réel encaissement Orange Money), docs CinetPay, paquet camerpay/php-sdk, pages d'incidents pawaPay. Seule source peu vue : docs.rafiki-api.com (couverture payout Afrique, page Cameroun) — agrégateur payout supplémentaire, non lu en détail [N].

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, MTN MoMo Collection/Disbursement, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Recommandation
Saturation atteinte : arrêter ou espacer fortement ce run planifié.

## Sources
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell — coût intégration MTN MoMo/Orange Money](https://kolonell.com/fr/blog/cout-integration-mtn-momo-orange-money-douala-2026)
- [CinetPay docs](https://docs.cinetpay.com/api/1.0-en/checkout/tableau)
- [Rafiki — couverture payout](https://docs.rafiki-api.com/docs/country-coverage-africa)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-40-netbuis.md -->

# Addendum 40 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode d'intégration. Deux recherches (Cameroun MoMo/Orange Money payout/push ; pawaPay/Campay/Flutterwave) ne remontent que des sources déjà connues : guides Kolonell, docs pawaPay (payouts, payment page), docs Flutterwave mobile money, alerte d'incident Flutterwave Cameroun, paquet laravel-pawapay.

Éléments de contexte seulement (non techniques, à surveiller) : MTN Cameroun a obtenu son agrément d'établissement de paiement (après Orange) ; carte virtuelle MoMo pour paiements en ligne internationaux (févr. 2026) ; Orange Money Cameroun a baissé ses tarifs et relevé les plafonds de retrait. Aucun impact sur l'architecture.

## Architecture (inchangée)
API agrégateur/opérateur (pawaPay, Campay, Flutterwave, MTN MoMo Collection/Disbursement, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants entiers XAF, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée : arrêter ou espacer fortement ce run planifié.

## Sources
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Journal du Cameroun — MTN agrément établissement de paiement](https://fr.journalducameroun.com/cameroun-apres-orange-mtn-obtient-son-agrement-detablissement-de-paiement/)
- [pawaPay — payouts](https://docs.pawapay.io/v2/docs/payouts)
- [Flutterwave — mobile money](https://developer.flutterwave.com/v3.0/docs/mobile-money-1)
- [Flutterwave — alerte Cameroun](https://isdown.app/status/flutterwave/incidents/645592-cameroon-service-alert-intermittent-mobile-money-service-disruption)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-41-netbuis.md -->

# Addendum 41 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (Cameroun MoMo/Orange payout/push ; pawaPay/Campay/Notch Pay/CinetPay) ne remontent que des sources déjà connues (Kolonell, pawaPay, CinetPay, Eversend, SDK camerpay). Seule source mineure peu vue : Rafiki (couverture payout Cameroun) — agrégateur de plus, même schéma.

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (cf. addendum 40, audit v39) : arrêter ou espacer fortement ce run planifié. Aucune notification envoyée (rien de nouveau).

## Sources
- [Rafiki — couverture payout](https://docs.rafiki-api.com/docs/country-coverage-africa)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [pawaPay à PROMOTE 2026](https://pawapay.io/blog/pawapay-at-promote-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-42-netbuis.md -->

# Addendum 42 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (Cameroun MoMo/Orange push+payout ; pawaPay/Flutterwave/Paystack/Hub2) ne ramènent que des sources déjà connues : Kolonell, Rafiki, Eversend, et la licence Flutterwave Cameroun (annoncée en 2025, déjà connue).

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 40–41, audit v39) : arrêter ou espacer fortement ce run planifié. Aucune notification envoyée (rien de nouveau).

## Sources
- [Rafiki — couverture payout](https://docs.rafiki-api.com/docs/country-coverage-africa)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Flutterwave — licence Cameroun](https://fintech.global/2025/06/27/flutterwave-expands-licensed-payments-in-cameroon/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-43-netbuis.md -->

# Addendum 43 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (MTN MoMo/Orange Money Cameroun collection+disbursement ; pawaPay/Flutterwave/Hub2/CinetPay payout) ne ramènent que des sources déjà connues (MTN MoMo API Developer Portal Cameroun, Kolonell, Flutterwave licence Cameroun).

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 40–42, audit v39). Arrêter ou espacer fortement ce run planifié. Aucune notification envoyée.

## Sources
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Flutterwave — licence Cameroun](https://fintech.global/2025/06/27/flutterwave-expands-licensed-payments-in-cameroon/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-44-netbuis.md -->

# Addendum 44 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (MTN MoMo / Orange Money Cameroun collecte + décaissement ; Orange Money API / pawaPay Cameroun) ne ramènent que des sources déjà connues : page produit MTN MoMo API Cameroun, guides Kolonell, paquets PHP communautaires. La plateforme #237# (Campost) est un article de 2019, sans API développeur.

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, Notch Pay, Flutterwave…) → invite PIN poussée sur le téléphone du client → webhook signé. Le PIN n'est jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 36–43, audit v39). Arrêter ou espacer fortement ce run planifié. Aucune notification envoyée.

## Sources
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — Orange Money Cameroun webhook 2026](https://kolonell.com/en/blog/orange-money-cameroon-api-webhook-integration-2026)
- [Business in Cameroon — #237# (2019)](https://www.businessincameroon.com/economy/2711-9717-cameroon-launches-mobile-money-services-aggregation-platform-to-boost-financial-inclusion)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-45-netbuis.md -->

# Addendum 45 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (collecte MTN/Orange Cameroun ; annonces pawaPay/Campay/Notch Pay 2026) ne ramènent que des sources déjà connues (guides Kolonell, paquet Packagist communautaire, article Camtel/Blue Money déjà suivi aux addenda 11 et 20, audit v14). Aucun changelog ou lancement d'API nouveau détecté.

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, Notch Pay, Flutterwave…) → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, montants XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 36–44, audit v39). Espacer ou arrêter ce run planifié. Aucune notification envoyée (rien de nouveau).

## Sources
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Camtel et le mobile money](https://www.camer.be/93232/11:1/camtel-prepare-son-entree-dans-le-mobile-money-et-bouscule-mtn-et-orange-au-cameroun-cameroon.html)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-46-netbuis.md -->

# Addendum 46 — API → push USSD / envoi de fonds — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (nouveautés pawaPay/Campay/Notch Pay/MTN MoMo/Orange Money ; annonces USSD push 2026) ne ramènent que des sources déjà connues (blogs Kolonell, docs MTN MoMo, page frais pawaPay). Aucun changelog ni lancement d'API nouveau.

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo API, Orange Money WebPay) → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 36–45, audit v39). Arrêter ou espacer fortement ce run planifié. Aucune notification envoyée.

## Sources
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — USSD push vs API checkout](https://kolonell.com/en/blog/ussd-push-vs-api-checkout-rural-kenya-2026)
- [pawaPay](https://pawapay.io/fees)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-47-netbuis.md -->

# Addendum 47 — API → push USSD / envoi de fonds — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (nouveautés pawaPay/Campay/Notch Pay/MTN MoMo/Orange Money Cameroun ; lancements USSD push / collections / disbursements Afrique 2026) ne ramènent que des sources déjà connues (blogs Kolonell, SDK Campay PyPI/Packagist). Seule mention marginale : Klasha « MoMo Payout API » (agrégateur de décaissement, même famille que pawaPay/Flutterwave — pas une nouvelle catégorie).

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 36–46, audit v39). Arrêter ou espacer fortement ce run planifié. Aucune notification envoyée.

## Sources
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — USSD vs API](https://kolonell.com/en/blog/ussd-vs-api-mobile-money-payment-sme-decision-2026)
- [Klasha — MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [Campay PyPI](https://pypi.org/project/campay)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-48-netbuis.md -->

# Addendum 48 — API → push USSD / envoi de fonds — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches ne ramènent que des sources déjà connues (Kolonell, Packagist, Flutterwave licence Cameroun 2025). Seule info marginale : Camtel prépare une entrée sur le mobile money (marché, pas une méthode d'intégration) et interconnexion Cameroun–Côte d'Ivoire–Sénégal (transferts) — à surveiller, aucune API publique annoncée.

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers.

## Recommandation
Saturation confirmée (addenda 36–47). Arrêter ou espacer fortement ce run. Aucune notification envoyée.

## Sources
- [Camtel mobile money](https://www.camer.be/93232/11:1/societe)
- [Interconnexion mobile money](https://www.capmad.com/article/mobile-money-interconnecte-le-trio-cameroun-cote-divoire-senegal-revolutionne-les-transferts-instantanes)
- [Flutterwave Cameroun](https://fintech.global/2025/06/27/flutterwave-expands-licensed-payments-in-cameroon/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-49-netbuis.md -->

# Addendum 49 — API → push USSD / envoi de fonds — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (MTN MoMo/Orange Money collection push ; Cameroun agrégateurs 2026) ne ramènent que des sources déjà connues : Kolonell, Packagist (laravel-mobile-money), pub.dev mtn_momo_sdk, agréments Orange Money SA et MTN établissement de paiement au Cameroun.

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers.

## Recommandation
Saturation confirmée (addenda 36–48). Espacer ou arrêter ce run. Aucune notification envoyée.

## Sources
- [Kolonell MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [MTN agrément paiement Cameroun](https://fr.journalducameroun.com/cameroun-apres-orange-mtn-obtient-son-agrement-detablissement-de-paiement/)
- [laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-50-netbuis.md -->

# Addendum 50 — API → push USSD / envoi de fonds — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (Orange Money/MTN MoMo Cameroun collection-disbursement ; agrégateurs Afrique push USSD/payout) ne renvoient que des sources déjà connues : MTN MoMo API (Collections Cameroun), Kolonell (guides Orange Money/MTN 2026), packages Packagist (laravel-mobile-money, simple-mobile-money), et Klasha MoMo Payout API (agrégateur payout multi-pays, même modèle que les agrégateurs déjà listés).

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone du client → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, montants XAF entiers.

## Recommandation
Saturation confirmée (addenda 36–49). Espacer ou arrêter ce run planifié. Aucune notification envoyée.

## Sources
- [MTN MoMo API Cameroun Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell Orange Money Cameroun 2026](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Klasha MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [simple-mobile-money](https://packagist.org/packages/maestrodimateo/simple-mobile-money)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-51-netbuis.md -->

# Addendum 51 — API → push USSD / envoi de fonds — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (Orange Money/MTN MoMo Cameroun ; agrégateurs Afrique payout/collections) ne renvoient que des variantes de ce qui est déjà couvert : guides Kolonell (MTN MoMo Cameroun, Orange Money, paysage paiement 2026), package Packagist laravel-mobile-money (catidegla), Klasha MoMo Payout, pawaPay (partenariat Deriv, dépôts mobile money), et Rafiki API (couverture payout Cameroun) — simple agrégateur supplémentaire du même modèle.

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone du client (USSD push) → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, montants XAF entiers.

## Recommandation
Saturation confirmée (addenda 36–50). Espacer ou arrêter ce run planifié. Aucune notification envoyée.

## Sources
- [Rafiki API couverture Afrique](https://docs.rafiki-api.com/docs/country-coverage-africa)
- [Kolonell MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Klasha MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [pawaPay x Deriv](https://thefintechtimes.com/pawapay-and-deriv-join-forces-to-scale-mobile-money-deposits-across-africa/)
- [laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-52-netbuis.md -->

# Addendum 52 — API → push USSD / envoi de fonds — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (Orange Money/MTN MoMo Cameroun ; annonces API mobile money Afrique/Cameroun) ne renvoient que les guides Kolonell, Klasha MoMo Payout, pawaPay, déjà couverts. Seule mention périphérique : Camtel prépare son entrée dans le mobile money (concurrent futur, sans API publique ; à surveiller seulement).

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone (USSD push) → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, montants XAF entiers.

## Recommandation
Saturation confirmée (addenda 36–51). Espacer ou arrêter ce run planifié. Aucune notification envoyée.

## Sources
- [Kolonell MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Klasha MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [Camtel et le mobile money](https://www.camer.be/93232/11:1/societe)
- [pawaPay](https://pawapay.io)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-53-netbuis.md -->

# Addendum 53 — API → push USSD / envoi de fonds — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (Orange Money/MTN MoMo Cameroun ; lancements API mobile money Afrique) ne renvoient que Kolonell, CinetPay, Klasha MoMo Payout, Eversend, pawaPay : tout déjà couvert.

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone (USSD push) → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, montants XAF entiers.

## Recommandation
Saturation confirmée (addenda 36–52). Arrêter ou espacer fortement ce run planifié. Aucune notification envoyée.

## Sources
- [Kolonell MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [CinetPay docs](https://docs.cinetpay.com/api/1.0-en/checkout/tableau)
- [Klasha MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [Eversend payouts](https://eversend.co/platform/guides/integrate-mobile-money-payouts)
- [pawaPay](https://pawapay.io)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-54-netbuis.md -->

# Addendum 54 — API → push USSD / envoi de fonds — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Une recherche (mobile money API Cameroun, collecte/décaissement, octobre 2026) ne renvoie que des sources déjà couvertes : MTN MoMo API Cameroun (Collections), Kolonell (MTN MoMo / Orange Money Web Payment), Klasha MoMo Payout, packages Laravel/Python communautaires.

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone (USSD push) → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 36–53). Arrêter ou espacer fortement ce run planifié. Aucune notification envoyée.

## Sources
- [MTN MoMo API Cameroun — Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell Orange Money Web Payment Cameroun 2026](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Klasha MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-55-netbuis.md -->

# Addendum 55 — API → push USSD / envoi de fonds — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (FR + EN, Cameroun, collecte/décaissement, oct. 2026) ne renvoient que des sources déjà couvertes : articles Kolonell (paysage paiement mobile Cameroun 2026, MTN MoMo, Orange Money API/Web Payment, comparatif frais), Digital Business Africa, Orange Money SA devenu établissement de paiement (2025).

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone (USSD push) → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 36–54). Arrêter ou espacer fortement ce run planifié. Aucune notification envoyée.

## Sources
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell — Orange Money vs MTN MoMo frais 2026](https://kolonell.com/fr/blog/orange-money-vs-mtn-momo-cameroun-douala-frais-2026)
- [Kolonell — brancher Orange Money API](https://kolonell.com/fr/blog/brancher-orange-money-api-boutique-douala-cameroun-2026)
- [Team France Export — Orange Money SA établissement de paiement](https://www.teamfrance-export.fr/infos-sectorielles/20250/20250-orange-money-sa-devient-le-tout-premier-etablissement-de-paiement-au-cameroun)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-56-netbuis.md -->

# Addendum 56 — API → push USSD / envoi de fonds — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (FR Cameroun + EN Afrique) ne renvoient que des sources déjà couvertes (Kolonell MTN MoMo / Orange Money / frais / paysage 2026, Digital Business Africa, developer.orange.com).

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone (USSD push) → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 36–55). Suspendre ou espacer fortement ce run planifié. Aucune notification envoyée.

## Sources
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell — MTN MoMo intégration site web](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — brancher Orange Money API](https://kolonell.com/fr/blog/brancher-orange-money-api-boutique-douala-cameroun-2026)
- [Kolonell — évolution mobile money 2026](https://kolonell.com/fr/blog/mobile-money-evolution-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-57-netbuis.md -->

# Addendum 57 — API → push USSD / envoi de fonds — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (FR Cameroun + EN Afrique) ne renvoient que des sources déjà connues : MTN MoMo API (Collections Cameroun, Disbursements), Orange Money Web Payment, blogs Kolonell, agrégateurs (ex. Klasha MoMo payout, packages Laravel/Python génériques).

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone (USSD push) → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 36–56). Suspendre ou espacer fortement ce run planifié. Aucune notification envoyée.

## Sources
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — coût intégration MTN MoMo / Orange Money](https://kolonell.com/fr/blog/cout-integration-mtn-momo-orange-money-douala-2026)
- [Kolonell — Orange Money Web Payment](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Klasha — MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-58-netbuis.md -->

# Addendum 58 — API → push USSD / envoi de fonds — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (Cameroun FR/EN + agrégateurs Afrique) ne renvoient que des sources déjà connues : MTN MoMo API, Orange Money Web Payment, blogs Kolonell, agrégateurs (pawaPay, Onafriq, Beyonic, IntaSend), packages Laravel/Python génériques.

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone (USSD push) → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 36–57). Suspendre ou espacer fortement ce run planifié. Aucune notification envoyée.

## Sources
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Kolonell — Orange Money Web Payment](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [pawaPay](https://pawapay.io/blog/pawapay-live-in-burkina-faso)
- [IntaSend — interopérabilité](https://intasend.com/payments/payment-apis-and-interoperability-building-africa-s-financial-future)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-59-netbuis.md -->

# Addendum 59 — API → push USSD / envoi de fonds — 2026-10-08 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (MTN MoMo/Orange Money collection-disbursement ; Cameroun développeurs 2026) ne renvoient que des sources déjà connues : portail MTN MoMo Developer, add-on bedigit, SDK Dart/Flutter MTN MoMo, blogs Kolonell, agréments d'établissement de paiement (Orange, MTN), carte virtuelle MoMo (févr. 2026, déjà connue).

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone (USSD push) → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 36–58). Suspendre ou passer cette routine en hebdomadaire. Aucune notification envoyée : rien d'urgent.

## Sources
- [MTN MoMo Developer — produits](https://momodeveloper.mtn.co.rw/products)
- [Kolonell — MTN MoMo Cameroun intégration](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [MTN agrément établissement de paiement](https://fr.journalducameroun.com/cameroun-apres-orange-mtn-obtient-son-agrement-detablissement-de-paiement/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-60-netbuis.md -->

# Addendum 60 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (MTN MoMo/Orange Money collection-disbursement Cameroun ; agrégateurs STK push Afrique) ne renvoient que des sources déjà connues : portail MTN MoMo Developer (page Cameroon Collection), add-on bedigit, blogs Kolonell, Laravel mobile-money (packagist), articles d'ouverture d'API MTN (Ouganda, Rwanda). Seule mention à vérifier éventuellement : Klasha « MoMo Payout API » (décaissements multi-pays), de date non confirmée — à traiter comme un agrégateur de plus, sans changement d'architecture.

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone (USSD push) → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 36–59). Suspendre cette routine ou la passer en hebdomadaire. Aucune notification envoyée : rien d'urgent.

## Sources
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [MTN MoMo Developer — produits](https://momodeveloper.mtn.co.rw/products)
- [Kolonell — MTN MoMo Cameroun intégration](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Klasha — MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [bedigit — momo add-on](https://bedigit.com/help/article/momo-add-on)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-61-netbuis.md -->

# Addendum 61 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (MTN MoMo/Orange Money collection-disbursement ; agrégateurs payout Cameroun) ne renvoient que des sources déjà connues (portail MTN MoMo Cameroon Collections, Kolonell, bedigit, SDK Dart mtn_momo_sdk). Mentions secondaires d'agrégateurs déjà classés comme « un agrégateur de plus » : Kora (XAF/XOF), Rafiki (couverture payout), pawaPay (PROMOTE 2026).

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone (USSD push) → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 36–60). Suspendre cette routine ou la passer en hebdomadaire. Aucune notification envoyée : rien d'urgent.

## Sources
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Kora — mobile money Côte d'Ivoire & Cameroun](https://www.korahq.com/blog/mobile-money-in-cote-divoire-and-cameroon-xaf-xof)
- [Rafiki — country coverage](https://docs.rafiki-api.com/docs/country-coverage-africa)
- [pawaPay at PROMOTE 2026](https://pawapay.io/blog/pawapay-at-promote-2026)
- [mtn_momo_sdk (Dart/Flutter)](https://pub.dev/packages/mtn_momo_sdk)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-62-netbuis.md -->

# Addendum 62 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié, 2e passage)

## Verdict
Aucune nouvelle méthode. Deux recherches (MTN MoMo/Orange Money push + disbursement ; agrégateurs Cameroun collections/payouts) ne renvoient que des sources déjà connues : portail MTN MoMo Cameroon Collections, Kolonell (paysage Cameroun 2026), Kora, pawaPay (PROMOTE 2026), SDK Dart mtn_momo_sdk, Payfonte (direct charge mobile money, agrégateur de plus).

Seul élément marginal : communiqué de Konoom Cameroun S.A. (agrément d'établissement de paiement) — à surveiller comme futur acteur, non exploitable tel quel (pas d'API publique documentée).

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone (USSD push) → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 36–62). Suspendre la routine ou la passer en hebdomadaire. Aucune notification envoyée : rien d'urgent.

## Sources
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Kora — Côte d'Ivoire & Cameroun](https://www.korahq.com/blog/mobile-money-in-cote-divoire-and-cameroon-xaf-xof)
- [pawaPay at PROMOTE 2026](https://pawapay.io/blog/pawapay-at-promote-2026)
- [Payfonte — direct charge mobile money](https://docs.payfonte.com/guides/collections/direct-charge/mobile-money)
- [Konoom Cameroun — agrément](https://ecomatin.net/communique-cameroun-la-societe-konoom-cameroun-s-a-a-le-plaisir-dannoncer-lobtention-de-son-agrement-en-qualite-detablissement-de-paiement)
- [mtn_momo_sdk](https://pub.dev/packages/mtn_momo_sdk)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-63-netbuis.md -->

# Addendum 63 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié, 3e passage)

## Verdict
Aucune méthode fondamentalement nouvelle. Deux recherches (MTN MoMo/Orange Money push + disbursement ; Orange Money Web Payment Cameroun) renvoient les mêmes familles déjà documentées : API directe MTN MoMo (Collections/Disbursements), Orange Money Web Payment, agrégateurs.

## Éléments marginaux (agrégateurs / SDK)
- Klasha : API « MoMo Payout » (décaissements mobile money multi-pays) — agrégateur de plus, à comparer à pawaPay/Kora pour les payouts.
- CinetPay (docs checkout) — agrégateur francophone déjà dans la même catégorie.
- camerpay/php-sdk (Packagist) — SDK communautaire, non officiel, à ne pas privilégier.
- Orange Money SA : premier établissement de paiement agréé au Cameroun (déjà connu).

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone (USSD push) → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée. Suspendre la routine ou la passer en hebdomadaire. Aucune notification : rien d'urgent.

## Sources
- [Klasha — MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [CinetPay — docs checkout](https://docs.cinetpay.com/api/1.0-en/checkout/tableau)
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money Web Payment](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-64-netbuis.md -->

# Addendum 64 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié, 4e passage)

## Verdict
Aucune méthode nouvelle. Deux recherches (MoMo/Orange Money push+disbursement Cameroun ; agrégateurs pawaPay/Flutterwave/Hub2) ne renvoient que les familles déjà documentées.

## Éléments marginaux
- Rafiki API : doc de couverture « Cameroon payout » — agrégateur de payouts supplémentaire, à comparer à pawaPay/Klasha.
- Flutterwave : licence de paiement au Cameroun (déjà couvert : agrégateur licencié).
- laravel-mobile-money (Packagist) : package communautaire, non officiel.
- Kolonell : guides MTN MoMo / paysage paiement Cameroun 2026 (déjà cités).

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée (USSD push) sur le téléphone → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (4 passages sans nouveauté aujourd'hui). Suspendre la routine ou la passer en hebdomadaire. Pas de notification : rien d'urgent.

## Sources
- [Rafiki — Country coverage](https://docs.rafiki-api.com/docs/country-coverage-africa)
- [Flutterwave Cameroun](https://fintech.global/2025/06/27/flutterwave-expands-licensed-payments-in-cameroon/)
- [pawaPay](https://pawapay.io)
- [Kolonell — paysage paiement Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-65-netbuis.md -->

# Addendum 65 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié, 5e passage)

## Verdict
Aucune méthode nouvelle. Deux recherches (MTN MoMo/Orange Money Cameroun collection+disbursement ; agrégateurs payout/push PIN en Afrique) ne renvoient que des familles déjà documentées.

## Éléments marginaux
- Eversend : guide « integrate mobile money payouts » — agrégateur de payouts supplémentaire (à comparer à pawaPay/Klasha, couverture Cameroun à vérifier).
- Klasha MoMo Payout API : déjà couvert.
- Kolonell : guides MTN MoMo / Orange Money Cameroun 2026, USSD push vs API checkout (déjà cités).

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée. Suspendre la routine ou la passer en hebdomadaire. Pas de notification.

## Sources
- [Klasha MoMo payout](https://developers.klasha.com/transfers/momo-payout)
- [Eversend payouts](https://eversend.co/platform/guides/integrate-mobile-money-payouts)
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — USSD push vs API](https://kolonell.com/en/blog/ussd-push-vs-api-payment-collection-no-smartphone-merchant-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-66-netbuis.md -->

# Addendum 66 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune méthode nouvelle. Deux recherches (MTN MoMo/Orange Money Cameroun ; payout mobile money Afrique) ne renvoient que des familles déjà documentées.

## Éléments marginaux
- Kotani Pay (docs Pay-In/Pay-Out flow) : agrégateur supplémentaire, couverture Cameroun à vérifier.
- Kolonell : guides MTN MoMo (Ghana, CI, Ouganda, Douala) et bulk payout Sénégal — déjà cités ou hors périmètre.
- Klasha, Eversend : déjà couverts (addendum 65).

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur → invite PIN poussée sur le téléphone → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée. Suspendre la routine ou la passer en hebdomadaire. Pas de notification.

## Sources
- [Kotani Pay pay-in/pay-out](https://docs.kotanipay.com/docs/mobile-money-pay-inpay-out-flow)
- [Klasha MoMo payout](https://developers.klasha.com/transfers/momo-payout)
- [Eversend payouts](https://eversend.co/platform/guides/integrate-mobile-money-payouts)
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-67-netbuis.md -->

# Addendum 67 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune méthode nouvelle. Deux recherches (MTN MoMo/Orange Money Cameroun ; mobile money Afrique disbursement/STK push) ne renvoient que des sources déjà documentées (Kolonell, Klasha, Africa's Talking, guides Daraja/Airtel hors périmètre Cameroun).

## Architecture (inchangée)
Backend NetBuis → API opérateur (MTN MoMo Collection/Disbursement, Orange Money WebPay) ou agrégateur → invite PIN poussée sur le téléphone du numéro enregistré → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 57–67). Suspendre la routine ou la passer en hebdomadaire. Pas de notification.

## Sources
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money API Cameroun](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)
- [Klasha MoMo payout](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [Africa's Talking Payments](https://help.africastalking.com/en/articles/2298172-what-can-i-do-with-the-payments-api-in-kenya)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-68-netbuis.md -->

# Addendum 68 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune méthode nouvelle. Deux recherches (MTN MoMo/Orange Money Cameroun ; mobile money Afrique payout/STK push) ne renvoient que des sources déjà connues (Kolonell, Klasha, Kora, MTN MoMo Developer).

## Architecture (inchangée)
Backend NetBuis → API opérateur (MTN MoMo Collection/Disbursement, Orange Money WebPay) ou agrégateur (Klasha, Kora…) → invite PIN poussée sur le téléphone du numéro enregistré → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 57–68). Suspendre la routine ou la passer en hebdomadaire. Pas de notification.

## Sources
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Paysage paiement mobile Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Klasha MoMo payout](https://developers.klasha.com/transfers/momo-payout)
- [Kora — Mobile money Côte d'Ivoire & Cameroun](https://www.korahq.com/blog/mobile-money-in-cote-divoire-and-cameroon-xaf-xof)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-69-netbuis.md -->

# Addendum 69 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune méthode nouvelle. Deux recherches (Cameroun MTN MoMo/Orange Money 2026 ; agrégateurs Afrique payout/STK push) ne renvoient que des sources déjà documentées (Kolonell, Klasha MoMo payout, Dusupay, Eversend, plateforme #237# de 2019, Camtel — vus aux addenda 14 et 20).

## Architecture (inchangée)
Backend NetBuis → API opérateur (MTN MoMo Collection/Disbursement, Orange Money WebPay) ou agrégateur (pawaPay, Campay, Flutterwave, Klasha…) → invite PIN poussée sur le téléphone du numéro enregistré → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 57–69). Suspendre la routine ou la passer en hebdomadaire. Pas de notification.

## Sources
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Klasha MoMo payout](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [Business in Cameroon — #237# (2019)](https://www.businessincameroon.com/economy/2711-9717-cameroon-launches-mobile-money-services-aggregation-platform-to-boost-financial-inclusion)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-70-netbuis.md -->

# Addendum 70 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune méthode nouvelle. Deux recherches (MTN MoMo / Orange Money Cameroun API USSD push 2026 ; pawaPay / Campay / Flutterwave payout STK push Cameroun) ne renvoient que des sources déjà documentées : articles Kolonell (MTN MoMo Cameroun, paysage paiement mobile 2026), portail développeur MTN MoMo, et l'agrément BEAC de Flutterwave au Cameroun (déjà connu, partenariat Ecobank).

## Architecture (inchangée)
Backend NetBuis → API opérateur (MTN MoMo Collection/Disbursement, Orange Money WebPay) ou agrégateur (pawaPay, Campay, Flutterwave…) → invite PIN poussée sur le téléphone du numéro enregistré → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 57–70). Suspendre la routine ou la passer en hebdomadaire. Pas de notification.

## Sources
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Flutterwave — licence Cameroun](https://thepaypers.com/payments/news/flutterwave-secures-digital-payment-licence-in-cameroon)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-71-netbuis.md -->

# Addendum 71 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune méthode nouvelle. Une recherche (MTN MoMo / Orange Money API USSD push, disbursement, Cameroun 2026) ne renvoie que des sources déjà documentées : Kolonell (MTN MoMo Cameroun, Orange Money Web Payment Douala, MTN MoMo Ghana/Côte d'Ivoire, disbursement Kigali), portail développeur MTN MoMo.

## Architecture (inchangée)
Backend NetBuis → API opérateur (MTN MoMo Collection/Disbursement, Orange Money WebPay) ou agrégateur (pawaPay, Campay, Flutterwave…) → invite PIN poussée sur le téléphone du numéro enregistré → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 57–71). Suspendre la routine ou la passer en hebdomadaire. Pas de notification.

## Sources
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money Web Payment Douala](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Kolonell — MTN MoMo disbursement](https://kolonell.com/en/blog/mtn-momo-disbursement-payout-api-kigali-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-72-netbuis.md -->

# Addendum 72 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune méthode nouvelle. Une recherche (MTN MoMo / Orange Money, API USSD push, disbursement, Cameroun 2026) ne renvoie que des sources déjà couvertes (Kolonell Cameroun/Ghana/CI, portail développeur MTN MoMo) plus une page Klasha (payout MoMo multi-pays), qui relève de la catégorie « agrégateur » déjà documentée.

## Architecture (inchangée)
Backend NetBuis → API opérateur (MTN MoMo Collection/Disbursement, Orange Money WebPay) ou agrégateur (pawaPay, Campay, Flutterwave, Klasha…) → invite PIN poussée sur le téléphone du numéro enregistré → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 57–72). Suspendre la routine ou la passer en hebdomadaire. Pas de notification.

## Sources
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Klasha — MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [MTN MoMo Developer](https://momodeveloper.mtn.co.rw/products)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-74-netbuis.md -->

# Addendum 74 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune méthode nouvelle. Deux recherches (MTN MoMo / Orange Money, push USSD, disbursement, Cameroun, 2026) ne renvoient que des sources déjà couvertes : Kolonell (Cameroun, Ghana/CI, Ouganda, disbursement bulk), portail développeur MTN MoMo, Klasha (payout MoMo), SDK communautaires (mtn_momo_sdk, packages Laravel/PHP, camerpay/php-sdk), plugin Magento Orange Money Cameroun — tous relevant des catégories déjà documentées (API opérateur directe ou agrégateur).

## Architecture (inchangée)
Backend NetBuis → API opérateur (MTN MoMo Collection/Disbursement, Orange Money WebPay) ou agrégateur (pawaPay, Campay, Flutterwave, Klasha…) → invite PIN poussée sur le téléphone du numéro enregistré → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 57–74). Suspendre la routine ou la passer en hebdomadaire. Pas de notification.

## Sources
- [Kolonell — MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money Cameroun](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)
- [Kolonell — disbursement bulk](https://kolonell.com/fr/blog/mobile-money-disbursement-bulk-payouts-afrique-2026)
- [Klasha — MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [MTN MoMo Developer](https://momodeveloper.mtn.co.rw/products)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-75-netbuis.md -->

# Addendum 75 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune méthode technique nouvelle. Deux recherches (MTN MoMo / Orange Money, push USSD, disbursement, Cameroun) renvoient les mêmes sources que l'addendum 74 : Kolonell (Cameroun, Ghana/CI, Guinée), portail développeur MTN MoMo, Klasha (payout MoMo), SDK communautaires (mtn_momo_sdk, packages Laravel).

Seul élément périphérique : articles sur Orange Cameroun devenant établissement financier / établissement de paiement agréé (aspect réglementaire, pas une nouvelle méthode d'intégration) — à garder à l'esprit pour la conformité (agrément, KYC) de NetBuis.

## Architecture (inchangée)
Backend → API opérateur (MTN MoMo Collection/Disbursement, Orange Money WebPay) ou agrégateur (pawaPay, Campay, Flutterwave, Klasha…) → invite PIN poussée sur le téléphone du numéro enregistré → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 57–75). Suspendre la routine ou la passer en hebdomadaire. Pas de notification.

## Sources
- [Kolonell — Orange Money Cameroun](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)
- [Journal du Cameroun — Orange établissement financier](https://fr.journalducameroun.com/cameroun-orange-devient-un-etablissement-financier/)
- [MTN MoMo Developer](https://momodeveloper.mtn.co.rw/products)
- [Klasha — MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-76-netbuis.md -->

# Addendum 76 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune méthode nouvelle. Deux recherches (MTN MoMo / Orange Money Cameroun ; agrégateurs mobile money PIN prompt / payout) renvoient les mêmes sources que l'addendum 75 : Kolonell, portail développeur MTN MoMo, Klasha payout, plus des références déjà connues (Flutterwave, Dusupay direct charge, Eversend payouts, EBANX, package Laravel simple-mobile-money).

## Architecture (inchangée)
Backend → API opérateur (MTN MoMo Collection/Disbursement, Orange Money WebPay) ou agrégateur (pawaPay, Campay, Flutterwave, Dusupay, Klasha…) → invite PIN poussée sur le téléphone du numéro enregistré → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 57–76). Suspendre la routine ou la passer en hebdomadaire. Pas de notification.

## Sources
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money Cameroun](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)
- [MTN MoMo Developer](https://momodeveloper.mtn.co.rw/products)
- [Klasha — MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [Dusupay — Direct Charge](https://developer.dusupay.com/funds-collection/mobile-money-collection/mobile-money-direct-charge)
- [Flutterwave — Mobile Money](https://developer.flutterwave.com/docs/mobile-money/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-77-netbuis.md -->

# Addendum 77 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune méthode nouvelle. Une recherche (mobile money API USSD push / PIN prompt / payout MTN MoMo & Orange Money) renvoie uniquement des sources déjà connues : Kolonell (guides MoMo Ghana/CI/Ouganda, flux USSD), add-on MoMo Bedigit, package Laravel mobile-money.

## Architecture (inchangée)
Backend → API opérateur (MTN MoMo Collection/Disbursement, Orange Money WebPay) ou agrégateur (pawaPay, Campay, Flutterwave, Dusupay, Klasha…) → invite PIN poussée sur le téléphone du numéro enregistré → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 57–77). Suspendre la routine ou la passer en hebdomadaire. Pas de notification.

## Sources
- [Kolonell — MTN MoMo Ghana/CI](https://kolonell.com/en/blog/mtn-momo-api-ghana-ivory-coast-2026)
- [Kolonell — USSD flow MoMo Ghana](https://kolonell.com/en/blog/ussd-payment-flow-mtn-momo-ghana-2026)
- [Kolonell — MoMo Collections Uganda](https://kolonell.com/en/blog/mtn-momo-collections-api-uganda-2026)
- [Bedigit MoMo add-on](https://bedigit.com/support/article/momo-add-on)
- [Laravel mobile money](https://packagist.org/packages/catidegla/laravel-mobile-money)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-78-netbuis.md -->

# Addendum 78 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune méthode nouvelle. La recherche (mobile money API USSD push / PIN prompt / payout MTN MoMo & Orange Money 2026) renvoie exactement les mêmes sources que l'addendum 77 (Kolonell, add-on MoMo Bedigit, package Laravel mobile-money).

## Architecture (inchangée)
Backend → API opérateur (MTN MoMo Collection/Disbursement, Orange Money WebPay) ou agrégateur (pawaPay, Campay, Flutterwave, Dusupay, Klasha…) → invite PIN poussée (USSD) sur le téléphone du numéro enregistré → webhook signé + polling de rapprochement. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 57–78). Suspendre la routine ou la passer en hebdomadaire. Pas de notification.

## Sources
- [Kolonell — MTN MoMo Ghana/CI](https://kolonell.com/en/blog/mtn-momo-api-ghana-ivory-coast-2026)
- [Kolonell — USSD flow MoMo Ghana](https://kolonell.com/en/blog/ussd-payment-flow-mtn-momo-ghana-2026)
- [Kolonell — MoMo Collections Uganda](https://kolonell.com/en/blog/mtn-momo-collections-api-uganda-2026)
- [Bedigit MoMo add-on](https://bedigit.com/support/article/momo-add-on)
- [Laravel mobile money](https://packagist.org/packages/catidegla/laravel-mobile-money)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-79-netbuis.md -->

# Addendum 79 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune méthode nouvelle. Mêmes sources que l'addendum 78 (Kolonell, Bedigit, package Laravel). Le billet pawaPay « Q3 round-up » est daté du 29/10/2025 (anciennes infos : MTN MoMo renforcé au Cameroun/Congo/Ouganda/Zambie/Bénin, réconciliation accélérée) — pas une nouveauté 2026.

## Architecture (inchangée)
Backend → API opérateur (MTN MoMo Collection/Disbursement, Orange Money WebPay) ou agrégateur (pawaPay, Campay, Flutterwave…) → invite PIN poussée sur le téléphone du numéro enregistré → webhook signé + polling. Le PIN n'est jamais saisi dans NetBuis.

## Recommandation
Saturation confirmée (addenda 57–79). Suspendre la routine ou la passer en hebdomadaire. Pas de notification.

## Sources
- [Kolonell — MTN MoMo Ghana/CI](https://kolonell.com/en/blog/mtn-momo-api-ghana-ivory-coast-2026)
- [pawaPay Q3 round-up](https://pawapay.io/blog/pawapay-q3-round-up)
- [Bedigit MoMo add-on](https://bedigit.com/support/article/momo-add-on)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-80-netbuis.md -->

# Addendum 80 — API → push USSD / envoi de fonds — 2026-10-09 (run planifié)

## Verdict
Aucune nouveauté. Le changelog pawaPay reste inchangé (dernière entrée 23 juillet 2024 ; Cameroun : fév. et mai 2024 ; aucune mention USSD ni dépréciation). La recherche web ne remonte que des sources déjà connues (Kolonell Orange Money Web Payment, docs MTN MoMo, pages d'incidents pawaPay).

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, Flutterwave, Moneroo, MTN MoMo API, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée depuis longtemps : arrêter ou espacer fortement ce run planifié. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — Orange Money Web Payment Cameroun](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-81-netbuis.md -->

# Addendum 81 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-10 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay inchangé (dernière entrée 23 juillet 2024). La recherche web ne remonte que les blogs Kolonell déjà connus (paysage paiement, Orange Money Web Payment, coût d'intégration, MTN MoMo Cameroun) et des pages de frais lefisk.cm / digitalbusiness.africa.

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur (pawaPay, Campay, Flutterwave, Moneroo, MTN MoMo Collections/Disbursement, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, montants entiers XAF, ne jamais détenir de fonds clients, interface `PaymentProvider`.

## Recommandation
Saturation confirmée (addenda 36–80). Suspendre ou espacer ce run planifié. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Kolonell — coût d'intégration MTN MoMo / Orange Money](https://kolonell.com/fr/blog/cout-integration-mtn-momo-orange-money-douala-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-82-netbuis.md -->

# Addendum 82 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-10 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay inchangé (dernière entrée 23 juillet 2024). La recherche web ne remonte que les blogs Kolonell déjà connus (paysage paiement, Orange Money Web Payment, MTN MoMo) et des pages d'information USSD génériques.

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur (pawaPay, Campay, Flutterwave, Moneroo, MTN MoMo Collections/Disbursement, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, montants entiers XAF, ne jamais détenir de fonds clients, interface `PaymentProvider`.

## Recommandation
Saturation confirmée (addenda 36–81). Suspendre ou espacer ce run planifié. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Kolonell — Orange Money Web Payment](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-83-netbuis.md -->

# Addendum 83 — API → push USSD / envoi de fonds (Cameroun) — 2026-10-10 (run planifié)

## Verdict
Aucune nouveauté significative. Changelog pawaPay inchangé (dernière entrée 23 juillet 2024). La recherche ne remonte que les blogs Kolonell déjà connus. Seule piste mineure : Kora (korahq.com/cameroon), agrégateur affichant le Cameroun — à évaluer seulement comme fournisseur de secours derrière l'interface `PaymentProvider`.

## Architecture (inchangée)
Backend NetBuis → API opérateur ou agrégateur (pawaPay, Campay, Flutterwave, Moneroo, Kora?, MTN MoMo Collections/Disbursement, Orange Money Web Payment) → invite PIN poussée sur le téléphone du client → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, montants entiers XAF, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 36–82). Suspendre ou espacer ce run planifié. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kora Cameroun](https://www.korahq.com/cameroon/home)
- [Kolonell — paysage paiement Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-88-netbuis.md -->

# Addendum 88 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (nouveautés API mobile money Cameroun ; annonces pawaPay/Campay/MTN MoMo/Orange Money oct. 2026) ne ramènent que des sources déjà connues (blogs Kolonell, page MTN MoMo API Cameroon Collection, article Business in Cameroon sur la plateforme d'agrégation). Mention marginale non approfondie : article Digital Business Africa sur un « code unique » d'accès aux services financiers mobiles au Cameroun (piste réglementaire USSD, pas une API développeur).

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, Flutterwave, Notch Pay, MTN MoMo API, Orange Money WebPay) → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Arrêter ou espacer fortement ce run planifié. Aucune notification envoyée.

## Sources
- [Kolonell — Orange Money API Cameroun 2026](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)
- [MTN MoMo API Cameroon Collection](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Digital Business Africa — code unique](https://www.digitalbusiness.africa/cameroun-bientot-un-code-unique-pour-lacces-aux-services-financiers-mobiles)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-89-netbuis.md -->

# Addendum 89 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (nouveautés API mobile money Cameroun ; annonces pawaPay/Campay/Notch Pay/Flutterwave) ne ramènent que des sources déjà connues : MTN MoMo API Collection Cameroun, blogs Kolonell, article Business in Cameroon (plateforme d'agrégation), et la licence Flutterwave au Cameroun (déjà couverte : agrégateur licencié BEAC). Packagist : wrappers PHP (ekolotech/mobilemoney-gateway, elgiopay) — simples SDK, pas de nouvelle méthode.

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, Flutterwave, Notch Pay, MTN MoMo API, Orange Money WebPay) → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Arrêter ou espacer fortement ce run planifié. Aucune notification envoyée.

## Sources
- [MTN MoMo API Cameroon Collection](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Business in Cameroon — plateforme d'agrégation](https://www.businessincameroon.com/economy/2711-9717-cameroon-launches-mobile-money-services-aggregation-platform-to-boost-financial-inclusion)
- [Techpoint — Flutterwave licence Cameroun](https://techpoint.africa/news/flutterwave-secures-cameroon-licence/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-90-netbuis.md -->

# Addendum 90 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (pawaPay/Campay/MTN/Orange push USSD ; Orange Money payout/disbursement Cameroun) ne remontent que des sources déjà documentées : guides Kolonell, docs pawaPay, Rafiki (payout), camerpay/php-sdk, campay PyPI, zaz-aangaraa/pay, enkap (Odoo).

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, MTN MoMo Collection/Disbursement, Orange Money WebPay, Notch Pay, Flutterwave) → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (cf. addendum 89). Suspendre ou passer ce run en hebdomadaire ; priorité = jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [pawaPay docs](https://docs.pawapay.io/)
- [Rafiki — couverture payout](https://docs.rafiki-api.com/docs/country-coverage-africa)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-91-netbuis.md -->

# Addendum 91 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (MTN MoMo / Orange Money USSD push + disbursement Cameroun ; pawaPay / Campay / Notch Pay / Flutterwave payout) ne renvoient que des sources déjà documentées : guides Kolonell, portail MTN MoMo, docs pawaPay, Klasha MoMo Payout (couverture Cameroun non confirmée, cf. addendum 10), licence Flutterwave Cameroun (cf. addenda 16, 38, 70), wrappers PHP (lepresk/momo-api, zaz-aangaraa/pay, laravel-pawapay).

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone du numéro enregistré → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (cf. addenda 89–90). Suspendre ou passer ce run en hebdomadaire ; priorité = jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Klasha — MoMo Payout API](https://www.klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [Flutterwave — licence Cameroun](https://thepaypers.com/payments/news/flutterwave-secures-digital-payment-licence-in-cameroon)
- [pawaPay docs](https://docs.pawapay.io/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-92-netbuis.md -->

# Addendum 92 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouvelle méthode d'intégration. Deux recherches (lancements mobile money API Cameroun ; changelogs pawaPay/Campay/Orange/MTN) ne ramènent que des sources connues, plus trois éléments marginaux à surveiller (non vérifiés, aucune API développeur documentée) :

- Camtel prépare son entrée dans le mobile money au Cameroun (nouvel opérateur potentiel, pas d'API publique à ce jour).
- Express Union : service mobile money via WhatsApp (canal conversationnel, pas d'API d'intégration documentée).
- pawaPay : billet « Q3 round-up » (marchés de remittance, réconciliation plus rapide) — évolution d'agrégateur, pas une nouvelle catégorie.

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo API, Orange Money WebPay) → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Espacer fortement ce run planifié. Aucune notification envoyée.

## Sources
- [Camtel — entrée dans le mobile money](https://www.camer.be/amp/93232/11:1/societe)
- [Express Union via WhatsApp](https://www.digitalbusiness.africa/cameroun-express-union-lance-un-service-de-mobile-money-via-whatsapp)
- [pawaPay Q3 round-up](https://pawapay.io/blog/pawapay-q3-round-up)
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-93-netbuis.md -->

# Addendum 93 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouvelle méthode. Recherche « mobile money API Cameroun » : mêmes sources que l'addendum 92 (Camtel en préparation, tarifs Orange/MTN, guides Kolonell). Changelog pawaPay : dernière entrée juillet 2024, rien de récent.

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo API, Orange Money WebPay) → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée : espacer fortement ce run planifié (hebdomadaire suffirait). Aucune notification envoyée.

## Sources
- [Camtel — entrée dans le mobile money](https://www.camer.be/93232/11:1/camtel-prepare-son-entree-dans-le-mobile-money-et-bouscule-mtn-et-orange-au-cameroun-cameroon.html)
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-94-netbuis.md -->

# Addendum 94 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouvelle méthode. Recherche web « mobile money API Cameroun » : mêmes sources que l'addendum 93 (guides Kolonell, Camtel/Orange Money, docs agrégateurs). Changelog pawaPay : dernière entrée 23 juillet 2024, aucune entrée 2026.

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo API, Orange Money WebPay) → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée : passer ce run planifié en hebdomadaire. Aucune notification envoyée.


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-96-netbuis.md -->

# Addendum 96 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (nouveautés API mobile money Cameroun ; annonces pawaPay/Campay/Notch Pay/Flutterwave) ne renvoient que des sources déjà connues : guides Kolonell, forum développeurs MTN MoMo, licence Flutterwave Cameroun (déjà couverte, addenda 16/38/89), incidents Flutterwave (interruptions intermittentes mobile money Cameroun → prévoir fournisseur de repli).

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo API, Orange Money WebPay) → invite PIN poussée sur le téléphone du client → webhook signé. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, polling + rapprochement, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Passer ce run en hebdomadaire ou le suspendre. Aucune notification envoyée.

## Sources
- [Kolonell — MTN MoMo API 2026](https://kolonell.com/fr/blog/mtn-momo-api-ghana-cote-ivoire-2026)
- [Techpoint — Flutterwave licence Cameroun](https://techpoint.africa/news/flutterwave-secures-cameroon-licence/)
- [Flutterwave — incident mobile money Cameroun](https://isdown.app/status/flutterwave/incidents/645592-cameroon-service-alert-intermittent-mobile-money-service-disruption)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-97-netbuis.md -->

# Addendum 97 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (nouveautés mobile money Cameroun / pawaPay / Campay ; Orange Money Cameroun API push 2026) ne renvoient que des sources déjà documentées : guides Kolonell, SDK camerpay/php-sdk, zaz-aangaraa/pay, Rafiki (payout, addendum 41), articles sur l'agrément d'établissement de paiement Orange/MTN (addenda 40, 75).

## Architecture (inchangée)
Agrégateur/opérateur (pawaPay, Campay, Notch Pay, TranZak, Flutterwave, MTN MoMo Collection/Disbursement, Orange Money WebPay) → invite PIN poussée sur le téléphone du client → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Suspendre ce run ou le passer en hebdomadaire. Aucune notification envoyée.

## Sources
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell — Orange Money API Cameroun](https://kolonell.com/fr/blog/integrer-orange-money-cameroun-api-webhook-2026)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)
- [Rafiki — couverture payout](https://docs.rafiki-api.com/docs/country-coverage-africa)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-98-netbuis.md -->

# Addendum 98 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (mobile money Cameroun USSD push ; pawaPay/Campay/Notch Pay/Flutterwave) ne renvoient que des sources déjà documentées : guides Kolonell, SDK Packagist (catidegla/laravel-mobile-money, zaz-aangaraa/pay), licence Flutterwave Cameroun (déjà couverte, addenda 16, 38, 89), article pawaPay PROMOTE 2026 (événementiel, pas technique).

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone du client → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Suspendre ce run ou le passer en hebdomadaire. Aucune notification envoyée.

## Sources
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Flutterwave — licence Cameroun](https://www.connectingafrica.com/fintech/flutterwave-expands-further-with-license-in-cameroon)
- [pawaPay at PROMOTE 2026](https://pawapay.io/blog/pawapay-at-promote-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-99-netbuis.md -->

# Addendum 99 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (mobile money Cameroun USSD push ; pawaPay/Campay/Notch Pay/Fapshi) ne renvoient que des sources déjà connues : guides Kolonell, SDK Laravel (zaz-aangaraa/pay), plugin Tsapa, documentation pawaPay v2 (upgrade_from_v1, SDK Node 2.0.0, déjà couvert).

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone du client → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (cf. addendum 98). Passer ce run en hebdomadaire ou le suspendre. Aucune notification envoyée.

## Sources
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell — intégration MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [pawaPay — upgrade from v1](https://docs.pawapay.io/v2/docs/upgrade_from_v1)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-100-netbuis.md -->

# Addendum 100 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (mobile money Cameroun USSD push ; changelogs pawaPay/Campay/Notch Pay/Fapshi) ne renvoient que des sources déjà connues : pawaPay (docs + Product Updates), Flutterwave Mobile Money, SDK PyPI campay, SDK Laravel zaz-aangaraa/pay, guides Kolonell. Seul élément marginal : doc Payfonte (direct-charge mobile money), agrégateur secondaire, à garder en veille sans action.

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone du client → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (cf. addenda 98-99). Passer ce run en hebdomadaire ou le suspendre. Aucune notification envoyée.

## Sources
- [pawaPay](https://docs.pawapay.io/)
- [pawaPay — Product Updates](https://pawapay.io/blog-categories/product-updates)
- [Flutterwave Mobile Money](https://developer.flutterwave.com/docs/mobile-money/)
- [Campay PyPI](https://pypi.org/project/campay)
- [Payfonte direct charge](https://docs.payfonte.com/guides/collections/direct-charge/mobile-money)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-101-netbuis.md -->

# Addendum 101 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (mobile money Cameroun USSD push ; nouveautés pawaPay/Campay/Notch Pay/Fapshi/CinetPay) ne renvoient que des sources déjà connues : MTN MoMo API (Collections Cameroun), guides Kolonell, packages Laravel (catidegla/laravel-mobile-money, zaz-aangaraa/pay), articles CinetPay (nouveau guichet, incident cyber de fév. 2026). Rien de nouveau côté opérateurs ou agrégateurs.

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone du client → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (cf. addenda 98-100). Passer ce run en hebdomadaire ou le suspendre. Aucune notification envoyée.

## Sources
- [MTN MoMo — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Laravel mobile money](https://packagist.org/packages/catidegla/laravel-mobile-money)
- [zaz-aangaraa/pay](https://laraplugins.io/plugins/zaz-aangaraa/pay)
- [CinetPay — nouveau guichet](https://www.osiris.sn/CinetPay-lance-son-nouveau-guichet.html)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-102-netbuis.md -->

# Addendum 102 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (MTN MoMo/Orange Money API Cameroun ; actualités pawaPay/Flutterwave/CinetPay/Campay) ne renvoient que des sources déjà connues : MTN MoMo Collections Cameroun, guides Kolonell 2026, licence Flutterwave Cameroun (2025, déjà connue), pawaPay à PROMOTE 2026 (événementiel, sans changement d'API).

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone du client → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 98-101). Passer ce run en hebdomadaire ou le suspendre. Aucune notification envoyée.

## Sources
- [MTN MoMo — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money Douala 2026](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Flutterwave — licence Cameroun](https://fintech.global/2025/06/27/flutterwave-expands-licensed-payments-in-cameroon/)
- [pawaPay à PROMOTE 2026](https://pawapay.io/blog/pawapay-at-promote-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-103-netbuis.md -->

# Addendum 103 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouvelle méthode. Deux recherches (Orange Money/MTN MoMo Cameroun ; pawaPay/Flutterwave/CinetPay/Campay) ne renvoient que des sources déjà connues (guides Kolonell 2026, docs pawaPay, SDK Campay, docs CinetPay, articles MTN/Orange inclusion financière).

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone du client → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 98-102). Passer ce run en hebdomadaire ou le suspendre. Aucune notification envoyée.

## Sources
- [Kolonell — Orange Money Douala 2026](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [pawaPay docs](https://docs.pawapay.io/)
- [CinetPay docs](https://docs.cinetpay.com/api/1.0-en/introduction/overview)
- [Campay (PyPI)](https://pypi.org/project/campay/1.0.1/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-104-netbuis.md -->

# Addendum 104 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune méthode fondamentalement nouvelle. Deux recherches standard : seules nuances mineures.

- Payfonte (docs.payfonte.com, « direct charge / mobile money ») : un agrégateur de plus avec le même modèle (charge directe → invite PIN sur le téléphone → webhook). À ajouter comme candidat secondaire derrière l'interface `PaymentProvider`.
- Flutterwave : licence de paiement au Cameroun (articles 2025, republiés en 2026) → option agrégateur régulé supplémentaire.
- Fil MTN MoMo Developer Community (erreur 510, auth haut volume) : rappel de gérer les tokens/rate-limits côté backend.

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 98-103). Passer ce run en hebdomadaire ou le suspendre. Aucune notification envoyée (rien d'actionnable).

## Sources
- [Kolonell — Orange Money Douala 2026](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Payfonte — direct charge mobile money](https://docs.payfonte.com/guides/collections/direct-charge/mobile-money)
- [MTN MoMo community — auth flow 510](https://momodevelopercommunity.mtn.com/momo-api-production-q-a-7/mtn-momo-api-authentication-flow-for-high-volume-pos-application-510)
- [The Paypers — Flutterwave licence Cameroun](https://thepaypers.com/payments/news/flutterwave-secures-digital-payment-licence-in-cameroon)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-105-netbuis.md -->

# Addendum 105 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouveauté. Deux recherches standard (Orange Money/MTN MoMo Cameroun ; payout/collection mobile money) ne remontent que des guides déjà couverts (Kolonell, CinetPay, Dusupay, Klasha MoMo Payout API, SDK communautaires).

- Klasha « MoMo Payout API » et Dusupay payouts : agrégateurs de décaissement supplémentaires, même modèle que les précédents → candidats secondaires derrière l'interface `PaymentProvider`.

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 98-104). Suspendre ou passer le run en hebdomadaire. Aucune notification envoyée (rien d'actionnable).

## Sources
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Klasha — MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [Dusupay — mobile money payouts](https://developer.dusupay.com/payouts-disbursements/mobile-money-payouts)
- [CinetPay docs](https://docs.cinetpay.com/api/1.0-en/checkout/tableau)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-106-netbuis.md -->

# Addendum 106 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouveauté. Deux recherches standard ne remontent que du déjà couvert (Kolonell, MTN MoMo Developer, Klasha, Orange/MTN interopérabilité) + agrégateurs secondaires Eversend et Kotani Pay (pay-in/pay-out mobile money), même modèle que les précédents.

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Suspendre le run ou passer en hebdomadaire. Aucune notification envoyée (rien d'actionnable).

## Sources
- [Kolonell — paysage Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Klasha MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [Eversend payouts](https://eversend.co/platform/guides/integrate-mobile-money-payouts)
- [Kotani Pay flow](https://docs.kotanipay.com/docs/mobile-money-pay-inpay-out-flow)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-107-netbuis.md -->

# Addendum 107 — API → push USSD / envoi de fonds — 2026-10-10 (run planifié)

## Verdict
Aucune nouveauté. Une recherche standard ne remonte que les sources déjà couvertes (Kolonell Cameroun/Orange/MTN, Klasha MoMo Payout, Digital Business Africa tarifs MoMo).

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 100+). Suspendre ce run planifié ou le passer en hebdomadaire/mensuel. Aucune notification envoyée (rien d'actionnable).

## Sources
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money API Cameroun](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)
- [Klasha MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [Digital Business Africa — tarifs MoMo](https://www.digitalbusiness.africa/cameroun-les-tarifs-de-retrait-de-mtn-mobile-money-momo-en-2025/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-108-netbuis.md -->

# Addendum 108 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté actionnable. Deux recherches standard (MTN MoMo/Orange Money Cameroun collection/disbursement/USSD push ; Orange Money Web Payment) ne remontent que les sources déjà couvertes (Kolonell, Digital Business Africa, lefisk.cm) et des SDK tiers mineurs (camerpay/php-sdk, plugin Laravel) sans valeur pour NetBuis.

## Architecture (inchangée)
Agrégateur/opérateur → invite PIN poussée sur le téléphone du payeur → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Suspendre ce run ou passer en mensuel. Aucune notification envoyée.

## Sources
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money API/webhook Cameroun](https://kolonell.com/fr/blog/integrer-orange-money-cameroun-api-webhook-2026)
- [Digital Business Africa — tarifs MoMo](https://www.digitalbusiness.africa/cameroun-les-tarifs-de-retrait-de-mtn-mobile-money-momo-en-2025/)
- [camerpay/php-sdk](https://packagist.org/packages/camerpay/php-sdk)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-109-netbuis.md -->

# Addendum 109 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté. Une recherche standard ne remonte que les sources déjà couvertes (Kolonell Cameroun MTN/Orange, MTN MoMo Developer Cameroon Collections, Digital Business Africa tarifs MoMo, guide « Going Live with MTN MoMo API »).

## Architecture (inchangée)
Opérateur/agrégateur → invite PIN poussée sur le téléphone du payeur → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Suspendre ce run planifié ou le passer en mensuel. Aucune notification envoyée (rien d'actionnable).

## Sources
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Going Live with MTN MoMo API](https://cleverengineer.substack.com/p/going-live-with-mtn-momo-api-in-2025)
- [Digital Business Africa — tarifs MoMo](https://www.digitalbusiness.africa/cameroun-les-tarifs-de-retrait-de-mtn-mobile-money-momo-en-2025/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-110-netbuis.md -->

# Addendum 110 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté actionnable. Une recherche (la seconde requête a été refusée par le classifieur d'autorisation, non contournée) ne remonte que des sources déjà couvertes : séries d'articles Kolonell (paysage paiement mobile Cameroun, coûts d'intégration MoMo/Orange Money, comparatif frais). Deux sources mineures vues : Eversend (rail MTN Mobile Money) et Rafiki (couverture payout Cameroun) — agrégateurs de payout, à ne considérer que comme alternatives secondaires, non vérifiées.

## Architecture (inchangée)
Opérateur/agrégateur → invite PIN poussée sur le téléphone du payeur (USSD push / Request-to-Pay) → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Suspendre ce run planifié ou le passer en mensuel. Aucune notification envoyée (rien d'actionnable).

## Sources
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Eversend — MTN Mobile Money rail](https://eversend.co/platform/rails/mtn-mobile-money)
- [Rafiki — couverture payout Afrique](https://docs.rafiki-api.com/docs/country-coverage-africa)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-111-netbuis.md -->

# Addendum 111 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté actionnable. Deux recherches (MTN MoMo Collection / Request-to-Pay Cameroun ; Orange Money Web Payment Cameroun) ne remontent que des sources déjà connues : portail officiel MTN MoMo API (Cameroon Collections), developer.orange.com (OM WebPay), séries Kolonell, packages communautaires (Laravel MoMo, add-on bedigit) sans valeur nouvelle.

## Architecture (inchangée)
Opérateur/agrégateur → invite PIN poussée sur le téléphone du payeur (USSD push / Request-to-Pay) → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Suspendre ce run planifié ou le passer en mensuel. Aucune notification envoyée (rien d'actionnable).

## Sources
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Orange Money Web Payment](https://developer.orange.com/apis/om-webpay)
- [Kolonell — Orange Money Cameroun API/webhook 2026](https://kolonell.com/en/blog/orange-money-cameroon-api-webhook-integration-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-112-netbuis.md -->

# Addendum 112 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté actionnable. Deux recherches (MTN MoMo / Orange Money Cameroun collection + USSD push ; agrégateurs payout Cameroun) ne remontent que des sources déjà connues : portail MTN MoMo API (Cameroon Collections), séries Kolonell, add-on bedigit, Rafiki payout (couverture Cameroun), Klasha MoMo Payout API.

## Architecture (inchangée)
Opérateur/agrégateur → invite PIN poussée sur le téléphone du payeur (Request-to-Pay / USSD push) → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, XAF entiers, ne jamais détenir de fonds clients. Décaissement : API Disbursements MTN / agrégateurs (Rafiki, Klasha) à évaluer côté conformité.

## Recommandation
Saturation confirmée. Suspendre ce run planifié ou le passer en mensuel. Aucune notification (rien d'actionnable).

## Sources
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Rafiki — Cameroon payout](https://docs.rafiki-api.com/docs/country-coverage-africa)
- [Klasha — MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-113-netbuis.md -->

# Addendum 113 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté actionnable. Une recherche (Cameroun mobile money API, USSD push, collection/décaissement, MTN MoMo / Orange Money) ne remonte que des sources déjà connues : portail MTN MoMo API (Cameroon Collections), séries Kolonell (paysage paiement, coût d'intégration, intégration MTN MoMo), package Laravel mobile-money.

## Architecture (inchangée)
Opérateur/agrégateur → invite PIN poussée sur le téléphone du payeur (Request-to-Pay / USSD push) → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, XAF entiers, ne jamais détenir de fonds clients. Décaissement via API Disbursements MTN / agrégateurs (Rafiki, Klasha), conformité à évaluer.

## Recommandation
Saturation confirmée (cf. addendum 112). Suspendre ce run planifié ou le passer en mensuel. Aucune notification (rien d'actionnable).

## Sources
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell — intégration MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-114-netbuis.md -->

# Addendum 114 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté actionnable. La recherche (Cameroun mobile money API, USSD push, collection/décaissement, MTN MoMo / Orange Money) ne remonte que les sources déjà connues : portail MTN MoMo API (Cameroon Collections), séries Kolonell, package Laravel mobile-money, guide codes USSD MTN.

## Architecture (inchangée)
Opérateur/agrégateur → invite PIN poussée sur le téléphone du payeur (Request-to-Pay / USSD push) → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, XAF entiers, ne jamais détenir de fonds clients. Décaissement via API Disbursements MTN / agrégateurs, conformité à évaluer.

## Recommandation
Saturation confirmée (cf. addenda 112-113). Suspendre ce run planifié ou le passer en mensuel. Aucune notification (rien d'actionnable).

## Sources
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell — intégration MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-115-netbuis.md -->

# Addendum 115 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté actionnable. Deux recherches (MTN MoMo / Orange Money Cameroun, agrégateurs) ne remontent que des sources déjà connues : portail MTN MoMo API (Cameroon Collections), séries Kolonell, package Laravel mobile-money, Orange Money Business API (developer.orange.com), CinetPay, Notch Pay. Mentions d'agrégateurs secondaires (Payfonte, Moneroo : couverture multi-pays) — à évaluer seulement si les agrégateurs principaux ne conviennent pas.

## Architecture (inchangée)
Opérateur/agrégateur → invite PIN poussée sur le téléphone du payeur (Request-to-Pay / USSD push) → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, XAF entiers, ne jamais détenir de fonds clients. Décaissement via API Disbursements MTN / agrégateurs, conformité à évaluer.

## Recommandation
Saturation confirmée (cf. addenda 112-114). Suspendre ce run planifié ou le passer en mensuel. Aucune notification (rien d'actionnable).

## Sources
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Orange Money Business API](https://developer.orange.com/apis/orange-money-business-api-discover)
- [Notch Pay — mobile money](https://developer.notchpay.co/accept-payments/mobile-money.md)
- [CinetPay docs](https://docs.cinetpay.com/api/1.0-en/checkout/tableau)
- [Moneroo — couverture](https://moneroo.io/en/coverage)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-116-netbuis.md -->

# Addendum 116 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté actionnable. Deux recherches (MTN MoMo / Orange Money Cameroun ; Orange Money Web Payment / Request-to-Pay) ne remontent que des sources déjà connues : séries Kolonell (paysage paiement mobile Cameroun, intégration MTN MoMo, Orange Money API + webhook), package Laravel mobile-money, portail developer.orange.com (om-webpay), docs Centipid.

## Architecture (inchangée)
Opérateur/agrégateur → invite PIN poussée sur le téléphone du payeur (Request-to-Pay / USSD push) → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Idempotence, XAF entiers, ne jamais détenir de fonds clients. Décaissement via API Disbursements MTN / agrégateurs, conformité à évaluer.

## Recommandation
Saturation confirmée (cf. addenda 112-115). Suspendre ce run planifié ou le passer en mensuel. Aucune notification (rien d'actionnable).

## Sources
- [Orange Money Web Payment](https://developer.orange.com/apis/om-webpay)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell — intégration MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money API webhook](https://kolonell.com/fr/blog/integrer-orange-money-cameroun-api-webhook-2026)
- [laravel-mobile-money](https://packagist.org/packages/catidegla/laravel-mobile-money)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-117-netbuis.md -->

# Addendum 117 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté actionnable. Deux recherches (MTN MoMo / Orange Money Cameroun collection-disbursement ; Orange Money / agrégateurs CinetPay, Flutterwave, pawaPay) ne remontent que des sources déjà connues : portail MTN MoMo Cameroon Collections, séries Kolonell (paysage, coût d'intégration, Orange Money Web Payment), docs Moneroo / Payfonte (agrégateurs de plus, même modèle), articles agrément Orange Money / Flutterwave BEAC, Orange Money Business API (developer.orange.com).

## Architecture (inchangée)
Backend → API opérateur ou agrégateur → invite PIN poussée (USSD push / Request-to-Pay) sur le numéro enregistré → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, XAF entiers, ne jamais détenir de fonds clients, décaissement via MTN Disbursements / agrégateurs (conformité à évaluer).

## Recommandation
Saturation confirmée (addenda 112-116). Suspendre ce run planifié ou le passer en mensuel. Aucune notification envoyée (rien d'actionnable).

## Sources
- [MTN MoMo Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Kolonell — Orange Money Web Payment Douala](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Orange Money Business API](https://developer.orange.com/apis/orange-money-business-api-discover)
- [Moneroo — méthodes disponibles](https://docs.moneroo.io/fr/payments/methodes-disponibles)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-122-netbuis.md -->

# Addendum 122 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté actionnable. Changelog pawaPay : dernière entrée 23 juillet 2024, aucune entrée 2026 (entrées Cameroun : février et mai 2024). Recherche web : mêmes sources que les addenda précédents (Kolonell paysage 2026, SDK CamerPay, carte virtuelle MoMo — allAfrica févr. 2026, incidents pawaPay).

## Architecture (inchangée)
Backend → API opérateur/agrégateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface `PaymentProvider`, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Passer ce run en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [allAfrica — carte virtuelle MoMo](https://fr.allafrica.com/stories/202602040622.html)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-123-netbuis.md -->

# Addendum 123 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée 23 juillet 2024, aucune entrée 2026. Recherche web : mêmes sources (Kolonell Orange Money Web Payment 2026, MTN MoMo API, docs pawaPay, SDK cauris). Rien de changé par rapport à l'addendum 122.

## Architecture (inchangée)
Backend → API opérateur/agrégateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Passer cette tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [docs pawaPay](https://docs.pawapay.io/)
- [MTN MoMo API](https://momo.mtn.com/api/)
- [Kolonell — Orange Money Web Payment 2026](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-124-netbuis.md -->

# Addendum 124 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée 23 juillet 2024 (Dashboard), aucune entrée 2026. Recherche web : mêmes sources (Kolonell paysage paiement mobile Cameroun 2026, MTN MoMo Cameroun intégration 2026, blog pawaPay PROMOTE 2026 = événementiel, sans changement d'API). Identique aux addenda 122-123.

## Architecture (inchangée)
Backend → API opérateur/agrégateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Passer cette tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [pawaPay at PROMOTE 2026](https://pawapay.io/blog/pawapay-at-promote-2026)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-125-netbuis.md -->

# Addendum 125 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée 23 juillet 2024, aucune entrée 2026. Recherche web : uniquement les articles Kolonell déjà connus (Orange Money Web Payment Douala, MTN MoMo Cameroun, paysage paiement mobile 2026). Identique aux addenda 122-124.

## Architecture (inchangée)
Backend → API opérateur/agrégateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Passer cette tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Kolonell — Orange Money Web Payment Douala 2026](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-126-netbuis.md -->

# Addendum 126 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée 23 juillet 2024, aucune entrée 2026. Recherche web : mêmes sources déjà connues (MTN MoMo API Cameroun Collections, Kolonell paysage paiement 2026). Identique aux addenda 122-125.

## Architecture (inchangée)
Backend → API opérateur/agrégateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée : passer cette tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [MTN MoMo API Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-127-netbuis.md -->

# Addendum 127 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée 23 juillet 2024, aucune entrée 2026. La recherche web ne ressort que les sources déjà connues (Kolonell, MTN MoMo API, Centipid, Eversend). Identique aux addenda 122-126.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée : passer cette tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-128-netbuis.md -->

# Addendum 128 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée 23 juillet 2024, aucune entrée 2026. Recherche web : uniquement sources déjà connues (Kolonell, MTN MoMo API Cameroun Collections). Identique aux addenda 122-127.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée : passer cette tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [MTN MoMo API Cameroun Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-129-netbuis.md -->

# Addendum 129 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée 23 juillet 2024, aucune entrée 2026. Recherche web : uniquement des sources déjà connues (Kolonell, MTN MoMo API Cameroun, Orange Money Web Payment, paquets communautaires PHP/Laravel/Odoo sans valeur nouvelle). Identique aux addenda 122-128.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée : passer cette tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [MTN MoMo API Cameroun Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money Web Payment 2026](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-130-netbuis.md -->

# Addendum 130 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée 23 juillet 2024. Recherche web : uniquement des sources déjà connues (Notch Pay docs, paquet PyPI campay, Kolonell, Kora). Identique aux addenda 122-129.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée : passer cette tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Notch Pay — autres méthodes](https://developer.notchpay.co/accept-payments/other-methods.md)
- [campay (PyPI)](https://pypi.org/project/campay)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-131-netbuis.md -->

# Addendum 131 — API → push USSD / envoi de fonds — 2026-10-11 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : uniquement des guides Kolonell (MTN MoMo Uganda/Ghana/CI, Orange Money Bamako), paquets Packagist/Centipid déjà dans le même paysage. Identique aux addenda 122-130.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée : passer cette tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — MTN MoMo Collections API 2026](https://kolonell.com/en/blog/mtn-momo-collections-api-uganda-2026)
- [Kolonell — Orange Money checkout Bamako 2026](https://kolonell.com/fr/blog/integration-api-orange-money-checkout-bamako-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-132-netbuis.md -->

# Addendum 132 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : uniquement guides Kolonell (Orange Money Web Payment Douala, MTN MoMo Cameroun/Ghana/CI, paysage paiement Cameroun), Rafiki (couverture payout), plugin Laravel — déjà dans le paysage connu. Identique aux addenda 122-131.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée : passer cette tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Kolonell — Orange Money Web Payment Douala](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Rafiki — couverture Afrique](https://docs.rafiki-api.com/docs/country-coverage-africa)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-133-netbuis.md -->

# Addendum 133 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié, 2e passage du jour)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : mêmes guides Kolonell (Orange Money Web Payment, MTN MoMo Cameroun/Ghana/CI, paysage Cameroun), plugin Laravel catidegla/laravel-mobile-money, simulateur lefisk.cm. Identique aux addenda 122-132.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Kolonell — MTN MoMo Ghana/CI](https://kolonell.com/en/blog/mtn-momo-api-ghana-ivory-coast-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-134-netbuis.md -->

# Addendum 134 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : mêmes sources Kolonell (MTN MoMo Collections Ouganda, frais Orange Money vs MTN Conakry), SDK pub.dev mtn_momo_sdk, add-on bedigit, portail MTN MoMo Rwanda. Identique aux addenda 122-133.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — MTN MoMo Collections Ouganda](https://kolonell.com/en/blog/mtn-momo-collections-api-uganda-2026)
- [Kolonell — Orange Money vs MTN MoMo Conakry](https://kolonell.com/en/blog/orange-money-vs-mtn-momo-fees-conakry-2026)
- [mtn_momo_sdk](https://pub.dev/packages/mtn_momo_sdk)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-135-netbuis.md -->

# Addendum 135 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : mêmes sources (Kolonell Orange Money CI/Douala, Klasha MoMo Payout API, packagist momo-payment, powerlynx). Identique aux addenda 122-134.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, Flutterwave, Klasha, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Klasha MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [Kolonell — Orange Money Douala](https://kolonell.com/fr/blog/paiement-orange-money-site-web-douala-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-136-netbuis.md -->

# Addendum 136 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : mêmes sources (Kolonell MTN MoMo / Orange Money Cameroun, packagist laravel-mobile-money, laraplugins). Identique aux addenda 122-135.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, Flutterwave, Klasha, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-137-netbuis.md -->

# Addendum 137 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : mêmes sources (Kolonell, CinetPay docs, lefisk.cm). Identique aux addenda 122-136.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, CinetPay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [CinetPay docs](https://docs.cinetpay.com/api/1.0-en/checkout/tableau)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-138-netbuis.md -->

# Addendum 138 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : mêmes sources (Notch Pay docs, Kolonell, Centipid). Identique aux addenda 122-137.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, CinetPay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Notch Pay — autres méthodes](https://developer.notchpay.co/accept-payments/other-methods)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-139-netbuis.md -->

# Addendum 139 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : mêmes sources (Notch Pay, Centipid, Kolonell, Eversend). Identique aux addenda 122-138.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, CinetPay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Notch Pay — autres méthodes](https://developer.notchpay.co/accept-payments/other-methods)
- [Kolonell — MTN MoMo Cameroun 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-140-netbuis.md -->

# Addendum 140 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : mêmes sources (pawaPay, Notch Pay, Campay, Centipid). Identique aux addenda 122-139.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, CinetPay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Notch Pay — autres méthodes](https://developer.notchpay.co/accept-payments/other-methods)
- [Notch Pay — transferts](https://developer.notchpay.co/send-money/transfers)
- [Campay (PyPI)](https://pypi.org/project/campay)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-141-netbuis.md -->

# Addendum 141 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : mêmes sources (pawaPay, Notch Pay, Centipid, Kolonell, Rafiki). Identique aux addenda 122-140.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, CinetPay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Notch Pay — autres méthodes](https://developer.notchpay.co/accept-payments/other-methods)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-142-netbuis.md -->

# Addendum 142 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : mêmes sources (Kolonell, pawaPay, Notch Pay). Identique aux addenda 122-141.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, CinetPay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-143-netbuis.md -->

# Addendum 143 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : mêmes sources (Kolonell, Notch Pay, Cauris). Identique aux addenda 122-142.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, CinetPay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Notch Pay — autres méthodes](https://developer.notchpay.co/accept-payments/other-methods)
- [Kolonell — Orange Money API vs USSD 2026](https://kolonell.com/fr/blog/orange-money-api-vs-ussd-cout-reel-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-144-netbuis.md -->

# Addendum 144 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay relu : dernière entrée toujours 23 juillet 2024 (Dashboard, incidents MNO), aucune entrée 2026. Recherche web : mêmes sources (Rafiki, Kolonell, Camer.be). Identique aux addenda 122-143.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, CinetPay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Rafiki — couverture payout Cameroun](https://docs.rafiki-api.com/docs/country-coverage-africa)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-146-netbuis.md -->

# Addendum 146 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : mêmes sources (Kolonell, Tsapa, Lefisk). Identique aux addenda 122-143.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, CinetPay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-147-netbuis.md -->

# Addendum 147 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : mêmes sources (MTN MoMo API Cameroun Collections, Kolonell, Lefisk). Identique aux addenda 122-146.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, CinetPay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [MTN MoMo API — Cameroon Collections](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-148-netbuis.md -->

# Addendum 148 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : mêmes sources (Kolonell, Lefisk, MTN MoMo). Identique aux addenda 122-147.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, CinetPay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-151-netbuis.md -->

# Addendum 151 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : mêmes sources (Kolonell, Lefisk, techjunction). Identique aux addenda 122-148.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, CinetPay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation : passer la tâche en mensuel. Aucune notification envoyée.

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-153-netbuis.md -->

# Addendum 153 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : Notch Pay, Campay, pawaPay docs, Kolonell (Orange Money Web Payment) — mêmes sources que les addenda 122-151.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, CinetPay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Passer la tâche en mensuel. Aucune notification envoyée (rien de nouveau).

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Notch Pay — autres méthodes](https://developer.notchpay.co/accept-payments/other-methods)
- [Kolonell — Orange Money Web Payment 2026](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-154-netbuis.md -->

# Addendum 154 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Changelog pawaPay : dernière entrée toujours 23 juillet 2024. Recherche web : seules les pages Kolonell (Orange Money Web Payment, MTN MoMo, paysage Cameroun 2026) déjà connues.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (pawaPay, Campay, Notch Pay, CinetPay, Flutterwave, MTN MoMo, Orange Money Web Payment) → invite PIN poussée sur le numéro enregistré → webhook signé + polling. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Passer la tâche en mensuel. Aucune notification envoyée (rien de nouveau).

## Sources
- [pawaPay changelog](https://www.pawapay.io/changelog)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-157-netbuis.md -->

# Addendum 157 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Deux recherches (MTN MoMo / Orange Money Cameroun push USSD + payout ; pawaPay / Campay / Notch Pay nouveautés 2026) ne remontent que des sources déjà connues : séries Kolonell (paysage, coût d'intégration, Orange Money Web Payment, MTN MoMo site web), docs CinetPay, pawaPay (PROMOTE 2026, partenariat Deriv — sans impact Cameroun), tarifs de retrait MTN MoMo.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (MTN MoMo Collection/Disbursement, Orange Money Web Payment, Campay, pawaPay, Notch Pay, CinetPay, Flutterwave) → invite PIN poussée sur le numéro enregistré → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 122-156). Passer la tâche en mensuel ou la suspendre et lancer le jalon 0. Aucune notification envoyée.

## Sources
- [Kolonell — coût intégration MTN/Orange Douala 2026](https://kolonell.com/fr/blog/cout-integration-mtn-momo-orange-money-douala-2026)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell — Orange Money Web Payment](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [CinetPay docs](https://docs.cinetpay.com/api/1.0-en/checkout/tableau)
- [pawaPay at PROMOTE 2026](https://pawapay.io/blog/pawapay-at-promote-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-159-netbuis.md -->

# Addendum 159 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Deux recherches (MTN MoMo / Orange Money Cameroun push USSD + payout ; pawaPay / Campay / Notch Pay / Flutterwave Cameroun) ne remontent que des sources déjà connues : séries Kolonell (paysage Cameroun, MTN MoMo site web, MoMo API Ghana/CI), portail développeur MTN MoMo, et la licence Flutterwave Cameroun (2025, déjà connue).

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (MTN MoMo Collection/Disbursement, Orange Money Web Payment, Campay, pawaPay, Notch Pay, CinetPay, Flutterwave) → invite PIN poussée sur le numéro enregistré → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 122-158). Passer la tâche en mensuel ou la suspendre et lancer le jalon 0. Aucune notification envoyée.

## Sources
- [Kolonell — MTN MoMo Cameroun site web 2026](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [MTN MoMo Developer — produits](https://momodeveloper.mtn.co.rw/products)
- [Flutterwave licence Cameroun](https://www.connectingafrica.com/fintech/flutterwave-expands-further-with-license-in-cameroon)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-161-netbuis.md -->

# Addendum 161 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Deux recherches (MTN MoMo / Orange Money Cameroun push USSD + payout ; pawaPay / Campay / Notch Pay Cameroun) ne remontent que des sources déjà connues : séries Kolonell (coût d'intégration, paysage Cameroun, Orange Money Web Payment, MTN MoMo site web), docs CinetPay, doc Notch Pay « send money / transfers », package PyPI Campay, Laravel pawaPay, blog pawaPay (PROMOTE 2026), pages d'incidents pawaPay.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (MTN MoMo Collection/Disbursement, Orange Money Web Payment, Campay, pawaPay, Notch Pay, CinetPay, Flutterwave) → invite PIN poussée sur le numéro enregistré → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 122-160). Passer la tâche en mensuel ou la suspendre et lancer le jalon 0. Aucune notification envoyée.

## Sources
- [Kolonell — coût intégration MTN MoMo / Orange Money](https://kolonell.com/fr/blog/cout-integration-mtn-momo-orange-money-douala-2026)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Notch Pay — transfers](https://developer.notchpay.co/send-money/transfers)
- [pawaPay at PROMOTE 2026](https://pawapay.io/blog/pawapay-at-promote-2026)
- [Campay PyPI](https://pypi.org/project/campay)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-163-netbuis.md -->

# Addendum 163 — API → push USSD / envoi de fonds — 2026-10-12 (run planifié)

## Verdict
Aucune nouveauté. Deux recherches (MTN MoMo / Orange Money Cameroun push USSD + disbursement ; pawaPay / Campay / Notch Pay / Flutterwave) ne remontent que des sources déjà couvertes : portail MTN MoMo developer, guides Kolonell (Orange Money Web Payment, MTN MoMo site web, MTN MoMo Ghana/CI), docs pawaPay, doc Notch Pay transfers, licence Flutterwave Cameroun (déjà couverte, addenda 16/38/89/96).

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (MTN MoMo Collection/Disbursement, Orange Money Web Payment, Campay, pawaPay, Notch Pay, CinetPay, Flutterwave) → invite PIN poussée sur le numéro enregistré → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 122-162). Suspendre ou passer en mensuel ; lancer le jalon 0. Aucune notification envoyée.

## Sources
- [MTN MoMo developer — products](https://momodeveloper.mtn.co.rw/products)
- [Kolonell — Orange Money Web Payment](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [pawaPay docs](https://docs.pawapay.io/)
- [Notch Pay — transfers](https://developer.notchpay.co/send-money/transfers)
- [Flutterwave licence Cameroun](https://thepaypers.com/payments/news/flutterwave-secures-digital-payment-licence-in-cameroon)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-165-netbuis.md -->

# Addendum 165 — API → push USSD / envoi de fonds — 2026-10-13 (run planifié)

## Verdict
Aucune nouveauté. Deux recherches (MTN MoMo / Orange Money Cameroun push USSD + disbursement ; pawaPay / Campay / Notch Pay / CinetPay) ne remontent que des sources déjà couvertes : portail MTN MoMo developer, séries Kolonell, Klasha MoMo Payout (addenda 105, 112), blog pawaPay (PROMOTE 2026, Gabon, Deriv), CinetPay guichet.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur → invite PIN poussée sur le numéro enregistré → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (addenda 122-163). Suspendre ou passer en mensuel ; lancer le jalon 0. Aucune notification envoyée.

## Sources
- [MTN MoMo developer — products](https://momodeveloper.mtn.co.rw/products)
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Klasha — MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [pawaPay blog](https://pawapay.io/blog)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-167-netbuis.md -->

# Addendum 167 — API → push USSD / envoi de fonds — 2026-10-13 (run planifié)

## Verdict
Aucune nouveauté majeure. Deux recherches (MTN MoMo / Orange Money Cameroun push USSD + disbursement ; pawaPay / Campay / Notch Pay / Flutterwave) ne remontent que des sources déjà connues : séries Kolonell (paysage paiement Cameroun, MoMo API Ghana/CI), Flutterwave (licence BEAC Cameroun, 2025), packages Laravel mobile money.
Seule source possiblement non traitée : Rafiki API (docs country-coverage, payout Cameroun) — à vérifier si besoin, agrégateur de plus parmi d'autres.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur → invite PIN poussée sur le numéro enregistré → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Suspendre ou passer en mensuel ; lancer le jalon 0. Aucune notification envoyée.

## Sources
- [Kolonell — paysage paiement Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell — MTN MoMo API Ghana/CI](https://kolonell.com/en/blog/mtn-momo-api-ghana-ivory-coast-2026)
- [Rafiki — couverture payout Afrique](https://docs.rafiki-api.com/docs/country-coverage-africa)
- [Flutterwave — licence Cameroun](https://fintech.global/2025/06/27/flutterwave-expands-licensed-payments-in-cameroon/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-169-netbuis.md -->

# Addendum 169 — API → push USSD / envoi de fonds — 2026-10-13 (run planifié)

## Verdict
Aucune nouveauté majeure. Deux recherches (MTN MoMo / Orange Money Cameroun push USSD + disbursement ; pawaPay / Campay / Notch Pay / Rafiki) ne remontent que des sources déjà connues, plus deux mentions mineures :
- Klasha : lancement d'une « MoMo Payout API » (décaissements mobile money multi-pays) — un agrégateur de plus, à comparer si besoin de payout.
- Rafiki : page d'incident statut (MTN Cameroun) — rappel que les agrégateurs dépendent de la disponibilité opérateur ; prévoir bascule entre fournisseurs.

## Architecture (inchangée)
Backend → API opérateur ou agrégateur → invite PIN poussée sur le numéro enregistré → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée. Suspendre ou passer la routine en mensuel ; lancer le jalon 0. Aucune notification envoyée.

## Sources
- [Klasha — MoMo Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [Rafiki — couverture payout](https://docs.rafiki-api.com/docs/country-coverage-africa)
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Notch Pay — autres méthodes](https://developer.notchpay.co/accept-payments/other-methods.md)
- [pawaPay SDK Node](https://unpkg.com/pawapay-sdk@1.0.3/README.md)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-171-netbuis.md -->

# Addendum 171 — API → push USSD / envoi de fonds — 2026-10-13 (run planifié)

## Verdict
Aucune nouveauté. Deux recherches (push USSD/PIN + décaissement Orange Money / MTN MoMo Cameroun ; pawaPay / Campay / Notch Pay / Flutterwave) ne remontent que des sources déjà connues : guides Kolonell (MTN MoMo, Orange Money), CinetPay, Payfonte (direct charge mobile money), Enkap (module Odoo), et Flutterwave (licence BEAC/Cameroun, déjà couverte).

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (MTN MoMo Collection/Disbursement, Orange Money Web Payment, ou agrégateur : pawaPay, Campay, Notch Pay, CinetPay, Flutterwave) → invite PIN poussée sur le numéro enregistré → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (cf. addendum 169). Suspendre la routine ou la passer en mensuel ; lancer le jalon 0. Aucune notification envoyée.

## Sources
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money Web Payment](https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026)
- [Payfonte — direct charge mobile money](https://docs.payfonte.com/guides/collections/direct-charge/mobile-money)
- [CinetPay docs](https://docs.cinetpay.com/api/1.0-en/checkout/tableau)
- [Flutterwave — licence Cameroun](https://www.techinafrica.com/flutterwave-powers-business-growth-in-cameroon-with-fully-licensed-payment-services/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-173-netbuis.md -->

# Addendum 173 — API → push USSD / envoi de fonds — 2026-10-13 (run planifié)

## Verdict
Aucune nouveauté. Deux recherches (push USSD/PIN Orange Money / MTN MoMo Cameroun ; changelogs pawaPay / Campay / Notch Pay / MTN MoMo API) ne remontent que des sources déjà connues : guides Kolonell, CinetPay, SDK/changelog pawaPay (v2, upgrade from v1), paquets communautaires (laravel-mobile-money, pytekmomoapi).

## Architecture (inchangée)
Backend → API opérateur ou agrégateur (MTN MoMo Collection/Disbursement, Orange Money Web Payment, pawaPay, Campay, Notch Pay, CinetPay, Flutterwave) → invite PIN poussée sur le numéro enregistré → webhook signé + polling de rapprochement. PIN jamais saisi dans NetBuis. Interface PaymentProvider, idempotence, XAF entiers, ne jamais détenir de fonds clients.

## Recommandation
Saturation confirmée (cf. addenda 169 et 171). Suspendre la routine ou la passer en mensuel ; lancer le jalon 0. Aucune notification envoyée.

## Sources
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [pawaPay changelog](https://pawapay.io/changelog)
- [pawaPay — upgrade from v1](https://docs.pawapay.io/v2/docs/upgrade_from_v1)
- [CinetPay docs](https://docs.cinetpay.com/api/1.0-en/checkout/tableau)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-175-netbuis.md -->

# Addendum 175 — Méthodes API / USSD push / paiement 2026 (run planifié, 2026-10-13)

## Verdict
Aucune nouveauté. Deux recherches (MTN MoMo / Orange Money collecte + décaissement + USSD push Cameroun ; agrégateurs Afrique Flutterwave/CinetPay/Campay/Moneroo) : uniquement des sources déjà connues (guides Kolonell MTN MoMo 2026, Moneroo coverage, doc Flutterwave mobile money, portail MTN MoMo Developer).

## Rappel des méthodes (inchangé)
1. Direct opérateur : MTN MoMo API (Collection requestToPay = push de validation PIN sur le téléphone du payeur ; Disbursement = envoi de fonds) et Orange Money Web Payment / API Cameroun.
2. Agrégateurs : Campay, TranZak, CinetPay, Flutterwave, Moneroo — un seul API pour collecte (push USSD/PIN) et payout.
3. Backend : webhooks de callback signés, idempotence, polling de statut en secours.

## Recommandation
Inchangée : Campay (+ TranZak) pour le MVP ; MTN MoMo direct une fois le volume justifié. Saturation confirmée : passer au jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [Kolonell — MTN MoMo Cameroun](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — agrégateurs mobile money](https://kolonell.com/fr/blog/choisir-agregateur-mobile-money-afrique-ouest-2026)
- [Moneroo coverage](https://moneroo.io/fr/coverage)
- [Flutterwave mobile money](https://developer.flutterwave.com/v3.0/docs/mobile-money-1)
- [MTN MoMo Developer](https://momodeveloper.mtn.co.rw/products)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-177-netbuis.md -->

# Addendum 177 — Méthodes API / USSD push / paiement 2026 (run planifié, 2026-10-13)

## Verdict
Aucune nouveauté. Deux recherches (MTN MoMo / Orange Money Cameroun collecte + décaissement ; Campay/TranZak/CinetPay payout) : uniquement des sources déjà connues (Kolonell, portail MTN MoMo Developer, page MTN Cameroon Collections, docs CinetPay).

## Rappel des méthodes (inchangé)
1. Direct opérateur : MTN MoMo API (Collection requestToPay = push PIN ; Disbursement = envoi de fonds), Orange Money Web Payment / API.
2. Agrégateurs : Campay, TranZak, CinetPay, Flutterwave, Moneroo.
3. Backend : webhooks signés, idempotence, polling de secours.

## Recommandation
Inchangée : Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite. Saturation confirmée : passer au jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [Cameroon Collections — MTN MoMo API](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — paysage paiement mobile Cameroun](https://kolonell.com/en/blog/cameroon-mobile-payment-landscape-mtn-orange-2026)
- [Kolonell — Orange Money API Cameroun](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)
- [CinetPay docs](https://docs.cinetpay.com/api/1.0-en/introduction/overview)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-179-netbuis.md -->

# Addendum 179 — Méthodes API / USSD push / paiement 2026 (run planifié, 2026-10-13)

## Verdict
Aucune nouveauté. Deux recherches (MTN MoMo / Orange Money Cameroun ; Campay/TranZak/Flutterwave payout). Sources déjà connues (Kolonell, portail MTN MoMo Developer, docs Flutterwave Mobile Money, SDK Campay PyPI). Seul point à surveiller : Flutterwave (agrément BEAC / partenariat Ecobank au Cameroun) et alertes d'interruption intermittente du mobile money Cameroun côté Flutterwave — à garder en secours, pas en primaire.

## Rappel des méthodes (inchangé)
1. Direct opérateur : MTN MoMo API (Collection requestToPay = push PIN ; Disbursement = envoi de fonds), Orange Money Web Payment / API.
2. Agrégateurs : Campay, TranZak, CinetPay, Flutterwave, Moneroo.
3. Backend : webhooks signés, idempotence, polling de secours.

## Recommandation
Inchangée : Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite. Passer au jalon 0 (30 commerçants pilotes). Aucune notification envoyée (rien de nouveau).

## Sources
- [Cameroon Collections — MTN MoMo API](https://momoapi.mtn.com/Cameroon_Collection_productDetails)
- [Kolonell — MTN MoMo Cameroun intégration](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Flutterwave Mobile Money docs](https://developer.flutterwave.com/docs/mobile-money/)
- [Campay (PyPI)](https://pypi.org/project/campay)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-181-netbuis.md -->

# Addendum 181 — Méthodes API / USSD push / paiement 2026 (run planifié, 2026-10-13)

## Verdict
Aucune nouveauté. Deux recherches (MTN MoMo / Orange Money Cameroun ; Campay/TranZak/CinetPay/Flutterwave/Moneroo). Résultats = sources déjà connues (Kolonell, docs CinetPay, articles Flutterwave licence BEAC / partenariat Ecobank, Moneroo coverage). Rien de nouveau sur les API directes opérateurs.

## Rappel des méthodes (inchangé)
1. Direct opérateur : MTN MoMo API (Collection requestToPay = push PIN ; Disbursement = envoi de fonds), Orange Money Web Payment / API.
2. Agrégateurs : Campay, TranZak, CinetPay, Flutterwave, Moneroo.
3. Backend : webhooks signés, idempotence, polling de secours.

## Recommandation
Inchangée : Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave en secours. Passer au jalon 0 (30 commerçants pilotes). Aucune notification envoyée (rien de nouveau).

## Sources
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell — MTN MoMo intégration](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [Kolonell — Orange Money API](https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026)
- [CinetPay docs](https://docs.cinetpay.com/api/1.0-en/checkout/tableau)
- [Flutterwave licence Cameroun (The Paypers)](https://thepaypers.com/payments/news/flutterwave-secures-digital-payment-licence-in-cameroon)
- [Moneroo coverage](https://moneroo.io/en/coverage)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-183-netbuis.md -->

# Addendum 183 — Méthodes API / USSD push / paiement 2026 (run planifié, 2026-10-13)

## Verdict
Aucune nouveauté. Deux recherches (MTN MoMo / Orange Money Cameroun ; Campay/TranZak/CinetPay/Flutterwave/Moneroo) ne renvoient que des sources déjà connues (Kolonell, docs CinetPay, Flutterwave licence BEAC, Moneroo, allAfrica MTN inclusion financière mars 2026).

## Rappel des méthodes (inchangé)
1. Direct opérateur : MTN MoMo API (Collection requestToPay = push PIN ; Disbursement = envoi de fonds), Orange Money Web Payment / API.
2. Agrégateurs : Campay, TranZak, CinetPay, Flutterwave, Moneroo.
3. Backend : webhooks signés, idempotence, polling de secours.

## Recommandation
Inchangée : Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave en secours. Passer au jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [Kolonell — paysage paiement mobile Cameroun 2026](https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026)
- [Kolonell — MTN MoMo intégration](https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026)
- [CinetPay docs](https://docs.cinetpay.com/api/1.0-en/checkout/tableau)
- [Flutterwave licence Cameroun](https://thepaypers.com/payments/news/flutterwave-secures-digital-payment-licence-in-cameroon)
- [Moneroo coverage](https://moneroo.io/en/coverage)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-185-netbuis.md -->

# Addendum 185 — Méthodes API / USSD push / paiement 2026 (run planifié, 2026-10-13)

## Verdict
Aucune nouveauté. Deux recherches (MTN MoMo / Orange Money Cameroun ; Campay/TranZak/Flutterwave payout) ne renvoient que des sources déjà connues (articles Kolonell, SDK Campay PyPI, doc Flutterwave, Rafiki couverture payout Cameroun, alerte Flutterwave d'interruption intermittente mobile money Cameroun déjà connue comme risque → prévoir polling de secours + idempotence).

## Rappel des méthodes (inchangé)
1. Direct opérateur : MTN MoMo API (Collection requestToPay = push PIN ; Disbursement = envoi de fonds), Orange Money Web Payment / API.
2. Agrégateurs : Campay, TranZak, CinetPay, Flutterwave, Moneroo.
3. Backend : webhooks signés, idempotence, polling de secours.

## Recommandation
Inchangée : Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave en secours. Passer au jalon 0 (30 commerçants pilotes). Aucune notification envoyée.

## Sources
- [Kolonell — intégration MTN MoMo Cameroun/Ghana](https://kolonell.com/en/blog/integrate-mtn-momo-api-collection-cameroon-ghana-2026)
- [Campay PyPI](https://pypi.org/project/campay)
- [Flutterwave docs](https://developer.flutterwave.com/docs/introduction-6)
- [Rafiki — couverture payout](https://docs.rafiki-api.com/docs/country-coverage-africa)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-186-netbuis.md -->

# Addendum 186 — Méthodes API / USSD push / envoi de fonds 2026 (run planifié, 2026-10-13 11:47 UTC)

## Verdict
Pas de nouvelle méthode. Architecture inchangée : backend → API opérateur ou agrégateur → invite PIN poussée par l'opérateur sur le téléphone → webhook signé. Le code secret n'est jamais saisi dans NetBuis ; aucune API ne permet au backend de lancer lui-même une session USSD sur le numéro d'un client.

## Deux sources nouvelles (marginales)
- **Cauris** (SDK Python `cauris` v0.2.1, avril 2026) : agrégateur mobile money, Cameroun parmi 8 pays, collecte par invite USSD + webhook + statut. Payout non documenté. Très jeune (1 mainteneur) : à surveiller, pas à retenir pour le MVP.
- **zaz-aangaraa/pay** (paquet Laravel) : MTN + Orange Cameroun, collecte + `withdrawMoney()`. Abandonné (~1 an sans commit, 1 téléchargement) : à écarter.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave en secours. Polling de secours + idempotence. Le sujet est saturé : espacer ce run planifié (hebdomadaire suffirait).

## Sources
- [Cauris — PyPI](https://pypi.org/project/cauris/)
- [zaz-aangaraa/pay — LaraPlugins](https://laraplugins.io/plugins/zaz-aangaraa/pay)
- [Kolonell — coût intégration MTN MoMo / Orange Money 2026](https://kolonell.com/fr/blog/cout-integration-mtn-momo-orange-money-douala-2026)
- [MTN MoMo API Cameroon Collection](https://momoapi.mtn.com/Cameroon_Collection_productDetails)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-187-netbuis.md -->

# Addendum 187 — Méthodes API / USSD push / envoi de fonds 2026 (runs planifiés 12:47, 13:46, 14:47 UTC du 2026-10-13, traités ensemble à 15:30)

## Verdict
Pas de nouvelle méthode. Trois déclenchements en attente ont été traités en une seule passe de recherche.

## Sources nouvelles pour la base (marginales)
- **Klasha MOMO Payout API** (annonce du 5 août 2025) : envoi de fonds vers des portefeuilles mobile money (MTN, Orange, Airtel, Wave), XAF listé ; Cameroun non confirmé nommément ; pas d'encaissement. Option de secours possible pour le payout uniquement, à vérifier si besoin.
- **lepresk/momo-api** v1.2.0 (bibliothèque PHP MTN MoMo) : client de l'API MTN directe, pas une nouvelle méthode.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée pour ces runs.

## Sources
- [Klasha — MOMO Payout API](https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa)
- [lepresk/momo-api v1.2.0](https://phpfreaks.com/news/20216)
- [Kolonell — MTN MoMo disbursement 2026](https://kolonell.com/en/blog/mtn-momo-disbursement-payout-api-kigali-2026)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-188-netbuis.md -->

# Addendum 188 — Méthodes API / USSD push / envoi de fonds 2026 (run planifié, 2026-10-13 15:47 UTC)

## Verdict
Aucune nouveauté. Une recherche (agrégateurs push USSD Cameroun 2026) ne renvoie que des sources déjà connues : Kolonell, plateforme nationale d'agrégation (Business in Cameroon), « code unique » (Digital Business Africa), paquet Laravel zaz-aangaraa/pay (déjà écarté en addendum 186).

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-189-netbuis.md -->

# Addendum 189 — Méthodes API / USSD push / envoi de fonds 2026 (run planifié, 2026-10-13 16:46 UTC)

## Verdict
Aucune nouveauté. Une recherche (Campay, TranZak, Notch Pay, pawaPay : mises à jour 2026) ne renvoie que des sources connues : doc Notch Pay, SDK Campay PyPI, plugins WordPress Campay, fiche TranZak (API Evangelist), pages d'incidents pawaPay (pingoru) qui confirment le besoin de polling de secours + idempotence.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-190-netbuis.md -->

# Addendum 190 — Méthodes API / USSD push / envoi de fonds 2026 (run planifié, 2026-10-13 17:46 UTC)

## Verdict
Aucune nouveauté. Une recherche (API marchand Orange Money Cameroun, payout/cash-in 2026) ne renvoie que des articles de blog Kolonell, déjà connus ou de même teneur (intégration, webhook, frais, coût réel d'encaissement).

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-191-netbuis.md -->

# Addendum 191 — Méthodes API / USSD push / envoi de fonds 2026 (run planifié, 2026-10-13 18:46 UTC)

## Verdict
Pas de nouvelle méthode. Architecture inchangée (API opérateur/agrégateur → invite PIN poussée par l'opérateur → webhook).

## Sources nouvelles pour la base
- **Kora (Korapay)** : agrégateur panafricain ; encaissement XAF MTN MoMo + Orange Money au Cameroun par Checkout ou API, payouts XAF annoncés (réseaux non précisés). Activation via l'équipe commerciale après conformité. Doc : developers.korapay.com/docs/mobile-money-apis. Alternative crédible de secours à Flutterwave ; à comparer (frais, délai KYB) si Campay pose problème. Article de février 2025.
- **Interconnexion mobile money Cameroun / Côte d'Ivoire / Sénégal** (Capmad, fév. 2026, maj juin 2026) : projet de plateforme reliant portefeuilles de différents opérateurs sous BEAC/BCEAO. Aucune API développeur publique documentée : impact sur NetBuis nul à court terme.
- CamooPay (plugin WordPress) : passerelle mobile money camerounaise, non approfondie.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- [Kora — Mobile money Côte d'Ivoire et Cameroun](https://www.korahq.com/blog/mobile-money-in-cote-divoire-and-cameroon-xaf-xof)
- [Capmad — interconnexion mobile money](https://www.capmad.com/article/mobile-money-interconnecte-le-trio-cameroun-cote-divoire-senegal-revolutionne-les-transferts-instantanes)
- [CamooPay — WordPress](https://he.wordpress.org/plugins/camoo-pay-for-ecommerce/)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-192-netbuis.md -->

# Addendum 192 — Méthodes API / USSD push / envoi de fonds 2026 (run planifié, 2026-10-13 19:46 UTC)

## Verdict
Aucune nouveauté. Une recherche (MTN MoMo API Cameroun, requestToPay / disbursement, changements 2026) ne renvoie que des sources connues ou équivalentes : guides Bedigit (add-on MoMo), Kolonell, lepresk/momo-api (Packagist, DEV Community).

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-193-netbuis.md -->

# Addendum 193 — Méthodes API / USSD push / envoi de fonds 2026 (run planifié, 2026-10-13 20:46 UTC)

## Verdict
Aucune nouveauté. Une recherche (« USSD push / STK push » Cameroun MTN Orange API 2026) ne renvoie que des sources hors sujet (guides USSD IoT Sierra Wireless, Creditswitch Nigeria, Tanzanie, Mali) ou déjà connues (Kolonell).

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-194-netbuis.md -->

# Addendum 194 — Méthodes API / USSD push / envoi de fonds 2026 (run planifié, 2026-10-13 21:46 UTC)

## Verdict
Pas de nouvelle méthode.

## Précision utile (source jusqu'ici non notée dans la base)
- **Flutterwave est agréé au Cameroun** : licence de paiement numérique de la banque centrale (BEAC), obtenue via un partenariat technique avec Ecobank (annonces juin 2025). Services : encaissement mobile money/carte/virement, payouts, règlements. Cela renforce Flutterwave comme option de secours réglementairement solide. Risque connu inchangé : alertes d'interruptions intermittentes mobile money Cameroun → polling + idempotence.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- [Gazette NGR — Flutterwave au Cameroun](https://gazettengr.com/flutterwave-powers-business-growth-in-cameroon-with-fully-licensed-payment-services/)
- [FinTech Global — Flutterwave expands licensed payments in Cameroon](https://fintech.global/2025/06/27/flutterwave-expands-licensed-payments-in-cameroon/)
- [Osiris — feu vert BEAC](https://osiris.sn/flutterwave-obtient-le-feu-vert-de-la-beac-pour-operer-au-cameroun.html)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-195-netbuis.md -->

# Addendum 195 — Méthodes API / USSD push / envoi de fonds 2026 (run planifié, 2026-10-13 22:46 UTC)

## Verdict
Aucune nouveauté. Une recherche (Moneroo, CinetPay : payout MTN/Orange Cameroun 2026) ne renvoie que des sources connues (docs CinetPay, couverture et méthodes de payout Moneroo, articles Kolonell centrés Côte d'Ivoire, paquet zaz-aangaraa/pay déjà écarté).

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-196-netbuis.md -->

# Addendum 196 — Méthodes API / USSD push / envoi de fonds 2026 (run planifié, 2026-10-13 23:47 UTC)

## Verdict
Aucune nouvelle méthode technique. Une recherche orientée réglementation (BEAC, agrégateurs, mobile money Cameroun) ne renvoie que des actualités générales (articles Osiris sur cadres BEAC et interdictions de certains transferts, TechCabal, Business in Cameroon sur un futur service mobile money de Société Générale Cameroun, formation CFIA). Aucune ne change le schéma d'intégration (API agrégateur/opérateur → invite PIN → webhook).

## Point à garder en tête
Passer par un agrégateur agréé BEAC (ou adossé à une banque) reste la voie la plus sûre ; NetBuis ne doit jamais détenir les fonds des clients.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-197-netbuis.md -->

# Addendum 197 — Méthodes API / USSD push / envoi de fonds 2026 (run planifié, 2026-10-14 00:46 UTC)

## Verdict
Pas de nouvelle méthode.

## Source nouvelle (marginale)
- **CamerPay** (SDK PHP `camerpay/php-sdk` v1.0.1, juin 2026, maj 12/10/2026) : passerelle camerounaise mobile money + carte + PayPal ; paiements Orange Money, payouts groupés (« mass payout ») vers Orange Money et MTN MoMo avec URL de rappel. Push USSD non documenté. 0 installation, 1 mainteneur : très jeune, à surveiller seulement.
- Rappel Orange : remittance Europe → Cameroun confirmée (ITWeb), sans impact sur l'intégration NetBuis.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- [CamerPay PHP SDK — Packagist](https://packagist.org/packages/camerpay/php-sdk)
- [ITWeb — Orange remittance Europe → Cameroun](https://itweb.africa/article/orange-confirms-europe-to-cameroon-remittance-in-place/VgZeyqJorW9vdjX9)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-198-netbuis.md -->

# Addendum 198 — Méthodes API / USSD push / envoi de fonds 2026 (run planifié, 2026-10-14 01:46 UTC)

## Verdict
Aucune nouveauté. Une recherche (pawaPay Cameroun, dépôts/payouts MTN Orange 2026) ne renvoie que des pages d'incidents pawaPay (pingoru), déjà connues ; elles confirment le besoin de polling de secours, d'idempotence et d'un second fournisseur.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-199-netbuis.md -->

# Addendum 199 — Méthodes API / USSD push / envoi de fonds 2026 (run planifié, 2026-10-14 02:46 UTC)

## Verdict
Pas de nouvelle méthode.

## Sources nouvelles (marginales)
- **ElgioPay** (SDK PHP `elgiosoft/elgiopay-php-sdk` v1.2.1, sept. 2026, Elgiosoft Ltd) : mobile money MTN + Orange au Cameroun et en Afrique de l'Ouest (XAF/XOF) ; payouts limités (MTN MoMo, marchands connectés) avec webhooks. Push USSD non documenté. 5 installations : trop jeune pour NetBuis.
- **TranZak** : SDK Node `tranzak-node` (npm) existe ; avis Trustpilot très maigres (2 avis positifs, 2023) → pas de signal de risque, mais pas non plus de preuve de fiabilité. Garder le test sandbox comme critère de choix.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- [ElgioPay PHP SDK — Packagist](https://packagist.org/packages/elgiosoft/elgiopay-php-sdk)
- [tranzak-node — npm](https://npmjs.com/package/tranzak-node)
- [TranZak — Trustpilot](https://fr-be.trustpilot.com/review/www.tranzak.net)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-200-netbuis.md -->

# Addendum 200 — Méthodes API / USSD push / envoi de fonds 2026 (run planifié, 2026-10-14 03:46 UTC)

## Verdict
Aucune nouveauté. Une recherche (Notch Pay : transferts/payouts mobile money Cameroun 2026) ne renvoie que la documentation développeur Notch Pay déjà connue (Send Money / Transfers, destinataires, SDK PHP).

## Note
200 passages sur ce sujet : le schéma (API agrégateur/opérateur → invite PIN poussée par l'opérateur → webhook ; envoi de fonds via endpoint payout) est stable depuis le 5 octobre. Les seules additions récentes sont des acteurs mineurs (Cauris, CamerPay, ElgioPay) ou des précisions (Kora, licence BEAC de Flutterwave).

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours. Espacer ce run (hebdomadaire). Aucune notification envoyée.


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-201-netbuis.md -->

# Addendum 201 — Méthodes API / push USSD paiement (run 2026-10-14 04:47 UTC)

## Verdict
Rien de nouveau. Les résultats (Camtel mobile money, articles Kolonell sur MTN MoMo/Orange 2026, Osiris sur MTN) sont déjà couverts dans la base de connaissances.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026
- https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026
- https://www.camer.be/93232/11:1/societe
- https://osiris.sn/Cameroun-MTN-en-passe-de-rejoindre.html


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-202-netbuis.md -->

# Addendum 202 — Méthodes API / push USSD paiement (run 2026-10-14 05:46 UTC)

## Verdict
Rien de nouveau. Rafiki API, Monifone (SGBC, wallet multi-opérateur bancaire, pas une API d'intégration) et Klasha sont déjà couverts. WorldRemit apparaît (article ancien) : service de transfert grand public, pas une API backend pour NetBuis, donc hors sujet.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://docs.rafiki-api.com/docs/country-coverage-africa
- https://societegenerale.com/en/news/newsroom/societe-generale-de-banques-au-cameroun-launching-monifone-first-multi-operator
- https://pctechmag.com/?p=41227
- https://klasha.com/blog/klasha-launches-momo-payout-api-powering-seamless-mobile-money-disbursements-across-africa


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-203-netbuis.md -->

# Addendum 203 — Méthodes API / push USSD paiement (run 2026-10-14 06:46 UTC)

## Verdict
Rien de nouveau. La recherche (API marchand Orange Money Cameroun, cashin/cashout) ne renvoie que des articles Kolonell déjà largement couverts dans la base.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://kolonell.com/fr/blog/integrer-orange-money-cameroun-api-webhook-2026
- https://kolonell.com/fr/blog/cout-reel-encaissement-orange-money-cameroun-commercant-2026
- https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-204-netbuis.md -->

# Addendum 204 — Méthodes API / push USSD paiement (run 2026-10-14 07:47 UTC)

## Verdict
Rien de significatif. Seule source inédite : la page de couverture Cameroun d'OrchestraPay (couche d'orchestration multi-PSP, non vérifiée, pas un fournisseur direct de push USSD). Elle n'est utile que si NetBuis veut un routage multi-agrégateurs, ce que l'interface PaymentProvider couvre déjà. Les autres résultats (catidegla/laravel-mobile-money, Rafiki, Kolonell, zaz-aangaraa/pay écarté) sont déjà connus.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://www.orchestrapay.com/coverage/africa/cameroon
- https://packagist.org/packages/catidegla/laravel-mobile-money
- https://docs.rafiki-api.com/docs/country-coverage-africa


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-205-netbuis.md -->

# Addendum 205 — Méthodes API / push USSD paiement (run 2026-10-14 08:46 UTC)

## Verdict
Rien de nouveau. La carte virtuelle MoMo et l'inclusion financière MTN Cameroun (AllAfrica, févr./mars 2026) sont déjà couvertes. Le hackathon API MoMo de MTN (mtn.com) est un ancien communiqué, sans impact sur l'intégration.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://fr.allafrica.com/stories/202602040622.html
- https://fr.allafrica.com/stories/202603310593.html
- https://www.mtn.com/mtn-launches-mobile-money-api-hackathon/


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-206-netbuis.md -->

# Addendum 206 — Méthodes API / push USSD paiement (run 2026-10-14 09:46 UTC)

## Verdict
Aucune nouvelle méthode technique. Contexte réglementaire BEAC noté, mais sans impact direct sur l'architecture :
- **Durcissement BEAC sur les remittances diaspora** (LaunchBase Africa, 9 juin 2026) : reporting des transactions, identification de l'émetteur et motif des fonds entrants. Les opérateurs mobile money non bancaires seraient alignés sur les standards bancaires. Pas de date d'entrée en vigueur publiée. Cela concerne les transferts internationaux entrants, pas la collecte ni le payout domestique de NetBuis. À surveiller seulement si NetBuis reçoit un jour des fonds de la diaspora.
- **Rapport BEAC sur les services de paiement dans la CEMAC 2024** (publié en avril 2026) : document de référence statistique, utile pour un dossier investisseur ou réglementaire, sans changement technique.
- Entretien du gouverneur BEAC (Financial Afrik, sept. 2025) sur l'agrément unique et la convergence XAF/XOF : orientation politique, sans effet immédiat.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://launchbaseafrica.com/2026/06/09/remittance-fintechs-brace-for-longer-delays-and-higher-fees-across-central-africa/
- https://www.beac.int/wp-content/uploads/2026/04/RAPPORT-SUR-LES-SERVICES-DE-PAIEMENT-DANS-LA-CEMAC-2024-.pdf
- https://www.financialafrik.com/2025/09/25/entretien-exclusif-avec-yvon-sana-bangui-gouverneur-de-la-banque-des-etats-de-lafrique-centrale-beac


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-207-netbuis.md -->

# Addendum 207 — Méthodes API / push USSD paiement (run 2026-10-14 10:46 UTC)

## Verdict
Rien de nouveau. Bedigit (add-on MoMo), Enkap (module Odoo), CamerPay SDK, Kolonell et zaz-aangaraa/pay (écarté) sont tous déjà couverts.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://bedigit.com/help/article/momo-add-on-guide
- https://apps.odoo.com/apps/modules/18.0/enkap_mobile_money
- https://packagist.org/packages/camerpay/php-sdk


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-208-netbuis.md -->

# Addendum 208 — Méthodes API / push USSD paiement (run 2026-10-14 11:46 UTC)

## Verdict
Aucune nouvelle méthode, mais une série d'incidents MTN Cameroun début octobre 2026 vient confirmer le risque déjà noté :
- **Rafiki Payout API, 5 oct. 2026** : « FULL OUTAGE » MTN Cameroun pendant environ 21 h (incident 665342). Deux autres incidents MTN Cameroun sont proches (664921, 665246).
- **pawaPay, 6-7 oct. 2026** : dégradation des MTN OpenAPI services (dépôts web et payouts) dans 9 pays dont le Cameroun, environ 2 h, corrigée côté opérateur.
- Smobilpay a aussi des incidents récurrents sur le « MTN MoMo cash-in depot ».

**Enseignement pour NetBuis** : quand la panne vient de l'opérateur (MTN OpenAPI), changer d'agrégateur n'aide pas, car tous passent par le même tuyau. Le secours multi-PSP couvre les pannes d'agrégateur, pas celles d'opérateur. Il faut donc aussi :
1. des statuts « en attente » durables, avec un job de polling et réconciliation qui tourne pendant des heures, pas seulement des minutes ;
2. une bascule UX qui propose Orange Money quand MTN est dégradé (taux d'échec MTN au-dessus d'un seuil, circuit breaker par opérateur) ;
3. pour les payouts, une file de réessai idempotente qui ne débite jamais deux fois.

## Recommandation (inchangée sur le fond)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours. Ajouter un circuit breaker par opérateur (MTN / Orange) en plus du secours par agrégateur. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://isdown.app/status/rafiki-payout-api/incidents/665342-incident-affecting-mtn-in-cameroon
- https://isdown.app/status/rafiki-payout-api/incidents/665246-incident-affecting-mtn-in-cameroon
- https://isdown.app/status/rafiki-payout-api/incidents/664921-incident-affecting-mtn-in-cameroon
- https://isdown.app/status/pawapay/incidents/666292-performance-degradation-affecting-mtn-openapi-services
- https://isdown.app/status/smobilpay/incidents/643963-performance-degradation-affecting-mtn-momo-cash-in-depot-service
- https://kolonell.com/fr/blog/paiements-mtn-momo-echouent-cameroun-solutions-2026


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-209-netbuis.md -->

# Addendum 209 — Méthodes API / push USSD paiement (run 2026-10-14 12:47 UTC)

## Verdict
Aucune nouvelle méthode. Un précédent côté Orange complète l'addendum 208 (pannes MTN d'octobre 2026) :
- **Panne majeure Orange Cameroun, 26-27 juillet 2025** : voix, data et surtout transactions Orange Money touchées. À partir du 28 juillet, Orange a remboursé les clients « débités sans avoir été crédités » (99 % traités en ordre chronologique).
- Perturbations CAMTEL liées à un sabotage d'installations (Digital Business Africa) : l'infrastructure réseau elle-même peut tomber, quel que soit l'opérateur.

**Enseignement pour NetBuis** : le cas « débité côté opérateur mais pas de confirmation » existe réellement chez les deux opérateurs. Il faut donc :
- un état `PENDING_UNKNOWN` distinct de `FAILED`, sans jamais recréditer ni relancer automatiquement à l'aveugle ;
- une réconciliation par la référence opérateur (relevé agrégateur, Get Transaction Status) après rétablissement ;
- un message utilisateur clair (« paiement en vérification ») et un canal de réclamation.
Cela renforce le circuit breaker par opérateur ajouté à l'addendum 208, qui couvre MTN comme Orange.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur et réconciliation longue durée. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://www.digitalbusiness.africa/orange-cameroun-rembourse-ses-clients-apres-une-panne-majeure-transparence-et-reactivite-saluees/
- https://www.digitalbusiness.africa/cameroun-les-services-de-communications-electroniques-perturbes-du-fait-dun-sabotage-sur-les-installations-de-camtel/
- https://www.digitalbusiness.africa/orange-cameroun-retablit-ses-services-voix-et-data-apres-une-panne-technique/


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-210-netbuis.md -->

# Addendum 210 — Méthodes API / push USSD paiement (run 2026-10-14 13:47 UTC)

## Verdict
Rien de nouveau. J'ai cherché d'éventuels incidents Campay ou TranZak en octobre 2026 : aucun résultat pertinent, seulement de l'actualité générale sur le Cameroun. Aucun incident public n'est trouvé pour les deux fournisseurs MVP recommandés. Cela ne vaut pas garantie, car ils n'ont pas de page de statut publique indexée. Une page de statut ou un SLA reste à leur demander avant contrat.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur et réconciliation longue durée (addenda 208-209). Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- Aucune source pertinente (recherche « Campay OR TranZak status incident Cameroon October 2026 »).


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-211-netbuis.md -->

# Addendum 211 — Méthodes API / push USSD paiement (run 2026-10-14 14:47 UTC)

## Verdict
Aucune nouvelle méthode. Un incident complète le tableau des pannes d'octobre 2026 (addenda 208-209) :
- **pawaPay, 8 oct. 2026** : dégradation Orange Cameroun (Web Deposits et Payouts), environ 3 h 50, sévérité « Major », résolue (incident 667220). Un précédent similaire existe (incident 653290).

**Bilan de la semaine du 5 au 8 oct. 2026** : MTN Cameroun en panne totale ~21 h (Rafiki, 5 oct.), MTN OpenAPI dégradé ~2 h (pawaPay, 6-7 oct.), Orange Cameroun dégradé ~4 h (pawaPay, 8 oct.). Les deux opérateurs ont été touchés la même semaine, ce qui confirme qu'il faut un circuit breaker **par opérateur**, des statuts en attente durables et une réconciliation longue durée (addendum 208). Le secours par agrégateur ne suffit pas.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur et réconciliation longue durée. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://isdown.app/status/pawapay/incidents/667220-performance-degradation-affecting-cameroon-orange-services
- https://isdown.app/status/pawapay/incidents/653290-performance-degradation-affecting-cameroon-orange-services


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-212-netbuis.md -->

# Addendum 212 — Méthodes API / push USSD paiement (run 2026-10-14 15:47 UTC)

## Verdict
Rien de nouveau. Notch Pay (API transfers) et le guichet CinetPay sont déjà couverts. Les seules pages inédites sont des portraits de fondateurs (Franklin Kamga pour Maviance/Smobilpay, Idriss Marcial Monthe pour CinetPay) et un ancien article sur le paiement VAS de CinetPay. Ce sont des articles de contexte, sans nouvelle méthode ni API.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur et réconciliation longue durée. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://developer.notchpay.co/send-money/transfers
- https://ecomatin.net/la-fintech-cinetpay-lance-un-nouveau-guichet-de-paiement-en-ligne
- https://www.wearetech.africa/fr/fils/tech-stars/cameroun-franklin-kamga-facilite-les-paiements-en-ligne-pour-les-entreprises


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-213-netbuis.md -->

# Addendum 213 — Méthodes API / push USSD paiement (run 2026-10-14 16:46 UTC)

## Verdict
Rien de nouveau. J'ai cherché des incidents plus récents (12 au 14 oct. 2026) : rien après le 8 octobre. Seul résultat inédit, l'incident pawaPay 666281 (dégradation MTN Cameroun), vraisemblablement le même épisode du 6-7 octobre que l'incident 666292 déjà noté (addendum 208). Le bilan des addenda 208-211 est inchangé.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur et réconciliation longue durée. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://isdown.app/status/pawapay/incidents/666281-performance-degradation-affecting-cameroon-mtn-services


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-214-netbuis.md -->

# Addendum 214 — Méthodes API / push USSD paiement (run 2026-10-14 17:46 UTC)

## Verdict
Aucune nouvelle méthode. Angle testé : le prélèvement récurrent ou pré-autorisé (mandat) en mobile money.
- **Paiement récurrent** (Kolonell 2026) : aucun endpoint public de pré-approbation MTN ou Orange Cameroun n'est documenté, le « mandat pré-approuvé » exige une « intégration opérateur ». En pratique, il faut relancer un push USSD (requestToPay) à chaque échéance, avec une séquence de relance en cas d'échec (WhatsApp J+1, SMS/USSD J+3, appel J+5, suspension J+7). Ce n'est pas un vrai débit automatique sans PIN, chaque débit reste validé par l'utilisateur.
- **MTN MoMo « zéro frais »** (5 mars 2026) : transferts entre abonnés gratuits et frais de retrait ramenés à 1 % (−25 %). Rien sur les frais marchands ou API. Déjà évoqué dans les audits v25, v43 et v54.

**Pour NetBuis** : les abonnements et paiements répétés se font par un push USSD par échéance, avec idempotence et relances. Il n'y a pas de débit silencieux possible, ce qui est cohérent avec la règle : le PIN n'est jamais saisi ni stocké par NetBuis.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur et réconciliation longue durée. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://kolonell.com/fr/blog/paiement-recurrent-mobile-money-sans-carte-cameroun-2026
- https://kolonell.com/fr/blog/paiement-recurrent-abonnement-mobile-money-cameroun-2026
- https://www.camer.be/92577/11:1/zero-frais-paye-ou-la-revolution-concurrentielle-du-mobile-money-de-mtn-cameroun-cameroon.html


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-215-netbuis.md -->

# Addendum 215 — Méthodes API / push USSD paiement (run 2026-10-14 18:46 UTC)

## Verdict
Pas de nouvelle méthode de push, mais une **bonne pratique payout** absente jusqu'ici de la base : valider le numéro bénéficiaire avant d'envoyer des fonds.

- **MTN MoMo Open API** : deux endpoints existent dans les produits Collection et Disbursement :
  - `ValidateAccountHolderStatus` (`GET /{product}/v1_0/accountholder/{accountHolderIdType}/{accountHolderId}/active`) : le compte MoMo est-il actif ? (`accountHolderIdType` = `msisdn`)
  - `GetBasicUserInfo` (`/v1_0/accountholder/msisdn/{msisdn}/basicuserinfo`) : nom et prénom du titulaire, selon le pays et les droits accordés. La disponibilité au Cameroun n'est pas confirmée (une question du forum développeurs MTN de nov. 2023 est restée sans réponse).
- **AZA Finance (agrégateur)**, `POST /v1/account_validations` pour le Cameroun (XAF) :
  - Orange : « telco check », qui confirme que le numéro est bien chez Orange (portabilité) ;
  - MTN : « account status check » (actif ou inactif) ;
  - **pas de vérification du nom** au Cameroun (seulement au Nigeria, au Ghana et en Ouganda) ;
  - service payant, activable dans le flux de payout (`traits.account_validation = true`), qui bloque le payout si le résultat ne correspond pas.

**Pour NetBuis** : avant chaque payout (retrait, remboursement, paiement vendeur), il faut :
1. valider le statut du compte (MTN `ValidateAccountHolderStatus`, ou l'équivalent de l'agrégateur) ;
2. afficher le nom du titulaire quand l'API le fournit, pour que l'utilisateur confirme avant l'envoi ;
3. sinon, imposer une double saisie du numéro et une liste de bénéficiaires déjà vérifiés (premier envoi de faible montant).
Il faut aussi demander à Campay et TranZak s'ils exposent une vérification de nom ou de statut, à ajouter à la checklist de sélection.

## Recommandation (inchangée sur le fond)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et **validation du bénéficiaire avant payout**. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://docs.azafinance.com/docs/account-validation/
- https://momodevelopercommunity.mtn.com/momo-api-production-q-a-7/mtn-momo-171
- https://developers.mtn.com/products/ayoaccountholderinfo/download/swagger
- https://npmjs.com/package/mtn-momo


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-216-netbuis.md -->

# Addendum 216 — Méthodes API / push USSD paiement (run 2026-10-14 19:47 UTC)

## Verdict
Rien de nouveau. Recherche ciblée sur une API Orange Money de vérification de compte / nom du titulaire au Cameroun : aucune API publique trouvée. Seule option connue : le contrôle télécom d'AZA Finance (payant, sans nom), déjà noté en addendum 215. Sources retournées (TapTapSend, centipidbilling, depscope, Kolonell, CinetPay, camerpay) déjà présentes dans la base.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et validation du bénéficiaire avant payout (Orange : double saisie du numéro + liste de bénéficiaires vérifiés, faute d'API de nom). Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- Recherche web « Orange Money API check user / account validation / get account holder name Cameroun » (2026-10-14) : résultats déjà indexés.
- Addendum 215 (AZA Finance, endpoints MTN accountholder).


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-217-netbuis.md -->

# Addendum 217 — Méthodes API / push USSD paiement (run 2026-10-14 20:47 UTC)

## Verdict
Rien de nouveau. Recherche « Mobile Money Cameroun API paiement nouveauté octobre 2026 » : sources déjà indexées (Rafiki, Kolonell MTN MoMo 2026, Kora XAF/XOF, carte virtuelle MoMo, laraplugins zaz-aangaraa). Deux pages génériques digitalbusiness.africa (?p=461, ?p=5652) sans contenu API nouveau.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et validation du bénéficiaire avant payout. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://docs.rafiki-api.com/docs/country-coverage-africa
- https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026
- https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026
- https://www.korahq.com/blog/mobile-money-in-cote-divoire-and-cameroon-xaf-xof
- https://fr.allafrica.com/stories/202602040622.html
- https://laraplugins.io/plugins/zaz-aangaraa/pay


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-218-netbuis.md -->

# Addendum 218 — Méthodes API / push USSD paiement (run 2026-10-14 21:46 UTC)

## Verdict
Rien de nouveau. Recherche « MTN MoMo API Cameroon disbursement update 2026 » : sources déjà indexées (Kolonell Kigali payout, Kolonell Ghana/Côte d'Ivoire, Kolonell Cameroun, lepresk/momo-api, bedigit). Seule nouveauté : un guide Kolonell pour Kumasi (Ghana), hors périmètre Cameroun.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et validation du bénéficiaire avant payout. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://kolonell.com/en/blog/accept-mtn-momo-website-kumasi-2026
- https://kolonell.com/en/blog/mtn-momo-disbursement-payout-api-kigali-2026
- https://kolonell.com/fr/blog/mtn-momo-cameroun-integration-site-web-paiement-2026
- https://root.packagist.org/packages/lepresk/momo-api


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-219-netbuis.md -->

# Addendum 219 — Méthodes API / push USSD paiement (run 2026-10-14 22:46 UTC)

## Verdict
Rien de nouveau. Recherche « Orange Money Cameroun API marchand webpay 2026 nouvelle version » : guides Kolonell (Web Payment Douala, API webhook, boutique) et camerpay/php-sdk déjà indexés. Article camer.be (n°92236) sur le partenariat Orange Money × Mastercard : accès aux paiements internationaux par carte, sans impact sur la collecte ou le payout par push USSD.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et validation du bénéficiaire avant payout. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026
- https://kolonell.com/fr/blog/integrer-orange-money-cameroun-api-webhook-2026
- https://packagist.org/packages/camerpay/php-sdk
- https://www.camer.be/92236/11:1/societe


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-220-netbuis.md -->

# Addendum 220 — Méthodes API / push USSD paiement (run 2026-10-14 23:46 UTC)

## Verdict
Rien de nouveau. Recherche « Campay TranZak Notch Pay Cameroon news October 2026 » : uniquement des revues de presse généralistes (hilltopvoices, businessincameroon, financialafrik), sans actualité sur les agrégateurs ni sur les API de push USSD.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et validation du bénéficiaire avant payout. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- Recherche web du 2026-10-14 23:46 UTC : aucun résultat pertinent (hilltopvoices.com, businessincameroon.com, financialafrik.com).


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-221-netbuis.md -->

# Addendum 221 — Méthodes API / push USSD paiement (run 2026-10-15 00:46 UTC)

## Verdict
Pas de nouvelle méthode. Recherche sur l'historique d'incidents pawaPay au Cameroun : deux dégradations Orange plus anciennes, non encore notées, confirment la récurrence déjà observée (addenda 208, 211).
- 23 juin 2026, 18:47–23:45 UTC (environ 5 h) : Orange Web Deposit **et** Payout dégradés (pingoru #4752842).
- 26 août 2026, 19:34–20:57 (environ 1h25) : dégradation Orange (isdown #644497).
- 8 oct. 2026 : Orange, environ 4 h (déjà noté, isdown #667220). MTN les 6 et 7 oct. (déjà noté, #666281).
Tendance : Orange Cameroun se dégrade en soirée environ une fois par mois chez pawaPay, collecte et payout ensemble. Le circuit breaker par opérateur et le statut PENDING_UNKNOWN restent justifiés. Une file de payout différé (retry idempotent après rétablissement) est préférable à une bascule vers un autre agrégateur, qui passerait par le même opérateur.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et validation du bénéficiaire avant payout. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://pingoru.io/providers/pawapay/incidents/4752842
- https://isdown.app/status/pawapay/incidents/644497-performance-degradation-affecting-cameroon-orange-services
- https://isdown.app/status/pawapay/incidents/667220-performance-degradation-affecting-cameroon-orange-services
- https://isdown.app/status/pawapay/incidents/666281-performance-degradation-affecting-cameroon-mtn-services


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-222-netbuis.md -->

# Addendum 222 — Méthodes API / push USSD paiement (run 2026-10-15 01:46 UTC)

## Verdict
Pas de nouvelle méthode exploitable. Le run précise un point déjà évoqué (Campost, #237#) : le **switch national de paiement (NPSI)**.
- **Exploitant** : Campost, avec l'appui technique d'eTranzact PLC (Nigeria). La BEAC l'a autorisé en juillet 2022.
- **Offre** : passerelle API et passerelle USSD (#237#). Camtel, MTN, Orange, Viettel (Nexttel) et Ecobank y adhèrent. Elle est présentée comme permettant d'opérer sur tous les réseaux sans contrat séparé avec chaque opérateur.
- **Limite** : aucune documentation développeur publique, aucune grille tarifaire ni procédure d'onboarding trouvées. Les articles datent de 2021–2022 et rien de récent ne montre un usage par des startups en 2026.
- **Kakotel Perfect-Pay (2021)** : agrégateur mobile money avec portail USSD via Campost. Aucune API publique documentée.
- **Piste éventuelle** : demander directement à Campost les conditions d'accès à l'API du NPSI, comme alternative souveraine aux agrégateurs. Ce n'est pas une option pour le MVP.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et validation du bénéficiaire avant payout. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://itweb.africa/article/tech-win-energises-cameroons-drive-to-unify-fintech-ecosystem/JBwEr7n3N9zM6Db2 (juillet 2022)
- https://itweb.africa/article/cameroons-start-ups-urged-to-leverage-national-payment-gateway/GxwQD71ZgA2MlPVo (octobre 2021)
- https://www.digitalbusiness.africa/cameroun-paiement-mobile-kakotel-presente-sa-solution-perfect-pay/ (janvier 2021)
- https://www.transfi.com/id/blog/cameroons-payment-rails-how-they-work---cemac-mobile-money-interoperable-transfers


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-223-netbuis.md -->

# Addendum 223 — Méthodes API / push USSD paiement (run 2026-10-15 02:46 UTC)

## Verdict
Suite de l'addendum 222 sur le switch national (NPSI, Campost/eTranzact). Pas de nouvelle méthode pour NetBuis.
- **Lancement** : code USSD national #237# mis en service le 30 mars 2022, inauguration en juillet 2022.
- **Adhérents** : plus de 42 entités connectées (5 banques, 15 EMF, 18 fournisseurs de services à valeur ajoutée, 4 startups), avec les 4 opérateurs mobiles regroupés (environ 23 M d'abonnés).
- **Ce qu'il apporte** : un **code USSD mutualisé** (pas besoin d'un contrat par opérateur pour obtenir un short code). Aucune API publique de collecte ou de payout mobile money n'est documentée.
- **Contexte** : le projet avait longtemps piétiné (Interswitch en 2017, puis eTranzact). Aucune trace d'activité ou de documentation développeur en 2025-2026.
- **Conclusion** : le NPSI sert à exposer un **menu USSD** NetBuis (#237#…), pas à déclencher un push de paiement avec code PIN. Pour la collecte et le payout, on garde agrégateur et MTN MoMo direct.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et validation du bénéficiaire avant payout. Option secondaire : un short code USSD via le NPSI (#237#) pour un menu NetBuis accessible sans internet. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://ecomatin.net/interoperabilite-des-transactions-financieres-la-solution-switch-deja-adoptee-par-42-entreprises (juillet 2022)
- https://ecomatin.net/restructuration-de-la-campost-ou-est-passe-le-projet-de-commutateur (2018, modifié en 2024)
- https://www.businessincameroon.com/telecom/3103-10150-cameroon-inaugurates-the-national-payment-switch
- https://ecomatin.net/e-tranzact-choisie-pour-realiser-le-switch-de-paiement-electronique-au-cameroun


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-224-netbuis.md -->

# Addendum 224 — Méthodes API / push USSD paiement (run 2026-10-15 03:46 UTC)

## Verdict
Rien de nouveau. La recherche « MTN MoMo Cameroun frais marchand API octobre 2026 nouveaux tarifs » ne renvoie que des articles déjà indexés ou sans rapport avec les API marchandes :
- camer.be n°92868, reprise de l'article allAfrica 202603310593 de mars 2026 sur l'inclusion financière MTN, déjà noté ;
- le simulateur de frais lefisk ;
- le guide grand public infospratiques.cm, qui donne les tarifs abonnés et non les frais d'API marchands.
Aucune nouvelle grille tarifaire marchande publiée.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et validation du bénéficiaire avant payout. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://www.camer.be/92868/11:1/comment-mtn-cameroun-veut-renforcer-linclusion-financiere-a-travers-le-mobile-money-cameroon.html
- https://infospratiques.cm/?p=396
- https://lefisk.cm/simulateurs/transfert-mobile-money


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-225-netbuis.md -->

# Addendum 225 — Méthodes API / push USSD paiement (run 2026-10-15 04:47 UTC)

## Verdict
Rien de nouveau sur le fond. Recherche « Orange Money API USSD push / merchant payment Cameroon sandbox 2026 » :
- **Catalogue Orange Developer MEA** (page d'avril 2024, modifiée en juillet 2024) : seuls Orange Money Web Payment (redirection), Pay with Orange Bill, Messaging Pro Cameroon et des SMS sont listés. Aucune API publique de payout ou de cashout, ni de push USSD Orange Money. Le service USSD #303# My Store est déprécié. SIM Swap, KYC Match et Number Verification apparaissent au menu, sans disponibilité précisée pour le Cameroun.
- **Extension Magento Meetanshi « Orange Money Payments Cameroon »** (v1.0.6, fiche mise à jour en janvier 2026) : page hébergée (redirection) où le client compose un code pour obtenir son code d'autorisation, avec sandbox. Elle ne gère pas les payouts.
Cela confirme les constats précédents : côté Orange Cameroun, la collecte par push PIN et surtout le **payout** passent par un agrégateur (ou par un contrat marchand direct négocié) et non par une API publique en libre-service.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et validation du bénéficiaire avant payout. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://developer.orange.com/resources/orange-apis-for-the-middle-east-africa/
- https://developer.orange.com/apis/om-webpay
- https://commercemarketplace.adobe.com/meetanshi-magento2-orange-money-payments-cameroon.html
- https://kolonell.com/en/blog/orange-money-website-payment-douala-2026


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-226-netbuis.md -->

# Addendum 226 — Méthodes API / push USSD paiement (run 2026-10-15 05:47 UTC)

## Verdict
Rien de nouveau. Recherche « Flutterwave Cameroon mobile money XAF payout collection update 2026 » : toutes les sources sont déjà indexées.
- **Agrément BEAC** : couvert par Gazette NGR (août 2026), fintech.global (juin 2025) et Osiris.
- **Incidents** : alertes isdown n°645592 et n°645593 sur la mobile money au Cameroun.
- **Couverture Rafiki** : déjà notée.
- **Documentation API** : la seule page nouvelle est l'ancienne référence Flutterwave v2 « mobile money francophone », obsolète. L'intégration doit viser la v3/v4.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et validation du bénéficiaire avant payout. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://gazettengr.com/flutterwave-powers-business-growth-in-cameroon-with-fully-licensed-payment-services/
- https://fintech.global/2025/06/27/flutterwave-expands-licensed-payments-in-cameroon/
- https://isdown.app/status/flutterwave/incidents/645592-cameroon-service-alert-intermittent-mobile-money-service-disruption
- https://developer.flutterwave.com/v2.0/reference/mobile-money-francophone


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-227-netbuis.md -->

# Addendum 227 — Méthodes API / push USSD paiement (run 2026-10-15 06:47 UTC)

## Verdict
Rien de nouveau sur le fond. Recherche « Kora Klasha Moneroo Cameroon mobile money payout API 2026 » :
- **Klasha** : l'API MoMo payout, la collecte mobile money et la page « pay-out » étaient déjà indexées.
- **Korapay** : la documentation « Send payments » confirme que le **payout vers les comptes mobile money XAF du Cameroun** est pris en charge (avec KES, GHS, XOF, EGP, TZS), via la Payout API (developers.korapay.com/docs/payout-via-api). La page ne précise pas les opérateurs (MTN, Orange). Cela confirme que Kora peut servir de secours pour le payout.
- **Moneroo** : aucun résultat nouveau.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et validation du bénéficiaire avant payout. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://developers.korapay.com/docs/send-payments
- https://developers.klasha.com/transfers/momo-payout
- https://www.klasha.com/home/pay-out
- https://www.korahq.com/blog/mobile-money-in-cote-divoire-and-cameroon-xaf-xof


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-228-netbuis.md -->

# Addendum 228 — Méthodes API / push USSD paiement (run 2026-10-15 07:46 UTC)

## Verdict
Rien de nouveau sur le fond. Recherche « Notch Pay Cameroon API transfers mobile money 2026 » : les pages Send money / Transfers / Accept mobile money étaient déjà indexées. La **FAQ développeur Notch Pay** (nouvelle) apporte quelques précisions opérationnelles :
- **Frais** : par transaction, sans frais fixes ni mensuels. Les taux figurent sur notchpay.co/pricing.
- **Délais** : collecte instantanée ou en quelques minutes ; transfert mobile money en quelques minutes ; remboursement en 5 à 7 jours ouvrés.
- **Limites** : elles varient selon le canal (voir l'API Channels) ; il faut contacter le support pour les relever.
- **Webhooks** : signés, avec l'événement `payment.failed`. Rien sur l'idempotence, à vérifier avant usage en payout.
- **KYC marchand** : 1 à 2 jours ouvrés.
- **Support** : du lundi au vendredi, de 9 h à 18 h (UTC+1), avec un email d'urgence. C'est un point à peser pour le payout la nuit et le week-end, puisque les pannes Orange surviennent souvent le soir (addendum 221).

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et validation du bénéficiaire avant payout. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://developer.notchpay.co/faq.md
- https://developer.notchpay.co/send-money/transfers
- https://packagist.org/packages/notchpay/notchpay-php


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-229-netbuis.md -->

# Addendum 229 — Méthodes API / push USSD paiement (run 2026-10-15 08:46 UTC)

## Verdict
Rien de nouveau. La recherche « Campay API Cameroon withdraw disburse documentation 2026 » renvoie uniquement des documents Banque mondiale et FMI (lettres de décaissement de projets) sans rapport avec l'API Campay. La documentation Campay (collect, withdraw, webhooks) est déjà indexée dans les addenda précédents.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et validation du bénéficiaire avant payout. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- Recherche web du 2026-10-15 08:46 UTC : aucun résultat pertinent (documents1.worldbank.org, archivescatalog.imf.org).


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-230-netbuis.md -->

# Addendum 230 — Méthodes API / push USSD paiement (run 2026-10-15 09:46 UTC)

## Verdict
Nouvel angle : la **fraude et le SIM swap**. Pas de nouvelle méthode de paiement, mais trois points utiles pour NetBuis.
1. **SIM Swap API au Cameroun : pas encore disponible.** Le document GSMA Open Gateway « COURE Statement of Requirement » (août 2026) demande aux opérateurs africains d'exposer six API : Number Verification, Number Recycle, Device Swap, SIM Swap, KYC Customer Match et Scam Signal. Le Cameroun figure parmi les 21 marchés prioritaires. Calendrier : pilotes fin 2026, production en 2027-2028. Aucun opérateur n'est nommé et il n'existe ni sandbox ni documentation développeur. → Pour le MVP, il faut compenser par d'autres contrôles : alerte et période de carence après un changement de numéro ou d'appareil dans l'app, 2FA sur les actions sensibles, payout uniquement vers des bénéficiaires déjà vérifiés.
2. **MTN MoMo `*126*15#` : blocage des retraits initiés par un tiers.** Un client peut empêcher quiconque d'initier un retrait sur son compte (article allAfrica, non daté, 2025 d'après l'identifiant). L'impact sur les requestToPay marchands n'est pas documenté. Si un push échoue de façon systématique pour un client, il faut prévoir un message d'aide qui l'invite à vérifier ce réglage, à confirmer en sandbox ou auprès de l'agrégateur.
3. **Pratiques anti-fraude côté app (Kolonell 2026)** :
   - ne valider un paiement **que sur le webhook serveur**, jamais sur une capture d'écran (efficace à environ 95 %) ;
   - limiter la vélocité, par exemple 3 opérations par heure et par numéro ;
   - plafonner chaque transaction, par exemple 500 000 FCFA ;
   - viser un taux de fraude inférieur à 0,5 %, contre 1 à 3 % du chiffre d'affaires sans protection.

## Recommandation (inchangée, complétée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée et validation du bénéficiaire avant payout. **Ajout : contrôles anti-fraude internes (vélocité, plafonds, carence après changement de numéro) en attendant les API SIM Swap de l'Open Gateway (2027-2028).** Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://www.gsma.com/solutions-and-impact/gsma-open-gateway/wp-content/uploads/2026/08/COURE-Statement-of-Requirement.pdf
- https://fr.allafrica.com/stories/202509300387.html
- https://kolonell.com/fr/blog/anti-fraude-paiement-mobile-money-cameroun-2026
- https://www.financialafrik.com/2025/12/11/la-fraude-par-echange-de-carte-sim-une-menace-criante-pour-linclusion-financiere-en-afrique
- https://developers.opengateway.telefonica.com/docs/simswap


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-231-netbuis.md -->

# Addendum 231 — Méthodes API / push USSD paiement (run 2026-10-15 10:46 UTC)

## Verdict
Aucune nouveauté. Angle « mises à jour CinetPay / SDK Camerpay » : sources déjà connues (docs CinetPay transfert de fonds, packagist camerpay/php-sdk, articles Kolonell 2026). Rien de nouveau sur le push USSD Orange/MTN Cameroun.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée, validation du bénéficiaire avant payout, contrôles anti-fraude internes en attendant les API SIM Swap Open Gateway (2027-2028). Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://docs.cinetpay.com/api/1.0-en/BO/virer-fond
- https://packagist.org/packages/camerpay/php-sdk
- https://kolonell.com/fr/blog/paysage-paiement-mobile-cameroun-mtn-orange-douala-2026


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-232-netbuis.md -->

# Addendum 232 — Méthodes API / push USSD paiement (run 2026-10-15 11:46 UTC)

## Verdict
Aucune nouveauté. Angle « réglementation BEAC monnaie électronique / agrégateurs 2026 » : réforme CEMAC des services de paiement (agrégateurs, initiateurs de paiement, bac à sable) déjà couverte (decision-campay, plan-realisation). Rien de nouveau sur le push USSD Orange/MTN Cameroun.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée, validation du bénéficiaire avant payout, contrôles anti-fraude internes en attendant les API SIM Swap Open Gateway (2027-2028). Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://droitmediasfinance.com/index.php/actualites/droit-tech-fintech/1298-cemac-une-reforme-en-cours-de-la-reglementation-des-services-de-paiements-agregateurs-initiateurs-de-paiement-transfert-dargent-bac-a-sable-reglementaire
- https://ecomatin.net/cemac-la-forte-croissance-de-lencours-de-la-monnaie-electronique-laisse-planer-un-risque-sur-la-liquidite-bancaire-beac


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-233-netbuis.md -->

# Addendum 233 — Méthodes API / push USSD paiement (run 2026-10-15 12:46 UTC)

## Verdict
Aucune nouveauté. Angle « mises à jour TranZak 2026 » : sources déjà connues (fiche API TranZak apis.io/apievangelist, SDK tranzak-node, elgiopay-php-sdk, lepresk/momo-api, guide Kolonell MTN MoMo 2026). Rien de nouveau sur le push USSD Orange/MTN Cameroun.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée, validation du bénéficiaire avant payout, contrôles anti-fraude internes en attendant les API SIM Swap Open Gateway (2027-2028). Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://apis.io/providers/tranzak/
- https://npmjs.com/package/tranzak-node
- https://momoapi.mtn.com/Cameroon_Collection_productDetails


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-234-netbuis.md -->

# Addendum 234 — Méthodes API / push USSD paiement (run 2026-10-15 13:47 UTC)

## Verdict
Petit complément technique (angle « sécurité des webhooks »), pas de changement de recommandation.

- Notch Pay signe ses webhooks : en-tête `x-notch-signature`, HMAC SHA-256 (hex) du **corps brut** JSON, clé = « Hash Key » du endpoint (Business suite > Settings > API Keys ; distincte sandbox/production, jamais la clé API publique/privée). Comparaison en temps constant (`crypto.timingSafeEqual` / `hash_equals` / `hmac.compare_digest`).
- La page ne documente ni horodatage/nonce anti-rejeu, ni politique de retry/idempotence. Coquille dans l'exemple PHP (`php:/input` au lieu de `php://input`), et l'exemple Node re-sérialise `req.body` (risque d'échec de signature) : utiliser le corps brut.
- Conséquence NetBuis (déjà dans le plan, à confirmer au code) : middleware raw-body sur la route webhook, vérif HMAC constant-time, déduplication par `reference`/id d'événement en base (contrainte unique), et re-vérification du statut par appel API (GET transaction) avant de créditer, car pas de protection anti-rejeu côté fournisseur.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée, validation du bénéficiaire avant payout, contrôles anti-fraude internes en attendant les API SIM Swap Open Gateway (2027-2028) ; webhooks : corps brut + HMAC constant-time + dédup + re-vérification API. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://developer.notchpay.co/get-started/webhooks/verify
- https://developer.notchpay.co/security/best-practices
- https://kolonell.com/fr/blog/webhook-confirmation-paiement-mobile-money-verifier-signature-2026
- https://kolonell.com/en/blog/reliable-payment-webhooks-momo-security-2026


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-235-netbuis.md -->

# Addendum 235 — Méthodes API / push USSD paiement (run 2026-10-15 14:47 UTC)

## Verdict
Aucune nouveauté. Angle « signature des webhooks Campay » (suite de l'addendum 234) : aucune documentation publique indexée sur une signature de webhook Campay. Le point reste ouvert (déjà noté dans audit-expert-v22) : à confirmer directement auprès de Campay. En attendant, ne jamais créditer sur la seule foi du webhook : re-vérifier le statut par l'API Campay (GET transaction) avant tout crédit, et dédupliquer par référence.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; circuit breaker par opérateur, réconciliation longue durée, validation du bénéficiaire avant payout, contrôles anti-fraude internes en attendant les API SIM Swap Open Gateway (2027-2028) ; webhooks : corps brut + HMAC constant-time quand disponible + dédup + re-vérification API. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- Recherches web sans résultat pertinent (requêtes « Campay webhook signature »).
- ./audit-expert-v22-goulot-revue-verification-play-netbuis.md (point ouvert existant)


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-236-netbuis.md -->

# Addendum 236 — Méthodes API / push USSD paiement (run 2026-10-15 15:47 UTC)

## Verdict
Angle « paiements récurrents / abonnements ». Une petite nouveauté, sans changement de recommandation.

- **Spotflow** (agrégateur non encore référencé dans nos notes) annonce MTN MoMo **et** Orange Money au Cameroun (XAF), avec un module « abonnements mobile money ». Sa documentation le dit clairement : il n'existe pas de débit récurrent silencieux, et **chaque échéance exige un nouveau push USSD/STK que l'utilisateur valide avec son PIN**. Le mécanisme : plan, rappels par e-mail (J-7 et J-3), push le jour de l'échéance, relances tous les 3 jours, puis annulation à J+4.
- **MTN MoMo preApproval** (`POST /preapproval`, `validityTime`) existe dans l'API, mais la seule source trouvée est une question du forum développeurs MTN (Ghana) sans réponse. Rien ne confirme sa disponibilité au Cameroun, ni qu'il permette de débiter sans PIN.
- Conséquence pour NetBuis : traiter tout abonnement (cotisations de tontine, forfaits) comme un **push requestToPay à chaque échéance**, avec rappels in-app, relances et statut d'impayé. Ne pas compter sur un mandat permanent.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; Spotflow à évaluer comme alternative supplémentaire (couvre MTN et Orange au Cameroun, statut BEAC non vérifié). Circuit breaker par opérateur, réconciliation longue durée, validation du bénéficiaire avant payout, contrôles anti-fraude internes, et webhooks sécurisés (corps brut, HMAC, déduplication, re-vérification par API). Récurrent = un push PIN par échéance. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://docs.spotflow.one/features/mobile-money-subscriptions.md
- https://momodevelopercommunity.mtn.com/momo-api-production-q-a-7/preapproval-renew-and-validitytime-ghana-471
- https://kolonell.com/fr/blog/paiement-recurrent-abonnement-mobile-money-cameroun-2026


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-237-netbuis.md -->

# Addendum 237 — Méthodes API / push USSD paiement (run 2026-10-15 16:47 UTC)

## Verdict
Petite nouveauté, angle « fournisseurs de payout internationaux au Cameroun » : **dLocal** (pas encore dans nos notes) documente les payouts au Cameroun.

- Virement wallet instantané : `account_type` = `MTN`, `ORANGE`, `EXPRESSUNION` ou `BICEC`, téléphone au format `+237` + 9 chiffres, devise XAF ou USD.
- Virement bancaire : IBAN `CM` de 27 caractères et SWIFT.
- Champs obligatoires : `external_id` unique (sert d'idempotence), nom et prénom du bénéficiaire. Le mode remittance P2P exige en plus la pièce d'identité de l'expéditeur.
- dLocal est un payout uniquement : pas de collecte ni de push USSD sur cette page. Ses plafonds ne sont pas publiés.
- Usage pour NetBuis : c'est un fournisseur de payout international de type entreprise, une option de secours pour les décaissements si les volumes le justifient, au même rang que Kora et Klasha. Inutile pour la collecte avec PIN au MVP.
- Spotflow : rien de plus sur son agrément BEAC ni sur ses payouts au Cameroun.

## Recommandation (inchangée)
- MVP : Campay (+ TranZak).
- Ensuite : MTN MoMo en direct.
- Secours : Flutterwave (agréé) ou Kora. Spotflow et dLocal (payout) restent des alternatives à évaluer.
- Exigences techniques : circuit breaker par opérateur, réconciliation longue durée, validation du bénéficiaire avant payout et contrôles anti-fraude internes.
- Webhooks : corps brut, HMAC, déduplication et re-vérification par API.
- Paiement récurrent : un push avec PIN à chaque échéance.

Le sujet est saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://docs.dlocal.com/docs/cameroon-payouts
- https://docs.spotflow.one/expert-desk/testing-payments
- https://www.korahq.com/blog/mobile-money-in-cote-divoire-and-cameroon-xaf-xof


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-238-netbuis.md -->

# Addendum 238 — Méthodes API / push USSD paiement (run 2026-10-15 17:46 UTC)

## Verdict
Aucune nouveauté. J'ai cherché sous l'angle « API marchand Orange Money Cameroun, push USSD, octobre 2026 ». Les seuls résultats sont des articles génériques de Kolonell (blog de contenu, déjà connu). Ils ne montrent aucune API publique Orange de push ou de payout au Cameroun. Le constat de l'addendum 225 tient toujours : Web Payment Orange fonctionne par redirection, et le push PIN Orange passe par un agrégateur.

## Recommandation (inchangée)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite ; Flutterwave (agréé) ou Kora en secours ; Spotflow et dLocal (payout) sont des alternatives à évaluer. Prévoir un circuit breaker par opérateur, une réconciliation longue durée, la validation du bénéficiaire avant chaque payout et des contrôles anti-fraude internes. Côté webhooks : corps brut, HMAC, déduplication et re-vérification par API. Pour le récurrent, un push PIN par échéance. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://kolonell.com/fr/blog/integrer-orange-money-cameroun-api-webhook-2026
- https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-239-netbuis.md -->

# Addendum 239 — Méthodes API / push USSD paiement (run 2026-10-15 18:46 UTC)

## Verdict
Aucune nouveauté. Angle « incidents pawaPay Cameroun, octobre 2026 » : seuls des incidents déjà connus remontent (isdown 667220 Orange, 666281 MTN, pages pingoru), tous déjà recensés dans l'addendum 221. Aucun nouvel incident Orange ou MTN Cameroun n'est signalé depuis le 8 octobre.

## Recommandation (inchangée)
- Fournisseurs :
  - MVP : Campay (+ TranZak).
  - Étape suivante : MTN MoMo en direct.
  - Secours : Flutterwave (agréé) ou Kora.
  - À évaluer : Spotflow, et dLocal pour les payouts.
- Exigences techniques :
  - circuit breaker par opérateur ;
  - réconciliation longue durée ;
  - validation du bénéficiaire avant chaque payout ;
  - contrôles anti-fraude internes ;
  - webhooks : corps brut, signature HMAC, déduplication et re-vérification par API ;
  - paiement récurrent : un push PIN à chaque échéance.

Le sujet est saturé : il faudrait espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://isdown.app/status/pawapay/incidents/667220-performance-degradation-affecting-cameroon-orange-services
- https://isdown.app/status/pawapay/incidents/666281-performance-degradation-affecting-cameroon-mtn-services


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-240-netbuis.md -->

# Addendum 240 — Méthodes API / push USSD paiement (run 2026-10-15 19:46 UTC)

## Verdict
Petit complément, angle « passage en production MTN MoMo API (KYC marchand) ».

- Le forum développeurs MTN mentionne trois documents d'onboarding pour la production : **Merchant Application Form**, **exigences KYC** et **questionnaire AML**. D'après un fintech (BWA), ces formulaires sont pensés pour des marchands classiques et collent mal aux fintechs digitales (sections réseau d'agents, gestion d'espèces).
- La question ne contient aucune réponse de MTN : pas de liste complète, pas de délais, pas de détail propre au Cameroun.
- Conséquence pour NetBuis : l'étape « MTN MoMo direct » suppose de constituer un dossier KYC/AML complet (RCCM, statuts, pièces des dirigeants, politique AML) et de prévoir des délais d'onboarding non publiés. C'est une raison de plus de démarrer via un agrégateur (Campay/TranZak) déjà onboardé.

## Recommandation (inchangée)
- **MVP** : Campay (+ TranZak).
- **Ensuite** : MTN MoMo direct, dossier KYC/AML à préparer en amont.
- **Secours** : Flutterwave (agréé) ou Kora.
- **À évaluer** : Spotflow, et dLocal pour les payouts.
- **Fiabilité** : circuit breaker par opérateur, réconciliation longue durée, validation du bénéficiaire avant payout.
- **Sécurité** : contrôles anti-fraude internes ; webhooks traités sur le corps brut avec vérification HMAC, déduplication et re-vérification par API.
- **Paiements récurrents** : un push PIN par échéance.

Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://momodevelopercommunity.mtn.com/momo-api-production-q-a-7/api-production-sign-up-process-477


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-241-netbuis.md -->

# Addendum 241 — Méthodes API / push USSD paiement (run 2026-10-15 20:46 UTC)

## Verdict
Petit complément fiscal, sans changement de recommandation. Angle : taxes sur les transactions mobile money au Cameroun.

- **TTA de 0,2 %** sur les transferts et retraits mobile money, en vigueur depuis 2022. Déjà dans nos notes.
- **Prélèvement fixe de 4 FCFA** par transaction financière locale.
  - Base légale : article 228 quinquies de la loi de finances 2025, en vigueur depuis le 1er janvier 2025.
  - Transactions couvertes (lettre du MINFI du 2 juillet 2025) : transferts, retraits, paiements par carte, transferts de titres et débits automatiques.
  - Exonérations :
    - les dépôts en espèces ;
    - les transferts entre un prestataire de paiement et son réseau ou ses partenaires ;
    - les paiements d'impôts, de droits ou de pensions publiques.
  - C'est un prélèvement indirect, supporté par le client.
  - La mention « 4 FCFA » figure déjà dans trois de nos notes. Cet addendum ajoute la base légale et la liste des exonérations.
- Aucune trace d'une modification par la loi de finances 2026 dans ces résultats ; à vérifier si le sujet fiscal devient prioritaire.
- Conséquences pour NetBuis :
  - Afficher clairement le coût total à l'utilisateur, frais de l'agrégateur compris.
  - En tenir compte dans la réconciliation, car le montant reçu par le marchand peut différer du montant débité.
  - Ne pas promettre « zéro frais » au client.

## Recommandation (inchangée)
- **MVP** : Campay (+ TranZak).
- **Ensuite** : MTN MoMo en direct, avec un dossier KYC/AML préparé à l'avance.
- **Secours** : Flutterwave (agréé) ou Kora.
- **À évaluer** : Spotflow, et dLocal pour les payouts.
- **Fiabilité** : circuit breaker par opérateur, réconciliation longue durée, validation du bénéficiaire avant payout.
- **Anti-fraude** : contrôles internes.
- **Webhooks** : corps brut, HMAC, déduplication, re-vérification par API.
- **Récurrent** : un push PIN par échéance.

Le sujet est saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://ecomatin.net/virements-retraits-paiements-par-carte-transferts-de-titresau-cameroun-le-prelevement-de-4-fcfa-suscite-debat (9 juillet 2025)
- https://www.digitalbusiness.africa/cameroun-la-hausse-des-transactions-om-et-momo-imputable-a-l-etat-pas-aux-operateurs/


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-242-netbuis.md -->

# Addendum 242 — Méthodes API / push USSD paiement (run 2026-10-15 21:46 UTC)

## Verdict
Aucune nouveauté sur le mobile money. J'ai cherché sous l'angle « loi de finances 2026 Cameroun » pour vérifier le point laissé ouvert par l'addendum 241 :
- La synthèse CMS des lois de finances 2026 en Afrique de l'Ouest et centrale ne relève **aucune modification** de la TTA de 0,2 % ni du prélèvement de 4 FCFA.
- Pour le Cameroun, la seule mesure qu'elle cite est la définition du « cycle commercial complet » (art. 5 bis CGI). Elle rend imposables au Cameroun les bénéfices d'une société non résidente qui réalise un ensemble cohérent d'opérations économiques sur le territoire, même sans installation fixe.
- Effet possible pour NetBuis : un agrégateur étranger (dLocal, Spotflow, Kora) qui opère au Cameroun pourrait être concerné. Cela ne change pas le choix MVP, puisque Campay et TranZak sont locaux.
- On ne voit qu'une synthèse, pas le texte de loi. À faire confirmer par un fiscaliste si NetBuis facture un acteur étranger.

## Recommandation (inchangée)
- **MVP** : Campay (+ TranZak).
- **Ensuite** : MTN MoMo en direct, avec un dossier KYC/AML.
- **Secours** : Flutterwave (agréé) ou Kora.
- **À évaluer** : Spotflow ; dLocal pour les payouts.
- **Fiabilité** : circuit breaker par opérateur, réconciliation longue durée, validation du bénéficiaire avant payout, contrôles anti-fraude internes.
- **Webhooks** : vérification HMAC sur le corps brut, déduplication, re-vérification par API.
- **Paiements récurrents** : un push PIN par échéance.
- **Frais** : afficher le coût total, taxes comprises (TTA 0,2 % et 4 FCFA).

Le sujet est saturé : il faudrait espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://cms.law/en/fra/legal-updates/lois-de-finances-2026-en-afrique-de-l-ouest-et-centrale
- https://www.digitalbusiness.africa/taxe-sur-les-transferts-dargent-au-cameroun-cest-04-qui-sera-preleve-au-total-et-non-02-cette-double-taxation-constitue-une-mesure-de-spoliation/


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-243-netbuis.md -->

# Addendum 243 — Méthodes API / push USSD paiement (run 2026-10-15 22:46 UTC)

## Verdict
Aucune nouveauté. J'ai cherché un changelog 2026 de l'API Campay (nouveaux endpoints de retrait ou de décaissement). Je n'ai trouvé que les plugins WordPress Campay, le SDK pypi `campay` et la fiche apitracker, tous déjà connus. Aucun changelog public ni nouvel endpoint n'est indexé.

## Recommandation (inchangée)
- **MVP** : Campay, avec TranZak.
- **Étape suivante** : MTN MoMo en direct, avec un dossier KYC/AML.
- **Secours** : Flutterwave (agréé) ou Kora.
- **À évaluer** : Spotflow, et dLocal pour les payouts.
- **Fiabilité** : circuit breaker par opérateur, réconciliation longue durée, validation du bénéficiaire avant payout, anti-fraude interne.
- **Webhooks** : vérification HMAC sur le corps brut, dédoublonnage, re-vérification par API.
- **Paiement récurrent** : un push PIN par échéance.
- **Frais** : afficher un coût total qui inclut la TTA de 0,2 % et les 4 FCFA.

Sujet saturé : il faudrait passer ce run en hebdomadaire. Aucune notification envoyée.

## Sources
- https://pypi.org/project/campay
- https://www.apitracker.io/a/campay-net


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-244-netbuis.md -->

# Addendum 244 — Méthodes API / push USSD paiement (run 2026-10-15 23:46 UTC)

## Verdict
Complément technique utile (angle « délais d'expiration / PENDING de requestToPay MTN MoMo »). Pas de changement de fournisseur, mais **une règle de sécurité à appliquer pour l'intégration MTN directe**.

Source : retour d'expérience d'un développeur sur dev.to (« A timeout is not a failure »), observé en **sandbox** MTN. Certains points y sont inférés du code source, pas observés en production.

- **Les callbacks MTN MoMo ne portent ni signature ni identifiants.** Il faut les traiter comme un simple signal et toujours re-vérifier par `GET /requesttopay/{referenceId}` avant d'écrire dans le grand livre.
  - MTN peut envoyer le même callback plusieurs fois (doublon observé environ 3 min plus tard). L'endpoint doit donc être idempotent.
  - Le callback contient `externalId` mais pas `referenceId`, d'où la nécessité de stocker le lien entre les deux.
  - MTN n'appelle que si la requête porte l'en-tête `X-Callback-Url`. L'hôte déclaré sur le portail n'est qu'une liste blanche.
- **Délai dépassé = `UNKNOWN`, jamais `FAILED`.** L'opérateur a pu débiter le client puis perdre la réponse.
  - `UNKNOWN` n'est pas un état final. Un réconciliateur relance avec un backoff (1, 2, 4, 8 min…), puis escalade vers un humain si rien de concluant ne revient. L'escalade ne doit jamais conclure à un échec.
  - Une réponse non concluante ne doit jamais écraser un état déjà connu.
- **Les réponses `PENDING` n'ont ni `financialTransactionId` ni `reason`.** Les adaptateurs ne doivent pas exiger ces champs. Lire `status` avant `reason`.
- Le `202` de requestToPay n'a pas de corps : le résultat ne s'obtient que par une requête de statut.
- Ces points confirment l'état `PENDING_UNKNOWN` et la réconciliation longue déjà recommandés. Le fait nouveau est l'absence de signature des callbacks MTN directs, contrairement à Notch Pay (HMAC, addendum 234).

## Recommandation (inchangée sur les fournisseurs)
Campay (+ TranZak) pour le MVP ; MTN MoMo direct ensuite, avec dossier KYC/AML et **callbacks non signés, donc re-vérification obligatoire par GET** ; Flutterwave (agréé) ou Kora en secours ; Spotflow et dLocal (payout) à évaluer. Circuit breaker par opérateur, état UNKNOWN non terminal avec réconciliation et backoff puis escalade humaine, validation du bénéficiaire, anti-fraude interne, webhooks idempotents, un push PIN par échéance, coût total affiché taxes comprises. Sujet saturé : espacer ce run (hebdomadaire). Aucune notification envoyée.

## Sources
- https://dev.to/deval123/a-timeout-is-not-a-failure-4a9d
- https://momodevelopercommunity.mtn.com/momo-api-production-q-a-7/request-to-pay-177


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-245-netbuis.md -->

# Addendum 245 — Méthodes API / push USSD paiement (run 2026-10-16 00:46 UTC)

## Verdict
Angle GIMAC / interopérabilité CEMAC. Rien qui change l'architecture :
- GIMACPAY est un switch interbancaire et inter-wallets réservé aux établissements membres. Il ne fournit pas d'API publique de push USSD pour un marchand tiers.
- Les nouveautés sont un QR code de paiement commun officialisé par la BEAC et un MoU GIMAC–Visa sur les paiements numériques interopérables. Ce sont des pistes à suivre pour un futur paiement par QR, pas un remplacement du push PIN MTN/Orange.
- Les détails viennent des titres de résultats seulement ; ils n'ont pas été lus en profondeur.

## Recommandation (inchangée)
- MVP : Campay (+ TranZak).
- Ensuite : MTN MoMo direct, avec dossier KYC/AML et re-vérification de chaque callback par GET.
- Repli : Flutterwave ou Kora.
- À évaluer : Spotflow, et dLocal pour les payouts.
- À surveiller : le QR commun BEAC/GIMAC comme moyen d'encaissement complémentaire.
- Sujet saturé : un rythme hebdomadaire suffirait.

## Sources
- https://www.ecofinagency.com/news-finances/0404-54416-central-africa-s-gimac-visa-sign-mou-to-expand-interoperable-digital-payments
- https://www.capmad.com/article/cemac-la-beac-officialise-un-qr-code-de-paiement-commun-pour-harmoniser-les-transactions-de-detail
- https://ecomatin.net/interoperabilite-en-08-mois-gimacpay-totalise-2-millions-de-transactions-pour-un-montant-de-33-milliards-de-fcfa/
- https://www.digitalbusiness.africa/fintech-cemac-les-defis-liees-aux-transactions-exposees-a-promote-les-innovations-du-gimac/


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-246-netbuis.md -->

# Addendum 246 — Méthodes API / push USSD paiement (run 2026-10-16 01:46 UTC)

## Verdict
Angle : payouts XAF via Flutterwave (MTN/Orange Cameroun). Rien de nouveau.
- Les résultats renvoient à des sources déjà connues : Rafiki API (déjà vu, addenda 202/204/208), le blog Kora XAF/XOF et l'agrément BEAC de Flutterwave.
- Les autres résultats sont des pages WorldRemit, qui couvrent le transfert grand public et non une API marchande.

## Recommandation (inchangée)
- MVP : Campay (+ TranZak).
- Ensuite : MTN MoMo direct, avec dossier KYC/AML et re-vérification de chaque callback par GET.
- Repli : Flutterwave (agréé BEAC) ou Kora.
- À évaluer : Spotflow, et dLocal pour les payouts.
- Sujet saturé : un rythme hebdomadaire suffirait.

## Sources
- https://docs.rafiki-api.com/docs/country-coverage-africa
- https://www.korahq.com/blog/mobile-money-in-cote-divoire-and-cameroon-xaf-xof
- https://osiris.sn/flutterwave-obtient-le-feu-vert-de-la-beac-pour-operer-au-cameroun.html


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-247-netbuis.md -->

# Addendum 247 — Méthodes API / push USSD paiement (run 2026-10-16 02:46 UTC)

## Verdict
Angle : Orange Money Cameroun, Max it et API marchand 2026. Rien de nouveau.
- Les guides Kolonell (Orange Money web payment, Douala 2026) sont déjà connus depuis les addenda 100 à 102.
- Le guide Kolonell sur l'API Max it concerne le Sénégal. Il ne prouve pas l'existence d'une API Max it publique au Cameroun.
- Max it au Cameroun reste une super-app grand public (22 M d'abonnés selon camer.be). Aucune API push ou payout publique n'a été trouvée.
- Orange au Cameroun passe donc toujours par un agrégateur.

## Recommandation (inchangée)
- MVP : Campay (+ TranZak).
- Ensuite : MTN MoMo direct, avec dossier KYC/AML et re-vérification de chaque callback par GET.
- Repli : Flutterwave ou Kora.
- Orange : via agrégateur.
- Sujet saturé : un rythme hebdomadaire suffirait.

## Sources
- https://kolonell.com/fr/blog/integrer-orange-money-api-boutique-cameroun-2026
- https://kolonell.com/fr/blog/integrer-orange-money-web-payment-douala-cameroun-2026
- https://kolonell.com/en/blog/orange-money-maxit-api-payment-integration-senegal-2026
- https://www.camer.be/83558/11:1/cameroun-orange-max-it-22-millions-dabonnes-aujourdhui-et-a-termes-17-pays-sur-2-continents-cameroon.html
- https://ecomatin.net/orange-se-renforce-dans-le-de-paiement-mobile-au-cameroun-et-dans-4-autres-marches-africains


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-248-netbuis.md -->

# Addendum 248 — Méthodes API / push USSD paiement (run 2026-10-16 03:46 UTC)

## Verdict
Angle : numéros de test du sandbox MTN MoMo (XAF/EUR). Résultats pauvres, rien de nouveau.
- La recherche ne renvoie que des plugins WordPress/WooCommerce « Pay with MTN MoMo », sans détails nouveaux.
- Rappel, connu de la doc MoMo et non revérifié ce run : le sandbox n'accepte que la devise EUR. Il faut passer en XAF au go-live, et donc ne pas coder la devise en dur.

## Recommandation (inchangée)
- MVP : Campay (+ TranZak).
- Ensuite : MTN MoMo direct, avec dossier KYC/AML et re-vérification de chaque callback par GET.
- Repli : Flutterwave ou Kora.
- Sujet saturé : un rythme hebdomadaire suffirait.

## Sources
- https://cy.wordpress.org/plugins/pay-with-mtn-momo-woocommerce/
- https://eo.wordpress.org/plugins/?p=124276


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-249-netbuis.md -->

# Addendum 249 — Méthodes API / push USSD paiement (run 2026-10-16 04:47 UTC)

## Verdict
Angle : loi camerounaise sur la protection des données personnelles. Rien de nouveau.
- La loi du 23 décembre 2024 est en vigueur depuis le 23 juin 2026. Ce point est déjà noté dans les addenda 13, 191, 197, 206 et 221.
- Rappel pour NETBUIS : les numéros MSISDN enregistrés dans l'app et l'historique des transactions sont des données personnelles. Il faut le consentement, la minimisation et la sécurisation de ces données, et vérifier les obligations de déclaration auprès de l'autorité prévue par la loi.

## Recommandation (inchangée)
- MVP : Campay (+ TranZak).
- Ensuite : MTN MoMo direct, avec dossier KYC/AML et re-vérification de chaque callback par GET.
- Repli : Flutterwave ou Kora.
- Sujet saturé : un rythme hebdomadaire suffirait.

## Sources
- https://droitmediasfinance.com/index.php/actualites/droit-tech-fintech/1297-cameroun-la-loi-sur-la-protection-des-donnees-a-caractere-personnel-entre-en-vigueur-ce-23-juin-2026
- https://cio-mag.com/protection-des-donnees-au-cameroun-la-course-contre-la-montre-avant-juin-2026/
- https://droitmediasfinance.com/index.php/actualites/droit-tech-fintech/880-cameroun-le-nouveau-visage-de-la-protection-des-donnees-a-caractere-personnel-et-ses-implications-pour-les-entreprises-financieres


---

<!-- source : recherche-methodes-api-ussd-push-paiement-2026-addendum-netbuis.md -->

# Addendum n°3 — Méthodes API → push USSD / envoi de fonds (Cameroun) — 2026-10-05

Complète `recherche-methodes-api-ussd-push-paiement-2026-netbuis.md` (qui reste la référence). Recherche automatique ; [S] = source lue, [N] = non confirmé.

## Nouveautés de cette passe

1. **Frais CamPay (déclarés par CamPay lui-même)** : dépôt (collect) 2 %, retrait (payout) 1 %. [S: blog.campay.net, source commerciale, à confirmer par contrat]. Un coût combiné encaissement + reversement d'environ 3 % est donc à prévoir pour un flux commerçant.
2. **Part de marché** (même source) : MTN ≈ 60 %, Orange ≈ 40 %. Accepter un seul opérateur exclut 40 à 50 % des clients potentiels : intégrer les deux dès le pilote. [S, chiffres marketing]
3. **Intégrateurs locaux « API locale / USSD Orange Money »** : Y-Note / Paynote publient un guide d'intégration de l'API locale Orange Money (USSD) ; page inaccessible ce jour (503 / robots). Piste à vérifier : intégrateur agréé Orange Cameroun comme alternative à l'accès direct. [N]
4. **Accès direct MTN MoMo Cameroun** : aucune source de cette passe ne décrit la procédure de production pour le Cameroun (les guides trouvés visent Ghana, Côte d'Ivoire, Ouganda, Congo). Reste à demander à MTN Cameroun. [N]
5. Pages non lisibles ce jour : y-note.cm, paynote.africa, camerpay.biz (403), simiz.io, beonweb.cm.

## Rappel des méthodes (synthèse)

| Méthode | Push PIN (collecte) | Envoi de fonds (payout) | Remarque |
|---|---|---|---|
| MTN MoMo Open API | requestToPay | Disbursement (IP en liste blanche) | Accès Cameroun à confirmer |
| Orange Money direct | Web Payment (OTP généré par le client) | Non décrit | Marchand enregistré |
| Campay | Collect | Withdraw | MTN + Orange ; ~2 % / ~1 % |
| pawaPay | Deposits | Payouts | MTN_MOMO_CMR, ORANGE_CMR |
| Notch Pay / CinetPay / Monetbil | Oui | Variable | Collecte surtout |

## Règles inchangées
Le PIN n'est saisi que dans l'invite de l'opérateur, jamais dans NetBuis ; webhook signé + idempotence + rapprochement ; ne pas conserver de fonds clients (alerte COBAC du 25/09/2026) ; couche `PaymentProvider` abstraite.

## À faire
Contrat/sandbox Campay et pawaPay ; demande d'accès MTN Cameroun et Orange Cameroun ; avis juridique sur le statut.

## Sources
- [CamPay — limites des moyens de paiement et frais](https://blog.campay.net/do-you-accept-orange-money-how-payment-method-limitations-cost-cameroon-businesses-annually/)
- [Y-Note — API locale / USSD Orange Money](https://www.y-note.cm/integration-de-lapi-local-orange-money/)
- [Intégration MTN MoMo & Orange Money Cameroun (NjokaLab)](https://www.njokalab.com/insights/how-to-integrate-mtn-momo-orange-money-cameroon-api/)

