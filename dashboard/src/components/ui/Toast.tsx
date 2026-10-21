import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { cn } from "../../lib/cn";

export type ToastKind = "success" | "error";

interface ToastItem {
  id: number;
  kind: ToastKind;
  message: string;
}

interface ToastApi {
  success: (message: string) => void;
  error: (message: string) => void;
}

const ToastContext = createContext<ToastApi | null>(null);

export const TOAST_DURATION_MS = 4000;

export function ToastProvider({ children, duration = TOAST_DURATION_MS }: { children: ReactNode; duration?: number }) {
  const [items, setItems] = useState<ToastItem[]>([]);
  const nextId = useRef(1);
  const timers = useRef(new Set<ReturnType<typeof setTimeout>>());

  const push = useCallback(
    (kind: ToastKind, message: string) => {
      const id = nextId.current++;
      setItems((cur) => [...cur, { id, kind, message }]);
      const t = setTimeout(() => {
        timers.current.delete(t);
        setItems((cur) => cur.filter((i) => i.id !== id));
      }, duration);
      timers.current.add(t);
    },
    [duration],
  );

  useEffect(() => {
    const all = timers.current;
    return () => all.forEach(clearTimeout);
  }, []);

  const api = useMemo<ToastApi>(
    () => ({ success: (m) => push("success", m), error: (m) => push("error", m) }),
    [push],
  );

  return (
    <ToastContext.Provider value={api}>
      {children}
      <div className="fixed bottom-4 right-4 z-[60] flex flex-col gap-2">
        {items.map((i) => (
          <div
            key={i.id}
            role={i.kind === "error" ? "alert" : "status"}
            className={cn(
              "rounded-xl px-4 py-3 text-[13px] font-bold",
              i.kind === "error" ? "bg-danger-bg text-danger" : "bg-success-bg text-success",
            )}
          >
            {i.kind === "error" ? "✕ " : "✓ "}
            {i.message}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastApi {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error("useToast doit être utilisé dans un ToastProvider");
  return ctx;
}
