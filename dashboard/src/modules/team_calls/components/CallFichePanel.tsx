import type { ReactNode } from "react";
import { Badge, Button, Spinner, type BadgeStatus } from "../../../components/ui";
import { formatDate, formatDateTime } from "../../../lib/dates";
import { useCallContext } from "../hooks";
import type { BusinessCard } from "../types";

const STATUS: Record<string, { status: BadgeStatus; label: string }> = {
  actif: { status: "actif", label: "Actif" },
  en_attente_validation: { status: "en_attente", label: "En attente de validation" },
  rejete: { status: "rejete", label: "Rejeté" },
};

/** « +237 655 012 345 » ; tout autre format est affiché tel que le serveur l'a donné. */
export function formatPhone(phone: string): string {
  const m = /^\+237(\d{3})(\d{3})(\d{3})$/.exec(phone);
  return m ? `+237 ${m[1]} ${m[2]} ${m[3]}` : phone;
}

function Row({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex justify-between gap-3 py-1 text-[13px]">
      <dt className="shrink-0 text-ink-2">{label}</dt>
      <dd className="min-w-0 break-words text-right font-semibold">{children}</dd>
    </div>
  );
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="border-t border-line pt-3">
      <h3 className="mb-1 text-[11.5px] font-bold uppercase text-ink-2">{title}</h3>
      {children}
    </section>
  );
}

function Photo({ url, alt }: { url: string | null; alt: string }) {
  return url ? (
    <img src={url} alt={alt} loading="lazy" className="h-20 w-20 rounded-[10px] border border-line object-cover" />
  ) : (
    <span className="flex h-20 w-20 items-center justify-center rounded-[10px] border border-line bg-bg text-center text-[11px] text-ink-3">
      {alt} : non fournie
    </span>
  );
}

