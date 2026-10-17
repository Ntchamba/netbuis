// Choix et mémorisation de la ville
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/zones/zone.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/routes.dart';
import '../../../core/storage/prefs.dart';

/// Villes disponibles : les zones actives de niveau `ville_village`
/// (toutes les pages). Rechargé à chaque ouverture de l'écran. Pas de nouvel essai
/// automatique : l'erreur s'affiche tout de suite avec « Réessayer ».
final citiesProvider = FutureProvider.autoDispose<List<Zone>>(
  (ref) => ref.read(zoneRepositoryProvider).listZones(level: ZoneLevel.villeVillage),
  retry: (retryCount, error) => null,
);

/// Ville mémorisée (null tant qu'aucune n'est choisie). Préférences simples seulement.
final selectedCityProvider =
    AsyncNotifierProvider<SelectedCityController, SelectedCity?>(SelectedCityController.new);

class SelectedCityController extends AsyncNotifier<SelectedCity?> {
  @override
  Future<SelectedCity?> build() async {
    try {
      return await ref.read(appPrefsProvider).getCity();
    } on Object {
      // Préférence illisible : comme si aucune ville n'était choisie.
      return null;
    }
  }

  /// Mémorise la ville choisie. Si l'écriture échoue, le choix reste valable
  /// jusqu'à la fermeture de l'application.
  Future<void> select(Zone city) async {
    final selected = SelectedCity(id: city.id, name: city.name);
    state = AsyncData(selected);
    try {
      await ref.read(appPrefsProvider).saveCity(selected);
    } on Object {
      // Mémorisation impossible : la personne pourra rechoisir au prochain lancement.
    }
  }
}

/// Écran qui suit la Découverte (ou le lancement si elle est déjà vue) :
/// le choix de la ville tant qu'aucune n'est mémorisée, sinon l'Accueil
/// (la garde de connexion redirige ensuite vers la connexion si besoin).
Future<String> routeAfterDiscovery(AppPrefs prefs) async {
  try {
    if (await prefs.getCity() != null) return Routes.home;
  } on Object {
    // Préférence illisible : on redemande la ville.
  }
  return Routes.chooseCity;
}
