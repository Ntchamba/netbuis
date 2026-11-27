// Version factice (USE_FAKE_API) : aucun réseau. Reproduit les règles du serveur :
// un seul signalement par cible, pas de signalement de son propre commentaire, cible inconnue = 404,
// et un contenu signalé disparaît des fils factices.
import '../../../../core/network/api_exception.dart';
import '../models/report.dart';
import 'forum_feed_repository_fake.dart';
import 'report_repository.dart';

class ReportRepositoryFake implements ReportRepository {
  ReportRepositoryFake([this._feed]);

  final ForumFeedRepositoryFake? _feed;
  final Set<String> _done = {};

  @override
  Future<void> report(ReportTarget target, int id, ReportReason reason) async {
    final feed = _feed;
    if (feed != null) {
      final exists = switch (target) {
        ReportTarget.post => feed.hasPost(id),
        ReportTarget.comment => feed.hasComment(id),
        ReportTarget.business => true,
      };
      if (!exists) {
        throw const ApiException(ApiErrorCode.unknown,
            statusCode: 404, serverCode: 'not_found');
      }
      if (target == ReportTarget.comment && feed.isMyComment(id)) {
        throw const ApiException(ApiErrorCode.unknown,
            statusCode: 400, serverCode: 'own_content');
      }
    }
    if (!_done.add('${target.value}:$id')) {
      throw const ApiException(ApiErrorCode.unknown,
          statusCode: 409, serverCode: 'already_reported');
    }
    if (target == ReportTarget.post) feed?.hiddenPosts.add(id);
    if (target == ReportTarget.comment) feed?.hiddenComments.add(id);
  }
}
