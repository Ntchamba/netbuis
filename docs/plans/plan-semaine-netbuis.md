# NetBuis — Plan de la semaine (6 au 12/10/2026) : 3 agents Claude, Flutter + Django (Railway) + tableau de bord (Vercel)

Document vivant (détail complet, frises, 97 tâches A/B/C) : https://claude.ai/code/artifact/e45ca371-567d-4f01-bcec-6c1cad01d046
Remplace, pour cette semaine, `plan-realisation-netbuis.md` (plan de 10 mois).

## Décisions (06/10/2026)
- Mobile : Flutter Android. Backend : Django 5.2 LTS + DRF sur Railway avec PostgreSQL Railway. Tableau de bord : Next.js (TypeScript) sur Vercel.
- Organisation : 3 agents de construction (A backend, B Flutter, C paiement + tableau de bord + mise en ligne), 3 sous-agents chacun, plus 1 orchestrateur unique qui intègre et fusionne ; Jeff relit les étapes.
- Découpage en 9 étapes (É0 à É8) selon les dépendances, chemin critique É0→É1→É2→É3→É4→É8 ; chaque étape se termine par une porte (tests, démonstration, relecture).
- Durée réaliste [avis, non mesuré] : démonstration 7 à 10 jours, plan complet 12 à 16 jours, options (carte, notifications, voix) 3 à 5 jours de plus. Les 7 jours du calendrier sont le meilleur cas.
- Briques : CamPay par API REST directe (pas le SDK GPL-3.0), `pg_trgm` + `unaccent`, `tel:` + `wa.me`, OpenFreeMap + MapLibre (si temps), FCM (si temps), forum natif Django.
- Hors semaine : Play Store (test fermé de 14 jours), iPhone, parrainage, commandes, Celery/Redis, CamPay en production.
## Points bloquants / à confirmer
- Railway exige une carte post-payée d'après sa documentation ; Jeff n'a pas de carte bancaire. À régler avant J1.
- `pg_trgm`/`unaccent` sur Railway non confirmés (repli vérifié : Neon).
- Fournisseur SMS et stockage photos non choisis ; webhook, frais et KYC CamPay non confirmés.
- Vercel Hobby = usage non commercial ; Pro dès que l'application encaisse.
## Détection WhatsApp (décision du 07/10/2026)
- Aucune vérification officielle et gratuite qu'un numéro est sur WhatsApp ; outils tiers écartés (session WhatsApp liée, risque de bannissement, numéros envoyés à un tiers, loi 2024/017).
- Retenu : case « Ce numéro est sur WhatsApp » + bouton Tester dans la fiche commerçant ; bouton WhatsApp affiché seulement si déclaré ; retour « WhatsApp n'a pas marché » ; à 3 signalements, bouton masqué et fiche « à corriger ». Tâches A.33, A.34, B.32, B.33.
