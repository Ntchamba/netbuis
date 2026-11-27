// Contrat du dépôt des tendances
import '../models/trend.dart';

abstract class TrendsRepository {
  /// GET GET /api/trends/ (paramètre zone = identifiant). Lève `ApiException` en cas d'erreur.
  Future<Trends> getTrends(int zone);
}
