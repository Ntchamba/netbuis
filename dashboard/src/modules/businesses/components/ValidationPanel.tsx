import { Button, Modal } from "../../../components/ui";
import { Can } from "../../../auth/permissions";
import { safeImageUrl } from "../../../lib/safeUrl";
import { formatRelative } from "../../../lib/dates";
import type { DocumentState } from "../hooks";
import type { BusinessRequest, TypeCompte } from "../types";

const TYPE_LABELS: Record<TypeCompte, string> = {
  boutique: "Commerce",
  entreprise: "Entreprise",
  particulier_vendeur: "Particulier vendeur",
  prestataire_service: "Prestataire de service",
  structure: "Structure",
};

const FORME_LABELS: Record<string, string> = {
  individuelle: "Entreprise individuelle",
  sarl: "SARL",
  sarlu: "SARLU",
  sa: "SA",
  gic_cooperative: "GIC / Coopérative",
  association: "Association",
  etablissement_public: "Établissement public",
  autre: "Autre",
};

export type DocumentKind = "cni" | "diplome";

interface PanelProps {
  request: BusinessRequest;
  /** Vrai pendant l'envoi d'une décision : tous les boutons sont désactivés (pas de double clic). */
  busy: boolean;
  onApprove: (request: BusinessRequest) => void;
  onReject: (request: BusinessRequest) => void;
  onOpenDocument: (request: BusinessRequest, kind: DocumentKind) => void;
}

function Photo({ url: rawUrl, alt, fallback }: { url: string | null; alt: string; fallback: "person" | "image" }) {
  const url = safeImageUrl(rawUrl);
  return (
    <div className="flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden rounded-[10px] border border-line bg-bg">
      {url ? (
        <img src={url} alt={alt} loading="lazy" className="h-full w-full object-cover" />
      ) : (
        <svg role="img" aria-label={`${alt} : non fournie`} width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" className="text-ink-3">
          {fallback === "person" ? (
            <>
              <circle cx="12" cy="8" r="4" />
              <path d="M4 21c0-4 4-7 8-7s8 3 8 7" />
            </>
          ) : (
            <>
              <rect x="3" y="4" width="18" height="16" rx="2" />
              <path d="M3 15l5-5 4 4 5-6 4 5" />
              <circle cx="8" cy="8.5" r="1.4" />
            </>
          )}
        </svg>
      )}
    </div>
  );
}

/** Dossier d'une demande (carte de la maquette) : pièces, informations, Valider / Rejeter. */
export function ValidationPanel({ request: r, busy, onApprove, onReject, onOpenDocument }: PanelProps) {
  const isPrestataire = r.type_compte === "prestataire_service";
  const isRepresentant = r.type_compte === "entreprise" || r.type_compte === "structure";
  const categorie = r.categorie_service_name || r.categorie_service_libre;
  const details: Array<[string, string]> = [
    ["Type de compte", TYPE_LABELS[r.type_compte] ?? r.type_compte],
    ["Propriétaire", r.owner_name],
    ["Représentant", r.representant_nom],
    ["Forme juridique", r.forme_juridique ? (FORME_LABELS[r.forme_juridique] ?? r.forme_juridique) : ""],
    ["RCCM", r.rccm],
    ["Catégorie de service", categorie ?? ""],
    ["Repère", r.repere],
    ["Description", r.description],
  ].filter((d): d is [string, string] => d[1] !== "");

  return (
    <article aria-label={`Demande : ${r.name}`} className="flex gap-[18px] rounded-2xl border border-line bg-card px-5 py-[18px]">
      <div className="flex shrink-0 gap-2">
        <Photo url={r.representant_photo_url} alt={isRepresentant ? "Photo du représentant" : "Photo du propriétaire"} fallback="person" />
        <Photo url={r.photo_url} alt="Photo du commerce" fallback="image" />
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex items-center justify-between gap-3">
          <h2 className="truncate text-[15px] font-extrabold">{r.name}</h2>
          <span className="shrink-0 text-[12px] text-ink-3">{formatRelative(r.created_at)}</span>
        </div>
        <p className="mt-[3px] text-[12.5px] text-ink-2">
          {[r.phone_masked, r.zone_name].filter(Boolean).join(" · ")}
        </p>

        {details.length > 0 && (
          <dl className="mt-3 grid grid-cols-[max-content_1fr] gap-x-4 gap-y-1 text-[12.5px]">
            {details.map(([label, value]) => (
              <div key={label} className="contents">
                <dt className="text-ink-3">{label}</dt>
                <dd className="m-0 break-words text-ink">{value}</dd>
              </div>
            ))}
          </dl>
        )}

        {(isPrestataire || r.diplome_url) && (
          <div className="mt-3 flex flex-wrap items-center gap-2">
            {isPrestataire &&
              (r.cni_url ? (
                <Button variant="secondary" onClick={() => onOpenDocument(r, "cni")}>
                  Voir la CNI
                </Button>
              ) : (
                <span className="text-[12px] text-ink-3">CNI non disponible</span>
              ))}
            {r.diplome_url && (
              <Button variant="secondary" onClick={() => onOpenDocument(r, "diplome")}>
                Voir le diplôme
              </Button>
            )}
          </div>
        )}

        <Can permission="peut_valider_demande">
          <div className="mt-3 flex items-center gap-2.5">
            <Button variant="primary" disabled={busy} onClick={() => onApprove(r)}>
              Valider
            </Button>
            <Button variant="danger" disabled={busy} onClick={() => onReject(r)}>
              Rejeter
            </Button>
            <span className="text-[11.5px] text-ink-3">Un motif sera demandé en cas de rejet</span>
          </div>
        </Can>
      </div>
    </article>
  );
}

interface ViewerProps {
  kind: DocumentKind | null;
  state: DocumentState;
  onClose: () => void;
  /** Recharge la demande pour obtenir un nouveau lien. */
  onReload: () => void;
  reloading: boolean;
}

/** Pièce d'identité ouverte à la demande, dans une fenêtre. L'adresse du fichier n'apparaît jamais en texte. */
export function IdDocumentModal({ kind, state, onClose, onReload, reloading }: ViewerProps) {
  const title = kind === "diplome" ? "Diplôme" : "Carte nationale d'identité";
  return (
    <Modal
      open={state.status !== "closed"}
      title={title}
      onClose={onClose}
      footer={
        <>
          {state.status === "expired" && (
            <Button variant="primary" loading={reloading} onClick={onReload}>
              Actualiser la demande
            </Button>
          )}
          <Button variant="secondary" onClick={onClose}>
            Fermer
          </Button>
        </>
      }
    >
      {state.status === "loading" && (
        <p role="status" className="text-[13px] text-ink-2">
          Ouverture de la pièce…
        </p>
      )}
      {state.status === "ready" && <img src={state.blobUrl} alt={title} className="max-h-[70vh] w-full rounded-[10px] object-contain" />}
      {state.status === "expired" && (
        <p role="alert" className="text-[13px] text-danger">
          Ce lien a expiré (il dure 5 minutes). Actualisez la demande pour obtenir un nouveau lien, puis rouvrez la pièce.
        </p>
      )}
      {state.status === "error" && (
        <p role="alert" className="text-[13px] text-danger">
          Impossible d'ouvrir cette pièce pour le moment. Réessayez dans un instant.
        </p>
      )}
    </Modal>
  );
}
