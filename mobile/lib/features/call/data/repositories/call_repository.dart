// Contrat du dépôt d'appel : demande d'autorisation au serveur
import '../models/call_session.dart';

abstract class CallRepository {
  /// `POST /api/calls/initiate/` (canal `call`). [line] est la ligne choisie (null si inconnue).
  /// Lève `ApiException` : `serverCode` vaut NOT_AUTHENTICATED, ACCOUNT_BLOCKED,
  /// BUSINESS_NOT_ACTIVE, OWN_BUSINESS, RATE_LIMITED ou CHANNEL_UNAVAILABLE.
  Future<CallSession> initiate({required int businessId, CallLine? line});
}
