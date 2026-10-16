import { act } from "react";
import { createRoot } from "react-dom/client";
import { afterEach, expect, test, vi } from "vitest";

async function renderApp(useMocks: string) {
  vi.stubEnv("VITE_USE_MOCKS", useMocks);
  vi.resetModules();
  const { default: App } = await import("../src/App");
  const div = document.createElement("div");
  await act(async () => createRoot(div).render(<App />));
  return div;
}

afterEach(() => vi.unstubAllEnvs());

test("affiche l'accueil et le bandeau du mode simulé", async () => {
  const div = await renderApp("true");
  expect(div.querySelector("h1")?.textContent).toBe("NetBuis — Administration");
  expect(div.querySelector('[role="status"]')?.textContent).toBe("Mode simulé : données factices");
});

test("sans mode simulé, aucun bandeau", async () => {
  const div = await renderApp("false");
  expect(div.querySelector("h1")).not.toBeNull();
  expect(div.querySelector('[role="status"]')).toBeNull();
});
