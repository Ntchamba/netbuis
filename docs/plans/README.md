# Historique du Projet Claude (référence)

Ces documents viennent du Projet Claude « NetBuis » (études, décisions argumentées, audits, veille). Ils expliquent **pourquoi** les choix ont été faits. Ils **ne font pas foi** : en cas de contradiction, l'ordre de `AGENTS.md` s'applique (`docs/DECISIONS_JEFF.md` > `docs/ORCHESTRATION.md` > `docs/spec/` > maquettes > `docs/BACKLOG.md`). Exemple : certaines notes anciennes parlent d'Expo/React Native ou de Twilio ; la décision retenue est Flutter et l'appel direct `tel:` / `wa.me`.

Non recopiés ici car leur version à jour est déjà dans `docs/` : le backlog T000–T125 (`docs/BACKLOG.md`), le guide d'orchestration (`docs/ORCHESTRATION.md`), le cahier de tâches par agent (`docs/TASKS_PAR_AGENT.md`), les décisions et points ouverts (`docs/DECISIONS_JEFF.md`).

## Documents

| Fichier | Sujet |
|---|---|
| `accessibilite-analphabetisme-netbuis.md` | Accessibilité pour les utilisateurs analphabètes ou non-lecteurs |
| `analyse-flux-appels.md` | Analyse critique — Flux d'appel client → commerçant (NetBuis) |
| `apis-github-complement-v3-netbuis.md` | APIs et dépôts GitHub gratuits — complément v3 (2026-10-06) |
| `apis-github-gratuites-netbuis.md` | APIs et briques GitHub gratuites pour aller vite — NetBuis (2026-10-06) |
| `architecture-performance-netbuis.md` | Fluidité de l'app, code natif (C/assembleur), appels système, et performance API — ce qui est réaliste |
| `audit-complement-v2-netbuis.md` | Complément d'audit v2 NetBuis (2026-10-05) |
| `audit-orchestration-gestion-projet-netbuis.md` | Audit expert NetBuis, orchestration d'agents IA et méthodes de gestion de projet (2026-10-05) |
| `comparatif-fournisseurs-sms-otp-cameroun-netbuis.md` | NetBuis — Comparatif des fournisseurs SMS pour l'OTP (Cameroun) |
| `comparatif-solutions-telecom-appels.md` | Comparatif des solutions télécom pour les appels NetBuis (VoIP intra-app + pont PSTN) |
| `dashboard-admin-netbuis.md` | Dashboard d'administration NetBuis — fonctionnalités et modèle de données |
| `decision-campay-netbuis.md` | Décision : CamPay comme passerelle Mobile Money de NetBuis (MTN + Orange) |
| `decision-finale-appels.md` | Décision finale — mécanisme d'appel NetBuis (v2.1, MVP) |
| `etape1-socle-rapport-netbuis.md` | NetBuis — Étape 1 (socle) : rapport (2026-10-11) |
| `modele-donnees-netbuis.md` | Modèle de données NetBuis — entités, relations, règles métier |
| `monetisation-appels-orange-money.md` | Monétisation des appels — quota gratuit + paiement Orange Money/MTN MoMo |
| `netbuis-contexte-compresse.md` | NetBuis : contexte compressé (état au 13/10/2026) |
| `plan-realisation-netbuis.md` | NetBuis — Plan de réalisation de A à Z (copie du document vivant) |
| `plan-semaine-netbuis.md` | NetBuis — Plan de la semaine (6 au 12/10/2026) : 3 agents Claude, Flutter + Django (Railway) + tableau de bord (Vercel) |
| `rapport-methodes-gestion-projet-netbuis.md` | Rapport: méthodes de gestion de projet de A à Z pour NetBuis (2026-10-05) |
| `rapport-orchestration-agents-ia-netbuis.md` | Rapport: orchestration d'agents IA pour développer NetBuis (2026-10-05) |
| `recherche-apis-github-gratuites-netbuis.md` | Briques open source et APIs gratuites pour l'application mobile NetBuis (v2, 2026-10-06) |
| `recherche-appel-direct-sans-dialer-netbuis.md` | Appel direct depuis NetBuis (sans ouvrir le dialer, sans voir le numéro, SIM par défaut) — recherche d'ingénierie |
| `recherche-methodes-api-ussd-push-paiement-2026-netbuis.md` | Méthodes 2026 : API backend → push USSD / envoi de fonds (Orange Money, MTN MoMo, Cameroun) |
| `recherche-technique-ux-netbuis.md` | Recherche technique & UX — synthèse par thème, avec critique de NetBuis |
| `structure-depot-netbuis.md` | NetBuis — Structure du dépôt (squelette modulaire, 2026-10-07) |

## Veille regroupée (`recherches/`)

Les routines du Projet ont produit plus de 850 petites notes, souvent « aucune nouveauté ». Elles sont regroupées en quatre fichiers, du plus ancien au plus récent, chaque note précédée de son nom d'origine :

- `recherches/audits-experts.md` : Audits d'expert successifs (v2 à v199) (197 notes)
- `recherches/veille-apis-github.md` : Veille : API et projets GitHub gratuits (addenda) (230 notes)
- `recherches/veille-appel-direct.md` : Veille : appel direct sans composeur (passages de vérification) (212 notes)
- `recherches/veille-paiement-ussd-push.md` : Veille : méthodes d'API USSD push / paiement 2026 (addenda) (219 notes)
