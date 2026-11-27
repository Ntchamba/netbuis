// T054 : WhatsApp (wa.me).
// Le lien wa.me CONTIENT le numéro du commerçant : il ne doit être ni affiché, ni gardé, ni
// mis dans une erreur. Faux canal natif et faux dépôt : aucun réseau, aucun téléphone.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/dio_client.dart';
import 'package:netbuis/features/business/application/public_business_controller.dart';
import 'package:netbuis/features/business/data/repositories/public_business_repository_fake.dart';
import 'package:netbuis/features/business/presentation/screens/business_detail_screen.dart';
import 'package:netbuis/features/call/application/call_controller.dart';
import 'package:netbuis/features/call/data/call_channel.dart';
import 'package:netbuis/features/call/data/models/call_feedback.dart';
import 'package:netbuis/features/call/data/models/call_session.dart';
import 'package:netbuis/features/call/data/repositories/call_repository_api.dart';
import 'package:netbuis/features/call/data/repositories/call_repository_fake.dart';
import 'package:netbuis/features/call/presentation/widgets/whatsapp_button.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';
import 'package:netbuis/features/search/presentation/widgets/result_card.dart';

import '../auth/auth_test_helpers.dart';
import '../business/business_submit_helpers.dart' show kApiUrl;
import 'call_test_helpers.dart';

const Key kOpenWa = Key('open-wa');

CallRepositoryApi _repo(FakeAdapter a) => CallRepositoryApi(
    buildDio(baseUrl: kApiUrl, readAccessToken: () async => 'acc-test')..httpClientAdapter = a);

ApiException _refused(String code, int status) =>
    ApiException(ApiErrorCode.fromValue(code), statusCode: status, serverCode: code);

/// Écran minimal avec un bouton WhatsApp pour le commerce n° 5 « Chez Aminatou ».
Future<void> pumpWaHost(
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
            key: kOpenWa,
            onPressed: () =>
                startWhatsapp(context, businessId: 5, businessName: 'Chez Aminatou'),
            child: const Text('WhatsApp'),
          ),
        ),
      ),
    )),
  ));
  await tester.pumpAndSettle();
}

/// Après un succès la feuille se ferme toute seule : on laisse finir son animation.
Future<void> afterClose(WidgetTester tester) => tester.pump(const Duration(milliseconds: 500));

