# Architecture

```
Mobile Flutter ──HTTPS/JSON──▶ Django REST (backend/) ──▶ PostgreSQL (pg_trgm, unaccent)
Dashboard React ──HTTPS/JSON──▶        │
                                       ├──▶ SMS (OTP)            [fournisseur à choisir]
                                       ├──▶ CamPay (collect / payout)   [reporté, É6]
                                       └──▶ Stockage photos       [à choisir]
Appel : le mobile ouvre `tel:` (ou `wa.me`) avec le numéro obtenu par POST /api/calls/initiate/
```

## Principes

- **Contrat d'abord** (OpenAPI) ; mobile et dashboard peuvent avancer sur des données factices.
- **Recherche** : PostgreSQL `TrigramSimilarity` + `unaccent` ; la voix est reconnue par le téléphone, le serveur ne
  reçoit que du texte.
- **Appel direct** : gratuit côté plateforme (`tel:` et `wa.me`). Le serveur journalise (`CallLog`) et remet le numéro.
- **Paiements** : abstraction `PaymentProvider` (`collect`, `status`, `payout`) ; CamPay en REST direct ; portefeuille
  idempotent avec journal append-only (`CreditLedger`) ; statut revérifié à la demande.
- **Sécurité** : permissions côté serveur, secrets en variables d'environnement.
