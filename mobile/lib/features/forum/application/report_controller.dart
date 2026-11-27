// Signalements (T093) : envoi, et mémoire de la session de ce qui est déjà signalé par moi.
// Un contenu signalé n'est plus montré à celui qui l'a signalé : le fil et la page de la
// publication retirent ces contenus tout de suite ; le serveur les exclut aussi des rechargements.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../search/application/offline_controller.dart';
import '../data/models/report.dart';
import 'forum_services.dart';

/// Ce que j'ai signalé depuis le début de la session (identifiants seulement).
class ReportedState {
  const ReportedState({
    this.posts = const {},
    this.comments = const {},
    this.businesses = const {},
  });

  final Set<int> posts;
  final Set<int> comments;
  final Set<int> businesses;

  bool contains(ReportTarget target, int id) => switch (target) {
        ReportTarget.post => posts.contains(id),
        ReportTarget.comment => comments.contains(id),
        ReportTarget.business => businesses.contains(id),
      };
}

final reportsProvider =
    NotifierProvider<ReportsController, ReportedState>(ReportsController.new);

class ReportsController extends Notifier<ReportedState> {
  final Set<String> _inFlight = {};

  @override
  ReportedState build() {
    // Déconnexion : la mémoire de la session est oubliée.
    ref.listen(authControllerProvider, (_, next) {
      if (next is AuthLoggedOut) state = const ReportedState();
    });
    return const ReportedState();
  }

  /// Envoie le signalement. Renvoie null si le même est déjà en cours (double envoi ignoré).
  /// Succès, 409 (déjà signalé) et 404 (contenu disparu) : le contenu est retiré de mes listes.
  Future<ReportOutcome?> submit(
      ReportTarget target, int id, ReportReason reason) async {
    final key = '${target.value}:$id';
    if (!_inFlight.add(key)) return null;
    try {
      await ref.read(reportRepositoryProvider).report(target, id, reason);
      if (!ref.mounted) return ReportOutcome.done;
      ref.read(offlineProvider.notifier).set(false);
      _mark(target, id);
      return ReportOutcome.done;
    } on ApiException catch (e) {
      if (!ref.mounted) return _outcomeOf(e);
      final outcome = _outcomeOf(e);
      if (outcome == ReportOutcome.network) {
        ref.read(offlineProvider.notifier).set(true);
      }
      if (outcome == ReportOutcome.already) _mark(target, id);
      // Un commentaire ou une publication disparus sont retirés ; un commerce disparu ne l'est pas
      // (il n'est pas dans une liste que je peux vider ici).
      if (outcome == ReportOutcome.gone && target != ReportTarget.business) {
        _mark(target, id);
      }
      return outcome;
    } finally {
      _inFlight.remove(key);
    }
  }

  static ReportOutcome _outcomeOf(ApiException e) {
    if (e.code == ApiErrorCode.network) return ReportOutcome.network;
    if (e.statusCode == 409 || e.serverCode == 'already_reported') {
      return ReportOutcome.already;
    }
    if (e.serverCode == 'own_content') return ReportOutcome.own;
    if (e.statusCode == 404) return ReportOutcome.gone;
    return ReportOutcome.failed;
  }

  void _mark(ReportTarget target, int id) {
    final s = state;
    state = switch (target) {
      ReportTarget.post => ReportedState(
          posts: {...s.posts, id},
          comments: s.comments,
          businesses: s.businesses),
      ReportTarget.comment => ReportedState(
          posts: s.posts,
          comments: {...s.comments, id},
          businesses: s.businesses),
      ReportTarget.business => ReportedState(
          posts: s.posts,
          comments: s.comments,
          businesses: {...s.businesses, id}),
    };
  }
}
