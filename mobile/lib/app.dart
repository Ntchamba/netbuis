import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/l10n/l10n.dart';
import 'core/router/app_router.dart';
import 'core/router/routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';

/// Racine de l'application. Le thème suit le réglage du téléphone.
class NetBuisApp extends ConsumerStatefulWidget {
  const NetBuisApp({
    super.key,
    this.themeMode = ThemeMode.system,
    this.initialLocation = Routes.splash,
  });

  final ThemeMode themeMode;

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
    return MaterialApp.router(
      title: 'NetBuis',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: widget.themeMode,
      locale: const Locale('fr'),
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
