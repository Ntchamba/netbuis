// État des tendances par zone : chargement, vide, erreur silencieuse, rafraîchissement
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/di/providers.dart';
import '../../onboarding/application/city_controller.dart';
import '../data/models/trend.dart';
import '../data/repositories/trends_repository.dart';
import '../data/repositories/trends_repository_api.dart';
import '../data/repositories/trends_repository_fake.dart';

/// Dépôt des tendances : factice si `USE_FAKE_API=true`, sinon relié à l'API.
final trendsRepositoryProvider = Provider<TrendsRepository>((ref) {
  if (Env.useFakeApi) return const TrendsRepositoryFake();
  return TrendsRepositoryApi(ref.read(dioProvider));
});

/// Tendances d'une zone ; `null` (aucune zone) = rien à afficher, sans appel au serveur.
///
/// Une erreur (réseau ou réponse inattendue) donne aussi [Trends.empty] : la bande est
/// masquée, sans message ni exception. Un succès reste en mémoire le temps de la session
/// (cache simple) ; une erreur n'est pas gardée, donc la prochaine lecture réessaie.
/// Rafraîchir : `ref.invalidate(trendsProvider(zone))`.
final trendsProvider = FutureProvider.autoDispose.family<Trends, int?>(
  (ref, zone) async {
    if (zone == null) return Trends.empty;
    try {
      final trends = await ref.read(trendsRepositoryProvider).getTrends(zone);
      if (ref.mounted) ref.keepAlive();
      return trends;
    } on Object {
      return Trends.empty;
    }
  },
  retry: (retryCount, error) => null,
);

/// Tendances de la ville choisie (null tant qu'elle n'est pas connue).
final cityTrendsProvider = Provider.autoDispose<AsyncValue<Trends>>((ref) {
  final city = ref.watch(selectedCityProvider);
  if (city.isLoading) return const AsyncLoading();
  return ref.watch(trendsProvider(city.value?.id));
});
