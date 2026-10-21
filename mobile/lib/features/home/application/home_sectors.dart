// Secteurs des puces de l'Accueil (GET /api/referentials/sectors/)
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/referentials/referential_models.dart';
import '../../../core/di/providers.dart';

/// Secteurs triés par ordre. Pas de nouvel essai automatique : l'Accueil reste utilisable
/// sans les puces (seul « Tous » s'affiche).
final homeSectorsProvider = FutureProvider.autoDispose<List<Sector>>((ref) async {
  final sectors = await ref.read(referentialRepositoryProvider).getSectors();
  return List.unmodifiable([...sectors]..sort((a, b) => a.order.compareTo(b.order)));
}, retry: (retryCount, error) => null);
