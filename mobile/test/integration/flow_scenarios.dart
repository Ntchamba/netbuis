// T056 : parcours de bout en bout Accueil → recherche → fiche → appel → retour → historique.
// Ces scénarios montent l'application COMPLÈTE (routeur, onglets) avec des faux services
// (aucun réseau, aucun téléphone). Ils sont partagés par :
//  - test/integration/search_call_flow_test.dart  (lancé par `flutter test`) ;
//  - integration_test/search_call_flow_test.dart  (lancé sur appareil / émulateur).
// Numéros : seul le numéro fictif réservé de call_test_helpers (+237 600000042) existe ici.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:netbuis/features/trends/application/trends_controller.dart';
import '../features/home/no_trends.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:netbuis/app.dart';
import 'package:netbuis/core/data/referentials/referential_repository_fake.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/account/data/models/me.dart';
import 'package:netbuis/features/business/application/public_business_controller.dart';
import 'package:netbuis/features/business/data/repositories/public_business_repository_fake.dart';
import 'package:netbuis/features/business/presentation/screens/business_detail_screen.dart';
import 'package:netbuis/features/call/application/call_history_controller.dart';
import 'package:netbuis/features/call/data/models/call_feedback.dart';
import 'package:netbuis/features/call/data/models/call_history_entry.dart';
import 'package:netbuis/features/call/data/models/call_session.dart';
import 'package:netbuis/features/call/data/repositories/call_history_repository.dart';
import 'package:netbuis/features/home/data/share_service.dart';
import 'package:netbuis/features/search/application/offline_controller.dart';
import 'package:netbuis/features/search/application/search_controller.dart';
import 'package:netbuis/features/search/data/models/search_query.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';
import 'package:netbuis/features/search/data/repositories/search_repository_fake.dart';
import 'package:netbuis/features/search/data/search_cache.dart';
import 'package:netbuis/features/search/voice_search/data/speech_service.dart';

import '../features/account/account_test_helpers.dart';
import '../features/auth/auth_test_helpers.dart';
import '../features/auth/login_test_helpers.dart';
import '../features/call/call_test_helpers.dart';

const _results = [
  SearchResult(
      id: 1, name: 'Boutique Aminatou', kind: 'produit', secteur: 'Alimentation',
      secteurCode: 'alimentation', zone: ResultZone(id: 17, name: 'Hardé'),
      repere: 'Près du marché', descriptionActivite: 'Riz, huile et condiments'),
  SearchResult(
      id: 2, name: 'Chez Mama Riz', kind: 'service', secteur: 'Restaurant',
      zone: ResultZone(id: 18, name: 'Dougoï'), descriptionActivite: 'Cuisine camerounaise',
      whatsappAvailable: false),
];

/// Faux service de reconnaissance vocale : le test décide de ce que « dit » l'utilisateur.
class FlowSpeech implements SpeechService {
  void Function(String, bool)? _onResult;
  bool listening = false;

  @override
  Future<SpeechAvailability> prepare() async => SpeechAvailability.ready;

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required void Function(SpeechFailure failure) onError,
    required void Function() onDone,
  }) async {
    listening = true;
    _onResult = onResult;
  }

  @override
  Future<void> stop() async => listening = false;

  @override
  Future<void> cancel() async => listening = false;

  void say(String words) => _onResult?.call(words, true);
}

/// Recherche factice qui peut tomber en panne réseau et note les recherches vocales.
class FlowSearch extends SearchRepositoryFake {
  FlowSearch() : super(data: _results);

  ApiException? error;
  final List<String> voiceCalls = [];

  @override
  Future<SearchPage> search(SearchQuery query, {int page = 1}) async {
    final e = error;
    if (e != null) throw e;
    return super.search(query, page: page);
  }

  @override
  Future<SearchPage> voiceSearch(String text, {int? zone, String? sector, int page = 1}) {
    voiceCalls.add(text);
    return super.voiceSearch(text, zone: zone, sector: sector, page: page);
  }
}

