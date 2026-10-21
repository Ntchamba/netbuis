// Version factice (USE_FAKE_API) : numéro de démonstration fictif (D-18), sans réseau
import '../models/call_session.dart';
import 'call_repository.dart';

class CallRepositoryFake implements CallRepository {
  int _next = 1;

  @override
  Future<CallSession> initiate({required int businessId, CallLine? line}) async =>
      CallSession(callId: _next++, phone: '+237600000001');
}
