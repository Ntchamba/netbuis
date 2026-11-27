// Thème clair/sombre appliqué avant l'affichage (évite un éclair). Fichier séparé pour qu'une CSP
// stricte (script-src 'self') puisse s'appliquer sans « unsafe-inline ».
try {
  document.documentElement.dataset.theme = localStorage.getItem("netbuis-theme") === "light" ? "light" : "dark";
} catch (e) {
  document.documentElement.dataset.theme = "dark";
}