/// Historique relié aux faux appels : tout appel ou WhatsApp lancé y apparaît (le serveur réel
/// fait la même chose côté base).
class FlowHistory implements CallHistoryRepository {
  FlowHistory(this.calls);

  final FakeCallRepository calls;

  static const _names = {1: 'Boutique Aminatou', 2: 'Chez Mama Riz'};

  @override
  Future<CallHistoryPage> history({int page = 1}) async {
    final all = <CallHistoryEntry>[
      for (final w in calls.whatsappRequests.reversed)
        CallHistoryEntry(
            id: 500 + w, businessId: w, businessName: _names[w] ?? 'Commerce',
            zone: 'Hardé', date: DateTime(2026, 10, 21, 11), type: HistoryType.whatsapp),
      for (var i = calls.requests.length - 1; i >= 0; i--)
        CallHistoryEntry(
            id: 100 + i, businessId: calls.requests[i].businessId,
            businessName: _names[calls.requests[i].businessId] ?? 'Commerce',
            zone: 'Hardé', date: DateTime(2026, 10, 21, 10), type: HistoryType.call),
    ];
    return CallHistoryPage(count: all.length, hasNext: false, results: all);
  }
}

/// Tout ce qu'un parcours a besoin d'observer.
class FlowEnv {
  FlowEnv() {
    calls = FakeCallRepository();
    history = FlowHistory(calls);
  }

  final channel = FakeCallChannel();
  final speech = FlowSpeech();
  final search = FlowSearch();
  final cache = MemorySearchCache();
  late final FakeCallRepository calls;
  late final FlowHistory history;
}

/// Monte l'application complète à 360 px, connectée, sur l'Accueil.
Future<void> pumpFlowApp(WidgetTester tester, FlowEnv env) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final List<Override> overrides = [
    appPrefsProvider.overrideWithValue(MemoryPrefs(seen: true)),
    tokenStorageProvider.overrideWithValue(MemoryTokenStorage(refresh: 'ref-1')),
    authRepositoryProvider.overrideWithValue(FlowRepository()),
    accountRepositoryProvider.overrideWithValue(ScriptedAccountRepository(
        me: const Me(id: 1, name: 'Jeff N.', phoneMasked: '6•• •• •• 12'))),
    referentialRepositoryProvider.overrideWithValue(const ReferentialRepositoryFake()),
    searchRepositoryProvider.overrideWithValue(env.search),
    searchCacheProvider.overrideWithValue(env.cache),
    trendsRepositoryProvider.overrideWithValue(const NoTrendsRepository()),
    speechServiceProvider.overrideWithValue(env.speech),
    shareServiceProvider.overrideWithValue(_NoShare()),
    publicBusinessRepositoryProvider.overrideWithValue(PublicBusinessRepositoryFake()),
    callHistoryRepositoryProvider.overrideWithValue(env.history),
    historyNowProvider.overrideWithValue(() => DateTime(2026, 10, 21, 12)),
    ...callOverrides(env.channel, env.calls),
  ];
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: const NetBuisApp(themeMode: ThemeMode.light, initialLocation: Routes.home),
  ));
  await tester.pumpAndSettle();
}

class _NoShare implements ShareService {
  @override
  Future<void> shareText(String text) async {}
}

// ---------------------------------------------------------------- petites étapes

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

/// Revient d'un écran poussé (fiche, recherche, historique).
Future<void> _back(WidgetTester tester, Finder screen) async {
  GoRouter.of(tester.element(screen)).pop();
  await _settle(tester);
}

Future<void> _openTab(WidgetTester tester, int index) async {
  await tester.tap(find.byType(NavigationDestination).at(index));
  await _settle(tester);
}

Future<void> _openDetailFromCard(WidgetTester tester, String name) async {
  await tester.tap(find.text(name).first);
  await _settle(tester);
  expect(find.byType(BusinessDetailScreen), findsOneWidget);
  expectNoPhoneOnScreen(tester);
}

