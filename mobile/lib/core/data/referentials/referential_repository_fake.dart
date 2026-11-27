// Version factice (USE_FAKE_API=true) : mêmes libellés que backend/apps/catalog/data/categories.json
import '../../network/api_exception.dart';
import 'referential_models.dart';
import 'referential_repository.dart';

class ReferentialRepositoryFake implements ReferentialRepository {
  const ReferentialRepositoryFake();

  @override
  Future<List<Sector>> getSectors() async => _sectors;

  @override
  Future<List<ReferentialItem>> getServiceCategories() async => _serviceCategories;

  @override
  Future<List<ReferentialItem>> getStructureTypes() async => _structureTypes;

  /// Le catalogue du serveur est vide pour l'instant : aucun produit n'est inventé.
  @override
  Future<List<CatalogProduct>> searchProducts(String query) async {
    final q = query.trim();
    if (q.isEmpty || q.length > maxProductQueryLength) {
      throw const ApiException(ApiErrorCode.invalid, statusCode: 400);
    }
    return const [];
  }
}

const List<Sector> _sectors = [
  Sector(
    item: ReferentialItem(id: 1, code: 'alimentation', name: 'Alimentation', icon: '🍌', order: 1),
    subcategories: [
      ReferentialItem(id: 1, code: 'fruits', name: 'Fruits', order: 1),
      ReferentialItem(id: 2, code: 'legumes', name: 'Légumes', order: 2),
      ReferentialItem(id: 3, code: 'tubercules', name: 'Tubercules', order: 3),
      ReferentialItem(id: 4, code: 'cereales_legumineuses', name: 'Céréales & Légumineuses', order: 4),
      ReferentialItem(id: 5, code: 'viande_volaille_poisson', name: 'Viande/Volaille & Poisson', order: 5),
      ReferentialItem(id: 6, code: 'produits_laitiers_oeufs', name: 'Produits laitiers & Œufs', order: 6),
      ReferentialItem(id: 7, code: 'huiles_graisses', name: 'Huiles & Graisses', order: 7),
      ReferentialItem(id: 8, code: 'epices_condiments', name: 'Épices & Condiments', order: 8),
      ReferentialItem(id: 9, code: 'boissons', name: 'Boissons', order: 9),
      ReferentialItem(id: 10, code: 'boulangerie_patisserie', name: 'Boulangerie & Pâtisserie', order: 10),
      ReferentialItem(id: 11, code: 'produits_surgeles', name: 'Produits surgelés', order: 11),
      ReferentialItem(id: 12, code: 'autre', name: 'Autre', order: 12),
    ],
  ),
  Sector(
    item: ReferentialItem(id: 2, code: 'boutique_superette', name: 'Boutique / Supérette', icon: '🏪', order: 2),
    subcategories: [
      ReferentialItem(id: 13, code: 'biscuits_confiseries', name: 'Biscuits & Confiseries', order: 1),
      ReferentialItem(id: 14, code: 'eau_boissons', name: 'Eau & Boissons', order: 2),
      ReferentialItem(id: 15, code: 'pates_riz_cereales_transformees', name: 'Pâtes/Riz & Céréales transformées', order: 3),
      ReferentialItem(id: 16, code: 'conserves', name: 'Conserves', order: 4),
      ReferentialItem(id: 17, code: 'produits_laitiers_emballes', name: 'Produits laitiers emballés', order: 5),
      ReferentialItem(id: 18, code: 'hygiene_entretien', name: 'Hygiène & Entretien', order: 6),
      ReferentialItem(id: 19, code: 'produits_bebes', name: 'Produits pour bébés', order: 7),
      ReferentialItem(id: 20, code: 'papeterie', name: 'Papeterie', order: 8),
      ReferentialItem(id: 21, code: 'autre', name: 'Autre', order: 9),
    ],
  ),
  Sector(
    item: ReferentialItem(id: 3, code: 'pharmacie_sante', name: 'Pharmacie & Santé', icon: '💊', order: 3),
    subcategories: [
      ReferentialItem(id: 22, code: 'autre', name: 'Autre', order: 1),
    ],
  ),
  Sector(
    item: ReferentialItem(id: 4, code: 'mode_beaute', name: 'Mode & Beauté', icon: '👗', order: 4),
    subcategories: [
      ReferentialItem(id: 23, code: 'autre', name: 'Autre', order: 1),
    ],
  ),
  Sector(
    item: ReferentialItem(id: 5, code: 'electronique_informatique', name: 'Électronique & Informatique', icon: '💻', order: 5),
    subcategories: [
      ReferentialItem(id: 24, code: 'autre', name: 'Autre', order: 1),
    ],
  ),
  Sector(
    item: ReferentialItem(id: 6, code: 'immobilier', name: 'Immobilier', icon: '🏠', order: 6),
    subcategories: [
      ReferentialItem(id: 25, code: 'autre', name: 'Autre', order: 1),
    ],
  ),
  Sector(
    item: ReferentialItem(id: 7, code: 'transport_livraison', name: 'Transport & Livraison', icon: '🛵', order: 7),
    subcategories: [
      ReferentialItem(id: 26, code: 'moto_taxi', name: 'Moto-taxi', order: 1),
      ReferentialItem(id: 27, code: 'taxi', name: 'Taxi', order: 2),
      ReferentialItem(id: 28, code: 'livraison_colis', name: 'Livraison de colis', order: 3),
      ReferentialItem(id: 29, code: 'transport_marchandises', name: 'Transport de marchandises', order: 4),
      ReferentialItem(id: 30, code: 'location_vehicule', name: 'Location de véhicule', order: 5),
      ReferentialItem(id: 31, code: 'demenagement', name: 'Déménagement', order: 6),
      ReferentialItem(id: 32, code: 'autre', name: 'Autre', order: 7),
    ],
  ),
  Sector(
    item: ReferentialItem(id: 8, code: 'agriculture_elevage', name: 'Agriculture & Élevage', icon: '🌾', order: 8),
    subcategories: [
      ReferentialItem(id: 33, code: 'autre', name: 'Autre', order: 1),
    ],
  ),
  Sector(
    item: ReferentialItem(id: 9, code: 'artisanat_services_domicile', name: 'Artisanat & Services à domicile', icon: '🔧', order: 9),
    subcategories: [
      ReferentialItem(id: 34, code: 'menuiserie', name: 'Menuiserie', order: 1),
      ReferentialItem(id: 35, code: 'plomberie', name: 'Plomberie', order: 2),
      ReferentialItem(id: 36, code: 'electricite', name: 'Électricité', order: 3),
      ReferentialItem(id: 37, code: 'couture', name: 'Couture', order: 4),
      ReferentialItem(id: 38, code: 'maconnerie', name: 'Maçonnerie', order: 5),
      ReferentialItem(id: 39, code: 'mecanique', name: 'Mécanique', order: 6),
      ReferentialItem(id: 40, code: 'informatique_reparation', name: 'Informatique & Réparation', order: 7),
      ReferentialItem(id: 41, code: 'coiffure_beaute', name: 'Coiffure & Beauté', order: 8),
      ReferentialItem(id: 42, code: 'autre', name: 'Autre', order: 9),
    ],
  ),
  Sector(
    item: ReferentialItem(id: 10, code: 'autre', name: 'Autre', icon: '✨', order: 10),
    subcategories: [
      ReferentialItem(id: 43, code: 'autre', name: 'Autre', order: 1),
    ],
  ),
];

