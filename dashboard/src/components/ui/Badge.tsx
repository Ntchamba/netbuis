import type { ReactNode } from "react";
import { cn } from "../../lib/cn";

/** Statuts de la maquette : actif (vert), en attente / bloqué (jaune), rejeté / supprimé (rouge), abonné (accent). */
export type BadgeStatus = "actif" | "en_attente" | "rejete" | "bloque" | "supprime" | "abonne" | "neutre";

const STYLES: Record<BadgeStatus, { cls: string; label: string }> = {
  actif: { cls: "bg-success-bg text-success", label: "Actif" },
  en_attente: { cls: "bg-warn-bg text-warn", label: "En attente" },
  rejete: { cls: "bg-danger-bg text-danger", label: "Rejeté" },
  bloque: { cls: "bg-warn-bg text-warn", label: "Bloqué" },
  supprime: { cls: "bg-danger-bg text-danger", label: "Supprimé" },
  abonne: { cls: "bg-accent text-on-accent", label: "Abonné" },
  neutre: { cls: "bg-card text-ink-2 border border-line", label: "" },
};

export function Badge({ status = "neutre", children }: { status?: BadgeStatus; children?: ReactNode }) {
  const s = STYLES[status];
  return (
    <span className={cn("inline-block rounded-full px-[10px] py-1 text-[11px] font-bold", s.cls)}>
      {children ?? s.label}
    </span>
  );
}
