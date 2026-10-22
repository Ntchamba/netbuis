// Appel à l'équipe NetBuis (D-25) : micro -> POST /calls/sessions/ -> salle Jitsi rejointe dès
// l'envoi -> suivi de l'état (flux temps réel, repli par consultation) -> fin.
// ZONE SENSIBLE : la salle et le jeton Jitsi passent du dépôt au service Jitsi dans [_createSession]
// et nulle part ailleurs : jamais dans l'état, jamais affichés, jamais journalisés. Aucun numéro
// de commerçant n'existe dans ce parcours.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../data/call_channel.dart';
import '../data/jitsi_service.dart';
import '../data/models/call_session.dart';
import '../data/repositories/call_repository.dart';
import '../data/repositories/call_repository_api.dart';
import '../data/repositories/call_repository_fake.dart';

/// Dépôt d'appel : factice si `USE_FAKE_API=true`, sinon relié à l'API.
final callRepositoryProvider = Provider<CallRepository>((ref) {
  if (Env.useFakeApi) return CallRepositoryFake();
  return CallRepositoryApi(ref.read(dioProvider));
});

/// Plateforme de l'appareil (remplaçable dans les tests). L'appel est Android seulement (V07).
final callPlatformProvider = Provider<TargetPlatform>((ref) => defaultTargetPlatform);

/// Intervalle de la consultation de repli quand le flux temps réel est coupé.
final callPollIntervalProvider = Provider<Duration>((ref) => const Duration(seconds: 2));

/// Nombre d'échecs de consultation de suite avant de déclarer la connexion perdue.
const int kCallPollFailuresBeforeLost = 5;

enum CallPhase {
  idle,

  /// Vérification du micro, puis création de la session.
  preparing,

  /// Explication avant la demande Android (RECORD_AUDIO).
  micRationale,

  /// Micro refusé : l'appel ne peut pas partir.
  micDenied,

  /// « Appel en cours... » : l'équipe sonne, la salle est rejointe, [CallFlowState.seconds] compte.
  ringing,

  /// L'équipe a répondu : conversation en cours, [CallFlowState.seconds] compte depuis la réponse.
  connected,

  /// Appel terminé (par l'équipe ou par l'utilisateur).
  ended,

  /// Personne n'est disponible : réponse immédiate du serveur.
  unavailable,

  /// Sonnerie sans réponse.
  missed,

  /// L'équipe a refusé.
  declined,

  /// Refus ou panne : voir [CallFlowState.error].
  error,

  /// iPhone / autre plateforme : pas disponible dans cette version.
  unsupported,

  /// Terminé : l'écran d'appel se ferme.
  done,
}

enum CallError {
  notAuthenticated,
  accountBlocked,
  businessNotActive,
  ownBusiness,
  rateLimited,
  channelUnavailable,

  /// Jitsi n'est pas configuré côté serveur (503).
  serviceUnavailable,

  /// Une session de cet utilisateur est encore en cours (409).
  alreadyActive,
  network,
  generic,

  /// La salle n'a pas pu être rejointe (SDK, jeton refusé, serveur Jitsi injoignable).
  joinFailed,

  /// Le réseau a été coupé pendant l'appel.
  connectionLost,

  /// Le téléphone n'a pas pu ouvrir WhatsApp.
  whatsappFailed,
}

class CallFlowState {
  const CallFlowState({
    this.phase = CallPhase.idle,
    this.businessId = 0,
    this.businessName = '',
    this.error,
    this.seconds = 0,
  });

  final CallPhase phase;
  final int businessId;
  final String businessName;
  final CallError? error;

  /// Minuteur : secondes de sonnerie (phase [CallPhase.ringing]) ou de conversation
  /// ([CallPhase.connected], [CallPhase.ended]).
  final int seconds;

  CallFlowState copyWith({CallPhase? phase, CallError? error, int? seconds}) =>
      CallFlowState(
        phase: phase ?? this.phase,
        businessId: businessId,
        businessName: businessName,
        error: error ?? this.error,
        seconds: seconds ?? this.seconds,
      );

