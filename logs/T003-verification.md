# T003 — Vérification (orchestrateur, reprise après coupure du PC)
1. `flutter pub get` OK — versions figées dans pubspec.yaml (logs/T003-versions.txt).
2. `flutter analyze` : No issues found (logs/T003-reprise-verif.txt).
3. `flutter test` : 1/1 vert (test/core/app_smoke_test.dart).
4. Pas d'émulateur : `flutter build apk --debug --dart-define=USE_FAKE_API=true` réussit (logs/T003-flutter-build-apk.txt, ~7 min, CMake 3.22.1 installé par Gradle).
5. scripts/verifier_tache.sh : OK (logs/T003-verifier_tache.txt).
Notes : SDK Android 36 + NDK 28.2 installés ; android/ exclu de l'analyse ; Linux desktop non configuré (inutile).
