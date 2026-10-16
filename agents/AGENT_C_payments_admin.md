# Agent C — Paiements, admin, dashboard

**Dossiers** : `backend/apps/{payments,admin_panel}`, `dashboard/`.

**Sous-agents proposés** (modifiable) :
- C1 — Paiements : `payments/{providers,collect,payout,wallet,packs}` — **vides jusqu'à É6**.
- C2 — API admin : `admin_panel` (stats, modération, audit).
- C3 — Dashboard React : `dashboard/src/modules/*`.

**Sensible** : tout `payments/`, `admin_panel/permissions.py`.
**Règle** : aucune clé CamPay hors variables d'environnement ; webhook jamais cru seul.
