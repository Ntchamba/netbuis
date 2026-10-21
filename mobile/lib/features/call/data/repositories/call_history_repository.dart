// Contrat du dépôt de l'historique : GET /api/calls/history/
import '../models/call_history_entry.dart';

abstract class CallHistoryRepository {
  /// Page [page] (à partir de 1), 20 lignes. Lève `ApiException`.
  Future<CallHistoryPage> history({int page = 1});
}
