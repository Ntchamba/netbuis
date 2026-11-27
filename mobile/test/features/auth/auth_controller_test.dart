import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/features/auth/application/auth_controller.dart';
import 'package:netbuis/features/auth/application/auth_state.dart';
import 'package:netbuis/features/auth/data/repositories/auth_repository_fake.dart';

import 'auth_test_helpers.dart';

final _now = DateTime.utc(2026, 1, 1, 12);

ProviderContainer _container(
    ScriptedRepository repo, MemoryTokenStorage storage) {
  final c = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      tokenStorageProvider.overrideWithValue(storage),
      authClockProvider.overrideWithValue(() => _now),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<AuthController> _ready(ProviderContainer c) async {
  c.listen(authControllerProvider, (prev, next) {});
  final controller = c.read(authControllerProvider.notifier);
  await controller.restoreSession();
  return controller;
}

AuthFailure _failure(ProviderContainer c) =>
    c.read(authControllerProvider) as AuthFailure;

void main() {
  late ScriptedRepository repo;
  late MemoryTokenStorage storage;
  setUp(() {
    repo = ScriptedRepository();
    storage = MemoryTokenStorage();
  });

  group('restauration de la session', () {
    test('démarre « en cours », puis non connecté si le stockage est vide',
        () async {
      final c = _container(repo, storage);
      c.listen(authControllerProvider, (prev, next) {});
      expect(c.read(authControllerProvider), isA<AuthLoading>());
      await c.read(authControllerProvider.notifier).restoreSession();
      expect(c.read(authControllerProvider), isA<AuthLoggedOut>());
    });

    test('connecté si un refresh est stocké', () async {
      storage = MemoryTokenStorage(access: 'a', refresh: 'r');
      final c = _container(repo, storage);
      await _ready(c);
      expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
    });

    test('un access seul (sans refresh) ne suffit pas', () async {
      storage = MemoryTokenStorage(access: 'a');
      final c = _container(repo, storage);
      await _ready(c);
      expect(c.read(authControllerProvider), isA<AuthLoggedOut>());
    });

    test('stockage illisible -> non connecté', () async {
      storage = MemoryTokenStorage(refresh: 'r')..throwOnRead = true;
      final c = _container(repo, storage);
      await _ready(c);
      expect(c.read(authControllerProvider), isA<AuthLoggedOut>());
    });
  });

  group('demande du code', () {
    test('succès : code envoyé avec validité et prochain renvoi', () async {
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      await ctrl.requestOtp('691234567');
      final s = c.read(authControllerProvider) as AuthCodeSent;
      expect(s.expiresIn, const Duration(seconds: 300));
      expect(s.expiresAt, _now.add(const Duration(seconds: 300)));
      expect(s.resendAvailableAt, _now.add(resendDelay));
    });

    test('passe par « en cours »', () async {
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      final seen = <Type>[];
      c.listen(authControllerProvider, (_, next) => seen.add(next.runtimeType));
      await ctrl.requestOtp('691234567');
      expect(seen, [AuthLoading, AuthCodeSent]);
    });

    test('numéro invalide -> erreur invalid_phone', () async {
      repo.requestError = const ApiException(ApiErrorCode.invalidPhone,
          message: 'Numéro invalide');
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      await ctrl.requestOtp('1');
      expect(_failure(c).code, ApiErrorCode.invalidPhone);
      expect(_failure(c).hasPendingCode, isFalse);
    });

    test('trop de demandes -> erreur avec durée d\'attente', () async {
      repo.requestError = const ApiException(ApiErrorCode.tooManyRequests,
          retryAfter: Duration(seconds: 90));
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      await ctrl.requestOtp('691234567');
      expect(_failure(c).code, ApiErrorCode.tooManyRequests);
      expect(_failure(c).retryAfter, const Duration(seconds: 90));
    });

    test('réseau coupé -> erreur network', () async {
      repo.requestError = const ApiException(ApiErrorCode.network);
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      await ctrl.requestOtp('691234567');
      expect(_failure(c).code, ApiErrorCode.network);
    });
  });

  group('vérification du code', () {
    test('succès : connecté, jetons dans le stockage sécurisé, is_new transmis',
        () async {
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      await ctrl.requestOtp('691234567');
      await ctrl.verifyOtp('123456');
      final s = c.read(authControllerProvider) as AuthAuthenticated;
      expect(s.isNew, isTrue);
      final stored = await storage.read();
      expect((stored.access, stored.refresh), ('acc-1', 'ref-1'));
    });

    test('sans demande préalable -> erreur, rien n\'est stocké', () async {
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      await ctrl.verifyOtp('123456');
      expect(_failure(c).code, ApiErrorCode.invalidPhone);
      expect((await storage.read()).hasRefresh, isFalse);
    });

    final cases = {
      'faux code': ApiErrorCode.otpInvalid,
      'code expiré': ApiErrorCode.otpExpired,
      'trop de demandes': ApiErrorCode.tooManyRequests,
      'compte bloqué': ApiErrorCode.accountBlocked,
      'compte supprimé': ApiErrorCode.accountDeleted,
      'réseau coupé': ApiErrorCode.network,
    };
    for (final entry in cases.entries) {
      test('${entry.key} -> erreur ${entry.value.value}, rien n\'est stocké',
          () async {
        final c = _container(repo, storage);
        final ctrl = await _ready(c);
        await ctrl.requestOtp('691234567');
        repo.verifyError = ApiException(entry.value);
        await ctrl.verifyOtp('000000');
        expect(_failure(c).code, entry.value);
        expect(_failure(c).hasPendingCode, isTrue);
        expect((await storage.read()).hasRefresh, isFalse);
      });
    }

    test('après un faux code on peut ressaisir le bon', () async {
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      await ctrl.requestOtp('691234567');
      repo.verifyError = const ApiException(ApiErrorCode.otpInvalid);
      await ctrl.verifyOtp('000000');
      repo.verifyError = null;
      await ctrl.verifyOtp('123456');
      expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
    });
  });

  group('rafraîchissement', () {
    test('le nouveau refresh remplace l\'ancien dans le stockage', () async {
      storage = MemoryTokenStorage(access: 'a', refresh: 'r');
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      expect(await ctrl.refreshSession(), isTrue);
      final stored = await storage.read();
      expect((stored.access, stored.refresh), ('acc-2', 'ref-2'));
    });

    test('jeton refusé -> jetons effacés, non connecté', () async {
      storage = MemoryTokenStorage(access: 'a', refresh: 'r');
      repo.refreshError = const ApiException(ApiErrorCode.tokenInvalid);
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      expect(await ctrl.refreshSession(), isFalse);
      expect(c.read(authControllerProvider), isA<AuthLoggedOut>());
      expect((await storage.read()).hasRefresh, isFalse);
    });

    test('compte bloqué -> jetons effacés et erreur account_blocked', () async {
      storage = MemoryTokenStorage(access: 'a', refresh: 'r');
      repo.refreshError = const ApiException(ApiErrorCode.accountBlocked);
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      expect(await ctrl.refreshSession(), isFalse);
      expect(_failure(c).code, ApiErrorCode.accountBlocked);
      expect((await storage.read()).hasRefresh, isFalse);
    });

    test('réseau coupé -> session et jetons conservés', () async {
      storage = MemoryTokenStorage(access: 'a', refresh: 'r');
      repo.refreshError = const ApiException(ApiErrorCode.network);
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      expect(await ctrl.refreshSession(), isTrue);
      expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
      expect((await storage.read()).refresh, 'r');
    });

    test('stockage vide -> non connecté, le serveur n\'est pas appelé',
        () async {
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      expect(await ctrl.refreshSession(), isFalse);
      expect(repo.refreshCalls, 0);
      expect(c.read(authControllerProvider), isA<AuthLoggedOut>());
    });
  });

  group('déconnexion', () {
    test('appelle logout avec le refresh puis efface le stockage', () async {
      storage = MemoryTokenStorage(access: 'a', refresh: 'r');
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      await ctrl.logout();
      expect(repo.logoutCalls, 1);
      expect(repo.lastLogoutToken, 'r');
      expect(c.read(authControllerProvider), isA<AuthLoggedOut>());
      final stored = await storage.read();
      expect((stored.access, stored.refresh), (null, null));
    });

    test('réseau coupé : les jetons locaux sont effacés quand même', () async {
      storage = MemoryTokenStorage(access: 'a', refresh: 'r');
      repo.logoutError = const ApiException(ApiErrorCode.network);
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      await ctrl.logout();
      expect(c.read(authControllerProvider), isA<AuthLoggedOut>());
      expect((await storage.read()).hasRefresh, isFalse);
    });

    test('stockage vide : pas d\'appel serveur, non connecté', () async {
      final c = _container(repo, storage);
      final ctrl = await _ready(c);
      await ctrl.logout();
      expect(repo.logoutCalls, 0);
      expect(c.read(authControllerProvider), isA<AuthLoggedOut>());
    });
  });

  test(
      'flux complet avec le dépôt factice : code 123456 connecte, autre code échoue',
      () async {
    final fake = AuthRepositoryFake();
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fake),
        tokenStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(c.dispose);
    final ctrl = await _ready(c);
    await ctrl.requestOtp('691234567');
    await ctrl.verifyOtp('654321');
    expect(_failure(c).code, ApiErrorCode.otpInvalid);
    await ctrl.verifyOtp('123456');
    expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
    expect((await storage.read()).hasRefresh, isTrue);
  });
}
