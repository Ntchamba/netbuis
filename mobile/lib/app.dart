import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/l10n/l10n.dart';
import 'core/router/app_router.dart';
import 'core/router/routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/settings/application/settings_controller.dart';
import 'features/settings/application/speech_providers.dart';

/// Racine de l'application. La langue et le thème viennent des réglages (français et
/// « Automatique » tant que rien n'est choisi) ; [themeMode], s'il est donné, les remplace (tests).
class NetBuisApp extends ConsumerStatefulWidget {
  const NetBuisApp({
    super.key,
    this.themeMode,
    this.initialLocation = Routes.splash,
  });

  final ThemeMode? themeMode;

  /// Écran de départ (le lancement ; les tests peuvent partir d'ailleurs).
  final String initialLocation;

  @override
  ConsumerState<NetBuisApp> createState() => _NetBuisAppState();
}

class _NetBuisAppState extends ConsumerState<NetBuisApp> {
  late final GoRouter _router;
  final ValueNotifier<int> _authChanges = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _router = buildRouter(
      initialLocation: widget.initialLocation,
      readAuth: () => ref.read(authControllerProvider),
      refreshListenable: _authChanges,
    );
    // Chaque changement d'état de connexion relance les redirections (connecté → Accueil…).
    ref.listenManual(authControllerProvider, (previous, next) => _authChanges.value++);
  }

  @override
  void dispose() {
    _router.dispose();
    _authChanges.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    ref.watch(speechLanguageGuardProvider);
    return MaterialApp.router(
      title: 'NetBuis',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: widget.themeMode ?? settings.themeMode,
      locale: settings.locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
    );
  }
}