void main() {
  late FakeCallChannel channel;
  late FakeCallRepository repo;

  setUp(() {
    channel = FakeCallChannel();
    repo = FakeCallRepository();
  });

  group('modèle WhatsappLink', () {
    test('lit {call_id, wa_url} ; toString ne montre jamais le lien', () {
      final l = WhatsappLink.fromJson({'call_id': 8, 'wa_url': kFakeWaUrl});
      expect(l.callId, 8);
      expect(l.url, kFakeWaUrl);
      expect(l.toString(), 'WhatsappLink(callId: 8)');
      expect(l.toString(), isNot(contains(kFakeDigits)));
      expect(l.toString(), isNot(contains('wa.me')));
    });

    test('un lien qui n\'est pas https://wa.me/… est refusé, sans détail', () {
      for (final url in <Object?>[
        'http://wa.me/237600000042',
        'https://evil.example/237600000042',
        'https://wa.me.evil.example/237600000042',
        'https://wa.me/',
        'tel:+237600000042',
        '',
        null,
        42,
      ]) {
        expect(
          () => WhatsappLink.fromJson({'call_id': 1, 'wa_url': url}),
          throwsA(isA<FormatException>()
              .having((e) => e.toString(), 'texte', isNot(contains(kFakeDigits)))),
          reason: '$url',
        );
      }
      expect(() => WhatsappLink.fromJson({'wa_url': kFakeWaUrl}), throwsFormatException);
      expect(() => WhatsappLink.fromJson(['x']), throwsFormatException);
    });
  });

  group('dépôt api', () {
    test('POST /calls/whatsapp/ {business_id, platform} et lien lu', () async {
      final a = FakeAdapter(
          (r) => FakeAdapter.reply(200, {'call_id': 12, 'wa_url': kFakeWaUrl}));
      final l = await _repo(a).initiateWhatsapp(businessId: 5);
      expect(a.seen.single.method, 'POST');
      expect(a.seen.single.path, '/calls/whatsapp/');
      final body = a.seen.single.body as Map;
      expect(body['business_id'], 5);
      expect(body.containsKey('channel'), isFalse);
      expect(body['platform'], anyOf('android', 'ios'));
      expect(body.containsKey('operator'), isFalse);
      expect(l.callId, 12);
      expect(l.url, kFakeWaUrl);
    });

    test('refus du serveur : ApiException avec le code, sans lien ni numéro', () async {
      final codes = {
        401: 'NOT_AUTHENTICATED',
        403: 'ACCOUNT_BLOCKED',
        409: 'CHANNEL_UNAVAILABLE',
        429: 'RATE_LIMITED',
      };
      for (final e in codes.entries) {
        final a = FakeAdapter((r) => FakeAdapter.reply(e.key, {'code': e.value, 'message': 'x'}));
        await expectLater(
          _repo(a).initiateWhatsapp(businessId: 5),
          throwsA(isA<ApiException>()
              .having((x) => x.serverCode, 'serverCode', e.value)
              .having((x) => x.toString(), 'texte', isNot(contains(kFakeDigits)))),
        );
      }
    });

    test('réponse sans lien, ou avec un lien d\'un autre site : erreur inconnue sans détail',
        () async {
      for (final body in <Object?>[
        {'call_id': 3},
        {'call_id': 3, 'wa_url': 'https://evil.example/237600000042'},
        {'call_id': 3, 'phone': kFakePhone},
        ['liste'],
      ]) {
        final a = FakeAdapter((r) => FakeAdapter.reply(200, body));
        await expectLater(
          _repo(a).initiateWhatsapp(businessId: 5),
          throwsA(isA<ApiException>()
              .having((x) => x.code, 'code', ApiErrorCode.unknown)
              .having((x) => x.toString(), 'texte', isNot(contains(kFakeDigits)))),
        );
      }
    });

    test('POST /calls/{id}/feedback/ {outcome}', () async {
      for (final o in CallOutcome.values) {
        final a = FakeAdapter((r) => FakeAdapter.reply(200, {'call_id': 7, 'outcome': o.value}));
        await _repo(a).sendFeedback(callId: 7, outcome: o);
        expect(a.seen.single.method, 'POST');
        expect(a.seen.single.path, '/calls/7/feedback/');
        expect(a.seen.single.body, {'outcome': o.value});
      }
      expect(CallOutcome.values.map((o) => o.value), ['answered', 'no_answer', 'wrong_number']);
    });

    test('feedback refusé (404 appel d\'un autre compte) : ApiException', () async {
      final a = FakeAdapter((r) => FakeAdapter.reply(404, {'code': 'not_found', 'message': 'x'}));
      await expectLater(_repo(a).sendFeedback(callId: 7, outcome: CallOutcome.answered),
          throwsA(isA<ApiException>().having((x) => x.statusCode, 'statut', 404)));
    });

    test('POST /calls/whatsapp-report/ {business_id} ; 404 -> ApiException', () async {
      final ok = FakeAdapter((r) => FakeAdapter.reply(200, {'recorded': true}));
      await _repo(ok).reportNoWhatsapp(businessId: 5);
      expect(ok.seen.single.path, '/calls/whatsapp-report/');
      expect(ok.seen.single.body, {'business_id': 5});
      final no = FakeAdapter((r) => FakeAdapter.reply(404, {'code': 'not_found', 'message': 'x'}));
      await expectLater(_repo(no).reportNoWhatsapp(businessId: 5), throwsA(isA<ApiException>()));
    });

    test('dépôt factice : lien fictif, jamais dans toString', () async {
      final l = await CallRepositoryFake().initiateWhatsapp(businessId: 1);
      expect(WhatsappLink.isWhatsappUrl(l.url), isTrue);
      expect(l.toString(), isNot(contains('wa.me')));
      await CallRepositoryFake().sendFeedback(callId: 1, outcome: CallOutcome.noAnswer);
      await CallRepositoryFake().reportNoWhatsapp(businessId: 1);
    });
  });

  group('canal natif Dart', () {
    test('openWhatsapp : réponses opened / not_installed / failed ; erreur sans détail', () async {
      const ch = PlatformCallChannel();
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      Object? sent;
      for (final e in {
        'opened': WhatsappOpenResult.opened,
        'not_installed': WhatsappOpenResult.notInstalled,
        'failed': WhatsappOpenResult.failed,
        'autre': WhatsappOpenResult.failed,
      }.entries) {
        messenger.setMockMethodCallHandler(PlatformCallChannel.channel, (call) async {
          sent = call.arguments;
          return e.key;
        });
        expect(await ch.openWhatsapp(kFakeWaUrl), e.value);
        expect(sent, {'url': kFakeWaUrl});
      }
      messenger.setMockMethodCallHandler(PlatformCallChannel.channel, null);
      // Sans code natif (autre plateforme) : CallChannelException, qui ne contient pas le lien.
      await expectLater(
        ch.openWhatsapp(kFakeWaUrl),
        throwsA(isA<CallChannelException>()
            .having((e) => e.toString(), 'texte', isNot(contains(kFakeDigits)))),
      );
    });
  });

  group('ouverture de WhatsApp', () {
    testWidgets('WhatsApp installé : POST whatsapp puis le lien passe au natif, rien d\'affiché',
        (tester) async {
      await pumpWaHost(tester, channel: channel, repo: repo);
      await tester.tap(find.byKey(kOpenWa));
      await tester.pump();
      // Pendant l'ouverture : la feuille montre seulement un indicateur.
      expect(find.byKey(const Key('whatsapp-sheet')), findsOneWidget);
      expectNoPhoneOnScreen(tester);
      await settleSheet(tester);
      await afterClose(tester);
      expect(repo.whatsappRequests, [5]);
      expect(repo.requests, isEmpty, reason: 'ce n\'est pas un appel à l\'équipe');
      expect(channel.whatsappOpened, [kFakeWaUrl]);
      expect(channel.dialed, isEmpty);
      expect(find.byKey(const Key('whatsapp-sheet')), findsNothing);
      expect(find.byKey(const Key('feedback-sheet')), findsNothing,
          reason: 'le retour d\'appel ne concerne que les appels');
      expectNoPhoneOnScreen(tester);
    });

    testWidgets('on peut rouvrir WhatsApp ensuite (la feuille est remise à zéro)', (tester) async {
      await pumpWaHost(tester, channel: channel, repo: repo);
      await tapAndSettle(tester, find.byKey(kOpenWa));
      await afterClose(tester);
      await tapAndSettle(tester, find.byKey(kOpenWa));
      await afterClose(tester);
      expect(channel.whatsappOpened, hasLength(2));
      expect(repo.whatsappRequests, [5, 5]);
    });

    testWidgets('WhatsApp absent : message simple, rien n\'est ouvert, signalement proposé',
        (tester) async {
      channel.whatsappResult = WhatsappOpenResult.notInstalled;
      await pumpWaHost(tester, channel: channel, repo: repo);
      await tapAndSettle(tester, find.byKey(kOpenWa));
      expect(find.byKey(const Key('whatsapp-not-installed')), findsOneWidget);
      expect(find.text("WhatsApp n'est pas installé sur ce téléphone."), findsOneWidget);
      expect(find.textContaining('Chez Aminatou'), findsOneWidget);
      expect(find.byKey(const Key('whatsapp-report')), findsOneWidget);
      expect(find.text("Ce commerce n'a pas WhatsApp"), findsOneWidget);
      expect(repo.reports, isEmpty, reason: 'rien n\'est envoyé sans toucher le bouton');
      expectNoPhoneOnScreen(tester);

      await tapAndSettle(tester, find.byKey(const Key('whatsapp-report')));
      expect(repo.reports, [5]);
      expect(find.byKey(const Key('whatsapp-reported')), findsOneWidget);
      expect(find.text("Merci, c'est noté."), findsOneWidget);
      expect(find.byKey(const Key('whatsapp-report')), findsNothing);
      expectNoPhoneOnScreen(tester);
      await tapAndSettle(tester, find.byKey(const Key('whatsapp-close')));
      expect(find.byKey(const Key('whatsapp-sheet')), findsNothing);
    });

    testWidgets('WhatsApp absent : « Fermer » sans signaler n\'envoie rien', (tester) async {
      channel.whatsappResult = WhatsappOpenResult.notInstalled;
      await pumpWaHost(tester, channel: channel, repo: repo);
      await tapAndSettle(tester, find.byKey(kOpenWa));
      await tapAndSettle(tester, find.byKey(const Key('whatsapp-close')));
      expect(find.byKey(const Key('whatsapp-sheet')), findsNothing);
      expect(repo.reports, isEmpty);
    });

    testWidgets('signalement en échec : message, puis on peut réessayer ; double toucher = 1 envoi',
        (tester) async {
      channel.whatsappResult = WhatsappOpenResult.notInstalled;
      repo.reportError = _refused('not_found', 404);
      await pumpWaHost(tester, channel: channel, repo: repo);
      await tapAndSettle(tester, find.byKey(kOpenWa));
      await tapAndSettle(tester, find.byKey(const Key('whatsapp-report')));
      expect(find.byKey(const Key('whatsapp-report-failed')), findsOneWidget);
      expect(find.byKey(const Key('whatsapp-not-installed')), findsOneWidget);
      expect(repo.reports, isEmpty);

      repo.reportError = null;
      final report = find.byKey(const Key('whatsapp-report'));
      await tester.tap(report);
      await tester.tap(report, warnIfMissed: false);
      await settleSheet(tester);
      expect(repo.reports, [5], reason: 'un seul envoi malgré le double toucher');
      expect(find.byKey(const Key('whatsapp-reported')), findsOneWidget);
    });

    testWidgets('le signalement n\'existe pas avant la tentative, ni après un refus du serveur',
        (tester) async {
      // Avant : le bouton WhatsApp ne montre aucun signalement.
      await pumpWaHost(tester, channel: channel, repo: repo);
      expect(find.byKey(const Key('whatsapp-report')), findsNothing);
      // Refus du serveur : pas de lien reçu, donc pas de signalement possible.
      repo.error = _refused('RATE_LIMITED', 429);
      await tapAndSettle(tester, find.byKey(kOpenWa));
      expect(find.byKey(const Key('whatsapp-error')), findsOneWidget);
      expect(find.byKey(const Key('whatsapp-report')), findsNothing);
      await tapAndSettle(tester, find.byKey(const Key('whatsapp-close')));
      expect(repo.reports, isEmpty);
    });

    test('WhatsappFlow.report() sans tentative préalable ne fait rien', () async {
      final container = ProviderContainer(overrides: callOverrides(channel, repo));
      addTearDown(container.dispose);
      await container.read(whatsappFlowProvider.notifier).report();
      expect(repo.reports, isEmpty);
      expect(container.read(whatsappFlowProvider).phase, WhatsappPhase.idle);
    });

    testWidgets('refus du serveur : un message simple par cas, WhatsApp n\'est pas ouvert',
        (tester) async {
      final cases = <ApiException, String>{
        _refused('RATE_LIMITED', 429):
            'Vous avez fait beaucoup de contacts. Réessayez un peu plus tard.',
        _refused('CHANNEL_UNAVAILABLE', 409): "WhatsApp n'est pas disponible pour ce commerce.",
        _refused('NOT_AUTHENTICATED', 401): 'Connectez-vous pour écrire à ce commerce.',
        _refused('ACCOUNT_BLOCKED', 403): 'Votre compte est bloqué. Contactez le support NetBuis.',
        _refused('BUSINESS_NOT_ACTIVE', 404): "Ce commerce n'est plus disponible.",
        _refused('OWN_BUSINESS', 403):
            "C'est votre propre commerce : vous ne pouvez pas lui écrire.",
        const ApiException(ApiErrorCode.network):
            'Pas de connexion. Vérifiez votre réseau et réessayez.',
        const ApiException(ApiErrorCode.unknown): "WhatsApp n'a pas pu être ouvert. Réessayez.",
      };
      for (final e in cases.entries) {
        repo.error = e.key;
        await pumpWaHost(tester, channel: channel, repo: repo);
        await tapAndSettle(tester, find.byKey(kOpenWa));
        expect(find.byKey(const Key('whatsapp-error')), findsOneWidget, reason: e.value);
        expect(find.text(e.value), findsOneWidget);
        expect(channel.whatsappOpened, isEmpty);
        expectNoPhoneOnScreen(tester);
        await tapAndSettle(tester, find.byKey(const Key('whatsapp-close')));
        expect(find.byKey(const Key('whatsapp-sheet')), findsNothing);
      }
    });

    testWidgets('le téléphone n\'arrive pas à ouvrir WhatsApp (échec natif ou exception)',
        (tester) async {
      for (final throwing in [false, true]) {
        channel
          ..whatsappResult = WhatsappOpenResult.failed
          ..throwOnWhatsapp = throwing;
        await pumpWaHost(tester, channel: channel, repo: repo);
        await tapAndSettle(tester, find.byKey(kOpenWa));
        expect(find.byKey(const Key('whatsapp-error')), findsOneWidget);
        expect(find.text("WhatsApp n'a pas pu être ouvert. Réessayez."), findsOneWidget);
        expect(find.byKey(const Key('whatsapp-report')), findsNothing);
        expectNoPhoneOnScreen(tester);
        await tapAndSettle(tester, find.byKey(const Key('whatsapp-close')));
      }
    });

    testWidgets('double toucher sur WhatsApp : un seul POST et une seule ouverture',
        (tester) async {
      await pumpWaHost(tester, channel: channel, repo: repo);
      await tester.tap(find.byKey(kOpenWa));
      await tester.tap(find.byKey(kOpenWa), warnIfMissed: false);
      await settleSheet(tester);
      await afterClose(tester);
      expect(repo.whatsappRequests, hasLength(1));
      expect(channel.whatsappOpened, hasLength(1));
    });

    testWidgets('iPhone : message honnête, aucun appel au serveur', (tester) async {
      await pumpWaHost(tester, channel: channel, repo: repo, platform: TargetPlatform.iOS);
      await tapAndSettle(tester, find.byKey(kOpenWa));
      expect(find.byKey(const Key('whatsapp-unsupported')), findsOneWidget);
      expect(repo.whatsappRequests, isEmpty);
      expect(channel.whatsappOpened, isEmpty);
      await tapAndSettle(tester, find.byKey(const Key('whatsapp-close')));
    });

    test('états : toString ne contient ni lien ni numéro', () {
      expect(const WhatsappFlowState().toString(), isNot(contains('wa.me')));
      expect(const CallFlowState().toString(), isNot(contains(kFakeDigits)));
    });
  });

  group('boutons WhatsApp des cartes et de la fiche', () {
    Future<void> pumpCard(WidgetTester tester, SearchResult r, {VoidCallback? onWhatsapp}) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: callOverrides(channel, repo),
        child: testApp(Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: ResultCard(result: r, onWhatsapp: onWhatsapp),
          ),
        )),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('carte : WhatsApp activé à côté d\'Appeler, appelle le rappel', (tester) async {
      var taps = 0;
      await pumpCard(tester, const SearchResult(id: 4, name: 'Pharmacie', kind: 'produit'),
          onWhatsapp: () => taps++);
      expect(find.text('Appeler'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Non disponible'), findsNothing);
      final b = tester.widget<OutlinedButton>(find.descendant(
          of: find.byKey(const Key('card-whatsapp')), matching: find.byType(OutlinedButton)));
      expect(b.onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('card-whatsapp')));
      expect(taps, 1);
      expect(tester.getSize(find.byKey(const Key('card-whatsapp'))).height, greaterThanOrEqualTo(48));
    });

    testWidgets('carte : whatsapp_available=false -> grisé avec « Non disponible »', (tester) async {
      var taps = 0;
      await pumpCard(
          tester,
          SearchResult.fromJson(const {
            'id': 4,
            'name': 'Pharmacie',
            'kind': 'produit',
            'whatsapp_available': false,
          }),
          onWhatsapp: () => taps++);
      expect(find.text('Non disponible'), findsOneWidget);
      final b = tester.widget<OutlinedButton>(find.descendant(
          of: find.byKey(const Key('card-whatsapp')), matching: find.byType(OutlinedButton)));
      expect(b.onPressed, isNull);
      await tester.tap(find.byKey(const Key('card-whatsapp')), warnIfMissed: false);
      expect(taps, 0);
    });

    test('SearchResult : whatsapp_available absent = disponible ; false = indisponible', () {
      expect(SearchResult.fromJson(const {'id': 1, 'name': 'A', 'kind': 'produit'}).whatsappAvailable,
          isTrue);
      expect(
          SearchResult.fromJson(
                  const {'id': 1, 'name': 'A', 'kind': 'produit', 'whatsapp_available': false})
              .whatsappAvailable,
          isFalse);
    });

    Future<void> pumpDetail(WidgetTester tester, int id) async {
      tester.view.physicalSize = const Size(360, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          publicBusinessRepositoryProvider.overrideWithValue(PublicBusinessRepositoryFake()),
          ...callOverrides(channel, repo),
        ],
        child: testApp(BusinessDetailScreen(businessId: id)),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('detail-whatsapp')), 300,
          scrollable: find.byType(Scrollable).first);
    }

    testWidgets('fiche publique : WhatsApp ouvre WhatsApp pour ce commerce, sans numéro affiché',
        (tester) async {
      await pumpDetail(tester, 1);
      expectNoPhoneOnScreen(tester);
      await tapAndSettle(tester, find.byKey(const Key('detail-whatsapp')));
      await afterClose(tester);
      expect(repo.whatsappRequests, [1]);
      expect(channel.whatsappOpened, [kFakeWaUrl]);
      expectNoPhoneOnScreen(tester);
    });

    testWidgets('fiche publique : whatsapp_available=false -> grisé « Non disponible », rien ne part',
        (tester) async {
      await pumpDetail(tester, 2);
      expect(find.text('WhatsApp · Non disponible'), findsOneWidget);
      await tester.tap(find.byKey(const Key('detail-whatsapp')), warnIfMissed: false);
      await settleSheet(tester);
      expect(find.byKey(const Key('whatsapp-sheet')), findsNothing);
      expect(repo.whatsappRequests, isEmpty);
    });
  });
}