  /// Vrai quand un appel est déjà en cours de traitement (protection du double clic).
  bool get busy => phase != CallPhase.idle;

  /// Vrai tant que l'appel est vivant (liaison, sonnerie ou conversation).
  bool get live =>
      phase == CallPhase.preparing ||
      phase == CallPhase.ringing ||
      phase == CallPhase.connected;

  @override
  String toString() => 'CallFlowState($phase)';
}

final callFlowProvider = NotifierProvider<CallFlow, CallFlowState>(CallFlow.new);

/// Traduit un refus du serveur en message simple.
CallError callErrorFor(Object e) {
  if (e is ActiveCallException) return CallError.alreadyActive;
  if (e is! ApiException) return CallError.generic;
  switch (e.serverCode) {
    case 'NOT_AUTHENTICATED':
      return CallError.notAuthenticated;
    case 'ACCOUNT_BLOCKED':
    case 'account_blocked':
      return CallError.accountBlocked;
    case 'BUSINESS_NOT_ACTIVE':
      return CallError.businessNotActive;
    case 'OWN_BUSINESS':
      return CallError.ownBusiness;
    case 'RATE_LIMITED':
      return CallError.rateLimited;
    case 'CHANNEL_UNAVAILABLE':
      return CallError.channelUnavailable;
    case 'jitsi_not_configured':
      return CallError.serviceUnavailable;
  }
  if (e.code == ApiErrorCode.network) return CallError.network;
  switch (e.statusCode) {
    case 401:
      return CallError.notAuthenticated;
    case 429:
      return CallError.rateLimited;
    case 404:
      return CallError.businessNotActive;
    case 503:
      return CallError.serviceUnavailable;
  }
  return CallError.generic;
}

class CallFlow extends Notifier<CallFlowState> {
  bool _disposed = false;
  String? _sessionId;
  Timer? _ticker;
  Timer? _poller;
  StreamSubscription<CallStatus>? _watch;
  StreamSubscription<JitsiEvent>? _jitsiEvents;
  int _pollFailures = 0;
  bool _minimized = false;

