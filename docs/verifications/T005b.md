# T005b — Vérification orchestrateur
| Critère | ✔/✘ | Preuve |
|---|---|---|
| 1 Champs, role supprimé | ✔ | user.py:19-24 ; migration 0002 (reporte role=admin → is_admin) |
| 2 Adaptations, grep role vide | ✔ | grep vide (T005b-verif.txt) ; manager, admin, fabriques |
| 3 Migration + tests createsuperuser | ✔ | makemigrations --check « No changes » ; tests createsuperuser clavier / refus en argument |
| 4 can_login() | ✔ | user.py:37-39 + 2 tests (accepté / refusé) |
ruff OK, pytest 37 passed, verifier_tache OK.
Suite : brancher can_login() sur l'admin Django (T007) ; champ langue (T008) ; IsMerchant supprimée → IsActiveBusinessOwner (T008).
