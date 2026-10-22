import { useEffect, useRef, useState } from "react";
import { isAxiosError } from "axios";
import { Button, ConfirmDialog } from "../../../components/ui";
import { useToast } from "../../../components/ui/Toast";
import { flushPendingRevocations } from "../exportAccounts";
import { useExportAccounts } from "../hooks";

export function exportErrorMessage(error: unknown): string {
  if (isAxiosError(error)) {
    if (!error.response) return "Connexion impossible. Vérifiez votre réseau, puis réessayez.";
    if (error.response.status === 403) return "Droit insuffisant";
    if (error.response.status >= 500) return "Le service est indisponible pour le moment. Réessayez dans un instant.";
  }
  return "L'export n'a pas pu être téléchargé. Réessayez.";
}

/** Bouton « Exporter les comptes (CSV) » : confirmation, puis téléchargement authentifié. */
export function ExportAccountsButton() {
  const toast = useToast();
  const exporter = useExportAccounts();
  const [confirming, setConfirming] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [warning, setWarning] = useState(false);
  const inFlight = useRef(false);

  // Démontage : les blob URL encore en attente sont révoquées sans attendre.
  useEffect(() => flushPendingRevocations, []);

  function run() {
    if (inFlight.current) return;
    inFlight.current = true;
    setConfirming(false);
    setError(null);
    setWarning(false);
    exporter.mutate(undefined, {
      onSuccess: (outcome) => {
        if (outcome === "downloaded") toast.success("Export téléchargé");
        else setWarning(true);
      },
      onError: (e) => setError(exportErrorMessage(e)),
      onSettled: () => {
        inFlight.current = false;
      },
    });
  }

  return (
    <>
      <Button variant="secondary" loading={exporter.isPending} onClick={() => setConfirming(true)}>
        Exporter les comptes (CSV)
      </Button>
      <ConfirmDialog
        open={confirming}
        variant="primary"
        title="Exporter les comptes"
        message="L'export contient la liste des comptes avec numéros masqués. Chaque export est enregistré dans le journal d'audit."
        confirmLabel="Exporter"
        onConfirm={run}
        onCancel={() => setConfirming(false)}
      />
      {error && (
        <div role="alert" className="flex items-center gap-2 text-[12.5px] text-danger">
          <span>{error}</span>
          <Button variant="secondary" onClick={run}>
            Réessayer
          </Button>
        </div>
      )}
      {warning && (
        <p role="alert" className="text-[12.5px] text-danger">
          Fichier non téléchargé : il contient une colonne interdite (CNI, jeton ou mot de passe). Prévenez l'équipe technique.
        </p>
      )}
    </>
  );
}
