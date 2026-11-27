import { useCallback, useEffect, useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { approveRequest, fetchBusinessRequests, fetchPrivateFile, rejectRequest } from "./api";

export const REQUESTS_KEY = ["admin", "requests", "business"] as const;

export function useBusinessRequests(page: number) {
  return useQuery({ queryKey: [...REQUESTS_KEY, page], queryFn: () => fetchBusinessRequests(page), retry: false });
}

/** La file, la pastille de la barre latérale et la vue d'ensemble se mettent à jour. */
export function useInvalidateRequests() {
  const qc = useQueryClient();
  return useCallback(
    () =>
      Promise.all([
        qc.invalidateQueries({ queryKey: ["admin", "requests"] }),
        qc.invalidateQueries({ queryKey: ["admin", "stats"] }),
        qc.invalidateQueries({ queryKey: ["admin", "overview"] }),
      ]),
    [qc],
  );
}

export function useApproveRequest() {
  const invalidate = useInvalidateRequests();
  return useMutation({ mutationFn: (id: number) => approveRequest(id), onSuccess: () => invalidate() });
}

export function useRejectRequest() {
  const invalidate = useInvalidateRequests();
  return useMutation({
    mutationFn: ({ id, reason }: { id: number; reason: string }) => rejectRequest(id, reason),
    onSuccess: () => invalidate(),
  });
}

export type DocumentState =
  | { status: "closed" }
  | { status: "loading" }
  | { status: "ready"; blobUrl: string }
  | { status: "expired" }
  | { status: "error" };

/**
 * Ouverture d'une pièce d'identité À LA DEMANDE. Le fichier est téléchargé avec le jeton d'accès
 * puis affiché via une URL locale (blob) ; elle est révoquée à la fermeture, au démontage et à
 * chaque nouvelle ouverture. Rien n'est écrit dans le stockage du navigateur.
 */
export function useIdDocument() {
  const [state, setState] = useState<DocumentState>({ status: "closed" });
  const current = useRef<string | null>(null);
  const ticket = useRef(0);

  const revoke = useCallback(() => {
    if (current.current) {
      URL.revokeObjectURL(current.current);
      current.current = null;
    }
  }, []);

  const close = useCallback(() => {
    ticket.current += 1; // une réponse tardive est ignorée
    revoke();
    setState({ status: "closed" });
  }, [revoke]);

  const open = useCallback(
    async (signedUrl: string) => {
      const mine = ++ticket.current;
      revoke();
      setState({ status: "loading" });
      try {
        const blob = await fetchPrivateFile(signedUrl);
        if (mine !== ticket.current) return;
        const blobUrl = URL.createObjectURL(blob);
        current.current = blobUrl;
        setState({ status: "ready", blobUrl });
      } catch (err) {
        if (mine !== ticket.current) return;
        const status = (err as { response?: { status?: number } }).response?.status;
        setState({ status: status === 403 ? "expired" : "error" });
      }
    },
    [revoke],
  );

  useEffect(
    () => () => {
      ticket.current += 1;
      revoke();
    },
    [revoke],
  );

  return { state, open, close };
}
