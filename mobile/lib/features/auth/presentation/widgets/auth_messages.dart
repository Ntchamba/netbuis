// Messages d'erreur courts de la connexion
import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../application/auth_state.dart';

/// Durée lisible : « 45 s », « 10 min », « 1 h » (arrondie vers le haut).
String formatWait(L10n l10n, Duration wait) {
  final seconds = wait.inSeconds < 1 ? 1 : wait.inSeconds;
  if (seconds < 60) return l10n.t('auth.duration.seconds').replaceAll('{n}', '$seconds');
  final minutes = (seconds / 60).ceil();
  if (minutes < 60) return l10n.t('auth.duration.minutes').replaceAll('{n}', '$minutes');
  final hours = (minutes / 60).ceil();
  return l10n.t('auth.duration.hours').replaceAll('{n}', '$hours');
}

/// Message court et simple pour un échec de connexion. Les messages du serveur
/// ne sont pas affichés : seuls les textes traduits de l'application le sont.
String authFailureMessage(L10n l10n, AuthFailure failure) {
  switch (failure.code) {
    case ApiErrorCode.invalidPhone:
    case ApiErrorCode.invalid:
      return l10n.t('auth.error.phone');
    case ApiErrorCode.otpInvalid:
      return l10n.t('auth.error.otpInvalid');
    case ApiErrorCode.otpExpired:
      return l10n.t('auth.error.otpExpired');
    case ApiErrorCode.tooManyRequests:
      final wait = failure.retryAfter;
      if (wait == null) return l10n.t('auth.error.tooMany');
      return l10n.t('auth.error.tooManyWait').replaceAll('{duration}', formatWait(l10n, wait));
    case ApiErrorCode.accountBlocked:
    case ApiErrorCode.accountDeleted:
      return l10n.t('auth.error.support');
    case ApiErrorCode.network:
      return l10n.t('auth.error.network');
    case ApiErrorCode.tokenInvalid:
    case ApiErrorCode.unknown:
      return l10n.t('auth.error.unknown');
  }
}
