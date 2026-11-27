import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/models/business.dart';

/// État du compte business du propriétaire (GET /api/business/me/), pour la carte du Profil.
/// Se recharge à chaque ouverture du Profil ; pas de nouvel essai automatique : l'erreur
/// s'affiche avec « Réessayer ».
final myBusinessProvider = FutureProvider.autoDispose<MyBusiness>(
  (ref) => ref.read(businessRepositoryProvider).getMine(),
  retry: (retryCount, error) => null,
);
