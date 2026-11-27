import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../account/application/account_controller.dart';
import '../data/image_type.dart';
import '../data/models/business_draft.dart';
import '../data/repositories/business_repository.dart';
import 'business_controller.dart';
import 'business_draft_controller.dart';
import 'business_request.dart';
import 'business_services.dart';

/// Où en est l'envoi.
enum SubmitPhase { idle, sending, failed, sent }

/// Pourquoi l'envoi s'est arrêté (l'écran choisit le message traduit ; jamais le texte du
/// serveur). Dans tous les cas le brouillon et les fichiers déjà envoyés sont conservés.
enum SubmitProblem {
  /// Pas de réponse du serveur : « Réessayer ».
  network,

  /// Session expirée (401 après renouvellement) : la garde renvoie à la connexion.
  session,

  /// 429 `throttled`.
  throttled,

  /// Compte bloqué ou supprimé.
  support,

  /// La photo du représentant manque (obligatoire, vérification) : rien n'est envoyé.
  /// (La photo du commerce, elle, est facultative.)
  photoMissing,

  /// Une photo est refusée (format, taille, contenu illisible) : à changer.
  photo,

  /// 400 `SUBSCRIPTION_REQUIRED` : plus de 3 éléments choisis.
  subscription,

  /// 400 `invalid` : des champs sont à corriger.
  fields,

  /// Toute autre erreur : « Réessayer ».
  server,
}

class SubmitState {
  const SubmitState({
    this.phase = SubmitPhase.idle,
    this.done = 0,
    this.total = 0,
    this.problem,
    this.fixRoute,
  });

  final SubmitPhase phase;

  /// Étapes terminées (fichiers envoyés) sur [total] (fichiers + la demande).
  final int done;
  final int total;
  final SubmitProblem? problem;

  /// Écran où corriger (photo refusée, champ refusé, plafond), s'il y en a un.
  final String? fixRoute;

  bool get sending => phase == SubmitPhase.sending;

  /// Dernière étape en cours : la demande elle-même (tous les fichiers sont partis).
  bool get sendingProfile => sending && done >= total - 1;
}

final businessSubmitProvider =
    NotifierProvider.autoDispose<BusinessSubmitController, SubmitState>(
  BusinessSubmitController.new,
);

/// Arrêt interne de l'envoi.
class _Stop implements Exception {
  const _Stop(this.problem, [this.fixRoute]);
  final SubmitProblem problem;
  final String? fixRoute;
}

