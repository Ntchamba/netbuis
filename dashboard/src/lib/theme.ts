export type Theme = "dark" | "light";

export const THEME_KEY = "netbuis-theme";

/** Lit le thème enregistré ; sombre par défaut (et si le stockage est inaccessible). */
export function readTheme(): Theme {
  try {
    return localStorage.getItem(THEME_KEY) === "light" ? "light" : "dark";
  } catch {
    return "dark";
  }
}

export function saveTheme(theme: Theme): void {
  try {
    localStorage.setItem(THEME_KEY, theme);
  } catch {
    // stockage indisponible : le thème reste valable pour la session
  }
}

export function applyTheme(theme: Theme): void {
  document.documentElement.dataset.theme = theme;
}
