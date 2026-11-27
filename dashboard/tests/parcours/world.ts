// Faux serveur À ÉTAT pour les parcours de bout en bout : une seule « base » en mémoire, partagée par
// toutes les pages (une validation change la pastille, un blocage apparaît dans le journal d'audit, etc.).
// Données FICTIVES. Le mot de passe ci-dessous n'existe nulle part.
import type { Call, Reply } from "../auth/fakeServer";

export const PHONE = "+237677123456";
export const PASSWORD = "mdp-fictif-123";
export const FULL_PHONE = "+237 600 00 00 41";
export const MASKED = "+237 6•• •• •• 41";
export const SIGNED_CNI = "/api/admin/private-files/jeton-cni-fictif/";

export const VALIDATEUR = ["peut_voir_comptes", "peut_voir_demandes", "peut_valider_demande"];
export const ADMIN_COMPLET = [
  "peut_voir_comptes",
  "peut_voir_demandes",
  "peut_valider_demande",
  "peut_bloquer_compte",
  "peut_supprimer_compte",
  "peut_moderer_contenu",
  "peut_gerer_referentiels",
  "peut_modifier_reglages",
  "peut_gerer_admins",
  "peut_exporter",
];

export interface AuditRow {
  id: number;
  admin_id: number;
  admin_name: string;
  action: string;
  action_label: string;
  target_type: string;
  target_id: number;
  reason: string;
  created_at: string;
}

type Obj = Record<string, unknown>;
const ok = (data: unknown, status = 200): Reply => ({ status, data });
const err = (status: number, code: string): Reply => ({ status, data: { code, message: code } });
const page = (rows: unknown[], count = rows.length): Reply => ok({ count, next: null, previous: null, results: rows });
const iso = () => new Date().toISOString();

export class World {
  permissions: string[];
  adminId = 1;
  adminName = "Awa Test";
  /** Cookie de rafraîchissement valide ? */
  cookie: boolean;
  /** Le jeton d'accès que le serveur accepte (changé par `expire()`). */
  access = "jeton-1";
  private tokenCounter = 1;
  me403 = false;
  refreshCount = 0;
  logoutCount = 0;

  requests: Obj[] = [];
  accounts: Obj[] = [];
  reports: Obj[] = [];
  sectors: Obj[] = [];
  settings: Obj[] = [];
  audit: AuditRow[] = [];
  /** Appels reçus par route, pour vérifier ce que le navigateur a vraiment envoyé. */
  extra: ((c: Call) => Reply | undefined) | null = null;

  constructor(permissions: string[], cookie = true) {
    this.permissions = permissions;
    this.cookie = cookie;
    const base = { type: "business", type_compte: "boutique", status: "en_attente_validation", zone: 1, zone_name: "Quartier Test", repere: "Près du marché", description: "", representant_nom: "", forme_juridique: "", rccm: "", categorie_service: null, categorie_service_name: null, categorie_service_libre: "", cni_verifiee: false, photo_url: null, representant_photo_url: null, cni_url: null, diplome_url: null, phone_masked: MASKED };
    this.requests = [
      { ...base, id: 1, name: "Boutique Mama", owner_id: 101, owner_name: "Mama Test", created_at: iso() },
      { ...base, id: 2, name: "Prestataire Paul", type_compte: "prestataire_service", owner_id: 102, owner_name: "Paul Test", cni_url: SIGNED_CNI, created_at: iso() },
    ];
    const acc = (id: number, name: string, over: Obj = {}) => ({ id, name, phone_masked: MASKED, type: "simple", status: "actif", is_admin: false, is_blocked: false, is_deleted: false, business_name: null, business_status: null, zone_id: null, zone_name: null, created_at: iso(), ...over });
    this.accounts = [acc(1, "Jeff N."), acc(2, "Mama Boutique", { type: "business", business_name: "Boutique Mama" }), acc(3, "Kevin T.")];
    const rep = (id: number, over: Obj = {}) => ({ target_type: "post", target_id: id, content_status: "actif", preview: `Texte du message ${id}`, media_type: null, post_id: null, business_id: 5, business_name: "Boutique Test", author_id: 9, author_name: "Awa Auteur", author_phone_masked: MASKED, reasons: [{ reason: "spam", count: 2 }], reporters_count: 2, first_reported_at: iso(), last_reported_at: iso(), ...over });
    this.reports = [rep(1), rep(2), rep(3)];
    this.sectors = [
      { id: 1, code: "alimentation", name: "Alimentation", icon: "", order: 1, is_active: true, updated_at: iso() },
      { id: 2, code: "mode", name: "Mode", icon: "", order: 2, is_active: true, updated_at: iso() },
    ];
    this.settings = [{ key: "limite_appels_par_jour", label: "Limite d'appels par jour", value: 50, default: 50, min: 0, max: 1000, modified_by: null, updated_at: null }];
  }

