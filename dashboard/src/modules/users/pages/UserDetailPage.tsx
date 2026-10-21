import { Link, useParams } from "react-router-dom";
import { Badge, Button, Skeleton } from "../../../components/ui";
import { formatDate } from "../../../lib/dates";
import { PATHS } from "../../../routes/paths";
import { IdDocumentModal, type DocumentKind } from "../../businesses/components/ValidationPanel";
import { useIdDocument } from "../../businesses/hooks";
import { AccountActionButtons, useAccountActions } from "../components/AccountActions";
import { STATUS_BADGE, TYPE_LABEL } from "../components/UserTable";
import { useAccount } from "../hooks";
import type { AccountDetail, AuditEntry } from "../types";
import { useState } from "react";

const BUSINESS_TYPE: Record<string, string> = {
  boutique: "Commerce",
  entreprise: "Entreprise",
  particulier_vendeur: "Particulier vendeur",
  prestataire_service: "Prestataire de service",
  structure: "Structure",
};

const BUSINESS_STATUS: Record<string, string> = {
  actif: "Actif",
  en_attente_validation: "En attente de validation",
  rejete: "Rejeté",
};

function Rows({ rows }: { rows: Array<[string, string | null | undefined]> }) {
  const shown = rows.filter((r): r is [string, string] => r[1] !== null && r[1] !== undefined && r[1] !== "");
  return (
    <dl className="grid grid-cols-[max-content_1fr] gap-x-6 gap-y-1.5 text-[13px]">
      {shown.map(([label, value]) => (
        <div key={label} className="contents">
          <dt className="text-ink-3">{label}</dt>
          <dd className="m-0 break-words text-ink">{value}</dd>
        </div>
      ))}
    </dl>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section aria-label={title} className="rounded-2xl border border-line bg-card px-5 py-[18px]">
      <h3 className="mb-3 text-[14px] font-extrabold">{title}</h3>
      {children}
    </section>
  );
}

function AuditList({ entries, empty }: { entries: AuditEntry[]; empty: string }) {
  if (entries.length === 0) return <p className="text-[12.5px] text-ink-3">{empty}</p>;
  return (
    <ul className="m-0 flex list-none flex-col gap-2 p-0">
      {entries.map((e, i) => (
        <li key={`${e.created_at}-${i}`} className="text-[12.5px]">
          <span className="font-bold text-ink">{e.label}</span>
          <span className="text-ink-2"> — {e.admin_name} · {formatDate(e.created_at)}</span>
          {e.reason && <p className="m-0 mt-0.5 break-words text-ink-2">Motif : {e.reason}</p>}
        </li>
      ))}
    </ul>
  );
}

/**
 * Numéro complet : affiché ICI SEULEMENT, et seulement si le serveur l'a renvoyé (Administrateur
 * complet). Sinon (Validateur) : le numéro masqué. Jamais dans le titre, l'adresse ni le stockage.
 */
function phoneText(a: AccountDetail): string {
  return a.phone ?? a.phone_masked;
}

