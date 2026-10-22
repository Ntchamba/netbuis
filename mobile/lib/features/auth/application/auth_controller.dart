// Contrôleur de la connexion
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/interceptors/refresh_interceptor.dart';
import 'auth_state.dart';
import 'session_cleaner.dart';

/// Délai avant de proposer « Renvoyer le code » (choix de l'application, le serveur n'en impose pas).
const Duration resendDelay = Duration(seconds: 30);

/// Horloge remplaçable dans les tests.
final authClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  String? _phone;

  /// Change à chaque action ; une restauration en retard ne doit pas écraser une action plus récente.
  int _epoch = 0;

  @override
  AuthState build() {
    _phone = null;
    final refresher = ref.read(sessionRefresherProvider);
    refresher.onRejected = _onSessionRejected;
    ref.onDispose(() {
      if (refresher.onRejected == _onSessionRejected) {
        refresher.onRejected = null;
      }
    });
    // Restauration au lancement ; l'état reste « en cours » jusqu'au résultat.
    unawaited(Future<void>.microtask(restoreSession));
    return const AuthLoading();
  }

  /// Session connectée si un jeton de rafraîchissement est stocké (sa validité
  /// réelle se vérifie au premier appel ou au rafraîchissement).
  /// N'écrase pas un état plus récent (l'utilisateur a déjà demandé un code).
  Future<void> restoreSession() async {
    final startedAt = _epoch;
    AuthState restored;
    try {
      final tokens = await ref.read(tokenStorageProvider).read();
      restored =
          tokens.hasRefresh ? const AuthAuthenticated() : const AuthLoggedOut();
    } on Object {
      // Stockage illisible : on repart d'une session vide.
      restored = const AuthLoggedOut();
    }
    if (ref.mounted && _epoch == startedAt) {
      _epoch++;
      state = restored;
    }
  }

  /// Demande un code SMS. Sert aussi pour « Renvoyer le code ».
  Future<void> requestOtp(String phone) async {
    _epoch++;
    state = const AuthLoading();
    try {
      final result = await ref.read(authRepositoryProvider).requestOtp(phone);
      _phone = phone;
      final now = ref.read(authClockProvider)();
      state = AuthCodeSent(
        expiresIn: result.expiresIn,
        expiresAt: now.add(result.expiresIn),
        resendAvailableAt: now.add(resendDelay),
      );
    } on ApiException catch (e) {
      state = _failure(e, hasPendingCode: false);
    } on Object {
      state = const AuthFailure(ApiErrorCode.unknown);
    }
  }

  /// Vérifie le code saisi pour le numéro de la dernière demande.
  Future<void> verifyOtp(String code) async {
    _epoch++;
    final phone = _phone;
    if (phone == null) {
      state = const AuthFailure(ApiErrorCode.invalidPhone);
      return;
    }
    state = const AuthLoading();
    try {
      final tokens = await ref
          .read(authRepositoryProvider)
          .verifyOtp(phone: phone, code: code);
      await ref
          .read(tokenStorageProvider)
          .save(access: tokens.access, refresh: tokens.refresh);
      _phone = null;
      state = AuthAuthenticated(isNew: tokens.isNew);
    } on ApiException catch (e) {
      // Un code faux ou expiré laisse la saisie ouverte ; les autres erreurs (blocage…) aussi.
      state = _failure(e, hasPendingCode: true);
    } on Object {
      state = const AuthFailure(ApiErrorCode.unknown, hasPendingCode: true);
    }
  }

  /// Renouvelle les jetons (code partagé avec l'intercepteur : voir SessionRefresher).
  /// Renvoie vrai si la session reste ouverte. Réseau coupé : la session est conservée.
  Future<bool> refreshSession() async =>
      await ref.read(sessionRefresherProvider).refresh() !=
      RefreshOutcome.rejected;

  /// Session fermée par le renouvellement : l'état change et la garde renvoie vers /login.
  void _onSessionRejected(ApiException? reason) {
    if (!ref.mounted) return;
    if (reason == null || reason.code == ApiErrorCode.tokenInvalid) {
      clearSessionData(ref);
      state = const AuthLoggedOut();
    } else {
      state = _failure(reason, hasPendingCode: false);
    }
  }

  /// Déconnexion : prévient le serveur si possible, puis efface les jetons dans tous les cas.
  Future<void> logout() async {
    _epoch++;
    final storage = ref.read(tokenStorageProvider);
    state = const AuthLoading();
    try {
      final refresh = (await storage.read()).refresh;
      if (refresh != null && refresh.isNotEmpty) {
        await ref.read(authRepositoryProvider).logout(refresh);
      }
    } on Object {
      // Réseau coupé, jeton déjà invalide… : l'effacement local a lieu quand même.
    } finally {
      await storage.clear();
      clearSessionData(ref);
      _phone = null;
      state = const AuthLoggedOut();
    }
  }

  /// Revient à l'écran du numéro (ex. « Changer de numéro »).
  void reset() {
    _epoch++;
    _phone = null;
    state = const AuthLoggedOut();
  }

  AuthFailure _failure(ApiException e, {required bool hasPendingCode}) =>
      AuthFailure(
        e.code,
        message: e.message,
        retryAfter: e.retryAfter,
        hasPendingCode: hasPendingCode,
      );
}
