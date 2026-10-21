// État de la fiche publique : chargement / fiche / erreur / « fiche introuvable » (404)
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../data/models/public_business.dart';
import '../data/repositories/public_business_repository.dart';
import '../data/repositories/public_business_repository_api.dart';
import '../data/repositories/public_business_repository_fake.dart';

/// Dépôt de la fiche publique : factice si `USE_FAKE_API=true`, sinon relié à l'API.
final publicBusinessRepositoryProvider = Provider<PublicBusinessRepository>((ref) {
  if (Env.useFakeApi) return PublicBusinessRepositoryFake();
  return PublicBusinessRepositoryApi(ref.read(dioProvider));
});

/// La fiche du commerce [id] (`AsyncLoading` / `AsyncData` / `AsyncError` avec [ApiException]).
/// Recharger = `ref.invalidate(publicBusinessProvider(id))`.
final publicBusinessProvider =
    FutureProvider.autoDispose.family<PublicBusiness, int>((ref, id) async {
  try {
    return await ref.read(publicBusinessRepositoryProvider).get(id);
  } on ApiException {
    rethrow;
  } on Object {
    throw const ApiException(ApiErrorCode.unknown);
  }
}, retry: (retryCount, error) => null);

/// Vrai si l'erreur est le 404 du serveur (profil absent ou non actif).
bool isBusinessNotFound(Object error) => error is ApiException && error.statusCode == 404;