/// Fiche → Appeler → feuille Orange/MTN → ligne choisie → « Appel en cours » → fermeture.
Future<void> _callFromDetail(WidgetTester tester, FlowEnv env, {required bool orange}) async {
  await tester.scrollUntilVisible(find.byKey(const Key('detail-call')), 300,
      scrollable: find.byType(Scrollable).first);
  await tapAndSettle(tester, find.byKey(const Key('detail-call')));
  await _chooseLineAndClose(tester, env, orange: orange);
}

Future<void> _chooseLineAndClose(WidgetTester tester, FlowEnv env,
    {required bool orange, int businessId = 1}) async {
  expect(find.byKey(const Key('call-choose')), findsOneWidget);
  expect(find.byKey(const Key('call-orange')), findsOneWidget);
  expect(find.byKey(const Key('call-mtn')), findsOneWidget);
  expect(env.calls.requests, isEmpty, reason: 'rien n\'est demandé avant le choix de la ligne');
  expect(env.channel.placed, isEmpty);
  expectNoPhoneOnScreen(tester);
  await tapAndSettle(tester, find.byKey(Key(orange ? 'call-orange' : 'call-mtn')));
  expect(env.calls.requests, [
    (businessId: businessId, line: orange ? CallLine.orange : CallLine.mtn)
  ]);
  expect(env.channel.placed, [(phone: kFakePhone, accountId: orange ? 'tel|orange' : 'tel|mtn')],
      reason: 'la ligne choisie est transmise au code natif');
  expect(find.byKey(const Key('call-running')), findsOneWidget);
  expectNoPhoneOnScreen(tester);
  await closeSheet(tester);
  expect(find.byKey(const Key('call-sheet')), findsNothing);
}

/// Au retour : « ça a abouti ? » puis la réponse.
Future<void> _answerFeedback(WidgetTester tester, FlowEnv env, String key, CallOutcome outcome) async {
  expect(find.byKey(const Key('feedback-sheet')), findsOneWidget);
  expect(find.textContaining('a-t-il abouti ?'), findsOneWidget);
  expectNoPhoneOnScreen(tester);
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
  expect(env.calls.feedbacks, [(callId: 7, outcome: outcome)]);
  expect(find.byKey(const Key('feedback-sheet')), findsNothing);
}

Future<void> _openHistory(WidgetTester tester) async {
  await _openTab(tester, 3);
  await tester.tap(find.byKey(const ValueKey('profile-history')));
  await _settle(tester);
  expect(find.byKey(const Key('history-list')), findsOneWidget);
  expectNoPhoneOnScreen(tester);
}

// ---------------------------------------------------------------- scénarios

/// Écrit : Accueil → recherche « riz » → fiche → Appeler (Orange) → « Abouti » → historique.
Future<void> scenarioWrittenSearchCall(WidgetTester tester) async {
  final env = FlowEnv();
  await pumpFlowApp(tester, env);
  expect(find.byKey(const Key('home-search')), findsOneWidget);
  expectNoPhoneOnScreen(tester);

  await tester.tap(find.byKey(const Key('home-search')));
  await _settle(tester);
  expect(find.byKey(const Key('search-field')), findsOneWidget);
  await tester.enterText(find.byKey(const Key('search-field')), 'riz');
  await tester.pump(const Duration(milliseconds: 450));
  await _settle(tester);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await _settle(tester);
  expect(find.text('Boutique Aminatou'), findsWidgets);
  expect(find.text('Chez Mama Riz'), findsWidgets);
  expectNoPhoneOnScreen(tester);

  await _openDetailFromCard(tester, 'Boutique Aminatou');
  await _callFromDetail(tester, env, orange: true);
  await _answerFeedback(tester, env, 'feedback-answered', CallOutcome.answered);
  expectNoPhoneOnScreen(tester);

  await _back(tester, find.byType(BusinessDetailScreen));
  await _back(tester, find.byKey(const Key('search-field')));
  await _openHistory(tester);
  expect(find.byKey(const ValueKey('history-name-100')), findsOneWidget);
  expect(find.text('Boutique Aminatou'), findsOneWidget);
  expect(env.calls.whatsappRequests, isEmpty);
}

