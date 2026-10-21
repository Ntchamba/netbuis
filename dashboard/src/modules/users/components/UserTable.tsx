import { useNavigate } from "react-router-dom";
import { Badge, EmptyState, Skeleton, type BadgeStatus } from "../../../components/ui";
import { cn } from "../../../lib/cn";
import { PATHS } from "../../../routes/paths";
import type { AccountAction, AccountListItem, AccountStatus } from "../types";
import { AccountActionButtons } from "./AccountActions";

export const STATUS_BADGE: Record<AccountStatus, BadgeStatus> = { actif: "actif", bloque: "bloque", supprime: "supprime" };
export const TYPE_LABEL = { simple: "Simple", business: "Business" } as const;

export function accountPath(id: number): string {
  return PATHS.compte.replace(":id", String(id));
}

const HEADERS = ["NOM", "TÉLÉPHONE", "TYPE", "ZONE", "STATUT", "ACTIONS"];

interface Props {
  rows: AccountListItem[];
  loading: boolean;
  busy: boolean;
  onAsk: (account: AccountListItem, action: AccountAction) => void;
}

/** Tableau de la maquette Comptes. Le numéro est celui que le serveur masque ; un clic ouvre le détail. */
export function UserTable({ rows, loading, busy, onAsk }: Props) {
  const navigate = useNavigate();
  return (
    <div className="overflow-hidden rounded-2xl border border-line bg-card">
      <table className="w-full border-collapse">
        <caption className="sr-only">Comptes</caption>
        <thead>
          <tr className="border-b border-line">
            {HEADERS.map((h) => (
              <th key={h} scope="col" className={cn("px-[18px] py-3 text-[11.5px] font-bold text-ink-3", h === "ACTIONS" ? "text-right" : "text-left")}>
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody aria-busy={loading || undefined}>
          {loading &&
            [0, 1, 2].map((i) => (
              <tr key={i} data-loading-row className="border-b border-line">
                {HEADERS.map((h) => (
                  <td key={h} className="px-[18px] py-[14px]">
                    <Skeleton className="h-4 w-3/4" />
                  </td>
                ))}
              </tr>
            ))}
          {!loading && rows.length === 0 && (
            <tr>
              <td colSpan={HEADERS.length}>
                <EmptyState title="Aucun compte" description="Aucun compte ne correspond à ces critères." />
              </td>
            </tr>
          )}
          {!loading &&
            rows.map((a) => (
              <tr
                key={a.id}
                data-testid={`account-row-${a.id}`}
                onClick={() => navigate(accountPath(a.id))}
                className={cn("cursor-pointer border-b border-line last:border-b-0 hover:bg-bg", a.is_deleted && "opacity-55")}
              >
                <td className="px-[18px] py-[14px] text-[13.5px] font-bold">
                  <a
                    href={accountPath(a.id)}
                    onClick={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      navigate(accountPath(a.id));
                    }}
                  >
                    {a.business_name || a.name}
                  </a>
                </td>
                <td className="px-[18px] py-[14px] text-[12.5px] text-ink-2">{a.phone_masked}</td>
                <td className={cn("px-[18px] py-[14px] text-[12px] font-bold", a.type === "business" ? "text-accent-ink" : "text-ink-2")}>{TYPE_LABEL[a.type] ?? a.type}</td>
                <td className="px-[18px] py-[14px] text-[12.5px] text-ink-2">{a.zone_name ?? "—"}</td>
                <td className="px-[18px] py-[14px]">
                  <Badge status={STATUS_BADGE[a.status]} />
                </td>
                <td className="px-[18px] py-[14px]" onClick={(e) => e.stopPropagation()}>
                  <div className="flex justify-end gap-2">
                    <AccountActionButtons account={a} busy={busy} compact onAsk={(action) => onAsk(a, action)} />
                  </div>
                </td>
              </tr>
            ))}
        </tbody>
      </table>
    </div>
  );
}
