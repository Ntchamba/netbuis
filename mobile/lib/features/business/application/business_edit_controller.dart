import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/zones/zone.dart';
import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../account/application/account_controller.dart';
import '../data/image_type.dart';
import '../data/models/business.dart';
import '../data/repositories/business_repository.dart';
import 'business_controller.dart';
import 'business_edit.dart';
import 'business_services.dart';

enum EditPhase { idle, saving, failed, saved }

/// Pourquoi l'enregistrement s'est arrêté (l'écran choisit le message traduit ; jamais le
/// texte du serveur).
enum EditProblem {
  network,
  session,
  throttled,
  support,

  /// Une photo est illisible, trop lourde ou d'un format refusé.
  photo,

  /// Plafond de 3 éléments sans abonnement.
  subscription,

  /// 400 `invalid` : [EditState.fieldNames] donne les champs à corriger.
  fields,

  /// Le compte business n'existe plus (404).
  noBusiness,
  server,
}

class EditState {
  const EditState({
    this.phase = EditPhase.idle,
    this.problem,
    this.fieldNames = const [],
    this.saved,
  });

  final EditPhase phase;
  final EditProblem? problem;

  /// Noms des champs refusés par le serveur (jamais leurs valeurs).
  final List<String> fieldNames;

  /// Le compte tel que le serveur le renvoie après l'enregistrement.
  final MyBusiness? saved;

  bool get saving => phase == EditPhase.saving;
}

final businessEditProvider =
    NotifierProvider.autoDispose<BusinessEditController, EditState>(BusinessEditController.new);

/// Arrêt interne.
class _Stop implements Exception {
  const _Stop(this.problem, [this.fieldNames = const []]);
  final EditProblem problem;
  final List<String> fieldNames;
}

/// Enregistre les modifications : photos choisies (sign puis PUT, une par une), puis
/// `PATCH /api/business/me/` avec les seuls champs changés. Rien n'est journalisé : ni chemin,
/// ni clé, ni nom, ni numéro. Les clés déjà obtenues sont gardées pour un nouvel essai.
class BusinessEditController extends Notifier<EditState> {
  /// Clés déjà obtenues pour un chemin donné : `kind` -> (chemin, clé).
  final Map<String, ({String path, String key})> _uploaded = {};

  @override
  EditState build() => const EditState();

  Future<void> save(MyBusiness original, BusinessEditForm form) async {
    if (state.saving) return;
    final repo = ref.read(businessRepositoryProvider);
    state = const EditState(phase: EditPhase.saving);
    try {
      final keys = <String, String>{};
      for (final photo in form.pickedPhotos) {
        final known = _uploaded[photo.kind];
        if (known != null && known.path == photo.path) {
          keys[photo.kind] = known.key;
          continue;
        }
        final key = await _upload(repo, photo.kind, photo.path);
        if (!ref.mounted) return;
        _uploaded[photo.kind] = (path: photo.path, key: key);
        keys[photo.kind] = key;
      }
      final body = buildEditBody(original, form, keys);
      final MyBusiness saved;
      try {
        saved = await repo.update(body);
      } on ApiException catch (e) {
        throw _stopFor(e);
      } on Object {
        throw const _Stop(EditProblem.server);
      }
      if (!ref.mounted) return;
      ref.invalidate(myBusinessProvider);
      ref.invalidate(accountControllerProvider);
      state = EditState(phase: EditPhase.saved, saved: saved);
    } on _Stop catch (stop) {
      if (!ref.mounted) return;
      // Un fichier que le serveur dit inconnu repartira au prochain essai.
      for (final f in stop.fieldNames) {
        _uploaded.remove(f);
      }
      state = EditState(
        phase: EditPhase.failed,
        problem: stop.problem,
        fieldNames: stop.fieldNames,
      );
    }
  }

  /// Revient à l'état de départ (par exemple après avoir lu l'erreur).
  void clearError() {
    if (state.phase == EditPhase.failed) state = const EditState();
  }

  Future<String> _upload(BusinessRepository repo, String kind, String path) async {
    final Uint8List bytes;
    try {
      bytes = await ref.read(photoBytesReaderProvider)(path);
    } on Object {
      throw _Stop(EditProblem.photo, [kind]);
    }
    final contentType = detectImageContentType(bytes);
    if (contentType == null || bytes.isEmpty || bytes.length > kMaxImageBytes) {
      throw _Stop(EditProblem.photo, [kind]);
    }
    for (var attempt = 0;; attempt++) {
      try {
        final ticket = await repo.signUpload(kind: kind, contentType: contentType, size: bytes.length);
        await repo.putFile(ticket, bytes);
        return ticket.key;
      } on ApiException catch (e) {
        final linkRefused = e.statusCode == 403 &&
            (e.serverCode == ServerCodes.invalidToken ||
                e.serverCode == ServerCodes.alreadyUsed ||
                e.code == ApiErrorCode.unknown);
        if (linkRefused && attempt == 0) continue;
        throw _stopFor(e, photoKind: kind);
      } on Object {
        throw const _Stop(EditProblem.server);
      }
    }
  }

  _Stop _stopFor(ApiException e, {String? photoKind}) {
    if (e.code == ApiErrorCode.network) return const _Stop(EditProblem.network);
    if (e.statusCode == 401) return const _Stop(EditProblem.session);
    switch (e.code) {
      case ApiErrorCode.accountBlocked:
      case ApiErrorCode.accountDeleted:
        return const _Stop(EditProblem.support);
      case ApiErrorCode.tooManyRequests:
        return const _Stop(EditProblem.throttled);
      default:
        break;
    }
    switch (e.serverCode) {
      case ServerCodes.throttled:
        return const _Stop(EditProblem.throttled);
      case ServerCodes.noBusiness:
        return const _Stop(EditProblem.noBusiness);
      case ServerCodes.subscriptionRequired:
        return const _Stop(EditProblem.subscription);
      case ServerCodes.invalidType:
      case ServerCodes.tooLarge:
      case ServerCodes.invalidContent:
        return _Stop(EditProblem.photo, [if (photoKind != null) photoKind]);
    }
    if (photoKind != null && e.code == ApiErrorCode.invalid) {
      return _Stop(EditProblem.photo, [photoKind]);
    }
    if (e.statusCode == 429) return const _Stop(EditProblem.throttled);
    if (e.statusCode == 413) return _Stop(EditProblem.photo, [if (photoKind != null) photoKind]);
    if (e.statusCode == 404) return const _Stop(EditProblem.noBusiness);
    if (e.statusCode == 400 && e.fieldNames.isNotEmpty) {
      return _Stop(EditProblem.fields, e.fieldNames);
    }
    return const _Stop(EditProblem.server);
  }
}

/// Lieu enregistré, pour l'affichage : « Maroua, Hardé » ou « Maroua » (ville, puis quartier
/// s'il y en a un), lu via GET /api/zones/{id}/. `null` si le serveur n'a pas de zone.
final businessZoneLabelProvider = FutureProvider.autoDispose.family<String?, int>(
  (ref, zoneId) async {
    final detail = await ref.read(zoneRepositoryProvider).getZone(zoneId);
    final names = [
      for (final item in detail.path)
        if (item.level == ZoneLevel.villeVillage || item.level == ZoneLevel.quartier) item.name,
    ];
    return names.isEmpty ? detail.zone.name : names.join(', ');
  },
  retry: (retryCount, error) => null,
);
