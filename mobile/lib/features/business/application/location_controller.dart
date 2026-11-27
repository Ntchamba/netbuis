// Quartiers d'une ville (T034)
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/zones/zone.dart';
import '../../../core/di/providers.dart';

/// Quartiers actifs d'une ville (zones `quartier` dont le parent est [cityId]), toutes
/// les pages. Seul appel réseau du second temps : GET /api/zones/?level=quartier&parent=.
/// Pas de nouvel essai automatique : l'erreur s'affiche tout de suite avec « Réessayer ».
final districtsProvider = FutureProvider.autoDispose.family<List<Zone>, int>(
  (ref, cityId) async {
    final zones = await ref
        .read(zoneRepositoryProvider)
        .listZones(level: ZoneLevel.quartier, parent: cityId);
    // Garde-fou : le serveur filtre déjà, on ne propose jamais un autre niveau.
    return [
      for (final z in zones)
        if (z.level == ZoneLevel.quartier && z.parent == cityId) z
    ];
  },
  retry: (retryCount, error) => null,
);