function Detail({ account: a, reload }: { account: AccountDetail; reload: () => Promise<void> }) {
  const actions = useAccountActions();
  const doc = useIdDocument();
  const [docKind, setDocKind] = useState<DocumentKind | null>(null);
  const [reloading, setReloading] = useState(false);
  const b = a.business;

  const open = (kind: DocumentKind) => {
    const url = kind === "cni" ? b?.cni_url : b?.diplome_url;
    if (!url) return;
    setDocKind(kind);
    void doc.open(url);
  };
  const onReload = async () => {
    setReloading(true);
    try {
      await reload();
      doc.close(); // nouveau lien : l'administrateur rouvre la pièce
    } finally {
      setReloading(false);
    }
  };

  return (
    <div className="flex flex-col gap-4">
      <Section title="Identité">
        <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-2.5">
            <h2 className="text-[18px] font-extrabold">{a.name}</h2>
            <Badge status={STATUS_BADGE[a.status]} />
          </div>
          <div className="flex items-center gap-2">
            <AccountActionButtons account={a} busy={actions.busy} onAsk={(action) => actions.ask(a, action)} />
          </div>
        </div>
        <Rows
          rows={[
            ["Téléphone", phoneText(a)],
            ["Type", TYPE_LABEL[a.type] ?? a.type],
            ["Zone", a.zone_name],
            ["Langue", a.language],
            ["Créé le", formatDate(a.created_at)],
            ["Rôles d'administration", a.roles.length > 0 ? a.roles.join(", ") : null],
            ["Motif du blocage", a.is_blocked ? a.blocked_reason : null],
            ["Bloqué le", a.is_blocked && a.blocked_at ? formatDate(a.blocked_at) : null],
            ["Supprimé le", a.is_deleted && a.deleted_at ? formatDate(a.deleted_at) : null],
          ]}
        />
      </Section>

      {b && (
        <Section title="Profil business">
          <Rows
            rows={[
              ["Nom", b.name],
              ["Statut", BUSINESS_STATUS[b.status] ?? b.status],
              ["Type de compte", BUSINESS_TYPE[b.type_compte] ?? b.type_compte],
              ["Représentant", b.representant_nom],
              ["Forme juridique", b.forme_juridique],
              ["RCCM", b.rccm],
              ["Catégorie de service", b.categorie_service_name || b.categorie_service_libre],
              ["Zone", b.zone_name],
              ["Repère", b.repere],
              ["Description", b.description],
            ]}
          />
          {(b.cni_url || b.diplome_url) && (
            <div className="mt-3 flex flex-wrap items-center gap-2">
              {b.cni_url && (
                <Button variant="secondary" onClick={() => open("cni")}>
                  Voir la CNI
                </Button>
              )}
              {b.diplome_url && (
                <Button variant="secondary" onClick={() => open("diplome")}>
                  Voir le diplôme
                </Button>
              )}
            </div>
          )}
        </Section>
      )}

      <Section title="Historique des statuts">
        <AuditList entries={a.status_history} empty="Aucun changement de statut." />
      </Section>
      <Section title="Dernières actions d'audit">
        <AuditList entries={a.recent_audit} empty="Aucune action enregistrée." />
      </Section>

      {actions.dialog}
      <IdDocumentModal kind={docKind} state={doc.state} onClose={doc.close} onReload={() => void onReload()} reloading={reloading} />
    </div>
  );
}

/** Page de détail d'un compte (route /comptes/:id). */
export function UserDetailPage() {
  const { id } = useParams();
  const parsed = id !== undefined && /^\d+$/.test(id) ? Number(id) : null;
  const query = useAccount(parsed);
  const status = (query.error as { response?: { status?: number } } | null)?.response?.status;

  return (
    <section aria-label="Détail du compte" className="flex flex-col gap-4 px-8 pb-7 pt-[18px]">
      <Link to={PATHS.comptes} className="self-start text-[12.5px] font-bold text-ink-2">
        ← Comptes
      </Link>
      {parsed === null || status === 404 ? (
        <p role="alert" className="py-8 text-center text-[13px] text-danger">
          Ce compte n'existe pas.
        </p>
      ) : query.isLoading ? (
        <div aria-busy="true" data-testid="account-skeleton" className="flex flex-col gap-4">
          <Skeleton className="h-[160px] w-full rounded-2xl" />
          <Skeleton className="h-[120px] w-full rounded-2xl" />
        </div>
      ) : query.isError || !query.data ? (
        <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center">
          <p className="text-[13px] text-danger">
            {status === 403 ? "Vous n'avez pas le droit de voir ce compte." : "Impossible de charger ce compte."}
          </p>
          <Button variant="secondary" onClick={() => void query.refetch()}>
            Réessayer
          </Button>
        </div>
      ) : (
        <Detail account={query.data} reload={async () => void (await query.refetch())} />
      )}
    </section>
  );
}