/// Vocal : Accueil → micro → « du riz » → résultat → Appeler depuis la carte (MTN) →
/// « Pas de réponse » → historique.
Future<void> scenarioVoiceSearchCall(WidgetTester tester) async {
  final env = FlowEnv();
  await pumpFlowApp(tester, env);
  await tester.tap(find.byKey(const Key('home-voice')));
  await _settle(tester);
  await tester.tap(find.byKey(const Key('voice-rationale-ok')));
  await _settle(tester);
  expect(env.speech.listening, isTrue);
  expectNoPhoneOnScreen(tester);
  env.speech.say('je cherche du riz');
  await _settle(tester);
  expect(env.search.voiceCalls, ['je cherche du riz']);
  expect(find.byKey(const Key('voice-banner')), findsNothing);
  expect(find.text('Boutique Aminatou'), findsOneWidget);
  expectNoPhoneOnScreen(tester);

  await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Appeler').first);
  await _chooseLineAndClose(tester, env, orange: false);
  await _answerFeedback(tester, env, 'feedback-no-answer', CallOutcome.noAnswer);

  await _openHistory(tester);
  expect(find.byKey(const ValueKey('history-name-100')), findsOneWidget);
  expect(find.byKey(const ValueKey('history-badge-100')), findsOneWidget);
}

/// WhatsApp : fiche → WhatsApp → le lien part au canal natif (jamais affiché) → historique.
Future<void> scenarioWhatsappFlow(WidgetTester tester) async {
  final env = FlowEnv();
  await pumpFlowApp(tester, env);
  await _openDetailFromCard(tester, 'Boutique Aminatou');
  await tester.scrollUntilVisible(find.byKey(const Key('detail-whatsapp')), 300,
      scrollable: find.byType(Scrollable).first);
  await tapAndSettle(tester, find.byKey(const Key('detail-whatsapp')));
  expectNoPhoneOnScreen(tester);
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 600));
  expect(env.calls.whatsappRequests, [1]);
  expect(env.channel.whatsappOpened, [kFakeWaUrl]);
  expect(env.calls.requests, isEmpty, reason: 'WhatsApp ne lance pas d\'appel');
  expect(env.channel.placed, isEmpty);
  expectNoPhoneOnScreen(tester);
  await tester.pumpAndSettle();

  // Retour de WhatsApp : si la question « ça a abouti ? » s'affiche, on la ferme sans répondre.
  if (find.byKey(const Key('feedback-sheet')).evaluate().isNotEmpty) {
    await dismissFeedback(tester);
  }
  expectNoPhoneOnScreen(tester);

  await _back(tester, find.byType(BusinessDetailScreen));
  await _openHistory(tester);
  expect(find.byKey(const ValueKey('history-name-501')), findsOneWidget);
  expect(find.byKey(const ValueKey('history-whatsapp-501')), findsOneWidget);
}

/// Un commerce sans WhatsApp : le bouton est grisé, rien ne part.
Future<void> scenarioWhatsappAbsent(WidgetTester tester) async {
  final env = FlowEnv();
  await pumpFlowApp(tester, env);
  await _openDetailFromCard(tester, 'Chez Mama Riz');
  await tester.scrollUntilVisible(find.byKey(const Key('detail-whatsapp')), 300,
      scrollable: find.byType(Scrollable).first);
  expect(find.text('WhatsApp · Non disponible'), findsOneWidget);
  await tester.tap(find.byKey(const Key('detail-whatsapp')), warnIfMissed: false);
  await settleSheet(tester);
  expect(find.byKey(const Key('whatsapp-sheet')), findsNothing);
  expect(env.calls.whatsappRequests, isEmpty);
  expect(env.channel.whatsappOpened, isEmpty);
  expectNoPhoneOnScreen(tester);
}

