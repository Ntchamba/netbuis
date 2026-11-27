import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { changeAdminRole, createAdmin, fetchAdmins, removeAdminRole } from "./api";
import type { AdminRole } from "./types";

export const ADMINS_KEY = ["admin", "admins"] as const;

export function useAdmins(page: number) {
  return useQuery({ queryKey: [...ADMINS_KEY, "list", page], queryFn: () => fetchAdmins(page), retry: false });
}

export function useRefreshAdmins() {
  const qc = useQueryClient();
  return () => qc.invalidateQueries({ queryKey: ADMINS_KEY });
}

/**
 * Création. 🔒 La réponse contient le mot de passe temporaire : il ne vit que dans `mutation.data`
 * (jamais dans le cache des requêtes), la mutation est oubliée dès qu'elle n'est plus observée
 * (gcTime 0) et la page appelle `reset()` à la fermeture de la fenêtre. Le `onSuccess` ne renvoie
 * rien de la réponse.
 */
export function useCreateAdmin() {
  const refresh = useRefreshAdmins();
  return useMutation({
    mutationFn: createAdmin,
    gcTime: 0,
    onSuccess: () => {
      void refresh();
    },
  });
}

export function useChangeAdminRole() {
  const refresh = useRefreshAdmins();
  return useMutation({
    mutationFn: ({ id, role }: { id: number; role: AdminRole }) => changeAdminRole(id, role),
    onSuccess: () => refresh(),
  });
}

export function useRemoveAdminRole() {
  const refresh = useRefreshAdmins();
  return useMutation({
    mutationFn: ({ id, reason }: { id: number; reason: string }) => removeAdminRole(id, reason),
    onSuccess: () => refresh(),
  });
}