  /** Le jeton d'accès expire : le serveur n'accepte plus que le prochain, délivré par /refresh/. */
  expire() {
    this.tokenCounter += 1;
    this.access = `jeton-${this.tokenCounter}`;
  }

  record(action: string, targetType: string, targetId: number, reason = "") {
    const labels: Obj = {
      validation_business: "Validation d'un compte business",
      rejet_business: "Rejet d'un compte business",
      blocage_compte: "Blocage d'un compte",
      deblocage_compte: "Déblocage d'un compte",
      suppression_compte: "Suppression d'un compte",
      restauration_compte: "Restauration d'un compte",
      consultation_numero: "Consultation du numéro complet d'un compte",
      moderation_contenu: "Modération d'un contenu",
      creation_referentiel: "Création d'un élément de référentiel",
      modification_referentiel: "Modification d'un élément de référentiel",
      modification_reglage: "Modification d'un réglage",
      export_comptes: "Export CSV des comptes",
    };
    this.audit.unshift({ id: this.audit.length + 1, admin_id: this.adminId, admin_name: this.adminName, action, action_label: String(labels[action] ?? action), target_type: targetType, target_id: targetId, reason, created_at: iso() });
  }

  private has(p: string) {
    return this.permissions.includes(p);
  }

  handle = (c: Call): Reply => {
    const url = c.url;
    // ---- authentification ----
    if (url === "/api/auth/refresh/") {
      this.refreshCount += 1;
      return this.cookie ? ok({ access: this.access }) : err(401, "token_invalid");
    }
    if (url === "/api/auth/admin/login/") {
      const b = c.body as { phone?: string; password?: string };
      if (b.phone !== PHONE || b.password !== PASSWORD) return err(401, "invalid_credentials");
      this.cookie = true;
      return ok({ access: this.access });
    }
    if (url === "/api/auth/logout/") {
      this.logoutCount += 1;
      this.cookie = false;
      return { status: 204 };
    }
    // ---- tout le reste exige le jeton courant ----
    if (c.auth !== `Bearer ${this.access}`) return err(401, "token_invalid");
    if (url === "/api/admin/me/") {
      if (this.me403) return err(403, "forbidden");
      return ok({ id: this.adminId, name: this.adminName, phone_masked: "+237 6•• •• •• 12", roles: ["Test"], permissions: this.permissions });
    }
    if (this.extra) {
      const r = this.extra(c);
      if (r) return r;
    }
    if (url === "/api/admin/stats/") return ok({ pending_requests: this.requests.length });
    if (url.startsWith("/api/admin/private-files/")) return { status: 200, data: new Blob(["image-fictive"], { type: "image/png" }) };

    // ---- demandes ----
    if (url === "/api/admin/requests/") return this.need("peut_voir_demandes") ?? page(this.requests);
    let m = /^\/api\/admin\/requests\/(\d+)\/(approve|reject)\/$/.exec(url);
    if (m) {
      if (!this.has("peut_valider_demande")) return err(403, "forbidden");
      const id = Number(m[1]);
      const i = this.requests.findIndex((r) => r.id === id);
      if (i < 0) return err(409, "already_processed");
      if (m[2] === "reject") {
        const reason = String((c.body as { reason?: string }).reason ?? "").trim();
        if (!reason) return err(400, "reason_required");
        this.requests.splice(i, 1);
        this.record("rejet_business", "businesses.business", id, reason);
        return ok({ id, status: "rejete", cni_verifiee: false, motif_rejet: reason });
      }
      this.requests.splice(i, 1);
      this.record("validation_business", "businesses.business", id);
      return ok({ id, status: "actif", cni_verifiee: false, motif_rejet: "" });
    }

    // ---- comptes ----
    if (url === "/api/zones/") return page([]);
    if (url === "/api/admin/accounts/" && c.method === "get") {
      const q = String(c.params?.q ?? "").toLowerCase();
      const rows = this.accounts.filter((a) => !q || `${a.name} ${a.business_name ?? ""}`.toLowerCase().includes(q));
      return page(rows);
    }
    m = /^\/api\/admin\/accounts\/(\d+)\/(?:(block|unblock|restore)\/)?$/.exec(url);
    if (m) {
      const acc = this.accounts.find((a) => a.id === Number(m![1]));
      if (!acc) return err(404, "not_found");
      const op = m[2] ?? (c.method === "delete" ? "delete" : "detail");
      const id = acc.id as number;
      const reason = String((c.body as { reason?: string } | undefined)?.reason ?? "").trim();
      if (op === "detail") {
        // Consulter le numéro complet est une action auditée côté serveur.
        const recent = this.audit.filter((a) => a.target_id === id && a.target_type === "accounts.user").slice(0, 5);
        this.record("consultation_numero", "accounts.user", id);
        return ok({ ...acc, phone: this.has("peut_gerer_admins") ? FULL_PHONE : null, language: "fr", blocked_reason: acc.blocked_reason ?? "", blocked_at: null, deleted_at: null, roles: [], business: null, status_history: recent.map((a) => ({ action: a.action, label: a.action_label, reason: a.reason, admin_id: a.admin_id, admin_name: a.admin_name, created_at: a.created_at })), recent_audit: recent.map((a) => ({ action: a.action, label: a.action_label, reason: a.reason, admin_id: a.admin_id, admin_name: a.admin_name, created_at: a.created_at })) });
      }
      if (op === "block" || op === "delete") {
        if (!this.has(op === "block" ? "peut_bloquer_compte" : "peut_supprimer_compte")) return err(403, "forbidden");
        if (!reason) return err(400, "reason_required");
        if (op === "block") Object.assign(acc, { status: "bloque", is_blocked: true, blocked_reason: reason });
        else Object.assign(acc, { status: "supprime", is_deleted: true });
        this.record(op === "block" ? "blocage_compte" : "suppression_compte", "accounts.user", id, reason);
      } else if (op === "unblock") {
        if (!acc.is_blocked) return err(409, "invalid_state");
        Object.assign(acc, { status: "actif", is_blocked: false, blocked_reason: "" });
        this.record("deblocage_compte", "accounts.user", id);
      } else {
        if (!acc.is_deleted) return err(409, "invalid_state");
        Object.assign(acc, { status: "actif", is_deleted: false });
        this.record("restauration_compte", "accounts.user", id);
      }
      return ok({ id, status: acc.status, is_blocked: acc.is_blocked, is_deleted: acc.is_deleted, blocked_reason: acc.blocked_reason ?? "", deleted_at: null });
    }
    if (url === "/api/admin/export/accounts.csv") {
      if (!this.has("peut_exporter")) return err(403, "forbidden");
      this.record("export_comptes", "accounts.user", 0);
      const body = "﻿id,nom,telephone,type,statut\r\n" + this.accounts.map((a) => `${a.id},${a.name},${a.phone_masked},${a.type},${a.status}`).join("\r\n") + "\r\n";
      return { status: 200, data: new Blob([body], { type: "text/csv" }) };
    }

    // ---- modération ----
    if (url === "/api/admin/reports/") {
      if (!this.has("peut_moderer_contenu")) return err(403, "forbidden");
      const status = c.params?.status as string | undefined;
      const rows = this.reports.filter((r) => (status ? r.content_status === status : r.content_status !== "supprime"));
      return page(rows);
    }
    m = /^\/api\/admin\/reports\/(post|comment|business)\/(\d+)\/(hide|restore|delete)\/$/.exec(url);
    if (m) {
      if (!this.has("peut_moderer_contenu")) return err(403, "forbidden");
      const row = this.reports.find((r) => r.target_type === m![1] && r.target_id === Number(m![2]));
      if (!row) return err(404, "not_found");
      const reason = String((c.body as { reason?: string }).reason ?? "").trim();
      if (m[3] === "delete" && !reason) return err(400, "reason_required");
      if (m[3] === "hide") row.content_status = "masque";
      if (m[3] === "restore") row.content_status = "actif";
      if (m[3] === "delete") row.content_status = "supprime";
      this.record("moderation_contenu", `forum.${m[1]}`, Number(m[2]), reason);
      return ok(row);
    }
    if (url === "/api/admin/forbidden-words/") return page([]);

    // ---- référentiels ----
    if (url === "/api/admin/referentials/sectors/" && c.method === "get") return page(this.sectors);
    if (url === "/api/admin/referentials/sectors/" && c.method === "post") {
      if (!this.has("peut_gerer_referentiels")) return err(403, "forbidden");
      const b = c.body as { code: string; name: string };
      if (this.sectors.some((s) => String(s.name).toLowerCase() === b.name.toLowerCase() || s.code === b.code)) return err(409, "already_exists");
      const row = { id: 10 + this.sectors.length, code: b.code, name: b.name, icon: "", order: this.sectors.length + 1, is_active: true, updated_at: iso() };
      this.sectors.push(row);
      this.record("creation_referentiel", "referentials.sector", row.id);
      return ok(row, 201);
    }
    m = /^\/api\/admin\/referentials\/sectors\/(\d+)\/$/.exec(url);
    if (m && c.method === "patch") {
      const row = this.sectors.find((s) => s.id === Number(m![1]));
      if (!row) return err(404, "not_found");
      const b = c.body as { name?: string };
      if (b.name && this.sectors.some((s) => s !== row && String(s.name).toLowerCase() === b.name!.toLowerCase())) return err(409, "already_exists");
      Object.assign(row, b);
      this.record("modification_referentiel", "referentials.sector", row.id as number);
      return ok(row);
    }

    // ---- réglages ----
    if (url === "/api/admin/settings/") return this.need("peut_modifier_reglages") ?? ok(this.settings);
    m = /^\/api\/admin\/settings\/([a-z_]+)\/$/.exec(url);
    if (m && c.method === "patch") {
      if (!this.has("peut_modifier_reglages")) return err(403, "forbidden");
      const s = this.settings.find((x) => x.key === m![1]);
      if (!s) return err(404, "not_found");
      const v = (c.body as { value: number }).value;
      if (v < (s.min as number) || v > (s.max as number)) return err(400, "invalid_value");
      s.value = v;
      s.modified_by = this.adminName;
      s.updated_at = iso();
      this.record("modification_reglage", "admin_panel.platformsetting", 1);
      return ok(s);
    }

    // ---- audit ----
    if (url === "/api/admin/admins/") return page([{ id: 1, name: "Awa Test" }, { id: 2, name: "Bello Test" }]);
    if (url === "/api/admin/audit/") {
      const action = c.params?.action as string | undefined;
      const rows = this.audit.filter((a) => !action || a.action === action);
      return page(rows);
    }
    return { status: 404 };
  };

  private need(p: string): Reply | undefined {
    return this.has(p) ? undefined : err(403, "forbidden");
  }
}
