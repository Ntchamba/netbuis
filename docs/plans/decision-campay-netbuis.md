# Décision : CamPay comme passerelle Mobile Money de NetBuis (MTN + Orange)

Date : 2026-10-05 (v2 : décision confirmée par Jeff, « on va utiliser CamPay, je vais créer un compte et on va intégrer son API » ; ajout du SDK Python officiel et du flux d'intégration). Statut des affirmations : [S] source lue, [N] non confirmé, à vérifier dans la documentation ou avec CamPay.

## Qui fait quoi
- **Jeff** : crée le compte CamPay (démo d'abord, puis production), note les pièces demandées (KYC) et le délai, récupère les identifiants.
- **Développement NetBuis** : intègre l'API côté Django, derrière une couche d'abstraction. Aucune clé ne doit être collée dans une conversation ni dans le code ; elles vont dans des variables d'environnement.

## Pourquoi (rappel)
- Orange et MTN Cameroun en collecte et en retrait via une seule API. [S: doc Postman CamPay, erreur ER102 « seuls les numéros MTN et Orange sont acceptés »]
- Fonctions annoncées : API, plugins WooCommerce/EDD, liens de paiement, paiements en masse. [S: Medium CamPay]
- Support WhatsApp indiqué sur leur blog : +237 652 007 684. [S, à confirmer sur le site]

## Ce qui est confirmé dans la documentation et le SDK officiel
- **Compte** : inscription sur https://demo.campay.net/en/signup/ ; une fois vérifié, accès au bac à sable et aux clés API ; passage ensuite en production (connexion production : https://www.campay.net/en/login/). [S: blog CamPay]
- **Authentification** : jeton permanent (section « APP KEYS »), en-tête `Authorization: Token <clé>`, ou jeton temporaire renouvelable. Le SDK Python utilise `app_username` + `app_password` et un paramètre `environment` (`DEV` ou `PROD`). [S]
- **SDK Python officiel** : `pip install campay` (dépôt CamPay/campay-python-sdk). Il existe aussi un SDK Android. [S]
- **Collecte (encaissement)** :
  - `initCollect()` démarre la transaction et rend la main tout de suite : retourne `reference`, `ussd_code`, `operator`, statut initial `PENDING`. C'est la méthode adaptée à NetBuis (pas de blocage d'une requête web).
  - `collect()` démarre puis attend la fin (bloquant) : retourne `reference`, `external_reference`, `status`, `amount`, `currency`, `operator`, `code`, `operator_reference`.
  - Paramètres : `amount`, `currency`, `from` (numéro avec indicatif), `description`, `external_reference`.
  - `get_transaction_status(reference)` : statuts `PENDING`, `SUCCESSFUL`, `FAILED`. [S]
- **Lien de paiement** : `get_payment_link()` (montant, devise, description, `external_reference`, `from`, prénom, nom, e-mail, `redirect_url`, `failure_redirect_url`, `payment_options`) retourne `status`, `link`, `reference`. [S]
- **Retrait / envoi de fonds** : `disburse()` (montant, devise, `to`, description, `external_reference`), à condition d'activer « API withdrawal » dans les réglages du compte. [S]
- **Solde** : `get_balance()` retourne `total_balance`, `mtn_balance`, `orange_balance`, `currency`. [S]
- **Environnement de test** : https://demo.campay.net [S]
- **Erreurs** : ER101 (numéro sans indicatif, format `237XXXXXXXXX`), ER102 (opérateur non pris en charge, seuls MTN et Orange), ER201 (montant décimal interdit, entier ou chaîne), ER301 (solde insuffisant pour un retrait). [S]

## Toujours non confirmé [N] — à demander à CamPay ou lire en créant le compte
- Format et signature du **webhook** (le SDK n'en parle pas) : à vérifier dans le tableau de bord ou la collection Postman complète. Tant que ce n'est pas connu, le filet de sécurité par interrogation du statut est obligatoire, pas optionnel.
- Frais de collecte et de retrait par opérateur, montant minimum, plafonds, délai de règlement.
- Pièces demandées (KYC/KYB), délai d'ouverture en production, compte personnel ou compte entreprise.
- URLs exactes de production (le SDK les masque derrière `environment`).
- Si l'on préfère ne pas dépendre du SDK : endpoints HTTP bruts (non lus ici).

## Architecture côté Django
1. Couche `PaymentProvider` (interface : `collect`, `payout`, `status`), avec `CampayProvider` comme première implémentation. Permet de basculer vers pawaPay ou Notch Pay sans réécrire.
2. Table `payment_transactions` : référence unique NetBuis (idempotence), utilisateur, opérateur détecté, montant XAF entier, état (`pending`, `success`, `failed`, `expired`), référence CamPay (`reference`), `external_reference` = notre référence, dates.
3. Achat de pack : l'app envoie numéro + pack → Django crée la transaction `pending` → `initCollect` → l'utilisateur confirme le PIN dans l'invite opérateur → notification (webhook) ou interrogation → Django vérifie, crédite le solde **une seule fois**.
4. Filet de sécurité : tâche de fond qui appelle `get_transaction_status` si aucune notification après ~90 s ; bouton « j'ai payé » avec preuve pour le support ; état « en attente » visible dans l'app.
5. Secrets (identifiants CamPay) en variables d'environnement, jamais dans l'app mobile. L'app ne parle qu'à Django.
6. Ne jamais demander le PIN dans l'app.
7. Mode `DEV` en développement et en tests automatiques, `PROD` seulement en production, avec une variable d'environnement distincte par environnement.

## Règles produit liées
- Pack minimum 50 FCFA (minimum Orange), de préférence 100 à 500 FCFA avec plusieurs appels ; un pack de 25 FCFA sera probablement refusé. Voir `monetisation-appels-orange-money.md`.
- Twilio, cité dans la description d'origine du projet, n'est plus utilisé : l'appel passe par l'opérateur du téléphone (voir `decision-finale-appels.md`) et le paiement par CamPay.
- Payouts (primes agents, remboursements) : `disburse()` après activation de l'option, alimenter d'abord le solde marchand ; limiter par plafond et validation humaine.

## Prochaines étapes
1. Jeff crée le compte CamPay (démo), note les exigences KYC et le délai. 2. Tester sur demo.campay.net avec un numéro MTN et un numéro Orange. 3. Demander par écrit : frais collecte/retrait par opérateur, montant minimum, règlement, plafonds, format du webhook, SLA/support. 4. Pilote réel avec quelques paiements des deux opérateurs. 5. Garder pawaPay/Notch Pay comme solution de repli.

## Risques
- Passerelle plus petite que Flutterwave : fiabilité et conditions non mesurées ici [N]. Garder la couche d'abstraction et un coussin de trésorerie.
- Avis juridique à obtenir si NetBuis envoie des fonds à des tiers (agrément éventuel).

## Sources
- [CamPay API (Postman)](https://documenter.getpostman.com/view/2391374/T1LV8PVA)
- [CamPay Python SDK (GitHub)](https://github.com/CamPay/campay-python-sdk)
- [Getting Started with CamPay API (blog CamPay)](https://blog.campay.net/getting-started-with-campay-api-a-step%E2%80%90by%E2%80%90step-guide/)
- [CamPay — présentation (Medium)](https://medium.com/@campayapi/accepter-les-paiements-par-mobile-money-sur-vos-site-web-et-applications-9865349e25c7)
- [CamPay](https://www.campay.net/en/)
