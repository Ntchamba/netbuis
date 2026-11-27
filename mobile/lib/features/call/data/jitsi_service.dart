// Service Jitsi derrière une interface : le vrai SDK (jitsi_meet_flutter_sdk) en production, un
// faux dans les tests (la salle réelle n'est pas testable sans téléphone).
// ZONE SENSIBLE : la salle et le jeton ([JitsiAccess]) ne sont ni journalisés, ni stockés, ni
// mis dans une erreur ; aucun `print` / `debugPrint` dans ce fichier.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

import '../../../core/config/env.dart';
import 'models/call_session.dart';

/// Ce que le service raconte de la salle.
enum JitsiEvent {
  /// La liaison avec la salle est établie.
  joined,

  /// L'utilisateur a quitté la salle (ou la salle s'est fermée sans erreur).
  left,

  /// La salle a refusé ou perdu la liaison (jeton refusé, serveur injoignable…).
  failed,
}

abstract class JitsiService {
  /// Flux des événements de la salle en cours (diffusion : plusieurs écoutes possibles).
  Stream<JitsiEvent> get events;

  /// Rejoint la salle : audio seul, micro actif, vidéo coupée. Faux si le SDK n'a pas pu démarrer.
  Future<bool> join(JitsiAccess access);

  /// Réduit l'écran Jitsi (image dans l'image) pour laisser voir l'écran d'appel NetBuis.
  /// Sans effet si le téléphone ne sait pas le faire.
  Future<void> minimize();

  /// Quitte la salle.
  Future<void> hangUp();
}

/// Réglages de la salle pour l'appel à l'équipe : audio seul, rien d'autre que parler.
const Map<String, Object?> kJitsiConfig = {
  'startWithAudioMuted': false,
  'startWithVideoMuted': true,
  'startAudioOnly': true,
  'subject': 'NetBuis',
};

/// Fonctions Jitsi coupées : l'appel n'a besoin ni d'invitation, ni de discussion, ni d'enregistrement,
/// ni de partage d'écran, ni d'intégration au téléphone (qui demanderait d'autres permissions).
const Map<String, Object?> kJitsiFeatureFlags = {
  FeatureFlags.preJoinPageEnabled: false,
  FeatureFlags.welcomePageEnabled: false,
  FeatureFlags.callIntegrationEnabled: false,
  FeatureFlags.inviteEnabled: false,
  FeatureFlags.addPeopleEnabled: false,
  FeatureFlags.chatEnabled: false,
  FeatureFlags.recordingEnabled: false,
  FeatureFlags.liveStreamingEnabled: false,
  FeatureFlags.androidScreenSharingEnabled: false,
  FeatureFlags.videoShareEnabled: false,
  FeatureFlags.videoMuteEnabled: false,
  FeatureFlags.calenderEnabled: false,
  FeatureFlags.raiseHandEnabled: false,
  FeatureFlags.reactionsEnabled: false,
  FeatureFlags.kickOutEnabled: false,
  FeatureFlags.helpButtonEnabled: false,
  FeatureFlags.settingsEnabled: false,
  FeatureFlags.serverUrlChangeEnabled: false,
  FeatureFlags.meetingPasswordEnabled: false,
  FeatureFlags.securityOptionEnabled: false,
  FeatureFlags.breakoutRoomsEnabled: false,
  FeatureFlags.unsafeRoomWarningEnabled: false,
  FeatureFlags.pipEnabled: true,
};

class JitsiMeetService implements JitsiService {
  JitsiMeetService([JitsiMeet? sdk]) : _sdk = sdk ?? JitsiMeet();

  final JitsiMeet _sdk;
  final StreamController<JitsiEvent> _events = StreamController<JitsiEvent>.broadcast();

  @override
  Stream<JitsiEvent> get events => _events.stream;

  void _emit(JitsiEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  @override
  Future<bool> join(JitsiAccess access) async {
    // Domaine donné par l'API : refusé s'il n'est pas un nom d'hôte valide, rien n'est ouvert.
    if (!access.hasValidDomain) return false;
    final options = JitsiMeetConferenceOptions(
      serverURL: access.serverUrl,
      room: access.room,
      token: access.jwt,
      configOverrides: kJitsiConfig,
      featureFlags: kJitsiFeatureFlags,
    );
    final listener = JitsiMeetEventListener(
      conferenceJoined: (_) => _emit(JitsiEvent.joined),
      conferenceTerminated: (_, error) =>
          _emit(error == null ? JitsiEvent.left : JitsiEvent.failed),
      readyToClose: () => _emit(JitsiEvent.left),
    );
    try {
      return (await _sdk.join(options, listener)).isSuccess;
    } on Object {
      // Détail volontairement ignoré : il pourrait citer l'adresse de la salle.
      return false;
    }
  }

  @override
  Future<void> minimize() async {
    try {
      await _sdk.enterPiP();
    } on Object {
      // Pas d'image dans l'image sur ce téléphone : l'écran Jitsi reste affiché, l'appel continue.
    }
  }

  @override
  Future<void> hangUp() async {
    try {
      await _sdk.hangUp();
    } on Object {
      // Déjà quittée.
    }
  }
}

/// Mode démonstration (USE_FAKE_API=true) : aucune salle réelle, l'appel « réussit » sans son.
class JitsiServiceFake implements JitsiService {
  @override
  Stream<JitsiEvent> get events => const Stream.empty();

  @override
  Future<bool> join(JitsiAccess access) async => true;

  @override
  Future<void> minimize() async {}

  @override
  Future<void> hangUp() async {}
}

/// Remplaçable dans les tests par un faux service.
final jitsiServiceProvider = Provider<JitsiService>(
    (ref) => Env.useFakeApi ? JitsiServiceFake() : JitsiMeetService());
