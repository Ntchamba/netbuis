import { Component, type ErrorInfo, type ReactNode } from "react";
import { Button } from "../../../components/ui";

interface Props {
  children: ReactNode;
  /** Raccrocher proprement l'appel en cours, s'il y en a un. */
  onAbort?: () => void;
}

/** Une erreur dans la fenêtre d'appel ne doit pas faire tomber le tableau de bord. */
export class CallErrorBoundary extends Component<Props, { failed: boolean }> {
  state = { failed: false };

  static getDerivedStateFromError(): { failed: boolean } {
    return { failed: true };
  }

  componentDidCatch(_error: Error, _info: ErrorInfo): void {
    // Rien dans la console : le message d'erreur pourrait contenir le nom d'une salle.
  }

  render() {
    if (!this.state.failed) return this.props.children;
    return (
      <div role="alert" className="fixed bottom-4 right-4 z-50 flex max-w-sm flex-col gap-3 rounded-2xl border border-danger bg-card p-5 text-ink">
        <p className="text-[13px] font-bold">La fenêtre d'appel a rencontré un problème.</p>
        <div className="flex gap-2">
          <Button
            className="min-h-11"
            onClick={() => {
              this.props.onAbort?.();
              this.setState({ failed: false });
            }}
          >
            Fermer l'appel
          </Button>
        </div>
      </div>
    );
  }
}
