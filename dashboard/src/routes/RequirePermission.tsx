import type { ReactNode } from "react";
import { Can } from "../auth/permissions";

/** Garde d'une page : le serveur décide (refus par défaut). Le serveur reste de toute façon l'autorité. */
export function RequirePermission({ permission, children }: { permission: string; children: ReactNode }) {
  return (
    <Can
      permission={permission}
      fallback={
        <section className="p-8" role="alert">
          <h1 className="text-2xl font-semibold">Accès refusé</h1>
          <p className="mt-2 text-ink-2">Votre rôle ne permet pas d'ouvrir cette page.</p>
        </section>
      }
    >
      {children}
    </Can>
  );
}
