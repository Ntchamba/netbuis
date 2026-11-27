import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/features/forum/data/models/report.dart';
import 'package:netbuis/features/forum/data/repositories/forum_feed_repository_fake.dart';
import 'package:netbuis/features/forum/data/repositories/report_repository_api.dart';
import 'package:netbuis/features/forum/data/repositories/report_repository_fake.dart';

import '../auth/auth_test_helpers.dart';

void main() {
  group('dépôt réel (faux serveur)', () {
    ReportRepositoryApi api(FakeAdapter adapter) =>
        ReportRepositoryApi(Dio(BaseOptions(baseUrl: 'http://test/api'))
          ..httpClientAdapter = adapter);

    test('POST /reports/ : target_type, target_id et reason, rien d\'autre',
        () async {
      final adapter = FakeAdapter((r) => FakeAdapter.reply(
          201, {'target_type': 'comment', 'target_id': 9, 'reason': 'spam'}));
      await api(adapter).report(ReportTarget.comment, 9, ReportReason.spam);
      final seen = adapter.seen.single;
      expect(seen.method, 'POST');
      expect(seen.path, '/reports/');
      expect(seen.body,
          {'target_type': 'comment', 'target_id': 9, 'reason': 'spam'});
    });

    test('les 3 cibles et les 4 motifs ont les valeurs de l\'API', () {
      expect([for (final t in ReportTarget.values) t.value],
          ['post', 'comment', 'business']);
      expect([for (final r in ReportReason.values) r.value],
          ['spam', 'arnaque', 'contenu_inapproprie', 'autre']);
    });

    test('400 own_content, 404, 409 : ApiException avec statut et code',
        () async {
      for (final (status, code) in [
        (400, 'own_content'),
        (404, 'not_found'),
        (409, 'already_reported'),
      ]) {
        final adapter =
            FakeAdapter((r) => FakeAdapter.reply(status, {'code': code}));
        await expectLater(
          api(adapter).report(ReportTarget.post, 1, ReportReason.autre),
          throwsA(isA<ApiException>()
              .having((e) => e.statusCode, 'status', status)
              .having((e) => e.serverCode, 'code', code)),
        );
      }
    });
  });

  group('dépôt factice (USE_FAKE_API)', () {
    test('un seul signalement par cible : le second donne 409', () async {
      final fake = ReportRepositoryFake(ForumFeedRepositoryFake());
      await fake.report(ReportTarget.business, 5, ReportReason.spam);
      await expectLater(
        fake.report(ReportTarget.business, 5, ReportReason.autre),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 409)),
      );
    });

    test('publication signalée : exclue du fil factice ; inconnue : 404',
        () async {
      final feed = ForumFeedRepositoryFake();
      final fake = ReportRepositoryFake(feed);
      await fake.report(ReportTarget.post, 1, ReportReason.arnaque);
      expect((await feed.feed()).items.any((p) => p.id == 1), isFalse);
      await expectLater(feed.getPost(1), throwsA(isA<ApiException>()));
      await expectLater(
        fake.report(ReportTarget.post, 999, ReportReason.spam),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 404)),
      );
    });

    test('commentaire : exclu des commentaires ; le mien : 400 own_content',
        () async {
      final feed = ForumFeedRepositoryFake();
      final fake = ReportRepositoryFake(feed);
      await fake.report(ReportTarget.comment, 1, ReportReason.spam);
      expect((await feed.comments(1)).items.any((c) => c.id == 1), isFalse);
      final mine = await feed.addComment(2, 'Bonjour');
      await expectLater(
        fake.report(ReportTarget.comment, mine.id, ReportReason.spam),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 's', 400)
            .having((e) => e.serverCode, 'c', 'own_content')),
      );
    });
  });
}
