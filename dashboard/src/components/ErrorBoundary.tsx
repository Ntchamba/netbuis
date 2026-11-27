import { Component, type ErrorInfo, type ReactNode } from "react";

/**
 * Filet de sécurité de toute l'application : une erreur d'affichage montre un message sobre
 * (jamais le texte de l'erreur, qui pourrait contenir une donnée) au lieu d'une page blanche.
 * Rien n'est écrit dans la console.
 */
export class ErrorBoundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false };

  static getDerivedStateFromError(): { failed: boolean } {
    return { failed: true };
  }

  componentDidCatch(_error: Error, _info: ErrorInfo): void {
    // Volontairement vide : ni console, ni envoi du détail.
  }

  render() {
    if (!this.state.failed) return this.props.children;
    return (
      <main role="alert" className="flex min-h-screen flex-col items-center justify-center gap-4 bg-bg p-8 text-center text-ink">
        <h1 className="text-2xl font-semibold">Une erreur est survenue</h1>
        <p className="max-w-md text-ink-2">L'écran n'a pas pu s'afficher. Rechargez la page ; si le problème continue, prévenez l'équipe technique.</p>
        <button type="button" className="min-h-11 rounded-xl bg-accent px-5 py-2 font-bold text-on-accent" onClick={() => window.location.reload()}>
          Recharger la page
        </button>
      </main>
    );
  }
}
