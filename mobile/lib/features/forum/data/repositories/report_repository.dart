// Contrat du dépôt des signalements (T093) : POST /api/reports/
import '../models/report.dart';

abstract class ReportRepository {
  /// Signale [id] (publication, commentaire ou commerce). Ne renvoie rien : le serveur ne dit
  /// jamais qui a signalé. Lève `ApiException` : 400 `own_content`, 404 `not_found`,
  /// 409 `already_reported`, réseau…
  Future<void> report(ReportTarget target, int id, ReportReason reason);
}
