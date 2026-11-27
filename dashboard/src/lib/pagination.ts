import { useEffect } from "react";

/** Vrai si le serveur répond 404 pour une page > 1 (page hors limites : le total a diminué). */
export function isPageOutOfRange(error: unknown, page: number): boolean {
  return page > 1 && (error as { response?: { status?: number } } | null)?.response?.status === 404;
}

interface Fallback {
  page: number;
  setPage: (page: number) => void;
  /** Résultat de isPageOutOfRange pour la requête courante. */
  outOfRange: boolean;
  /** Total renvoyé par le serveur (données valides seulement). */
  count: number | undefined;
  pageSize: number;
  /** Page chargée mais vide. */
  empty: boolean;
}

/**
 * Recule à une page valide : page hors limites (404), total sous la page courante, page vide.
 * Chaque recul diminue la page : pas de boucle possible, une requête par recul au plus.
 */
export function usePageFallback({ page, setPage, outOfRange, count, pageSize, empty }: Fallback): void {
  useEffect(() => {
    if (page <= 1) return;
    if (outOfRange) {
      setPage(page - 1);
      return;
    }
    if (count === undefined) return;
    const last = Math.max(1, Math.ceil(count / pageSize));
    if (page > last) setPage(last);
    else if (empty) setPage(page - 1);
  }, [page, setPage, outOfRange, count, pageSize, empty]);
}
