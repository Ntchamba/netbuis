import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:netbuis/features/trends/application/trends_controller.dart';
import '../home/no_trends.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:netbuis/core/data/referentials/referential_repository_fake.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/l10n/l10n.dart';
import 'package:netbuis/core/theme/app_theme.dart';
import 'package:netbuis/features/account/data/repositories/account_repository_fake.dart';
import 'package:netbuis/features/home/data/share_service.dart';
import 'package:netbuis/features/home/presentation/screens/home_screen.dart';
import 'package:netbuis/features/search/application/search_controller.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';
import 'package:netbuis/features/search/data/repositories/search_repository_fake.dart';
import 'package:netbuis/features/search/voice_search/application/voice_search_controller.dart';
import 'package:netbuis/features/search/voice_search/data/speech_service.dart';

import '../auth/login_test_helpers.dart' show MemoryPrefs;

/// Faux service de reconnaissance : on décide de ce que « dit » l'utilisateur.
class FakeSpeechService implements SpeechService {
  FakeSpeechService({this.availability = SpeechAvailability.ready});

  SpeechAvailability availability;
  int prepares = 0, cancels = 0;
  bool listening = false;
  bool failListen = false;
  void Function(String, bool)? _onResult;
  void Function(SpeechFailure)? _onError;
  void Function()? _onDone;

  @override
  Future<SpeechAvailability> prepare() async {
    prepares++;
    return availability;
  }

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required void Function(SpeechFailure failure) onError,
    required void Function() onDone,
  }) async {
    if (failListen) throw StateError('micro occupé');
    listening = true;
    _onResult = onResult;
    _onError = onError;
    _onDone = onDone;
  }

  @override
  Future<void> stop() async => listening = false;

  @override
  Future<void> cancel() async {
    cancels++;
    listening = false;
  }

  void say(String words, {bool isFinal = true}) => _onResult?.call(words, isFinal);
  void error(SpeechFailure f) => _onError?.call(f);
  void done() => _onDone?.call();
}

class _Search extends SearchRepositoryFake {
  _Search()
      : super(data: const [
          SearchResult(
              id: 1, name: 'Boutique Aminatou', kind: 'produit', secteur: 'Alimentation',
              secteurCode: 'alimentation', zone: ResultZone(id: 17, name: 'Hardé'),
              descriptionActivite: 'Riz, huile et condiments'),
          SearchResult(
              id: 2, name: 'Pharmacie du Centre', kind: 'produit', secteur: 'Santé',
              secteurCode: 'pharmacie_sante', zone: ResultZone(id: 19, name: 'Domayo'),
              descriptionActivite: 'Médicaments'),
        ]);

  final List<String> voiceCalls = [];

  @override
  Future<SearchPage> voiceSearch(String text, {int? zone, String? sector, int page = 1}) {
    voiceCalls.add(text);
    return super.voiceSearch(text, zone: zone, sector: sector, page: page);
  }
}

class _Share implements ShareService {
  @override
  Future<void> shareText(String text) async {}
}

const _listening = "Je vous écoute... dites le nom d'un produit";

Future<void> _pump(
  WidgetTester tester, {
  required FakeSpeechService speech,
  required _Search search,
  VoidCallback? onOpenSearch,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, __) => Scaffold(body: HomeScreen(onOpenSearch: onOpenSearch)),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appPrefsProvider.overrideWithValue(MemoryPrefs()),
      trendsRepositoryProvider.overrideWithValue(const NoTrendsRepository()),
      searchRepositoryProvider.overrideWithValue(search),
      speechServiceProvider.overrideWithValue(speech),
      referentialRepositoryProvider.overrideWithValue(const ReferentialRepositoryFake()),
      accountRepositoryProvider.overrideWithValue(AccountRepositoryFake()),
      shareServiceProvider.overrideWithValue(_Share()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      locale: const Locale('fr'),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tapMic(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('home-voice')));
  await tester.pumpAndSettle();
}

Future<void> _accept(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('voice-rationale-ok')));
  await tester.pumpAndSettle();
}