/// Hors connexion : dernier résultat gardé, bandeau, boutons désactivés, rien n'est demandé ;
/// le réseau revient (Réessayer) et l'appel redevient possible.
Future<void> scenarioOffline(WidgetTester tester) async {
  final env = FlowEnv();
  await env.cache.write(const CachedSearch(query: SearchQuery(zone: 16), items: _results, count: 2));
  env.search.error = const ApiException(ApiErrorCode.network);
  await pumpFlowApp(tester, env);

  expect(find.byKey(const Key('offline-banner')), findsOneWidget);
  expect(find.textContaining('Hors connexion'), findsWidgets);
  expect(find.text('Boutique Aminatou'), findsOneWidget);
  expect(find.byKey(const Key('card-call-offline')), findsWidgets);
  final call = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Appeler').first);
  expect(call.onPressed, isNull);
  expect(find.byKey(const Key('call-sheet')), findsNothing);
  expect(env.calls.requests, isEmpty);
  expect(env.channel.placed, isEmpty);
  expectNoPhoneOnScreen(tester);

  // La fiche est lisible, ses boutons sont désactivés avec un message.
  // (L'encart « Aidez NetBuis à grandir » couvre le bas de l'écran : on le ferme.)
  await tester.tap(find.byKey(const Key('home-promo-close')));
  await _settle(tester);
  await _openDetailFromCard(tester, 'Boutique Aminatou');
  // Charger la fiche réussit (le faux dépôt répond) : le réseau retombe ensuite.
  ProviderScope.containerOf(tester.element(find.byType(BusinessDetailScreen)))
      .read(offlineProvider.notifier)
      .set(true);
  await _settle(tester);
  await tester.scrollUntilVisible(find.byKey(const Key('detail-call')), 300,
      scrollable: find.byType(Scrollable).first);
  expect(find.byKey(const Key('detail-offline')), findsOneWidget);
  final detailCall = tester.widget<FilledButton>(find.descendant(
      of: find.byKey(const Key('detail-call')), matching: find.byType(FilledButton)));
  expect(detailCall.onPressed, isNull);
  final detailWa = tester.widget<OutlinedButton>(find.descendant(
      of: find.byKey(const Key('detail-whatsapp')), matching: find.byType(OutlinedButton)));
  expect(detailWa.onPressed, isNull);
  expect(env.calls.whatsappRequests, isEmpty);
  expectNoPhoneOnScreen(tester);
  await _back(tester, find.byType(BusinessDetailScreen));

  // Le réseau revient.
  env.search.error = null;
  await tester.tap(find.byKey(const Key('offline-retry')));
  await _settle(tester);
  expect(find.byKey(const Key('offline-banner')), findsNothing);
  final back = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Appeler').first);
  expect(back.onPressed, isNotNull);
  await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Appeler').first);
  await _chooseLineAndClose(tester, env, orange: true);
  await dismissFeedback(tester);
}

/// Cas d'échec : le serveur ne donne pas la ligne (réseau perdu au moment d'appeler) ->
/// message simple, aucun appel natif, aucune question « ça a abouti ? », aucun numéro.
Future<void> scenarioCallRefused(WidgetTester tester) async {
  final env = FlowEnv();
  await pumpFlowApp(tester, env);
  env.calls.error = const ApiException(ApiErrorCode.network);
  await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Appeler').first);
  await tapAndSettle(tester, find.byKey(const Key('call-orange')));
  expect(env.calls.requests, hasLength(1));
  expect(find.byKey(const Key('call-error')), findsOneWidget);
  expect(env.channel.placed, isEmpty);
  expect(find.byKey(const Key('call-running')), findsNothing);
  expectNoPhoneOnScreen(tester);
  await tester.tap(find.byKey(const Key('call-close')));
  await settleSheet(tester);
  await tester.pump(const Duration(seconds: 1));
  expect(find.byKey(const Key('feedback-sheet')), findsNothing);
  expect(env.calls.feedbacks, isEmpty);
}
