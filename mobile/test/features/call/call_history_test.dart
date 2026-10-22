import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/dio_client.dart';
import 'package:netbuis/features/call/application/call_history_controller.dart';
import 'package:netbuis/features/forum/application/forum_services.dart';
import 'package:netbuis/features/forum/data/models/report.dart';
import 'package:netbuis/features/search/application/offline_controller.dart';
import 'package:netbuis/features/call/data/models/call_history_entry.dart';
import 'package:netbuis/features/call/data/repositories/call_history_repository.dart';
import 'package:netbuis/features/call/data/repositories/call_history_repository_api.dart';
import 'package:netbuis/features/call/data/repositories/call_history_repository_fake.dart';
import 'package:netbuis/features/call/presentation/screens/call_history_screen.dart';

import '../account/account_test_helpers.dart';
import '../auth/auth_test_helpers.dart';
import '../business/business_submit_helpers.dart' show kApiUrl;
import '../forum/forum_test_helpers.dart'
    show ScriptedReportRepository, kAlreadyReported, kGone, kOwnContent;
import 'call_test_helpers.dart';

Map<String, Object?> _row(int id, {String type = 'call', String name = 'Chez Aminatou'}) => {
      'id': id,
      'business_id': 5,
      'business_name': name,
      'zone': 'Hardé',
      'date': '2026-10-20T09:14:00',
      'type': type,
      'feedback': null,
    };

CallHistoryEntry _entry(int id, {HistoryType type = HistoryType.call, DateTime? date}) =>
    CallHistoryEntry(
      id: id,
      businessId: 5,
      businessName: 'Chez Aminatou',
      zone: 'Hardé',
      date: date ?? DateTime(2026, 10, 20, 9, 14),
      type: type,
    );

class _ScriptedHistory implements CallHistoryRepository {
  _ScriptedHistory(this.pages);

  final List<CallHistoryPage> pages;
  ApiException? error;
  final List<int> asked = [];

  @override
  Future<CallHistoryPage> history({int page = 1}) async {
    asked.add(page);
    final e = error;
    if (e != null) throw e;
    return pages[page - 1];
  }
}

class _GatedHistory implements CallHistoryRepository {
  _GatedHistory(this.future);

  final Future<CallHistoryPage> future;

  @override
  Future<CallHistoryPage> history({int page = 1}) => future;
}

final _now = DateTime(2026, 10, 21, 12);

