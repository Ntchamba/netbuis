import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/app.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/core/storage/prefs.dart';
import 'package:netbuis/features/auth/application/auth_controller.dart';
import 'package:netbuis/features/auth/data/models/auth_tokens.dart';
import 'package:netbuis/features/auth/data/models/otp_request.dart';
import 'package:netbuis/features/auth/data/repositories/auth_repository.dart';
import 'package:netbuis/features/auth/presentation/widgets/otp_input.dart';

import 'auth_test_helpers.dart';

/// Dépôt scénarisé pour les écrans : les erreurs de la file sont levées une par une
/// (une file vide = succès). Garde les appels pour les vérifier.
class FlowRepository implements AuthRepository {
  final Queue<ApiException> requestErrors = Queue();
  final Queue<ApiException> verifyErrors = Queue();
  final List<String> requestedPhones = [];
  final List<String> verifiedCodes = [];

  @override
  Future<OtpRequest> requestOtp(String phone) async {
    requestedPhones.add(phone);
    if (requestErrors.isNotEmpty) throw requestErrors.removeFirst();
    return const OtpRequest(expiresIn: Duration(minutes: 5));
  }

  @override
  Future<AuthTokens> verifyOtp({required String phone, required String code}) async {
    verifiedCodes.add(code);
    if (verifyErrors.isNotEmpty) throw verifyErrors.removeFirst();
    // Compte existant : le parcours de première connexion (saisie du nom) a ses propres tests.
    return const AuthTokens(access: 'acc-1', refresh: 'ref-1');
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async =>
      const AuthTokens(access: 'acc-2', refresh: 'ref-2');

  @override
  Future<void> logout(String refreshToken) async {}
}

/// Source de SMS pilotée par le test.
class FakeSmsSource implements SmsCodeSource {
  final StreamController<String> _controller = StreamController<String>.broadcast();
  bool started = false;
  bool stopped = false;

  void receive(String sms) => _controller.add(sms);

  @override
  Stream<String> get codes => _controller.stream;

  @override
  Future<void> start() async => started = true;

  @override
  Future<void> stop() async => stopped = true;
}

class MemoryPrefs implements AppPrefs {
  /// Une ville est déjà choisie par défaut : ces tests ne portent pas sur ce choix.
  MemoryPrefs({this.seen = false, this.city = const SelectedCity(id: 16, name: 'Maroua')});

  bool seen;
  SelectedCity? city;

  @override
  Future<bool> isOnboardingSeen() async => seen;

  @override
  Future<void> markOnboardingSeen() async => seen = true;

  @override
  Future<SelectedCity?> getCity() async => city;

  @override
  Future<void> saveCity(SelectedCity value) async => city = value;
}

/// Lance l'application complète à 360 px de large, sans réseau ni disque.
Future<void> pumpAuthApp(
  WidgetTester tester, {
  required AuthRepository repository,
  FakeSmsSource? sms,
  String initialLocation = Routes.login,
  bool signedIn = false,
  bool onboardingSeen = true,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        tokenStorageProvider.overrideWithValue(
          MemoryTokenStorage(refresh: signedIn ? 'ref-1' : null),
        ),
        appPrefsProvider.overrideWithValue(MemoryPrefs(seen: onboardingSeen)),
        smsCodeSourceProvider.overrideWithValue(sms ?? FakeSmsSource()),
        // Horloge liée au temps simulé du test (le décompte avance avec pump).
        authClockProvider.overrideWith((ref) => () => tester.binding.clock.now()),
      ],
      child: NetBuisApp(themeMode: ThemeMode.dark, initialLocation: initialLocation),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get phoneField => find.byKey(const ValueKey('phone-field'));
Finder get otpField => find.byKey(const ValueKey('otp-field'));

/// Saisit le numéro et demande le code.
Future<void> submitPhone(WidgetTester tester, String digits) async {
  await tester.enterText(phoneField, digits);
  await tester.pump();
  await tester.tap(find.text('Recevoir le code'));
  await tester.pumpAndSettle();
}

/// Aucun défilement de l'écran n'est horizontal (le défilement interne d'un champ de texte
/// sur une seule ligne n'est pas un défilement de l'écran).
void expectNoHorizontalScroll(WidgetTester tester) {
  final scrollables = find.byType(Scrollable).evaluate().where(
        (e) => find.ancestor(of: find.byElementPredicate((x) => x == e), matching: find.byType(EditableText)).evaluate().isEmpty,
      );
  expect(scrollables, isNotEmpty);
  for (final e in scrollables) {
    expect((e.widget as Scrollable).axis, Axis.vertical);
  }
}