  @override
  CallFlowState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _stopWatching();
    });
    return const CallFlowState();
  }

  void _set(CallFlowState s) {
    if (!_disposed) state = s;
  }

  CallRepository get _repo => ref.read(callRepositoryProvider);
  JitsiService get _jitsi => ref.read(jitsiServiceProvider);

  /// Démarre un appel à l'équipe. Faux (et rien ne se passe) si un appel est déjà en cours :
  /// c'est la protection contre le double clic.
  bool begin(int businessId, String businessName) {
    if (state.busy) return false;
    _set(CallFlowState(
        phase: CallPhase.preparing, businessId: businessId, businessName: businessName));
    unawaited(_prepare());
    return true;
  }

  /// Après la fermeture de l'écran : prêt pour un nouvel appel. Si l'appel vivait encore, il est
  /// raccroché des deux côtés.
  void reset() {
    if (state.live) _leaveSilently();
    _stopWatching();
    _sessionId = null;
    _set(const CallFlowState());
  }

  // --- Micro -------------------------------------------------------------------------------

  Future<void> _prepare() async {
    if (ref.read(callPlatformProvider) != TargetPlatform.android) {
      _set(state.copyWith(phase: CallPhase.unsupported));
      return;
    }
    MicPermission mic;
    try {
      mic = await ref.read(callChannelProvider).microphone();
    } on Object {
      _set(state.copyWith(phase: CallPhase.error, error: CallError.generic));
      return;
    }
    if (mic.granted) {
      await _createSession();
    } else {
      _set(state.copyWith(
          phase: mic.asked ? CallPhase.micDenied : CallPhase.micRationale));
    }
  }

  /// « Continuer » après l'explication, ou « Réessayer » après un refus : Android affiche sa demande.
  Future<void> requestMicrophone() async {
    if (state.phase != CallPhase.micRationale && state.phase != CallPhase.micDenied) {
      return;
    }
    _set(state.copyWith(phase: CallPhase.preparing));
    var granted = false;
    try {
      granted = await ref.read(callChannelProvider).requestMicrophone();
    } on Object {
      // Traité comme un refus.
    }
    if (granted) {
      await _createSession();
    } else {
      _set(state.copyWith(phase: CallPhase.micDenied));
    }
  }

  // --- Création de la session et salle -----------------------------------------------------

  Future<void> _createSession() async {
    final CallStart start;
    try {
      start = await _repo.startSession(businessId: state.businessId);
    } on ActiveCallException catch (e) {
      // Une session oubliée (application fermée en plein appel) : on la ferme pour que le
      // prochain essai passe.
      if (e.sessionId.isNotEmpty) await _release(e.sessionId);
      _set(state.copyWith(phase: CallPhase.error, error: CallError.alreadyActive));
      return;
    } on Object catch (e) {
      _set(state.copyWith(phase: CallPhase.error, error: callErrorFor(e)));
      return;
    }
    if (_disposed) return;
    if (start.state.isFinal) {
      _set(state.copyWith(phase: _phaseOf(start.state)));
      return;
    }
    final access = start.jitsi;
    if (access == null) {
      _set(state.copyWith(phase: CallPhase.error, error: CallError.generic));
      return;
    }
    _sessionId = start.sessionId;
    _pollFailures = 0;
    _minimized = false;
    _set(state.copyWith(phase: CallPhase.ringing, seconds: 0));
    _startTicker();
    _listen(start.sessionId);
    _jitsiEvents?.cancel();
    _jitsiEvents = _jitsi.events.listen(_onJitsi);
    final joined = await _jitsi.join(access);
    if (!joined && state.live) {
      await _fail(CallError.joinFailed);
    }
  }

  CallPhase _phaseOf(CallState s) => switch (s) {
        CallState.ringing => CallPhase.ringing,
        CallState.answered => CallPhase.connected,
        CallState.ended => CallPhase.ended,
        CallState.missed => CallPhase.missed,
        CallState.declined => CallPhase.declined,
        CallState.unavailable => CallPhase.unavailable,
        CallState.cancelled => CallPhase.done,
      };

  /// Ferme une session restée ouverte : annulation si elle sonne, sinon raccrochage.
  Future<void> _release(String sessionId) async {
    try {
      await _repo.cancel(sessionId);
    } on Object {
      try {
        await _repo.end(sessionId);
      } on Object {
        // Le serveur la fermera de lui-même (sonnerie expirée, durée maximale).
      }
    }
  }

  // --- Suivi de l'état ---------------------------------------------------------------------

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.phase == CallPhase.ringing || state.phase == CallPhase.connected) {
        _set(state.copyWith(seconds: state.seconds + 1));
      }
    });
  }

  void _listen(String sessionId) {
    _watch?.cancel();
    _watch = _repo.watch(sessionId).listen(
          _onStatus,
          onError: (Object _) => _startPolling(sessionId),
          onDone: () {
            if (state.phase == CallPhase.ringing || state.phase == CallPhase.connected) {
              _startPolling(sessionId);
            }
          },
          cancelOnError: true,
        );
  }

  /// Repli : consultation courte tant que le flux est coupé.
  void _startPolling(String sessionId) {
    if (_poller != null || _disposed) return;
    _poller = Timer.periodic(ref.read(callPollIntervalProvider), (_) async {
      if (!state.live) return;
      try {
        _onStatus(await _repo.status(sessionId));
        _pollFailures = 0;
      } on Object {
        _pollFailures++;
        if (_pollFailures >= kCallPollFailuresBeforeLost && state.live) {
          await _fail(CallError.connectionLost);
        }
      }
    });
  }

  void _onStatus(CallStatus s) {
    if (_disposed) return;
    final phase = state.phase;
    if (phase != CallPhase.ringing && phase != CallPhase.connected) return;
    switch (s.state) {
      case CallState.ringing:
        break;
      case CallState.answered:
        if (phase == CallPhase.ringing) {
          _set(state.copyWith(phase: CallPhase.connected, seconds: 0));
        }
      case CallState.ended:
      case CallState.missed:
      case CallState.declined:
      case CallState.unavailable:
      case CallState.cancelled:
        _stopWatching();
        unawaited(_jitsi.hangUp());
        _set(state.copyWith(phase: _phaseOf(s.state)));
    }
  }

  void _onJitsi(JitsiEvent e) {
    if (_disposed || !state.live) return;
    switch (e) {
      case JitsiEvent.joined:
        if (!_minimized) {
          _minimized = true;
          unawaited(_jitsi.minimize());
        }
      case JitsiEvent.left:
        // L'utilisateur a quitté depuis l'écran Jitsi : c'est un raccrochage.
        unawaited(hangUp());
      case JitsiEvent.failed:
        unawaited(_fail(CallError.joinFailed));
    }
  }

  void _stopWatching() {
    _ticker?.cancel();
    _ticker = null;
    _poller?.cancel();
    _poller = null;
    _watch?.cancel();
    _watch = null;
    _jitsiEvents?.cancel();
    _jitsiEvents = null;
  }

  /// Panne pendant l'appel : on raccroche la salle et on prévient le serveur si on peut.
  Future<void> _fail(CallError error) async {
    final id = _sessionId;
    _stopWatching();
    unawaited(_jitsi.hangUp());
    _set(state.copyWith(phase: CallPhase.error, error: error));
    if (id != null) await _release(id);
  }

  /// Fermeture sans changer l'écran (écran déjà parti).
  void _leaveSilently() {
    final id = _sessionId;
    unawaited(_jitsi.hangUp());
    if (id != null) unawaited(_release(id));
  }

  // --- Actions de l'utilisateur ------------------------------------------------------------

  /// « Annuler » pendant la sonnerie. Si l'équipe vient de répondre, l'appel est raccroché.
  Future<void> cancel() async {
    if (state.phase != CallPhase.ringing) return;
    final id = _sessionId;
    _stopWatching();
    unawaited(_jitsi.hangUp());
    _set(state.copyWith(phase: CallPhase.done));
    if (id == null) return;
    try {
      await _repo.cancel(id);
    } on ApiException catch (e) {
      if (e.serverCode == 'call_not_ringing') {
        try {
          await _repo.end(id);
        } on Object {
          // Le serveur fermera l'appel de lui-même.
        }
      }
    } on Object {
      // Pas de réseau : la sonnerie expire côté serveur.
    }
  }

  /// « Raccrocher » pendant la conversation (ou sortie de l'écran Jitsi).
  Future<void> hangUp() async {
    final phase = state.phase;
    if (phase == CallPhase.ringing) return cancel();
    if (phase != CallPhase.connected) return;
    final id = _sessionId;
    final seconds = state.seconds;
    _stopWatching();
    unawaited(_jitsi.hangUp());
    _set(state.copyWith(phase: CallPhase.ended, seconds: seconds));
    if (id == null) return;
    try {
      await _repo.end(id);
    } on Object {
      // Le serveur fermera l'appel de lui-même (salle vide, durée maximale).
    }
  }

  /// Fermer l'écran d'un état final ou d'une erreur. Sans effet pendant l'appel.
  void close() {
    if (state.live || state.phase == CallPhase.idle) return;
    _set(state.copyWith(phase: CallPhase.done));
  }
}

