// Version factice (USE_FAKE_API) : numéro de démonstration fictif (D-18), sans réseau
import '../models/call_feedback.dart';
import '../models/call_session.dart';
import 'call_repository.dart';

class CallRepositoryFake implements CallRepository {
  int _next = 1;

  @override
  Future<CallSession> initiate({required int businessId, CallLine? line}) async =>
      CallSession(callId: _next++, phone: '+237600000001');

  @override
  Future<WhatsappLink> initiateWhatsapp({required int businessId}) async =>
      WhatsappLink(
          callId: _next++, url: 'https://wa.me/237600000001?text=Bonjour');

  @override
  Future<void> sendFeedback(
      {required int callId, required CallOutcome outcome}) async {}

  @override
  Future<void> reportNoWhatsapp({required int businessId}) async {}
}
