{{flutter_js}}
{{flutter_build_config}}

// Le service worker de Flutter est obsolète (la version 3.47 le désinscrit lui-même et recharge la
// page) : il n'est donc PAS enregistré ici. Le fonctionnement hors connexion est assuré par
// netbuis_sw.js, enregistré dans index.html.
_flutter.loader.load();