/// Envoie la demande : photos (sign puis PUT, une par une), puis `POST /api/business/`.
///
/// Rien n'est perdu : le brouillon reste en mémoire jusqu'au succès, chaque clé obtenue est
/// gardée dans le brouillon (`uploaded`) et n'est pas renvoyée tant que la photo est la même.
/// Aucune journalisation : ni chemin, ni clé, ni adresse d'envoi, ni numéro.
class BusinessSubmitController extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  Future<void> submit() async {
    if (state.sending) return;
    final repo = ref.read(businessRepositoryProvider);
    final photos = photosToSend(ref.read(businessDraftProvider));
    if (ref.read(businessDraftProvider).representantPhotoPath == null) {
      // Le serveur exige cette photo : inutile d'envoyer les autres fichiers pour rien.
      state = const SubmitState(
        phase: SubmitPhase.failed,
        problem: SubmitProblem.photoMissing,
        fixRoute: Routes.createBusiness,
      );
      return;
    }
    final total = photos.length + 1;
    var done = 0;
    state = SubmitState(phase: SubmitPhase.sending, done: done, total: total);
    try {
      for (final photo in photos) {
        final known = ref.read(businessDraftProvider).uploaded[photo.kind];
        if (known == null || known.path != photo.path) {
          final key = await _upload(repo, photo);
          if (!ref.mounted) return;
          ref.read(businessDraftProvider.notifier)
              .setUploaded(photo.kind, UploadedPhoto(path: photo.path, key: key));
        }
        done++;
        state = SubmitState(phase: SubmitPhase.sending, done: done, total: total);
      }
      await _createProfile(repo);
      if (!ref.mounted) return;
      ref.invalidate(accountControllerProvider);
      ref.invalidate(myBusinessProvider);
      state = SubmitState(phase: SubmitPhase.sent, done: total, total: total);
    } on _Stop catch (stop) {
      if (!ref.mounted) return;
      state = SubmitState(
        phase: SubmitPhase.failed,
        done: done,
        total: total,
        problem: stop.problem,
        fixRoute: stop.fixRoute,
      );
    }
  }

  /// Envoie un fichier ; si l'adresse d'envoi est refusée (expirée, déjà servie), en demande
  /// une nouvelle pour CE fichier seulement, une fois.
  Future<String> _upload(BusinessRepository repo, PhotoToSend photo) async {
    final photoRoute = _photoRoute(photo.kind);
    final Uint8List bytes;
    try {
      bytes = await ref.read(photoBytesReaderProvider)(photo.path);
    } on Object {
      throw _Stop(SubmitProblem.photo, photoRoute);
    }
    final contentType = detectImageContentType(bytes);
    if (contentType == null || bytes.isEmpty || bytes.length > kMaxImageBytes) {
      throw _Stop(SubmitProblem.photo, photoRoute);
    }
    for (var attempt = 0;; attempt++) {
      try {
        final ticket = await repo.signUpload(
          kind: photo.kind,
          contentType: contentType,
          size: bytes.length,
        );
        await repo.putFile(ticket, bytes);
        return ticket.key;
      } on ApiException catch (e) {
        final linkRefused = e.statusCode == 403 &&
            (e.serverCode == ServerCodes.invalidToken ||
                e.serverCode == ServerCodes.alreadyUsed ||
                e.code == ApiErrorCode.unknown);
        if (linkRefused && attempt == 0) continue;
        throw _stopFor(e, photoRoute: photoRoute);
      } on Object {
        throw const _Stop(SubmitProblem.server);
      }
    }
  }

  Future<void> _createProfile(BusinessRepository repo) async {
    final draft = ref.read(businessDraftProvider);
    final keys = {
      for (final photo in photosToSend(draft))
        if (draft.uploaded[photo.kind]?.path == photo.path)
          photo.kind: draft.uploaded[photo.kind]!.key,
    };
    try {
      await repo.create(buildBusinessBody(draft, keys));
    } on ApiException catch (e) {
      if (e.statusCode == 409 || e.serverCode == ServerCodes.businessExists) {
        // La demande a peut-être déjà réussi (réponse perdue) : on relit l'état du compte.
        await _confirmExisting(repo);
        return;
      }
      throw _stopFor(e, draft: draft);
    } on Object {
      throw const _Stop(SubmitProblem.server);
    }
  }

  Future<void> _confirmExisting(BusinessRepository repo) async {
    try {
      await repo.getMine();
    } on ApiException catch (e) {
      throw _stopFor(e);
    } on Object {
      throw const _Stop(SubmitProblem.server);
    }
  }

  _Stop _stopFor(ApiException e, {String? photoRoute, BusinessDraft? draft}) {
    if (e.code == ApiErrorCode.network) return const _Stop(SubmitProblem.network);
    if (e.statusCode == 401) return const _Stop(SubmitProblem.session);
    switch (e.code) {
      case ApiErrorCode.accountBlocked:
      case ApiErrorCode.accountDeleted:
        return const _Stop(SubmitProblem.support);
      case ApiErrorCode.tooManyRequests:
        return const _Stop(SubmitProblem.throttled);
      default:
        break;
    }
    switch (e.serverCode) {
      case ServerCodes.throttled:
        return const _Stop(SubmitProblem.throttled);
      case ServerCodes.subscriptionRequired:
        return _Stop(
          SubmitProblem.subscription,
          draft?.typeCompte == BusinessAccountType.structure
              ? Routes.createBusinessStructureDetails
              : Routes.createBusinessDetails,
        );
      case ServerCodes.invalidType:
      case ServerCodes.tooLarge:
      case ServerCodes.invalidContent:
        return _Stop(SubmitProblem.photo, photoRoute);
    }
    if (e.code == ApiErrorCode.invalid && photoRoute != null) {
      return _Stop(SubmitProblem.photo, photoRoute);
    }
    if (e.statusCode == 429) return const _Stop(SubmitProblem.throttled);
    if (e.statusCode == 413) return _Stop(SubmitProblem.photo, photoRoute);
    if (e.statusCode == 400 && e.fieldNames.isNotEmpty && draft != null) {
      _forgetRefusedFiles(e.fieldNames);
      final route = routeForFields(e.fieldNames, draft.typeCompte);
      // Aucun écran ne permet de corriger ce champ (ex. `phone_anchor`, que le mobile ne
      // peut pas fournir) : on ne promet pas une correction, on propose de réessayer.
      return route == null ? const _Stop(SubmitProblem.server) : _Stop(SubmitProblem.fields, route);
    }
    return const _Stop(SubmitProblem.server);
  }

  /// Une clé que le serveur dit inconnue ne sera pas reprise : le fichier repartira.
  void _forgetRefusedFiles(List<String> fields) {
    final notifier = ref.read(businessDraftProvider.notifier);
    for (final kind in const [
      kPhotoKind,
      kRepresentantPhotoKind,
      kCniPhotoKind,
      kDiplomePhotoKind,
    ]) {
      if (fields.contains(kind)) notifier.setUploaded(kind, null);
    }
  }

  static String _photoRoute(String kind) =>
      kind == kCniPhotoKind || kind == kDiplomePhotoKind
          ? Routes.createBusinessServiceCategory
          : Routes.createBusiness;
}

/// Écran où l'on corrige les champs refusés par le serveur : le premier champ connu, dans
/// l'ordre de la liste reçue ; `null` si aucun champ ne correspond à un écran.
String? routeForFields(List<String> fields, BusinessAccountType type) {
  for (final field in fields) {
    final route = _fieldRoute(field, type);
    if (route != null) return route;
  }
  return null;
}

String? _fieldRoute(String field, BusinessAccountType type) {
  switch (field) {
    case 'zone':
      return Routes.createBusinessLocation;
    case 'type_compte':
    case 'name':
    case 'repere':
    case 'representant_nom':
    case 'representant_photo':
    case 'photo':
      return Routes.createBusiness;
    case 'forme_juridique':
    case 'rccm':
      return Routes.createBusinessLegalForm;
    case 'secteur':
      return Routes.createBusinessSector;
    case 'secteur_libre':
    case 'sous_categories':
    case 'description_activite':
      return Routes.createBusinessDetails;
    case 'categorie_service':
    case 'categorie_service_libre':
    case 'cni_photo':
    case 'diplome_photo':
      return Routes.createBusinessServiceCategory;
    case 'structure_type':
      return Routes.createBusinessStructureType;
    case 'structure_type_libre':
    case 'rayons':
    case 'cuisine':
    case 'livraison':
    case 'horaires':
    case 'standing':
    case 'nombre_chambres':
    case 'equipements':
    case 'numero_agrement':
    case 'specialites':
      return Routes.createBusinessStructureDetails;
    case 'description':
      return type == BusinessAccountType.structure ? Routes.createBusinessStructureDetails : null;
  }
  return null;
}
