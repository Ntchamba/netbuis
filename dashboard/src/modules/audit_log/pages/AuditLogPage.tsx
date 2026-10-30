import { useEffect, useMemo, useState } from "react";
import { usePermissions } from "../../../auth/permissions";
import { Button, Input, Pagination, Select } from "../../../components/ui";
import { AuditTable } from "../components/AuditTable";
import { auditError } from "../errors";
import { useAdminOptions, useAudit } from "../hooks";
import { ACTION_LABELS, AUDIT_PAGE_SIZE, EMPTY_FILTERS, type AuditFilters } from "../types";
import { validateFilters } from "../validation";
import { isPageOutOfRange, usePageFallback } from "../../../lib/pagination";

const ACTION_OPTIONS = [
  { value: "", label: "Toutes les actions" },
  ...Object.entries(ACTION_LABELS)
    .map(([value, label]) => ({ value, label }))
    .sort((a, b) => a.label.localeCompare(b.label, "fr")),
];

/** Journal d'audit : lecture seule. Les filtres vivent dans l'état de la page (pas dans l'adresse). */
export function AuditLogPage() {
  const { can } = usePermissions();
  const canPickAdmin = can("peut_gerer_admins");
  const [draft, setDraft] = useState<AuditFilters>(EMPTY_FILTERS);
  const [page, setPage] = useState(1);
  const errors = useMemo(() => validateFilters(draft), [draft]);
  const valid = Object.keys(errors).length === 0;
  const admins = useAdminOptions(canPickAdmin);
  const query = useAudit({ ...draft, page }, valid);

  const set = (key: keyof AuditFilters, value: string) => {
    setDraft((d) => ({ ...d, [key]: value }));
    setPage(1);
  };

  const outOfRange = valid && isPageOutOfRange(query.error, page);
  const data = valid && !outOfRange ? query.data : undefined;
  const pageCount = data ? Math.max(1, Math.ceil(data.count / AUDIT_PAGE_SIZE)) : 1;
  usePageFallback({ page, setPage, outOfRange, count: data?.count, pageSize: AUDIT_PAGE_SIZE, empty: data ? data.results.length === 0 : false });

  const adminOptions = [{ value: "", label: "Tous les administrateurs" }, ...(admins.data ?? []).map((a) => ({ value: String(a.id), label: a.name }))];

  return (
    <section aria-label="Journal d'audit" className="flex flex-col gap-4 px-8 pb-7 pt-[18px]">
      <div className="flex flex-wrap items-start gap-3">
        {canPickAdmin && <Select label="Administrateur" value={draft.admin} options={adminOptions} onChange={(e) => set("admin", e.target.value)} />}
        <Select label="Action" value={draft.action} options={ACTION_OPTIONS} onChange={(e) => set("action", e.target.value)} />
        <Input label="Du" placeholder="AAAA-MM-JJ" inputMode="numeric" autoComplete="off" value={draft.from} error={errors.from} onChange={(e) => set("from", e.target.value.trim())} />
        <Input label="Au" placeholder="AAAA-MM-JJ" inputMode="numeric" autoComplete="off" value={draft.to} error={errors.to} onChange={(e) => set("to", e.target.value.trim())} />
        <div className="self-end">
          <Button
            variant="secondary"
            onClick={() => {
              setDraft(EMPTY_FILTERS);
              setPage(1);
            }}
          >
            Réinitialiser
          </Button>
        </div>
      </div>

      {valid && query.isError && !data && !outOfRange ? (
        <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center">
          <p className="text-[13px] text-danger">{auditError(query.error)}</p>
          <Button variant="secondary" onClick={() => void query.refetch()}>
            Réessayer
          </Button>
        </div>
      ) : valid ? (
        <AuditTable rows={data?.results ?? []} loading={query.isLoading} />
      ) : (
        <p role="status" className="py-6 text-center text-[13px] text-ink-2">
          Corrigez les filtres pour afficher le journal.
        </p>
      )}

      {data && <Pagination page={page} pageCount={pageCount} onPageChange={setPage} />}
    </section>
  );
}
