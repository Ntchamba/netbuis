# T002 — vérification orchestrateur (2026-10-11)
| Critère | ✔/✘ | Preuve vue par l'orchestrateur |
|---|---|---|
| npm install réussit | ✔ | logs/T002-npm-install.txt (127 paquets, 0 vulnérabilité) |
| latest remplacés, lock présent | ✔ | `grep -c latest package.json` = 0 ; package-lock.json non ignoré |
| typecheck, test, build verts | ✔ | relancés : logs/T002-verif.txt, exit 0, 2 tests passés |
| npm run dev en mode simulé | ✔ | logs/T002-dev.txt (port 5180, 5173 occupé par un autre projet) |
| périmètre | ✔ | git status : seulement dashboard/ |
| verifier_tache.sh | ✔ | Contrôles automatiques : OK |
Réserve : Node 24.13 < 24.15 demandé par jsdom (avertissement EBADENGINE seulement).
