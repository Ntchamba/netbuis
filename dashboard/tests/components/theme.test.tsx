import { afterEach, beforeEach, expect, test, vi } from "vitest";
import { ThemeProvider } from "../../src/components/theme/ThemeProvider";
import { ThemeToggle } from "../../src/components/theme/ThemeToggle";
import { readTheme, THEME_KEY } from "../../src/lib/theme";
import { cleanup, click, render } from "./helpers";

beforeEach(() => {
  localStorage.clear();
  delete document.documentElement.dataset.theme;
});
afterEach(async () => {
  await cleanup();
  vi.restoreAllMocks();
});

test("sombre par défaut", async () => {
  await render(
    <ThemeProvider>
      <ThemeToggle />
    </ThemeProvider>,
  );
  expect(document.documentElement.dataset.theme).toBe("dark");
});

test("la bascule passe en clair, persiste, puis revient en sombre", async () => {
  const div = await render(
    <ThemeProvider>
      <ThemeToggle />
    </ThemeProvider>,
  );
  await click(div.querySelector('button[aria-label="Changer de thème"]'));
  expect(document.documentElement.dataset.theme).toBe("light");
  expect(localStorage.getItem(THEME_KEY)).toBe("light");
  await click(div.querySelector("button"));
  expect(document.documentElement.dataset.theme).toBe("dark");
});

test("le thème clair enregistré est restauré", async () => {
  localStorage.setItem(THEME_KEY, "light");
  await render(<ThemeProvider>x</ThemeProvider>);
  expect(document.documentElement.dataset.theme).toBe("light");
});

test("stockage inaccessible : sombre, sans planter", async () => {
  vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
    throw new Error("refusé");
  });
  vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
    throw new Error("refusé");
  });
  expect(readTheme()).toBe("dark");
  const div = await render(
    <ThemeProvider>
      <ThemeToggle />
    </ThemeProvider>,
  );
  await click(div.querySelector("button"));
  expect(document.documentElement.dataset.theme).toBe("light");
});
