import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/l10n/l10n.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/theme/app_theme.dart';
import 'package:netbuis/features/call/application/call_controller.dart';
import 'package:netbuis/features/call/data/call_channel.dart';
import 'package:netbuis/features/call/data/jitsi_service.dart';
import 'package:netbuis/features/call/data/models/call_feedback.dart';
import 'package:netbuis/features/call/data/models/call_session.dart';
import 'package:netbuis/features/call/data/repositories/call_repository.dart';
import 'package:netbuis/features/call/presentation/widgets/call_button.dart';

/// Lien WhatsApp FICTIF de test : il contient le numéro fictif, donc il ne doit apparaître nulle part.
const String kFakeWaUrl = 'https://wa.me/237600000042?text=Bonjour%20NetBuis';

/// Numéro FICTIF de test (D-18, présent seulement dans le lien WhatsApp). Il ne doit apparaître nulle part dans l'arbre de widgets.
const String kFakePhone = '+237600000042';
const String kFakeDigits = '600000042';

/// Faux code natif : enregistre les appels reçus, aucun accès au téléphone.
class FakeCallChannel implements CallChannel {
  MicPermission mic = const MicPermission(granted: true, asked: true);
  bool grantOnRequest = true;
  bool dialResult = true;
  bool throwOnMic = false;
  WhatsappOpenResult whatsappResult = WhatsappOpenResult.opened;
  bool throwOnWhatsapp = false;

  int requestCount = 0;
  final List<String> dialed = [];
  final List<String> whatsappOpened = [];

  @override
  Future<MicPermission> microphone() async {
    if (throwOnMic) throw const CallChannelException();
    return mic;
  }

  @override
  Future<bool> requestMicrophone() async {
    requestCount++;
    if (grantOnRequest) mic = const MicPermission(granted: true, asked: true);
    return grantOnRequest;
  }

  @override
  Future<bool> dial(String phone) async {
    dialed.add(phone);
    return dialResult;
  }

  @override
  Future<WhatsappOpenResult> openWhatsapp(String url) async {
    if (throwOnWhatsapp) throw const CallChannelException();
    whatsappOpened.add(url);
    return whatsappResult;
  }
}

/// Faux service Jitsi : aucune salle réelle. Enregistre ce qu'on lui demande.
class FakeJitsiService implements JitsiService {
  bool joinResult = true;
  final List<String> joinedDomains = [];
  int hangUps = 0;
  int minimizes = 0;
  final StreamController<JitsiEvent> _events = StreamController<JitsiEvent>.broadcast();

  @override
  Stream<JitsiEvent> get events => _events.stream;

  void emit(JitsiEvent e) => _events.add(e);

  @override
  Future<bool> join(JitsiAccess access) async {
    joinedDomains.add(access.domain);
    return joinResult;
  }

  @override
  Future<void> minimize() async => minimizes++;

  @override
  Future<void> hangUp() async => hangUps++;
}

/// Faux dépôt : peut refuser comme le serveur et pousse les états à la demande.
class FakeCallRepository implements CallRepository {
  ApiException? error;
  ApiException? feedbackError;
  ApiException? reportError;
  ApiException? cancelError;
  ApiException? statusError;
  CallStart? start;
  bool watchFails = false;
  CallState polledState = CallState.ringing;

  /// Commerces demandés à `startSession` (null = sans commerce).
  final List<int?> requests = [];
  final List<String> cancels = [];
  final List<String> ends = [];
  int warmUps = 0;
  int polls = 0;
  final List<int> whatsappRequests = [];
  final List<({int callId, CallOutcome outcome})> feedbacks = [];
  final List<int> reports = [];
  final StreamController<CallStatus> _watch = StreamController<CallStatus>.broadcast();

  void push(CallState state, {String reason = ''}) =>
      _watch.add(CallStatus(sessionId: kSessionId, state: state, reason: reason));

  Future<void> closeFlow() => _watch.close();

  @override
  Future<CallStart> startSession({int? businessId}) async {
    requests.add(businessId);
    final e = error;
    if (e != null) throw e;
    return start ??
        const CallStart(
          sessionId: kSessionId,
          state: CallState.ringing,
          ringSeconds: 30,
          jitsi: JitsiAccess(domain: 'jitsi.exemple.test', room: 'salle-secrete-de-test', jwt: 'jeton-secret-de-test'),
        );
  }

