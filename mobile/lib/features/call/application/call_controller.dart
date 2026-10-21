// Déroulé d'un appel : autorisations -> choix de la ligne -> POST /calls/initiate/ -> appel natif.
// ZONE SENSIBLE : le numéro reçu passe de [CallRepository] à [CallChannel] dans [_run] et
// nulle part ailleurs : jamais dans l'état, jamais affiché, jamais journalisé.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../data/call_channel.dart';
import '../data/models/call_session.dart';
import '../data/repositories/call_repository.dart';
import '../data/repositories/call_repository_api.dart';
import '../data/repositories/call_repository_fake.dart';
import 'call_plan.dart';

/// Dépôt d'appel : factice si `USE_FAKE_API=true`, sinon relié à l'API.
final callRepositoryProvider = Provider<CallRepository>((ref) {
  if (Env.useFakeApi) return CallRepositoryFake();
  return CallRepositoryApi(ref.read(dioProvider));
});

/// Plateforme de l'appareil (remplaçable dans les tests). L'appel direct est Android seulement.
final callPlatformProvider = Provider<TargetPlatform>((ref) => defaultTargetPlatform);

/// Temps pendant lequel « Appel en cours… » reste affiché avant la fermeture.
final callCloseDelayProvider = Provider<Duration>((ref) => const Duration(milliseconds: 1500));

enum CallPhase {
  idle,

  /// Vérification des autorisations et lecture des lignes.
  preparing,

  /// Explication avant la demande Android (CALL_PHONE).
  rationale,

  /// Feuille « Avec quelle ligne voulez-vous appeler ? ».
  chooseLine,

  /// La ligne choisie n'existe pas dans ce téléphone ; on propose l'autre.
  lineAbsent,

  /// Repli : noms de SIM donnés par le système.
  pickSim,

  /// Repli : composeur du téléphone, avec avertissement.
  dialWarning,

  /// « Appel en cours… ».
  running,

  /// Refus ou panne : voir [CallFlowState.error].
  error,

  /// Appel d'iPhone / autre plateforme : pas disponible dans cette version.
  unsupported,

  /// Terminé : la feuille se ferme.
  done,
}

enum CallError {
  notAuthenticated,
  accountBlocked,
  businessNotActive,
  ownBusiness,
  rateLimited,
  channelUnavailable,
  network,
  generic,

  /// Le téléphone n'a pas pu lancer l'appel.
  placeFailed,
}

class CallFlowState {
  const CallFlowState({
    this.phase = CallPhase.idle,
    this.businessId = 0,
    this.businessName = '',
    this.line,
    this.runningLabel = '',
    this.absentLine,
    this.sims = const [],
    this.error,
  });

  final CallPhase phase;
  final int businessId;
  final String businessName;

  /// Ligne choisie (Orange / MTN), si elle est connue.
  final CallLine? line;

  /// Texte « ligne X » quand [line] est inconnue (nom de SIM donné par le système).
  final String runningLabel;

  /// Phase [CallPhase.lineAbsent] : la ligne demandée est [absentLine], on propose son autre.
  final CallLine? absentLine;
  final List<SimAccount> sims;
  final CallError? error;

  CallFlowState copyWith({
    CallPhase? phase,
    CallLine? line,
    String? runningLabel,
    CallLine? absentLine,
    List<SimAccount>? sims,
    CallError? error,
  }) =>
      CallFlowState(
        phase: phase ?? this.phase,
        businessId: businessId,
        businessName: businessName,
        line: line ?? this.line,
        runningLabel: runningLabel ?? this.runningLabel,
        absentLine: absentLine ?? this.absentLine,
        sims: sims ?? this.sims,
        error: error ?? this.error,
      );

  /// Vrai quand un appel est déjà en cours de traitement (protection du double clic).
  bool get busy => phase != CallPhase.idle;

  @override
  String toString() => 'CallFlowState($phase)';
}

final callFlowProvider = NotifierProvider<CallFlow, CallFlowState>(CallFlow.new);

/// Traduit un refus du serveur en message simple.
CallError callErrorFor(Object e) {
  if (e is! ApiException) return CallError.generic;
  switch (e.serverCode) {
    case 'NOT_AUTHENTICATED':
      return CallError.notAuthenticated;
    case 'ACCOUNT_BLOCKED':
      return CallError.accountBlocked;
    case 'BUSINESS_NOT_ACTIVE':
      return CallError.businessNotActive;
    case 'OWN_BUSINESS':
      return CallError.ownBusiness;
    case 'RATE_LIMITED':
      return CallError.rateLimited;
    case 'CHANNEL_UNAVAILABLE':
      return CallError.channelUnavailable;
  }
  if (e.code == ApiErrorCode.network) return CallError.network;
  switch (e.statusCode) {
    case 401:
      return CallError.notAuthenticated;
    case 429:
      return CallError.rateLimited;
    case 404:
      return CallError.businessNotActive;
  }
  return CallError.generic;
}

class CallFlow extends Notifier<CallFlowState> {
  bool _disposed = false;
  CallPlan? _plan;

