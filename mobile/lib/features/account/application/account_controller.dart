// Contrôleur du profil
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../data/models/me.dart';

/// Profil de la personne connectée. L'état est détruit quand plus aucun écran
/// ne l'écoute (donc rechargé après une déconnexion puis une nouvelle connexion).
final accountControllerProvider =
    AsyncNotifierProvider.autoDispose<AccountController, Me>(
        AccountController.new);

class AccountController extends AsyncNotifier<Me> {
  @override
  Future<Me> build() => ref.read(accountRepositoryProvider).getMe();

  /// Recharge le profil (bouton « Réessayer »).
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(accountRepositoryProvider).getMe());
  }

  /// Envoie le nom. Renvoie `null` en cas de succès, sinon l'erreur ; en cas
  /// d'échec le profil affiché ne change pas.
  Future<ApiException?> updateName(String name) async {
    try {
      final me = await ref.read(accountRepositoryProvider).updateName(name);
      if (ref.mounted) state = AsyncData(me);
      return null;
    } on ApiException catch (e) {
      return e;
    } on Object {
      return const ApiException(ApiErrorCode.unknown);
    }
  }

  /// DELETE /api/me/. Renvoie `null` en cas de succès, sinon l'erreur ; rien n'est effacé
  /// ici (la déconnexion locale est faite par l'écran, seulement après un succès).
  Future<ApiException?> deleteAccount() async {
    try {
      await ref.read(accountRepositoryProvider).deleteAccount();
      return null;
    } on ApiException catch (e) {
      return e;
    } on Object {
      return const ApiException(ApiErrorCode.unknown);
    }
  }
}