  @override
  Future<CallStatus> status(String sessionId) async {
    polls++;
    final e = statusError;
    if (e != null) throw e;
    return CallStatus(sessionId: sessionId, state: polledState);
  }

  @override
  Stream<CallStatus> watch(String sessionId) =>
      watchFails ? Stream.error(const ApiException(ApiErrorCode.network)) : _watch.stream;

  @override
  Future<CallStatus> cancel(String sessionId) async {
    cancels.add(sessionId);
    final e = cancelError;
    if (e != null) throw e;
    return CallStatus(sessionId: sessionId, state: CallState.cancelled);
  }

  @override
  Future<CallStatus> end(String sessionId) async {
    ends.add(sessionId);
    return CallStatus(sessionId: sessionId, state: CallState.ended);
  }

  @override
  Future<void> warmUp() async => warmUps++;

  @override
  Future<WhatsappLink> initiateWhatsapp({required int businessId}) async {
    whatsappRequests.add(businessId);
    final e = error;
    if (e != null) throw e;
    return const WhatsappLink(callId: 8, url: kFakeWaUrl);
  }

  @override
  Future<void> sendFeedback({required int callId, required CallOutcome outcome}) async {
    final e = feedbackError;
    if (e != null) throw e;
    feedbacks.add((callId: callId, outcome: outcome));
  }

  @override
  Future<void> reportNoWhatsapp({required int businessId}) async {
    final e = reportError;
    if (e != null) throw e;
    reports.add(businessId);
  }
}

const String kSessionId = '11111111-2222-4333-8444-555555555555';

List<Override> callOverrides(FakeCallChannel channel, FakeCallRepository repo,
        {TargetPlatform platform = TargetPlatform.android, FakeJitsiService? jitsi}) =>
    [
      callChannelProvider.overrideWithValue(channel),
      callRepositoryProvider.overrideWithValue(repo),
      jitsiServiceProvider.overrideWithValue(jitsi ?? FakeJitsiService()),
      callPlatformProvider.overrideWithValue(platform),
    ];

Widget testApp(Widget home) => MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('fr'),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

const Key kOpenCall = Key('open-call');

/// Écran minimal avec un bouton qui lance l'appel du commerce n° 5 « Chez Aminatou ».
Future<void> pumpCallHost(
  WidgetTester tester, {
  required FakeCallChannel channel,
  required FakeCallRepository repo,
  FakeJitsiService? jitsi,
  TargetPlatform platform = TargetPlatform.android,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: callOverrides(channel, repo, platform: platform, jitsi: jitsi),
    child: testApp(Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            key: kOpenCall,
            onPressed: () =>
                startCall(context, businessId: 5, businessName: 'Chez Aminatou'),
            child: const Text('Appeler'),
          ),
        ),
      ),
    )),
  ));
  await tester.pumpAndSettle();
}

/// Laisse passer les tâches asynchrones et l'animation de la feuille.
Future<void> settleSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await settleSheet(tester);
}

/// Ferme la feuille facultative « ça a abouti ? » sans répondre.
Future<void> dismissFeedback(WidgetTester tester) async {
  expect(find.byKey(const Key('feedback-sheet')), findsOneWidget);
  await tester.tap(find.byKey(const Key('feedback-later')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.byKey(const Key('feedback-sheet')), findsNothing);
}

/// Aucun texte de l'arbre de widgets (Text, RichText, étiquettes d'accessibilité,
/// info-bulles, champs) ne contient le numéro, sous aucune des écritures courantes.
void expectNoPhoneOnScreen(WidgetTester tester) {
  bool leaks(String? s) =>
      s != null &&
      (s.contains(kFakeDigits) ||
          s.contains('+237') ||
          s.contains('237 6') ||
          s.contains('wa.me'));
  for (final w in tester.allWidgets) {
    if (w is Text) {
      expect(leaks(w.data) || leaks(w.textSpan?.toPlainText()) || leaks(w.semanticsLabel), isFalse,
          reason: 'Text contient le numéro');
    } else if (w is RichText) {
      expect(leaks(w.text.toPlainText()), isFalse, reason: 'RichText contient le numéro');
    } else if (w is Semantics) {
      expect(leaks(w.properties.label) || leaks(w.properties.value) || leaks(w.properties.hint),
          isFalse,
          reason: 'Semantics contient le numéro');
    } else if (w is Tooltip) {
      expect(leaks(w.message), isFalse);
    } else if (w is EditableText) {
      expect(leaks(w.controller.text), isFalse);
    }
  }
}