// ---------------------------------------------------------------------------------------------
// WhatsApp : POST /calls/whatsapp/ -> ouverture du lien wa.me par le code natif.
// ZONE SENSIBLE : le lien reçu contient le numéro. Il passe de [CallRepository] à [CallChannel]
// dans [WhatsappFlow._open] et nulle part ailleurs : jamais dans l'état, affiché, journalisé.
// ---------------------------------------------------------------------------------------------

enum WhatsappPhase {
  idle,

  /// Demande au serveur, puis ouverture de WhatsApp.
  opening,

  /// WhatsApp est absent du téléphone : message + possibilité de signaler « pas de WhatsApp ».
  notInstalled,

  /// Envoi du signalement.
  reporting,

  /// Signalement enregistré.
  reported,

  /// Refus ou panne : voir [WhatsappFlowState.error].
  error,

  /// iPhone / autre plateforme : pas disponible dans cette version.
  unsupported,

  /// Terminé : la feuille se ferme.
  done,
}

class WhatsappFlowState {
  const WhatsappFlowState({
    this.phase = WhatsappPhase.idle,
    this.businessId = 0,
    this.businessName = '',
    this.error,
    this.reportFailed = false,
  });

  final WhatsappPhase phase;
  final int businessId;
  final String businessName;
  final CallError? error;

