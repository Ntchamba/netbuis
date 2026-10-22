import { useRef, useState } from "react";
import { Button, ConfirmDialog, EmptyState, Pagination, Skeleton, useToast } from "../../../components/ui";
import { IdDocumentModal, ValidationPanel, type DocumentKind } from "../components/ValidationPanel";
import { useApproveRequest, useBusinessRequests, useIdDocument, useInvalidateRequests, useRejectRequest } from "../hooks";
import { REASON_MAX_LENGTH, REQUESTS_PAGE_SIZE, type BusinessRequest } from "../types";
import { isPageOutOfRange, usePageFallback } from "../../../lib/pagination";

/** Message clair selon l'erreur du serveur ; `refresh` : la file doit être rechargée. */
export function decisionError(err: unknown): { message: string; refresh: boolean } {
  const response = (err as { response?: { status?: number; data?: { code?: string } } }).response;
  if (!response) return { message: "Connexion impossible. Vérifiez le réseau, puis réessayez.", refresh: false };
  switch (response.status) {
    case 409:
      return { message: "Cette demande a déjà été traitée. La liste a été actualisée.", refresh: true };
    case 404:
      return { message: "Cette demande n'existe plus. La liste a été actualisée.", refresh: true };
    case 400:
      return response.data?.code === "reason_required"
        ? { message: "Le motif du rejet est obligatoire.", refresh: false }
        : { message: "La demande n'a pas pu être envoyée. Vérifiez les informations.", refresh: false };
    case 403:
      return { message: "Vous n'avez pas le droit de traiter cette demande.", refresh: false };
    default:
      return { message: "Une erreur est survenue. Réessayez dans un instant.", refresh: false };
  }
}

/** Demandes en attente : onglet « Comptes business » (l'onglet Équipe NetBuis viendra avec V01). */
export function BusinessesPage() {
  const toast = useToast();
  const [page, setPage] = useState(1);
  const query = useBusinessRequests(page);
  const approve = useApproveRequest();
  const reject = useRejectRequest();
  const invalidate = useInvalidateRequests();
  const doc = useIdDocument();
  const [rejecting, setRejecting] = useState<BusinessRequest | null>(null);
  const [docKind, setDocKind] = useState<DocumentKind | null>(null);
  const [reloading, setReloading] = useState(false);

  const outOfRange = isPageOutOfRange(query.error, page);
  const data = outOfRange ? undefined : query.data; // jamais de carte déjà traitée avec ses boutons
  const pageCount = data ? Math.max(1, Math.ceil(data.count / REQUESTS_PAGE_SIZE)) : 1;
  // Verrou immédiat (react-query signale « en cours » avec un léger retard) : pas de double envoi.
  const lock = useRef(false);
  const [sending, setSending] = useState(false);
  const busy = sending || approve.isPending || reject.isPending;
  const begin = () => {
    if (lock.current) return false;
    lock.current = true;
    setSending(true);
    return true;
  };
  const end = () => {
    lock.current = false;
    setSending(false);
  };

  // Dernière demande d'une page traitée (page vide ou 404) : retour à la dernière page valide.
  usePageFallback({ page, setPage, outOfRange, count: data?.count, pageSize: REQUESTS_PAGE_SIZE, empty: data ? data.results.length === 0 : false });

  const onApprove = (r: BusinessRequest) => {
    if (!begin()) return;
    approve.mutate(r.id, {
      onSettled: end,
      onSuccess: () => toast.success("Compte validé — actif sur NetBuis"),
      onError: (err) => {
        const e = decisionError(err);
        toast.error(e.message);
        if (e.refresh) void invalidate();
      },
    });
  };

  const onRejectConfirm = (reason?: string) => {
    if (!rejecting) return;
    const text = (reason ?? "").trim();
    if (text === "") {
      toast.error("Le motif du rejet est obligatoire.");
      return;
    }
    if (text.length > REASON_MAX_LENGTH) {
      toast.error(`Le motif est trop long (${REASON_MAX_LENGTH} caractères au plus).`);
      return;
    }
    if (!begin()) return;
    reject.mutate(
      { id: rejecting.id, reason: text },
      {
        onSettled: end,
        onSuccess: () => {
          setRejecting(null);
          toast.error("Demande rejetée");
        },
        onError: (err) => {
          const e = decisionError(err);
          toast.error(e.message);
          if (e.refresh) {
            setRejecting(null);
            void invalidate();
          }
        },
      },
    );
  };

  const onOpenDocument = (r: BusinessRequest, kind: DocumentKind) => {
    const url = kind === "cni" ? r.cni_url : r.diplome_url;
    if (!url) return;
    setDocKind(kind);
    void doc.open(url);
  };

  const onReload = async () => {
    setReloading(true);
    try {
      await query.refetch();
      doc.close(); // l'administrateur rouvre la pièce avec le nouveau lien
    } finally {
      setReloading(false);
    }
  };

  return (
    <section aria-label="Demandes" className="flex flex-col gap-3.5 px-8 pb-7 pt-[18px]">
      <div role="tablist" aria-label="Type de demande" className="inline-flex self-start rounded-xl border border-line bg-card p-[3px]">
        <button role="tab" aria-selected="true" type="button" className="rounded-[9px] bg-accent px-[18px] py-[9px] text-[13px] font-bold text-on-accent">
          Comptes business ({data ? data.count : "…"})
        </button>
      </div>

      {query.isLoading && (
        <div aria-busy="true" className="flex flex-col gap-3.5" data-testid="requests-skeleton">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} className="h-[110px] w-full rounded-2xl" />
          ))}
        </div>
      )}

      {query.isError && !data && !outOfRange && (
        <div role="alert" className="flex flex-col items-center gap-3 py-8 text-center">
          <p className="text-[13px] text-danger">Impossible de charger les demandes.</p>
          <Button variant="secondary" onClick={() => void query.refetch()}>
            Réessayer
          </Button>
        </div>
      )}

      {data && data.results.length === 0 && page === 1 && <EmptyState title="Aucune demande en attente" />}

      {data?.results.map((r) => (
        <ValidationPanel key={r.id} request={r} busy={busy} onApprove={onApprove} onReject={setRejecting} onOpenDocument={onOpenDocument} />
      ))}

      {data && <Pagination page={page} pageCount={pageCount} onPageChange={setPage} />}

      <ConfirmDialog
        open={rejecting !== null}
        title="Rejeter la demande"
        message={rejecting ? `Le commerçant lira ce motif. Demande : ${rejecting.name}.` : undefined}
        confirmLabel="Rejeter"
        variant="danger"
        reasonLabel="Motif du rejet"
        loading={busy}
        onConfirm={onRejectConfirm}
        onCancel={() => {
          if (!busy) setRejecting(null);
        }}
      />

      <IdDocumentModal kind={docKind} state={doc.state} onClose={doc.close} onReload={() => void onReload()} reloading={reloading} />
    </section>
  );
}