void main() {
  group('recherche vocale depuis l\'Accueil', () {
    testWidgets('explication du micro, puis bandeau d\'écoute de la maquette', (tester) async {
      final speech = FakeSpeechService();
      await _pump(tester, speech: speech, search: _Search());
      await _tapMic(tester);
      expect(find.text('Utiliser le micro ?'), findsOneWidget);
      expect(speech.prepares, 0, reason: 'le micro n\'est demandé qu\'après l\'explication');
      await _accept(tester);
      expect(speech.prepares, 1);
      expect(speech.listening, isTrue);
      expect(find.text(_listening), findsOneWidget);
    });

    testWidgets('le texte reconnu lance la recherche vocale et ferme le bandeau', (tester) async {
      final speech = FakeSpeechService();
      final search = _Search();
      await _pump(tester, speech: speech, search: search);
      await _tapMic(tester);
      await _accept(tester);
      speech.say('je cherche du riz', isFinal: false);
      await tester.pump();
      expect(search.voiceCalls, isEmpty, reason: 'un texte partiel ne lance rien');
      speech.say('je cherche du riz');
      await tester.pumpAndSettle();
      expect(search.voiceCalls, ['je cherche du riz']);
      expect(find.text(_listening), findsNothing);
      expect(find.text('Boutique Aminatou'), findsOneWidget);
      expect(find.text('Pharmacie du Centre'), findsNothing);
    });

    testWidgets('micro refusé : message simple et retour à la recherche écrite', (tester) async {
      var opened = 0;
      final speech = FakeSpeechService(availability: SpeechAvailability.denied);
      final search = _Search();
      await _pump(tester, speech: speech, search: search, onOpenSearch: () => opened++);
      await _tapMic(tester);
      await _accept(tester);
      expect(find.textContaining("Le micro n'est pas autorisé"), findsOneWidget);
      expect(find.text(_listening), findsNothing);
      expect(opened, 1);
      expect(search.voiceCalls, isEmpty);
    });

    testWidgets('rien compris : message et retour à la recherche écrite', (tester) async {
      var opened = 0;
      final speech = FakeSpeechService();
      await _pump(tester, speech: speech, search: _Search(), onOpenSearch: () => opened++);
      await _tapMic(tester);
      await _accept(tester);
      speech.error(const SpeechFailure(message: 'error_no_match', noSpeech: true));
      await tester.pumpAndSettle();
      expect(find.textContaining("Je n'ai rien compris"), findsOneWidget);
      expect(find.text(_listening), findsNothing);
      expect(opened, 1);
    });

    testWidgets('service absent : message simple', (tester) async {
      final speech = FakeSpeechService(availability: SpeechAvailability.unavailable);
      await _pump(tester, speech: speech, search: _Search());
      await _tapMic(tester);
      await _accept(tester);
      expect(find.textContaining("pas disponible sur ce téléphone"), findsOneWidget);
    });

    testWidgets('« Non merci » sur l\'explication : le micro n\'est pas demandé', (tester) async {
      final speech = FakeSpeechService();
      await _pump(tester, speech: speech, search: _Search());
      await _tapMic(tester);
      await tester.tap(find.byKey(const Key('voice-rationale-cancel')));
      await tester.pumpAndSettle();
      expect(speech.prepares, 0);
      expect(find.text(_listening), findsNothing);
    });

    testWidgets('l\'explication n\'est montrée qu\'une fois ; toucher le bandeau arrête', (tester) async {
      final speech = FakeSpeechService();
      final search = _Search();
      await _pump(tester, speech: speech, search: search);
      await _tapMic(tester);
      await _accept(tester);
      await tester.tap(find.byKey(const Key('voice-banner')));
      await tester.pumpAndSettle();
      expect(find.text(_listening), findsNothing);
      expect(speech.listening, isFalse);
      await _tapMic(tester);
      expect(find.text('Utiliser le micro ?'), findsNothing);
      expect(find.text(_listening), findsOneWidget);
      expect(speech.prepares, 2);
      expect(search.voiceCalls, isEmpty);
    });
  });

  group('VoiceSearchController', () {
    ProviderContainer make(FakeSpeechService speech, _Search search) {
      final c = ProviderContainer(overrides: [
        searchRepositoryProvider.overrideWithValue(search),
        speechServiceProvider.overrideWithValue(speech),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('fin d\'écoute sans résultat final : le texte partiel est utilisé', () async {
      final speech = FakeSpeechService();
      final search = _Search();
      final c = make(speech, search);
      final ctrl = c.read(voiceSearchControllerProvider.notifier);
      await ctrl.start();
      expect(c.read(voiceSearchControllerProvider).phase, VoicePhase.listening);
      speech.say('pharmacie', isFinal: false);
      speech.done();
      await Future<void>.delayed(Duration.zero);
      expect(search.voiceCalls, ['pharmacie']);
      expect(c.read(voiceSearchControllerProvider).phase, VoicePhase.idle);
    });

    test('fin d\'écoute sans aucun mot : erreur « noSpeech », aucune recherche', () async {
      final speech = FakeSpeechService();
      final search = _Search();
      final c = make(speech, search);
      await c.read(voiceSearchControllerProvider.notifier).start();
      speech.done();
      final s = c.read(voiceSearchControllerProvider);
      expect(s.phase, VoicePhase.failed);
      expect(s.error, VoiceError.noSpeech);
      expect(search.voiceCalls, isEmpty);
    });

    test('le service plante au démarrage : erreur « failed »', () async {
      final speech = FakeSpeechService()..failListen = true;
      final c = make(speech, _Search());
      await c.read(voiceSearchControllerProvider.notifier).start();
      expect(c.read(voiceSearchControllerProvider).error, VoiceError.failed);
    });

    test('un texte tardif après annulation est ignoré', () async {
      final speech = FakeSpeechService();
      final search = _Search();
      final c = make(speech, search);
      final ctrl = c.read(voiceSearchControllerProvider.notifier);
      await ctrl.start();
      await ctrl.cancel();
      speech.say('riz');
      expect(search.voiceCalls, isEmpty);
      expect(c.read(voiceSearchControllerProvider).phase, VoicePhase.idle);
    });
  });
}
