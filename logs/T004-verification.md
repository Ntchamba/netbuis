# T004 — Vérification orchestrateur
| Critère | ✔/✘ | Preuve |
|---|---|---|
| 1 Jetons | ✔ | app_colors.dart:16-38 = README + D-20 ; grep teal/2EC4B6 vide (T004-verif.txt) |
| 2 Barre 4 onglets | ✔ | app_scaffold.dart:29-37 ; fr.json Accueil/Carte/Forum/Profil = maquette Main ; test navigation |
| 3 Logo | ✔ | core/widgets/netbuis_logo.dart + test |
| 4 Rayons/graisse | ✔ | app_theme.dart (bouton 12/700/48, champ 14, carte 16) + test |
| 5 Tests | ✔ | flutter test 12/12, analyze 0 |
| 6 Description Accueil | ✔ | dans le rapport b1 (pas d'émulateur) |
verifier_tache.sh OK. Hors périmètre : aucun.
