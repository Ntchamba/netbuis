// Providers Riverpod globaux
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/auth_repository_api.dart';
import '../../features/auth/data/repositories/auth_repository_fake.dart';
import '../config/env.dart';
import '../network/dio_client.dart';
import '../storage/secure_storage.dart';

/// Stockage sécurisé des jetons.
final tokenStorageProvider =
    Provider<TokenStorage>((ref) => SecureTokenStorage());

/// Client HTTP unique.
final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  return buildDio(
      baseUrl: Env.apiUrl,
      readAccessToken: () async => (await storage.read()).access);
});

/// Dépôt de connexion : factice si `USE_FAKE_API=true`, sinon relié à l'API.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (Env.useFakeApi) return AuthRepositoryFake();
  return AuthRepositoryApi(ref.watch(dioProvider));
});
