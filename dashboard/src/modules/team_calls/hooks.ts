import { useQuery } from "@tanstack/react-query";
import { fetchCallContext, fetchTeamCalls } from "./api";
import { TEAM_CALLS_KEY } from "./CallsProvider";
import type { CallFilter } from "./types";

export function useTeamCalls(filter: CallFilter, mine: number | null, page: number) {
  return useQuery({
    queryKey: [...TEAM_CALLS_KEY, "list", filter, mine, page],
    queryFn: () => fetchTeamCalls(filter, mine, page),
    retry: false,
  });
}

/**
 * Fiche de l'appel en cours. Les numéros ne restent qu'en mémoire, le temps de l'affichage :
 * `gcTime: 0` retire la réponse du cache dès que le panneau ou la salle se ferme, rien n'est
 * écrit dans le stockage du navigateur.
 */
export function useCallContext(sessionId: string, enabled: boolean) {
  return useQuery({
    queryKey: [...TEAM_CALLS_KEY, "context", sessionId],
    queryFn: () => fetchCallContext(sessionId),
    enabled,
    retry: false,
    gcTime: 0,
    staleTime: 0,
    refetchOnWindowFocus: false,
  });
}
