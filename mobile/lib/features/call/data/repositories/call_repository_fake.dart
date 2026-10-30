// Version factice (USE_FAKE_API) : une équipe qui répond après quelques secondes, sans réseau
// ni Jitsi réel. Aucun numéro de commerçant n'existe dans un appel à l'équipe ; le lien WhatsApp
// de démonstration est fictif (D-18).
import 'dart:async';

import '../models/call_feedback.dart';
import '../models/call_session.dart';
import 'call_repository.dart';

class CallRepositoryFake implements CallRepository {
  CallRepositoryFake({this.answerAfter = const Duration(seconds: 4)});

  /// Délai avant que l'équipe fictive réponde.
  final Duration answerAfter;
  int _next = 1;
  final Map<String, StreamController<CallStatus>> _streams = {};

  @override
  Future<CallStart> startSession({int? businessId}) async {
    final id = '00000000-0000-4000-8000-${(_next++).toString().padLeft(12, '0')}';
    final controller = StreamController<CallStatus>.broadcast();
    _streams[id] = controller;
    Timer(answerAfter, () {
      if (!controller.isClosed) {
        controller.add(CallStatus(sessionId: id, state: CallState.answered));
      }
    });
    return CallStart(
      sessionId: id,
      state: CallState.ringing,
      ringSeconds: 30,
      jitsi: const JitsiAccess(
          domain: 'jitsi.exemple.test', room: 'salle-de-demonstration', jwt: 'jeton-de-demonstration'),
    );
  }

  @override
  Future<CallStatus> status(String sessionId) async =>
      CallStatus(sessionId: sessionId, state: CallState.ringing);

  @override
  Stream<CallStatus> watch(String sessionId) =>
      _streams[sessionId]?.stream ?? const Stream.empty();

  Future<CallStatus> _finish(String sessionId, CallState state) async {
    final c = _streams.remove(sessionId);
    c?.add(CallStatus(sessionId: sessionId, state: state));
    unawaited(c?.close());
    return CallStatus(sessionId: sessionId, state: state);
  }

  @override
  Future<CallStatus> cancel(String sessionId) =>
      _finish(sessionId, CallState.cancelled);

  @override
  Future<CallStatus> end(String sessionId) => _finish(sessionId, CallState.ended);

  @override
  Future<void> warmUp() async {}

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
