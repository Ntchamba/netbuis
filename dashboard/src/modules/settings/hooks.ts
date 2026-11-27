import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchSettings, updateSetting } from "./api";

export const SETTINGS_KEY = ["admin", "settings"] as const;

export function useSettings() {
  return useQuery({ queryKey: SETTINGS_KEY, queryFn: fetchSettings, retry: false });
}

export function useUpdateSetting() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ key, value }: { key: string; value: number }) => updateSetting(key, value),
    onSuccess: () => qc.invalidateQueries({ queryKey: SETTINGS_KEY }),
  });
}
