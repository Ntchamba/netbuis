// Renouvellement de la session : un seul code, partagé par l'intercepteur et AuthController
import '../../../core/network/api_exception.dart';
import '../../../core/network/interceptors/refresh_interceptor.dart';
import '../../../core/storage/secure_storage.dart';
import '../data/models/auth_tokens.dart';

/// Renouvelle les jetons (rotation : le nouveau refresh remplace l'ancien) ;
/// les appels simultanés partagent un seul appel réseau.
class SessionRefresher {
  SessionRefresher({
    required TokenStorage storage,
    required Future<AuthTokens> Function(String refreshToken) callRefresh,
  })  : _storage = storage,
        _callRefresh = callRefresh;

  final TokenStorage _storage;
  final Future<AuthTokens> Function(String refreshToken) _callRefresh;

  /// Appelé quand la session est fermée : l'erreur du serveur, ou null s'il n'y avait plus de jeton.
  void Function(ApiException? reason)? onRejected;

  Future<RefreshOutcome>? _inFlight;

  Future<RefreshOutcome> refresh() =>
      _inFlight ??= _run().whenComplete(() => _inFlight = null);

  Future<RefreshOutcome> _run() async {
    final stored = await _storage.read();
    final refresh = stored.refresh;
    if (refresh == null || refresh.isEmpty) {
      onRejected?.call(null);
      return RefreshOutcome.rejected;
    }
    try {
      final tokens = await _callRefresh(refresh);
      await _storage.save(access: tokens.access, refresh: tokens.refresh);
      return RefreshOutcome.renewed;
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.network) return RefreshOutcome.offline;
      await _storage.clear();
      onRejected?.call(e);
      return RefreshOutcome.rejected;
    }
  }
}
