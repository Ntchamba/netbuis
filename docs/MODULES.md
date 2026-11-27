# Carte des modules

## Backend (`backend/apps/`)

| App | Rôle | Agent | Étape |
|---|---|---|---|
| `core` | Santé, pagination, permissions, utilitaires (téléphone E.164, normalisation du texte) | A | É1 |
| `accounts` | Utilisateur, OTP SMS, JWT, `/api/me/` | A | É2 |
| `geo` | Villes, quartiers, « autour de moi » (cartes) | A | É3 |
| `catalog` | Catégories, produits, synonymes | A | É3 |
| `business` | Fiches commerçants, offres, photos, espace commerçant | A | É3 |
| `search` | Recherche **écrite** (`text/`) et **vocale** (`voice/`), suggestions, journal | A | É4 |
| `calls` | Appel direct, WhatsApp (`wa.me`), retours, signalements | A | É4 |
| `forum` | Fils, messages, signalements, modération | A | É7 |
| `trends` | Produits les plus recherchés et commerces les plus contactés par ville (`compute_trends`, `GET /api/trends/`) | A | É7 |
| `payments` | **Vide pour l'instant.** `collect/` = réception des frais (CamPay), `payout/` = paiements sortants automatiques, `wallet/`, `packs/`, `providers/` | C | É6 |
| `admin_panel` | API du dashboard : stats, validation commerçants, modération, audit | C | É5 |
| `notifications` | Jetons d'appareil, push FCM, boîte de notifications | A | É8 / optionnel |
| `printing` | PDF imprimables : fiche commerçant, affiche QR, reçu | A | optionnel |

## Mobile (`mobile/lib/features/`)

`auth`, `onboarding`, `account`, `home`, `search` (`text_search/` + `voice_search/`), `business`, `call`, `maps`,
`merchant`, `payments` (vide jusqu'à É6), `forum`, `trends`, `printing`, `notifications`, `settings`. Bases partagées dans `lib/core/`.

## Dashboard (`dashboard/src/modules/`)

`auth`, `overview`, `businesses`, `users`, `forum_moderation`, `trends`, `search_analytics`, `calls_analytics`, `maps`,
`payments` (vide jusqu'à É6 : `collect/`, `payout/`, `packs/`, `ledger/`), `notifications`, `audit_log`, `printing`, `settings`.

## Hypothèses à confirmer par Jeff

- **Impression** : interprétée comme PDF imprimables (fiche commerçant, affiche avec QR, reçu, rapports admin).
- **Cartes** : interprétées comme « commerçants autour de moi » + carte dans le dashboard (OpenStreetMap par défaut, sans clé).
- Ces trois blocs (`maps`, `printing`, `notifications`) ne font pas partie des 97 tâches du plan : à planifier.