function Card({ b }: { b: BusinessCard }) {
  const status = STATUS[b.status] ?? { status: "neutre" as BadgeStatus, label: b.status };
  const place = [b.zone_name, b.zone_parent_name].filter(Boolean).join(", ");
  return (
    <>
      <Section title="Identité">
        <dl>
          <Row label="Nom">{b.name}</Row>
          <Row label="Type">{b.type_label}</Row>
          {b.owner_name && <Row label="Titulaire du compte">{b.owner_name}</Row>}
          {b.representant_nom && <Row label="Représentant">{b.representant_nom}</Row>}
          {b.forme_juridique && <Row label="Forme juridique">{b.forme_juridique}</Row>}
          {b.rccm && <Row label="RCCM">{b.rccm}</Row>}
          <Row label="Inscrit le">{formatDate(b.created_at)}</Row>
        </dl>
      </Section>
      <Section title="Activité">
        <dl>
          {b.category && <Row label="Catégorie">{b.category}</Row>}
          {b.sous_categories.length > 0 && <Row label="Sous-catégories">{b.sous_categories.join(", ")}</Row>}
          <Row label="Lieu">{place}</Row>
          {b.repere && <Row label="Repère">{b.repere}</Row>}
        </dl>
        {b.description && <p className="mt-2 whitespace-pre-line text-[13px] text-ink-2">{b.description}</p>}
      </Section>
      <Section title="Photos">
        <div className="flex gap-3">
          <Photo url={b.photo_url} alt="Photo du commerce" />
          <Photo url={b.representant_photo_url} alt="Photo du représentant" />
        </div>
      </Section>
      <Section title="Vérification et abonnement">
        <dl>
          <Row label="Statut">
            <Badge status={status.status}>{status.label}</Badge>
          </Row>
          <Row label="Pièce d'identité">{b.cni_verifiee ? "Vérifiée" : "Non vérifiée"}</Row>
          {b.motif_rejet && <Row label="Motif du rejet">{b.motif_rejet}</Row>}
          <Row label="Abonnement">
            {b.subscription.active ? `Abonné${b.subscription.end ? ` jusqu'au ${formatDate(b.subscription.end)}` : ""}` : "Non abonné"}
          </Row>
        </dl>
      </Section>
      <Section title="Signalements et activité">
        <dl>
          <Row label="Signalements">{b.reports_count}</Row>
          <Row label="Signalements WhatsApp">{b.whatsapp_reports_count}</Row>
          <Row label="Appels reçus">{b.calls_count}</Row>
          <Row label="Vues de la fiche">{b.views_count}</Row>
        </dl>
      </Section>
      <Section title="Historique">
        {b.history.length === 0 ? (
          <p className="text-[13px] text-ink-2">Aucun changement de statut.</p>
        ) : (
          <ul className="space-y-1 text-[13px]">
            {b.history.map((h, i) => (
              <li key={`${h.created_at}-${i}`}>
                <span className="font-semibold">{h.label}</span> · {formatDateTime(h.created_at)} · {h.admin_name}
                {h.reason && <span className="text-ink-2"> — {h.reason}</span>}
              </li>
            ))}
          </ul>
        )}
      </Section>
    </>
  );
}

interface Props {
  sessionId: string;
  onClose: () => void;
}

/**
 * Panneau latéral « Fiche du compte visé » : s'ouvre à côté de la salle sans la couper. Les numéros
 * (commerce et appelant) ne viennent que de la route de l'appel en cours ; ils restent en mémoire.
 */
export function CallFichePanel({ sessionId, onClose }: Props) {
  const query = useCallContext(sessionId, true);
  const data = query.data;
  return (
    <aside
      aria-label="Fiche du compte visé"
      data-testid="call-fiche"
      className="fixed inset-x-4 top-4 z-50 flex max-h-[45vh] flex-col overflow-hidden rounded-2xl border border-line bg-card text-ink shadow-2xl lg:inset-x-auto lg:bottom-4 lg:right-[calc(min(420px,100vw-2rem)+2rem)] lg:top-4 lg:max-h-none lg:w-[min(400px,calc(100vw-2rem))]"
    >
      <header className="flex items-center justify-between gap-3 border-b border-line px-4 py-3">
        <h2 className="truncate text-[15px] font-extrabold">{data?.business ? data.business.name : "Fiche du compte"}</h2>
        <Button variant="secondary" className="min-h-11 shrink-0" onClick={onClose}>
          Fermer la fiche
        </Button>
      </header>
      <div className="min-h-0 flex-1 space-y-3 overflow-y-auto px-4 py-3">
        {query.isPending && (
          <p role="status" className="flex items-center gap-2 text-[13px] text-ink-2">
            <Spinner size={16} /> Chargement de la fiche…
          </p>
        )}
        {query.isError && (
          <div role="alert" className="space-y-2">
            <p className="text-[13px] text-danger">Impossible de charger la fiche. L'appel continue.</p>
            <Button variant="secondary" className="min-h-11" onClick={() => void query.refetch()}>
              Réessayer
            </Button>
          </div>
        )}
        {data && (
          <>
            <section aria-label="Numéros de téléphone" className="rounded-xl border border-accent bg-bg p-3">
              <dl>
                {data.business && (
                  <Row label={`Numéro du ${data.business.kind === "particulier" ? "particulier" : "commerce"}`}>
                    <span data-testid="phone-business" className="text-[15px]">
                      {formatPhone(data.business.phone)}
                    </span>
                  </Row>
                )}
                <Row label={`Numéro de l'appelant (${data.caller.name})`}>
                  <span data-testid="phone-caller" className="text-[15px]">
                    {formatPhone(data.caller.phone)}
                  </span>
                </Row>
              </dl>
              <p className="mt-1 text-[11.5px] text-ink-3">Visibles par vous seul, pendant cet appel.</p>
            </section>
            {data.business ? <Card b={data.business} /> : <p className="text-[13px] text-ink-2">Cet appel n'est lié à aucun commerce.</p>}
          </>
        )}
      </div>
    </aside>
  );
}
