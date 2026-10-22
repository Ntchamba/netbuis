// Contrat du dépôt d'appel : appel à l'équipe NetBuis (sessions Jitsi) et lien WhatsApp.
import 'dart:async';

import '../models/call_feedback.dart';
import '../models/call_session.dart';

abstract class CallRepository {
  /// `POST /api/calls/sessions/` : appelle l'équipe NetBuis. [businessId] est le commerce
  /// consulté (contexte seulement). Lève `ApiException` : `serverCode` vaut `jitsi_not_configured`,
  /// BUSINESS_NOT_ACTIVE, RATE_LIMITED, `account_blocked` ; [ActiveCallException] pour
  /// `call_already_active`.
  Future<CallStart> startSession({int? businessId});

  /// `GET /api/calls/sessions/{id}/` : état courant (repli quand le flux temps réel est coupé).
  Future<CallStatus> status(String sessionId);

  /// `GET /api/calls/sessions/{id}/events/` (flux SSE) : un [CallStatus] à chaque changement ;
  /// le flux se termine à l'état final. Une erreur de flux = repli sur [status].
  Stream<CallStatus> watch(String sessionId);

  /// `POST /api/calls/sessions/{id}/cancel/` : annuler avant la réponse de l'équipe.
  Future<CallStatus> cancel(String sessionId);

  /// `POST /api/calls/sessions/{id}/end/` : raccrocher un appel en cours.
  Future<CallStatus> end(String sessionId);

  /// Réchauffe la connexion réseau (poignée de main TLS) sans rien demander d'utile. Ne lève jamais.
  Future<void> warmUp();

  /// `POST /api/calls/whatsapp/` : le lien rendu contient le numéro du commerçant (voir
  /// [WhatsappLink]). Mêmes refus que l'appel, en majuscules (ACCOUNT_BLOCKED, OWN_BUSINESS,
  /// BUSINESS_NOT_ACTIVE, CHANNEL_UNAVAILABLE, RATE_LIMITED).
  Future<WhatsappLink> initiateWhatsapp({required int businessId});

  /// `POST /api/calls/{id}/feedback/` : « ça a abouti ? » (journal WhatsApp / anciens appels).
  Future<void> sendFeedback(
      {required int callId, required CallOutcome outcome});

  /// `POST /api/calls/whatsapp-report/` : « ce numéro n'a pas WhatsApp ». Le serveur exige
  /// d'avoir déjà reçu le lien WhatsApp de ce commerce (sinon 404).
  Future<void> reportNoWhatsapp({required int businessId});
}
