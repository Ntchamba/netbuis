import { useQuery } from "@tanstack/react-query";
import { fetchTeamCalls } from "./api";
import { TEAM_CALLS_KEY } from "./CallsProvider";
import type { CallFilter } from "./types";

export function useTeamCalls(filter: CallFilter, mine: number | null, page: number) {
  return useQuery({
    queryKey: [...TEAM_CALLS_KEY, "list", filter, mine, page],
    queryFn: () => fetchTeamCalls(filter, mine, page),
    retry: false,
  });
}