Future<void> _pump(WidgetTester tester, CallHistoryRepository repo, FakeCallRepository calls,
    FakeCallChannel channel, {List<Override> extra = const []}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...callOverrides(channel, calls),
      callHistoryRepositoryProvider.overrideWithValue(repo),
      historyNowProvider.overrideWithValue(() => _now),
      ...extra,
    ],
    child: testApp(const CallHistoryScreen()),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('modèle et dépôt api', () {
    test('lit une page ; aucun numéro dans le modèle', () {
      final page = CallHistoryPage.fromJson({
        'count': 2,
        'next': 'http://x/?page=2',
        'results': [_row(1), _row(2, type: 'whatsapp')],
      });
      expect(page.count, 2);
      expect(page.hasNext, isTrue);
      expect(page.results[0].type, HistoryType.call);
      expect(page.results[1].type, HistoryType.whatsapp);
      expect(page.results[0].businessName, 'Chez Aminatou');
    });

    test('ligne incomplète : FormatException', () {
      expect(
          () => CallHistoryPage.fromJson({
                'count': 1,
                'results': [
                  {'id': 1}
                ],
              }),
          throwsFormatException);
    });

    test('GET /calls/history/ : page lue ; réponse cassée -> ApiException', () async {
      final ok = FakeAdapter((r) => FakeAdapter.reply(200, {
            'count': 1,
            'next': null,
            'results': [_row(9)],
          }));
      final repo = CallHistoryRepositoryApi(
          buildDio(baseUrl: kApiUrl, readAccessToken: () async => 'acc-test')
            ..httpClientAdapter = ok);
      final page = await repo.history();
      expect(ok.seen.single.method, 'GET');
      expect(ok.seen.single.path, '/calls/history/');
      expect(page.results.single.id, 9);
      expect(page.hasNext, isFalse);

      final bad = FakeAdapter((r) => FakeAdapter.reply(200, {'oops': 1}));
      final repo2 = CallHistoryRepositoryApi(
          buildDio(baseUrl: kApiUrl, readAccessToken: () async => 'acc-test')
            ..httpClientAdapter = bad);
      await expectLater(repo2.history(), throwsA(isA<ApiException>()));
    });

    test('dépôt factice : 25 lignes en 2 pages', () async {
      final fake = CallHistoryRepositoryFake(now: () => _now);
      final p1 = await fake.history();
      final p2 = await fake.history(page: 2);
      expect(p1.results, hasLength(20));
      expect(p1.hasNext, isTrue);
      expect(p2.results, hasLength(5));
      expect(p2.hasNext, isFalse);
    });
  });

  group('écran', () {
    testWidgets('liste : nom, zone, date, badge appel / WhatsApp', (tester) async {
      final repo = _ScriptedHistory([
        CallHistoryPage(count: 3, hasNext: false, results: [
          _entry(1, date: DateTime(2026, 10, 21, 9, 14)),
          _entry(2, type: HistoryType.whatsapp, date: DateTime(2026, 10, 20, 17, 40)),
          _entry(3, date: DateTime(2026, 9, 28, 11, 2)),
        ]),
      ]);
      await _pump(tester, repo, FakeCallRepository(), FakeCallChannel());
      expect(find.text('Historique de mes appels'), findsOneWidget);
      expect(find.text('Hardé · Aujourd\'hui, 09:14'), findsOneWidget);
      expect(find.text('Hardé · Hier, 17:40'), findsOneWidget);
      expect(find.textContaining('11:02'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('history-badge-1')),
          matching: find.text('Appel')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('history-badge-2')),
          matching: find.text('WhatsApp')), findsOneWidget);
      expectNoPhoneOnScreen(tester);
    });

    testWidgets('état vide soigné', (tester) async {
      final repo = _ScriptedHistory([const CallHistoryPage(count: 0, hasNext: false, results: [])]);
      await _pump(tester, repo, FakeCallRepository(), FakeCallChannel());
      expect(find.byKey(const Key('history-empty')), findsOneWidget);
      expect(find.text('Aucun appel pour le moment'), findsOneWidget);
      expect(find.byKey(const Key('history-empty-action')), findsOneWidget);
    });

    testWidgets('erreur : message et Réessayer recharge', (tester) async {
      final repo = _ScriptedHistory([
        CallHistoryPage(count: 1, hasNext: false, results: [_entry(1)]),
      ])
        ..error = const ApiException(ApiErrorCode.network);
      await _pump(tester, repo, FakeCallRepository(), FakeCallChannel());
      expect(find.byKey(const Key('history-error')), findsOneWidget);
      expect(find.byKey(const Key('history-list')), findsNothing);

      repo.error = null;
      await tester.tap(find.byKey(const Key('history-retry')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('history-list')), findsOneWidget);
      expect(find.byKey(const Key('history-error')), findsNothing);
    });

    testWidgets('chargement : indicateur tant que la réponse n\'est pas arrivée', (tester) async {
      final gate = Completer<CallHistoryPage>();
      await _pump(tester, _GatedHistory(gate.future), FakeCallRepository(), FakeCallChannel());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('history-list')), findsNothing);
      gate.complete(CallHistoryPage(count: 1, hasNext: false, results: [_entry(1)]));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('history-list')), findsOneWidget);
    });

    testWidgets('pagination infinie : la page 2 arrive en bas de liste', (tester) async {
      final repo = CallHistoryRepositoryFake(now: () => _now);
      await _pump(tester, repo, FakeCallRepository(), FakeCallChannel());
      expect(find.byKey(const ValueKey('history-name-1000')), findsOneWidget);
      expect(find.byKey(const ValueKey('history-name-975')), findsNothing);
      await tester.drag(find.byKey(const Key('history-list')), const Offset(0, -6000));
      await tester.pump();
      await tester.pump();
      await tester.drag(find.byKey(const Key('history-list')), const Offset(0, -6000));
      await tester.pump();
      expect(find.byKey(const ValueKey('history-name-976')), findsOneWidget);
    });

    testWidgets('échec de la page 2 : la liste reste, Réessayer', (tester) async {
      final repo = _ScriptedHistory([
        CallHistoryPage(count: 2, hasNext: true, results: [_entry(1)]),
        CallHistoryPage(count: 2, hasNext: false, results: [_entry(2)]),
      ]);
      await _pump(tester, repo, FakeCallRepository(), FakeCallChannel());
      final container = ProviderScope.containerOf(tester.element(find.byType(CallHistoryScreen)));
      repo.error = const ApiException(ApiErrorCode.network);
      await container.read(callHistoryControllerProvider.notifier).loadMore();
      await tester.pump();
      expect(find.byKey(const ValueKey('history-name-1')), findsOneWidget);
      expect(find.byKey(const Key('history-retry-more')), findsOneWidget);

      repo.error = null;
      await tester.ensureVisible(find.byKey(const Key('history-retry-more')));
      await tester.tap(find.byKey(const Key('history-retry-more')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('history-name-2')), findsOneWidget);
      expect(repo.asked, [1, 2, 2]);
    });

    testWidgets('Rappeler : feuille Orange / MTN, ligne redemandée, rien d\'appelé avant le choix',
        (tester) async {
      final repo = _ScriptedHistory([
        CallHistoryPage(count: 1, hasNext: false, results: [_entry(1)]),
      ]);
      final calls = FakeCallRepository();
      final channel = FakeCallChannel();
      await _pump(tester, repo, calls, channel);

      await tester.tap(find.byKey(const ValueKey('history-recall-1')));
      await settleSheet(tester);
      expect(find.text('Orange'), findsWidgets);
      expect(find.text('MTN'), findsWidgets);
      expect(calls.requests, isEmpty);
      expect(channel.placed, isEmpty);
      expectNoPhoneOnScreen(tester);

      await tester.tap(find.text('MTN').first);
      await settleSheet(tester);
      expect(calls.requests.single.businessId, 5);
      expect(calls.requests.single.line?.value, 'mtn');
      expect(channel.placed, hasLength(1));
      await closeSheet(tester);
      await dismissFeedback(tester);

      // Second rappel : la feuille revient (D-22), le choix n'est pas gardé.
      await tester.tap(find.byKey(const ValueKey('history-recall-1')));
      await settleSheet(tester);
      expect(find.text('Orange'), findsWidgets);
      expect(calls.requests, hasLength(1));
      expectNoPhoneOnScreen(tester);
    });
  });

  testWidgets('ligne WhatsApp : garde « Rappeler » (appel) et gagne un bouton WhatsApp (T054)',
      (tester) async {
    final repo = _ScriptedHistory([
      CallHistoryPage(
          count: 1, hasNext: false, results: [_entry(2, type: HistoryType.whatsapp)]),
    ]);
    final calls = FakeCallRepository();
    final channel = FakeCallChannel();
    await _pump(tester, repo, calls, channel);

    // « Rappeler » reste un appel : feuille Orange / MTN, rien d'envoyé avant le choix.
    expect(find.byKey(const ValueKey('history-recall-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('history-whatsapp-2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history-recall-2')));
    await settleSheet(tester);
    expect(find.byKey(const Key('call-choose')), findsOneWidget);
    expect(calls.whatsappRequests, isEmpty);
    await tester.tap(find.byKey(const Key('call-cancel')));
    await settleSheet(tester);

    // Le bouton WhatsApp ouvre WhatsApp pour ce commerce, sans rien afficher du lien.
    await tester.tap(find.byKey(const ValueKey('history-whatsapp-2')));
    await settleSheet(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls.whatsappRequests, [5]);
    expect(calls.requests, isEmpty);
    expect(channel.whatsappOpened, [kFakeWaUrl]);
    expectNoPhoneOnScreen(tester);
  });

  testWidgets('Profil : « Historique de mes appels » ouvre l\'écran, Profil ramène en arrière',
      (tester) async {
    await pumpAccountApp(tester, account: ScriptedAccountRepository(me: meWith(name: 'Jeff N.')));
    await tester.tap(find.byKey(const ValueKey('profile-history')));
    await tester.pumpAndSettle();
    expect(find.byType(CallHistoryScreen), findsOneWidget);
    expect(find.byKey(const Key('history-list')), findsOneWidget);

    await tester.tap(find.byKey(const Key('history-back')));
    await tester.pumpAndSettle();
    expect(find.byType(CallHistoryScreen), findsNothing);
    expect(find.text('Mon profil'), findsOneWidget);
  });

  group('Signaler ce commerce (T093)', () {
    CallHistoryEntry other() => CallHistoryEntry(
          id: 2,
          businessId: 6,
          businessName: 'Atelier Ibrahim',
          zone: 'Domayo',
          date: DateTime(2026, 10, 19, 8, 0),
          type: HistoryType.call,
        );

    Future<ScriptedReportRepository> open(WidgetTester tester,
        {bool offline = false}) async {
      final reports = ScriptedReportRepository();
      final repo = _ScriptedHistory([
        CallHistoryPage(count: 2, hasNext: false, results: [_entry(1), other()]),
      ]);
      await _pump(tester, repo, FakeCallRepository(), FakeCallChannel(),
          extra: [reportRepositoryProvider.overrideWithValue(reports)]);
      if (offline) {
        ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
            .read(offlineProvider.notifier)
            .set(true);
        await tester.pump();
      }
      return reports;
    }

    Future<void> tapKey(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    bool enabled(WidgetTester tester, String key) =>
        tester.widget<TextButton>(find.byKey(ValueKey(key))).onPressed != null;

    testWidgets(
        'chaque ligne a « Signaler ce commerce » ; un motif envoie target_type=business ; merci puis « Déjà signalé » pour ce seul commerce',
        (tester) async {
      final reports = await open(tester);
      expect(find.text('Signaler ce commerce'), findsNWidgets(2));
      await tapKey(tester, const ValueKey('history-report-1'));
      for (final label in ['Spam', 'Arnaque', 'Contenu inapproprié', 'Autre']) {
        expect(find.text(label), findsOneWidget);
      }
      await tapKey(tester, const Key('report-reason-contenu_inapproprie'));

      expect(reports.calls.single, (
        target: ReportTarget.business,
        id: 5,
        reason: ReportReason.inapproprie
      ));
      expect(find.text('Merci, votre signalement a été envoyé.'), findsOneWidget);
      expect(find.text('Déjà signalé'), findsOneWidget);
      expect(enabled(tester, 'history-report-1'), isFalse);
      // L'autre commerce reste signalable ; les boutons Rappeler restent là.
      expect(enabled(tester, 'history-report-2'), isTrue);
      expect(find.byKey(const ValueKey('history-recall-1')), findsOneWidget);
    });

    testWidgets('annuler : rien n\'est envoyé', (tester) async {
      final reports = await open(tester);
      await tapKey(tester, const ValueKey('history-report-2'));
      await tapKey(tester, const Key('report-cancel'));
      expect(reports.calls, isEmpty);
      expect(enabled(tester, 'history-report-2'), isTrue);
    });

    testWidgets('409 : « Déjà signalé » sans erreur', (tester) async {
      final reports = await open(tester);
      reports.error = kAlreadyReported;
      await tapKey(tester, const ValueKey('history-report-1'));
      await tapKey(tester, const Key('report-reason-spam'));
      expect(find.text('Vous avez déjà signalé ce contenu.'), findsOneWidget);
      expect(enabled(tester, 'history-report-1'), isFalse);
    });

    testWidgets('own_content : message clair', (tester) async {
      final reports = await open(tester);
      reports.error = kOwnContent;
      await tapKey(tester, const ValueKey('history-report-1'));
      await tapKey(tester, const Key('report-reason-spam'));
      expect(find.text('Vous ne pouvez pas signaler votre propre contenu.'),
          findsOneWidget);
      await tapKey(tester, const Key('report-close'));
      expect(enabled(tester, 'history-report-1'), isTrue);
    });

    testWidgets('404 : « plus disponible »', (tester) async {
      final reports = await open(tester);
      reports.error = kGone;
      await tapKey(tester, const ValueKey('history-report-1'));
      await tapKey(tester, const Key('report-reason-autre'));
      expect(find.text('Ce commerce n\'est plus disponible.'), findsOneWidget);
      expect(enabled(tester, 'history-report-1'), isTrue);
    });

    testWidgets('réseau : message + Réessayer', (tester) async {
      final reports = await open(tester);
      reports.error = const ApiException(ApiErrorCode.network);
      await tapKey(tester, const ValueKey('history-report-1'));
      await tapKey(tester, const Key('report-reason-spam'));
      expect(find.byKey(const Key('report-error')), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      reports.error = null;
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
          .read(offlineProvider.notifier)
          .set(false);
      await tapKey(tester, const Key('report-retry'));
      expect(reports.calls.length, 2);
      expect(enabled(tester, 'history-report-1'), isFalse);
    });

    testWidgets('double envoi impossible', (tester) async {
      final reports = await open(tester);
      reports.gate = Completer<void>();
      await tapKey(tester, const ValueKey('history-report-1'));
      await tester.tap(find.byKey(const Key('report-reason-spam')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('report-reason-spam')), warnIfMissed: false);
      await tester.tap(find.byKey(const Key('report-reason-arnaque')), warnIfMissed: false);
      await tester.pump();
      expect(reports.calls.length, 1);
      reports.gate!.complete();
      await tester.pumpAndSettle();
      expect(reports.calls.length, 1);
    });

    testWidgets('hors connexion : bouton désactivé avec « Hors connexion »',
        (tester) async {
      final reports = await open(tester, offline: true);
      expect(enabled(tester, 'history-report-1'), isFalse);
      expect(find.text('Signaler ce commerce · Hors connexion'), findsNWidgets(2));
      expect(reports.calls, isEmpty);
    });
  });
}
