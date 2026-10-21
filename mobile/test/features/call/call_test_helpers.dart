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
import 'package:netbuis/features/call/data/models/call_feedback.dart';
import 'package:netbuis/features/call/data/models/call_session.dart';
import 'package:netbuis/features/call/data/repositories/call_repository.dart';
import 'package:netbuis/features/call/presentation/widgets/call_button.dart';

/// Lien WhatsApp FICTIF de test : il contient le numéro fictif, donc il ne doit apparaître nulle part.
const String kFakeWaUrl = 'https://wa.me/237600000042?text=Bonjour%20NetBuis';

/// Numéro FICTIF de test (D-18). Il ne doit apparaître nulle part dans l'arbre de widgets.
const String kFakePhone = '+237600000042';
const String kFakeDigits = '600000042';

const orangeSim = SimAccount(id: 'tel|orange', label: 'SIM 1', carrier: 'Orange CM');
const mtnSim = SimAccount(id: 'tel|mtn', label: 'SIM 2', carrier: 'MTN CAMEROON');
const otherSim = SimAccount(id: 'tel|other', label: 'SIM 2', carrier: 'Camtel');

/// Faux code natif : enregistre les appels reçus, aucun accès au téléphone.
class FakeCallChannel implements CallChannel {
  FakeCallChannel({this.sims = const [orangeSim, mtnSim]});

  CallPermissions perms = const CallPermissions(granted: true, asked: true);
  bool grantOnRequest = true;
  List<SimAccount> sims;
  PlaceCallResult placeResult = PlaceCallResult.placed;
  bool dialResult = true;
  bool throwOnPermissions = false;
  bool throwOnPlace = false;
  WhatsappOpenResult whatsappResult = WhatsappOpenResult.opened;
  bool throwOnWhatsapp = false;

  int requestCount = 0;
  final List<({String phone, String? accountId})> placed = [];
  final List<String> dialed = [];
  final List<String> whatsappOpened = [];

  @override
  Future<CallPermissions> permissions() async {
    if (throwOnPermissions) throw const CallChannelException();
    return perms;
  }

  @override
  Future<bool> requestPermissions() async {
    requestCount++;
    if (grantOnRequest) perms = const CallPermissions(granted: true, asked: true);
    return grantOnRequest;
  }

  @override
  Future<List<SimAccount>> listSims() async => sims;

  @override
  Future<PlaceCallResult> placeCall({required String phone, String? accountId}) async {
    if (throwOnPlace) throw const CallChannelException();
    placed.add((phone: phone, accountId: accountId));
    return placeResult;
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

/// Faux dépôt : garde seulement l'opérateur demandé ; peut refuser comme le serveur.
class FakeCallRepository implements CallRepository {
  ApiException? error;
  ApiException? feedbackError;
  ApiException? reportError;
  final List<({int businessId, CallLine? line})> requests = [];
  final List<int> whatsappRequests = [];
  final List<({int callId, CallOutcome outcome})> feedbacks = [];
  final List<int> reports = [];

  @override
  Future<CallSession> initiate({required int businessId, CallLine? line}) async {
    requests.add((businessId: businessId, line: line));
    final e = error;
    if (e != null) throw e;
    return const CallSession(callId: 7, phone: kFakePhone);
  }

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

List<Override> callOverrides(FakeCallChannel channel, FakeCallRepository repo,
        {TargetPlatform platform = TargetPlatform.android}) =>
    [
      callChannelProvider.overrideWithValue(channel),
      callRepositoryProvider.overrideWithValue(repo),
      callCloseDelayProvider.overrideWithValue(const Duration(seconds: 2)),
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
  TargetPlatform platform = TargetPlatform.android,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: callOverrides(channel, repo, platform: platform),
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

/// Laisse fermer la feuille (délai « Appel en cours… » dépassé).
Future<void> closeSheet(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 500));
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
