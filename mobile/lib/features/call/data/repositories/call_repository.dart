// Contrat du dépôt d'appel : demande d'autorisation au serveur
import '../models/call_feedback.dart';
import '../models/call_session.dart';

abstract class CallRepository {
  /// `POST /api/calls/initiate/` (canal `call`). [line] est la ligne choisie (null si inconnue).
  /// Lève `ApiException` : `serverCode` vaut NOT_AUTHENTICATED, ACCOUNT_BLOCKED,
  /// BUSINESS_NOT_ACTIVE, OWN_BUSINESS, RATE_LIMITED ou CHANNEL_UNAVAILABLE.
  Future<CallSession> initiate({required int businessId, CallLine? line});

  /// `POST /api/calls/initiate/` (canal `whatsapp`) : mêmes refus que l'appel. Le lien rendu
  /// contient le numéro du commerçant (voir [WhatsappLink]).
  Future<WhatsappLink> initiateWhatsapp({required int businessId});

  /// `POST /api/calls/{id}/feedback/` : « ça a abouti ? ». Le dernier choix est conservé.
  Future<void> sendFeedback(
      {required int callId, required CallOutcome outcome});

  /// `POST /api/calls/whatsapp-report/` : « ce numéro n'a pas WhatsApp ». Le serveur exige
  /// d'avoir déjà reçu le lien WhatsApp de ce commerce (sinon 404).
  Future<void> reportNoWhatsapp({required int businessId});
}
