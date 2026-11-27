// Dépôt de tendances vide, pour les tests d'écran qui ne s'intéressent pas à la bande.
import 'package:netbuis/features/trends/data/models/trend.dart';
import 'package:netbuis/features/trends/data/repositories/trends_repository.dart';

class NoTrendsRepository implements TrendsRepository {
  const NoTrendsRepository();

  @override
  Future<Trends> getTrends(int zone) async => Trends.empty;
}
