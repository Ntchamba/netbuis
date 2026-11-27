// Version factice (USE_FAKE_API=true) : tendances réalistes, sans numéro
import '../models/trend.dart';
import 'trends_repository.dart';

class TrendsRepositoryFake implements TrendsRepository {
  const TrendsRepositoryFake();

  static const _products = [
    'Riz', 'Huile de palme', 'Paracétamol', 'Tomates', 'Charbon', 'Ciment', 'Tissu wax', 'Oignons',
  ];

  // Quartiers du faux référentiel de zones (17 Hardé, 18 Dougoï, 19 Domayo).
  static const _businesses = [
    ('Boutique Aminatou', 17, 'Hardé'),
    ('Pharmacie du Centre', 19, 'Domayo'),
    ('Couturier Ibrahim', 18, 'Dougoï'),
    ('Quincaillerie Bello', 17, 'Hardé'),
  ];

  @override
  Future<Trends> getTrends(int zone) async => Trends(
        zoneId: zone,
        zoneName: 'Maroua',
        computedAt: DateTime.utc(2026, 1, 1),
        periodDays: 7,
        products: [
          for (var i = 0; i < _products.length; i++)
            TrendProduct(id: i + 1, name: _products[i], rank: i + 1),
        ],
        businesses: [
          for (var i = 0; i < _businesses.length; i++)
            TrendBusiness(
              id: i + 1,
              name: _businesses[i].$1,
              zoneId: _businesses[i].$2,
              zoneName: _businesses[i].$3,
              rank: i + 1,
            ),
        ],
      );
}
