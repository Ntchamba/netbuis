import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/app.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/account/data/models/me.dart';
import 'package:netbuis/features/account/data/repositories/account_repository.dart';
import 'package:netbuis/features/auth/data/repositories/auth_repository.dart';

import '../auth/auth_test_helpers.dart';
import '../auth/login_test_helpers.dart';

/// Profil fictif au format du serveur (valeur factice, pas un vrai numéro).
Me meWith({String name = ''}) =>
    Me(id: 1, name: name, phoneMasked: '+237 6•• •• •• 12');

/// Dépôt scénarisé : [getError] / [patchErrors] sont levées (une file vide = succès).
class ScriptedAccountRepository implements AccountRepository {
  ScriptedAccountRepository({this.me});

  Me? me;
  ApiException? getError;
  final List<ApiException> patchErrors = [];
  final List<String> sentNames = [];
  int getCalls = 0;

  /// Erreur levée par `deleteAccount` (null = succès) et nombre d'appels.
  ApiException? deleteError;
  int deleteCalls = 0;

  @override
  Future<Me> getMe() async {
    getCalls++;
    final error = getError;
    if (error != null) throw error;
    return me ?? meWith();
  }

  @override
  Future<Me> updateName(String name) async {
    sentNames.add(name);
    if (patchErrors.isNotEmpty) throw patchErrors.removeAt(0);
    me = (me ?? meWith()).copyWith(name: name);
    return me!;
  }

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    final error = deleteError;
    if (error != null) throw error;
  }
}

/// Lance l'application complète à 360 px, connectée, sans réseau ni disque.
Future<void> pumpAccountApp(
  WidgetTester tester, {
  required ScriptedAccountRepository account,
  AuthRepository? auth,
  String initialLocation = Routes.profile,
  bool signedIn = true,
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.dark,
  MemoryTokenStorage? tokens,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountRepositoryProvider.overrideWithValue(account),
        authRepositoryProvider.overrideWithValue(auth ?? FlowRepository()),
        tokenStorageProvider.overrideWithValue(
            tokens ?? MemoryTokenStorage(refresh: signedIn ? 'ref-1' : null)),
        appPrefsProvider.overrideWithValue(MemoryPrefs(seen: true)),
        ...overrides,
      ],
      child: NetBuisApp(themeMode: mode, initialLocation: initialLocation),
    ),
  );
  await tester.pumpAndSettle();
}

bool onHome() => find.byType(NavigationDestination).evaluate().length == 4;
