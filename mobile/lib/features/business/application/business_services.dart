import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/referentials/referential_models.dart';
import '../../../core/di/providers.dart';
import '../data/models/business_draft.dart';
import '../data/photo_service.dart';
import '../data/speech_service.dart';

/// Synthèse vocale du téléphone (remplaçable dans les tests).
final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = FlutterTtsSpeechService();
  ref.onDispose(service.stop);
  return service;
});

/// Appareil photo et galerie (remplaçable dans les tests).
final photoPickerProvider = Provider<PhotoPickerService>((ref) => ImagePickerPhotoService());

/// Les secteurs avec leurs sous-catégories, lus via le dépôt de référentiels (jamais en
/// dur), triés par `order`. Se recharge à chaque ouverture de l'écran Secteur.
final businessSectorsProvider = FutureProvider.autoDispose<List<Sector>>(
  (ref) async {
    final sectors = await ref.read(referentialRepositoryProvider).getSectors();
    return List.unmodifiable([...sectors]..sort((a, b) => a.order.compareTo(b.order)));
  },
  // Pas de nouvel essai automatique : l'erreur s'affiche avec « Réessayer ».
  retry: (retryCount, error) => null,
);

/// Nombre de sous-catégories permis sans abonnement ; `null` = illimité (compte abonné).
/// Vaut [freeSubcategoryLimit] tant qu'aucune route ne publie la valeur du serveur.
/// C'est ici que se branchera la réponse du serveur (`SUBSCRIPTION_REQUIRED`, T035).
final subcategoryLimitProvider = Provider<int?>((ref) => freeSubcategoryLimit);
