// Providers Riverpod globaux
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/account/data/repositories/account_repository.dart';
import '../../features/account/data/repositories/account_repository_api.dart';
import '../../features/account/data/repositories/account_repository_fake.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/auth_repository_api.dart';
import '../../features/auth/data/repositories/auth_repository_fake.dart';
import '../../features/auth/application/session_refresher.dart';
import '../config/env.dart';
import '../data/referentials/referential_repository.dart';
import '../data/referentials/referential_repository_api.dart';
import '../data/referentials/referential_repository_fake.dart';
import '../data/zones/zone_repository.dart';
import '../data/zones/zone_repository_api.dart';
import '../data/zones/zone_repository_fake.dart';
import '../network/dio_client.dart';
import '../storage/prefs.dart';
import '../storage/secure_storage.dart';

/// Stockage sécurisé des jetons.
final tokenStorageProvider =
    Provider<TokenStorage>((ref) => SecureTokenStorage());

/// Renouvellement de session partagé (intercepteur Dio et AuthController).
/// Le dépôt est lu au moment de l'appel pour rester remplaçable.
final Provider<SessionRefresher> sessionRefresherProvider =
    Provider<SessionRefresher>((ref) {
  return SessionRefresher(
    storage: ref.watch(tokenStorageProvider),
    callRefresh: (token) => ref.read(authRepositoryProvider).refresh(token),
  );
});

/// Client HTTP unique.
final Provider<Dio> dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  final refresher = ref.watch(sessionRefresherProvider);
  return buildDio(
      baseUrl: Env.apiUrl,
      readAccessToken: () async => (await storage.read()).access,
      refreshSession: refresher.refresh);
});

/// Les dépôts lisent (et non surveillent) le client : le client dépend du
/// renouvellement, qui dépend du dépôt de connexion ; un `watch` ferait un cycle.
/// Dépôt de connexion : factice si `USE_FAKE_API=true`, sinon relié à l'API.
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
  if (Env.useFakeApi) return AuthRepositoryFake();
  return AuthRepositoryApi(ref.read(dioProvider));
});

/// Dépôt du profil : factice si `USE_FAKE_API=true`, sinon relié à l'API.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  if (Env.useFakeApi) return AccountRepositoryFake();
  return AccountRepositoryApi(ref.read(dioProvider));
});

/// Zones géographiques (partagé) : factice si `USE_FAKE_API=true`, sinon relié à l'API.
final zoneRepositoryProvider = Provider<ZoneRepository>((ref) {
  if (Env.useFakeApi) return ZoneRepositoryFake();
  return ZoneRepositoryApi(ref.read(dioProvider));
});

/// Référentiels et catalogue (partagé) : factice si `USE_FAKE_API=true`, sinon relié à l'API.
final referentialRepositoryProvider = Provider<ReferentialRepository>((ref) {
  if (Env.useFakeApi) return const ReferentialRepositoryFake();
  return ReferentialRepositoryApi(ref.read(dioProvider));
});

/// Préférences simples (Découverte déjà vue…), remplaçable dans les tests.
final appPrefsProvider = Provider<AppPrefs>((ref) => SharedAppPrefs());
