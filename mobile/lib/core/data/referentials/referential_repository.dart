import 'referential_models.dart';

/// Accès aux référentiels et au catalogue (public, sans connexion). Partagé par
/// la création de commerce et la recherche.
abstract class ReferentialRepository {
  /// Les secteurs avec leurs sous-catégories, triés par ordre.
  Future<List<Sector>> getSectors();

  /// Les catégories de service (prestataires).
  Future<List<ReferentialItem>> getServiceCategories();

  /// Les types de structure.
  Future<List<ReferentialItem>> getStructureTypes();

  /// Complétion du catalogue : 10 produits au plus. [query] vide ou de plus de
  /// 100 caractères : erreur `invalid` (comme le serveur, code 400).
  Future<List<CatalogProduct>> searchProducts(String query);
}

/// Longueur maximale d'une recherche de produit acceptée par le serveur.
const int maxProductQueryLength = 100;
