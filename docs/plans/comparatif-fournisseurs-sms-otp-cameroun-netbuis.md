# NetBuis — Comparatif des fournisseurs SMS pour l'OTP (Cameroun)

Date de recherche : 2026-10-11. Les prix et délais viennent des pages publiques des fournisseurs ou d'agrégateurs. Aucun n'a été testé en réel : à vérifier avant de s'engager.

| Option | Réseaux | Prix indicatif | Paiement | Points d'attention |
|---|---|---|---|---|
| Orange SMS Cameroun 2.0 (developer.orange.com) | Tous opérateurs du Cameroun, uniquement à destination du Cameroun | à partir d'environ 16 FCFA/SMS selon le forfait (50 à 50 000 SMS) | Orange Money ou crédit de communication, virement pour gros volumes | Client ID + secret, noms d'expéditeur personnalisés via liste blanche (gratuit), accusés de réception en temps réel. Pas de carte bancaire. |
| Cooms (cooms.app) | Orange et MTN Cameroun, routage direct annoncé | forfaits dès 3 000 XAF | Mobile Money annoncé | Acteur local, peu d'informations publiques (sender ID, inscription). À tester. |
| Twilio | Tous | environ 0,0075 USD/SMS (agrégateur tiers) | carte bancaire | Pré-enregistrement du sender ID alphanumérique obligatoire pour MTN (environ 3 semaines). Pas de SMS bidirectionnel. Carte bancaire exclue par Jeff. |
| Vonage | Tous | non relevé | carte bancaire | MTN exige un pré-enregistrement. Numéros au format 2376XXXXXXXX. |
| Infobip / Sinch / MessageBird | Tous | plus chers (0,02 à 0,17 USD) | contrat | Surdimensionnés pour le démarrage. |

## Recommandation

1. Orange SMS Cameroun 2.0 pour démarrer (paiement par Orange Money, pas de carte, couverture tous opérateurs).
2. Cooms en secours ou second choix.
3. Twilio/Vonage seulement si une carte devient disponible.

## Implémentation prévue

`SMS_PROVIDER=console` (dev) → `orange` (prod). Interface `SmsProvider.send(phone, message)` avec trois implémentations : console, orange, (cooms). Clés dans `backend/.env` uniquement. Format des numéros : `2376XXXXXXXX`.

## À décider par Jeff

Choix du fournisseur avant l'étape 2 (OTP réel). L'étape 1 se fait avec `console`.
