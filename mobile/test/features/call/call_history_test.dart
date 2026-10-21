import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/dio_client.dart';
import 'package:netbuis/features/call/application/call_history_controller.dart';
import 'package:netbuis/features/call/data/models/call_history_entry.dart';
import 'package:netbuis/features/call/data/repositories/call_history_repository.dart';
import 'package:netbuis/features/call/data/repositories/call_history_repository_api.dart';
import 'package:netbuis/features/call/data/repositories/call_history_repository_fake.dart';
import 'package:netbuis/features/call/presentation/screens/call_history_screen.dart';

import '../account/account_test_helpers.dart';
import '../auth/auth_test_helpers.dart';
import '../business/business_submit_helpers.dart' show kApiUrl;
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
    FakeCallChannel channel) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...callOverrides(channel, calls),
      callHistoryRepositoryProvider.overrideWithValue(repo),
      historyNowProvider.overrideWithValue(() => _now),
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

      // Second rappel : la feuille revient (D-22), le choix n'est pas gardé.
      await tester.tap(find.byKey(const ValueKey('history-recall-1')));
      await settleSheet(tester);
      expect(find.text('Orange'), findsWidgets);
      expect(calls.requests, hasLength(1));
      expectNoPhoneOnScreen(tester);
    });
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
}
