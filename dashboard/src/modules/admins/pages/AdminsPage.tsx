import { useEffect, useState } from "react";
import { Can } from "../../../auth/permissions";
import { useAuth } from "../../../auth/useAuth";
import { Badge, Button, EmptyState, Pagination, Skeleton } from "../../../components/ui";
import { formatDate } from "../../../lib/dates";
import { useAdminActions } from "../components/AdminActions";
import { CreateAdmin } from "../components/CreateAdmin";
import { useAdmins } from "../hooks";
import { ADMINS_PAGE_SIZE } from "../types";

const HEADERS = ["NOM", "TÉLÉPHONE", "RÔLE", "STATUT", "ACTIONS"];

/** Administrateurs : liste (numéros masqués par le serveur), création, changement et retrait de rôle. */
export function AdminsPage() {
  const [page, setPage] = useState(1);
  const query = useAdmins(page);
  const actions = useAdminActions();
  const { me } = useAuth();
  const data = query.data;
  const pageCount = data ? Math.max(1, Math.ceil(data.count / ADMINS_PAGE_SIZE)) : 1;

  useEffect(() => {
    if (data && data.results.length === 0 && page > 1) setPage(page - 1);
  }, [data, page]);

  return (
    <section aria-label="Administrateurs" className="flex flex-col gap-4 px-8 pb-7 pt-[18px]">
      <div className="flex items-center justify-between gap-3">
        <p className="text-[13px] text-ink-2">Comptes ayant un rôle d'administration. Retirer le rôle ne supprime pas le compte.</p>
        <Can permission="peut_gerer_admins">
          <CreateAdmin />
        </Can>
      </div>

      {query.isError && !data ? (
        <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center">
          <p className="text-[13px] text-danger">Impossible de charger les administrateurs.</p>
          <Button variant="secondary" onClick={() => void query.refetch()}>
            Réessayer
          </Button>
        </div>
      ) : (
        <div className="overflow-hidden rounded-2xl border border-line bg-card">
          <table className="w-full border-collapse">
            <caption className="sr-only">Administrateurs</caption>
            <thead>
              <tr className="border-b border-line">
                {HEADERS.map((h) => (
                  <th key={h} scope="col" className={`px-[18px] py-3 text-[11.5px] font-bold text-ink-3 ${h === "ACTIONS" ? "text-right" : "text-left"}`}>
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody aria-busy={query.isLoading || undefined}>
              {query.isLoading &&
                [0, 1, 2].map((i) => (
                  <tr key={i} data-loading-row className="border-b border-line">
                    {HEADERS.map((h) => (
                      <td key={h} className="px-[18px] py-[14px]">
                        <Skeleton className="h-4 w-3/4" />
                      </td>
                    ))}
                  </tr>
                ))}
              {data && data.results.length === 0 && (
                <tr>
                  <td colSpan={HEADERS.length}>
                    <EmptyState title="Aucun administrateur" description="Aucun compte n'a de rôle d'administration." />
                  </td>
                </tr>
              )}
              {data?.results.map((a) => {
                const self = me !== null && me !== undefined && me.id === a.id;
                return (
                  <tr key={a.id} data-testid={`admin-row-${a.id}`} className="border-b border-line last:border-b-0">
                    <td className="px-[18px] py-[14px] text-[13.5px] font-bold">
                      {a.name}
                      {self && <span className="ml-2 text-[11px] font-semibold text-ink-3">(vous)</span>}
                      <div className="text-[11px] font-normal text-ink-3">Créé le {formatDate(a.created_at)}</div>
                    </td>
                    <td className="px-[18px] py-[14px] text-[12.5px] text-ink-2">{a.phone_masked}</td>
                    <td className="px-[18px] py-[14px] text-[12.5px] font-bold">{a.roles.join(", ") || "—"}</td>
                    <td className="px-[18px] py-[14px]">
                      <Badge status={a.status} />
                    </td>
                    <td className="px-[18px] py-[14px]">
                      <div className="flex justify-end gap-2">
                        {!self && (
                          <Can permission="peut_gerer_admins">
                            <Button variant="secondary" disabled={actions.busy} onClick={() => actions.ask(a, "role")} className="px-2.5 py-1.5 text-[11.5px]">
                              Changer le rôle
                            </Button>
                            <Button variant="danger" disabled={actions.busy} onClick={() => actions.ask(a, "remove")} className="px-2.5 py-1.5 text-[11.5px]">
                              Retirer le rôle
                            </Button>
                          </Can>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
      {data && <Pagination page={page} pageCount={pageCount} onPageChange={setPage} />}
      {actions.dialog}
    </section>
  );
}