const List<ReferentialItem> _serviceCategories = [
  ReferentialItem(id: 1, code: 'enseignement_domicile', name: 'Enseignement à domicile', icon: '', order: 1),
  ReferentialItem(id: 2, code: 'technique_reparation', name: 'Technique & Réparation', icon: '', order: 2),
  ReferentialItem(id: 3, code: 'services_medicaux_independants', name: 'Services médicaux indépendants', icon: '', order: 3),
  ReferentialItem(id: 4, code: 'beaute_bien_etre_domicile', name: 'Beauté & Bien-être à domicile', icon: '', order: 4),
  ReferentialItem(id: 5, code: 'juridique_comptabilite', name: 'Juridique & Comptabilité', icon: '', order: 5),
  ReferentialItem(id: 6, code: 'evenementiel', name: 'Événementiel', icon: '', order: 6),
  ReferentialItem(id: 7, code: 'autre', name: 'Autre', icon: '', order: 7),
];

const List<ReferentialItem> _structureTypes = [
  ReferentialItem(id: 1, code: 'supermarche', name: 'Supermarché', icon: '🛒', order: 1),
  ReferentialItem(id: 2, code: 'restaurant', name: 'Restaurant', icon: '🍲', order: 2),
  ReferentialItem(id: 3, code: 'hotel', name: 'Hôtel', icon: '🏨', order: 3),
  ReferentialItem(id: 4, code: 'sante', name: 'Centre de santé', icon: '🏥', order: 4),
  ReferentialItem(id: 5, code: 'autre', name: 'Autre', icon: '✨', order: 5),
];