  @override
  CallFlowState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return const CallFlowState();
  }

  void _set(CallFlowState s) {
    if (!_disposed) state = s;
  }

  /// Démarre un appel. Faux (et rien ne se passe) si un appel est déjà en cours :
  /// c'est la protection contre le double clic.
  bool begin(int businessId, String businessName) {
    if (state.busy) return false;
    _plan = null;
    _set(CallFlowState(
        phase: CallPhase.preparing, businessId: businessId, businessName: businessName));
    unawaited(_prepare());
    return true;
  }

  /// Après la fermeture de la feuille : prêt pour un nouvel appel (la ligne est redemandée, D-22).
  void reset() {
    _plan = null;
    _set(const CallFlowState());
  }

  Future<void> _prepare() async {
    if (ref.read(callPlatformProvider) != TargetPlatform.android) {
      _set(state.copyWith(phase: CallPhase.unsupported));
      return;
    }
    CallPermissions perms;
    try {
      perms = await ref.read(callChannelProvider).permissions();
    } on CallChannelException {
      _set(state.copyWith(phase: CallPhase.dialWarning));
      return;
    }
    if (perms.granted) {
      await _readSims();
    } else {
      _set(state.copyWith(phase: perms.asked ? CallPhase.dialWarning : CallPhase.rationale));
    }
  }

  /// « Continuer » après l'explication : Android affiche sa demande.
  Future<void> confirmRationale() async {
    if (state.phase != CallPhase.rationale) return;
    _set(state.copyWith(phase: CallPhase.preparing));
    var granted = false;
    try {
      granted = await ref.read(callChannelProvider).requestPermissions();
    } on CallChannelException {
      // Traité comme un refus : repli sur le composeur.
    }
    if (granted) {
      await _readSims();
    } else {
      _set(state.copyWith(phase: CallPhase.dialWarning));
    }
  }

  Future<void> _readSims() async {
    try {
      final plan = planFor(await ref.read(callChannelProvider).listSims());
      _plan = plan;
      switch (plan) {
        case PlanNoSim():
          _set(state.copyWith(phase: CallPhase.dialWarning));
        case PlanSingle(:final sim):
          // Une seule SIM : pas de question, l'appel part tout de suite.
          await _run(sim: sim, line: lineOf(sim));
        case PlanSheet():
          _set(state.copyWith(phase: CallPhase.chooseLine));
        case PlanNames(:final sims):
          _set(state.copyWith(phase: CallPhase.pickSim, sims: sims));
      }
    } on CallChannelException {
      _set(state.copyWith(phase: CallPhase.dialWarning));
    }
  }

  /// Le choix de la ligne EST la confirmation : l'appel part immédiatement.
  Future<void> chooseLine(CallLine line) async {
    final plan = _plan;
    if (state.phase != CallPhase.chooseLine || plan is! PlanSheet) return;
    final sim = plan.of(line);
    if (sim == null) {
      _set(state.copyWith(phase: CallPhase.lineAbsent, absentLine: line));
      return;
    }
    await _run(sim: sim, line: line);
  }

  /// « Appeler avec l'autre ligne » après [CallPhase.lineAbsent].
  Future<void> chooseOtherLine() async {
    final plan = _plan;
    final absent = state.absentLine;
    if (state.phase != CallPhase.lineAbsent || plan is! PlanSheet || absent == null) return;
    final other = absent.other;
    final sim = plan.of(other);
    if (sim == null) return;
    await _run(sim: sim, line: other);
  }

  /// Repli « noms de SIM » : l'utilisateur choisit la SIM par le nom du système.
  Future<void> pickSim(SimAccount sim) async {
    if (state.phase != CallPhase.pickSim) return;
    await _run(sim: sim, line: lineOf(sim), label: sim.displayName);
  }

  /// Avertissement lu : on ouvre le composeur du téléphone (le numéro y sera visible).
  Future<void> confirmDial() async {
    if (state.phase != CallPhase.dialWarning) return;
    await _run();
  }

  /// Annuler / fermer. Sans effet pendant la préparation ou l'appel.
  void cancel() {
    switch (state.phase) {
      case CallPhase.rationale:
      case CallPhase.chooseLine:
      case CallPhase.lineAbsent:
      case CallPhase.pickSim:
      case CallPhase.dialWarning:
      case CallPhase.error:
      case CallPhase.unsupported:
        _set(state.copyWith(phase: CallPhase.done));
      case CallPhase.idle:
      case CallPhase.preparing:
      case CallPhase.running:
      case CallPhase.done:
        break;
    }
  }

  /// [sim] null = repli composeur. Le numéro n'existe que dans cette méthode.
  Future<void> _run({SimAccount? sim, CallLine? line, String label = ''}) async {
    _set(state.copyWith(phase: CallPhase.running, line: line, runningLabel: label));
    final CallSession session;
    try {
      session = await ref
          .read(callRepositoryProvider)
          .initiate(businessId: state.businessId, line: line);
    } on Object catch (e) {
      _set(state.copyWith(phase: CallPhase.error, error: callErrorFor(e)));
      return;
    }
    bool ok;
    try {
      final channel = ref.read(callChannelProvider);
      if (sim == null) {
        ok = await channel.dial(session.phone);
      } else {
        ok = await channel.placeCall(phone: session.phone, accountId: sim.id) ==
            PlaceCallResult.placed;
      }
    } on Object {
      ok = false;
    }
    if (!ok) {
      _set(state.copyWith(phase: CallPhase.error, error: CallError.placeFailed));
      return;
    }
    await Future<void>.delayed(ref.read(callCloseDelayProvider));
    _set(state.copyWith(phase: CallPhase.done));
  }
}