  /// Le dernier envoi du signalement a échoué (on peut réessayer).
  final bool reportFailed;

  WhatsappFlowState copyWith(
          {WhatsappPhase? phase, CallError? error, bool? reportFailed}) =>
      WhatsappFlowState(
        phase: phase ?? this.phase,
        businessId: businessId,
        businessName: businessName,
        error: error ?? this.error,
        reportFailed: reportFailed ?? this.reportFailed,
      );

  /// Vrai quand une ouverture est déjà en cours (protection du double clic).
  bool get busy => phase != WhatsappPhase.idle;

  @override
  String toString() => 'WhatsappFlowState($phase)';
}

final whatsappFlowProvider =
    NotifierProvider<WhatsappFlow, WhatsappFlowState>(WhatsappFlow.new);

class WhatsappFlow extends Notifier<WhatsappFlowState> {
  bool _disposed = false;

  @override
  WhatsappFlowState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const WhatsappFlowState();
  }

  void _set(WhatsappFlowState s) {
    if (!_disposed) state = s;
  }

  /// Démarre l'ouverture de WhatsApp. Faux (et rien ne se passe) si une est déjà en cours.
  bool begin(int businessId, String businessName) {
    if (state.busy) return false;
    _set(WhatsappFlowState(
        phase: WhatsappPhase.opening,
        businessId: businessId,
        businessName: businessName));
    unawaited(_open());
    return true;
  }

  /// Après la fermeture de la feuille : prêt pour une nouvelle ouverture.
  void reset() => _set(const WhatsappFlowState());

  Future<void> _open() async {
    if (ref.read(callPlatformProvider) != TargetPlatform.android) {
      _set(state.copyWith(phase: WhatsappPhase.unsupported));
      return;
    }
    final WhatsappLink link;
    try {
      link = await ref
          .read(callRepositoryProvider)
          .initiateWhatsapp(businessId: state.businessId);
    } on Object catch (e) {
      _set(state.copyWith(phase: WhatsappPhase.error, error: callErrorFor(e)));
      return;
    }
    WhatsappOpenResult result;
    try {
      result = await ref.read(callChannelProvider).openWhatsapp(link.url);
    } on Object {
      result = WhatsappOpenResult.failed;
    }
    switch (result) {
      case WhatsappOpenResult.opened:
        _set(state.copyWith(phase: WhatsappPhase.done));
      case WhatsappOpenResult.notInstalled:
        _set(state.copyWith(phase: WhatsappPhase.notInstalled));
      case WhatsappOpenResult.failed:
        _set(state.copyWith(
            phase: WhatsappPhase.error, error: CallError.whatsappFailed));
    }
  }

  /// « Ce commerce n'a pas WhatsApp » : possible seulement après une tentative (le serveur exige
  /// d'avoir reçu le lien).
  Future<void> report() async {
    if (state.phase != WhatsappPhase.notInstalled) return;
    _set(state.copyWith(phase: WhatsappPhase.reporting, reportFailed: false));
    try {
      await ref
          .read(callRepositoryProvider)
          .reportNoWhatsapp(businessId: state.businessId);
      _set(state.copyWith(phase: WhatsappPhase.reported));
    } on Object {
      _set(state.copyWith(
          phase: WhatsappPhase.notInstalled, reportFailed: true));
    }
  }

  /// Fermer. Sans effet pendant l'ouverture ou l'envoi.
  void cancel() {
    switch (state.phase) {
      case WhatsappPhase.notInstalled:
      case WhatsappPhase.reported:
      case WhatsappPhase.error:
      case WhatsappPhase.unsupported:
        _set(state.copyWith(phase: WhatsappPhase.done));
      case WhatsappPhase.idle:
      case WhatsappPhase.opening:
      case WhatsappPhase.reporting:
      case WhatsappPhase.done:
        break;
    }
  }
}

