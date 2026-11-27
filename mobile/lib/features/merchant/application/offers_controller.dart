import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../business/application/business_services.dart';
import '../../business/data/image_type.dart';
import '../../business/data/models/business_draft.dart' show kPhotoKind;
import '../../business/data/repositories/business_repository.dart';
import '../data/repositories/merchant_repository.dart';
import '../data/repositories/merchant_repository_api.dart';
import '../data/repositories/merchant_repository_fake.dart';

/// Nombre maximal de photos par produit (contrat de l'API).
const int kMaxOfferPhotos = 4;

/// Dépôt « espace commerçant » : factice si `USE_FAKE_API=true`, sinon relié à l'API.
final merchantRepositoryProvider = Provider<MerchantRepository>((ref) {
  if (Env.useFakeApi) return MerchantRepositoryFake();
  return MerchantRepositoryApi(ref.read(dioProvider));
});

/// Une photo du formulaire : déjà envoyée ([key]) ou choisie sur le téléphone ([path]).
class OfferPhoto {
  const OfferPhoto.stored(String this.key) : path = null;
  const OfferPhoto.local(String this.path) : key = null;

  final String? key;
  final String? path;
}

/// Une photo n'a pas pu être lue ou est refusée (format, taille).
class OfferPhotoException implements Exception {
  const OfferPhotoException();
}

/// Mes produits : liste chargée à l'ouverture, mise à jour après chaque ajout, modification
/// ou suppression. À n'utiliser que si le compte business est actif (sinon le serveur répond 403).
final offersProvider =
    AsyncNotifierProvider.autoDispose<OffersController, List<MerchantOffer>>(
  OffersController.new,
);

class OffersController extends AsyncNotifier<List<MerchantOffer>> {
  @override
  Future<List<MerchantOffer>> build() => ref.read(merchantRepositoryProvider).listOffers();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(merchantRepositoryProvider).listOffers());
  }

  /// Envoie les nouvelles photos puis crée ([existing] absent) ou modifie l'offre.
  /// Lève [ApiException] ou [OfferPhotoException] ; la liste affichée ne change qu'en cas de succès.
  Future<void> save({
    MerchantOffer? existing,
    required String name,
    required String description,
    required int? priceFcfa,
    required List<OfferPhoto> photos,
  }) async {
    final repo = ref.read(merchantRepositoryProvider);
    final keys = <String>[];
    for (final photo in photos) {
      keys.add(photo.key ?? await _upload(photo.path!));
    }
    final input = OfferInput(
      name: name.trim(),
      description: description.trim(),
      priceFcfa: priceFcfa,
      photoKeys: keys,
    );
    final saved = existing == null
        ? await repo.createOffer(input)
        : await repo.updateOffer(existing.id, input);
    if (!ref.mounted) return;
    final current = state.value ?? const <MerchantOffer>[];
    state = AsyncData(
      existing == null
          ? [...current, saved]
          : [for (final o in current) o.id == saved.id ? saved : o],
    );
  }

  /// Supprime l'offre ; lève [ApiException] si le serveur refuse (la liste reste inchangée).
  Future<void> delete(int id) async {
    await ref.read(merchantRepositoryProvider).deleteOffer(id);
    if (!ref.mounted) return;
    state = AsyncData([
      for (final o in state.value ?? const <MerchantOffer>[])
        if (o.id != id) o,
    ]);
  }

  /// Signe puis envoie UN fichier (kind `photo`) ; une seule nouvelle tentative si
  /// l'adresse d'envoi est refusée (expirée, déjà servie).
  Future<String> _upload(String path) async {
    final BusinessRepository repo = ref.read(businessRepositoryProvider);
    final Uint8List bytes;
    try {
      bytes = await ref.read(photoBytesReaderProvider)(path);
    } on Object {
      throw const OfferPhotoException();
    }
    final contentType = detectImageContentType(bytes);
    if (contentType == null || bytes.isEmpty || bytes.length > kMaxImageBytes) {
      throw const OfferPhotoException();
    }
    for (var attempt = 0;; attempt++) {
      try {
        final ticket = await repo.signUpload(
          kind: kPhotoKind,
          contentType: contentType,
          size: bytes.length,
        );
        await repo.putFile(ticket, bytes);
        return ticket.key;
      } on ApiException catch (e) {
        if (e.statusCode == 403 && attempt == 0) continue;
        if (e.serverCode == ServerCodes.invalidType ||
            e.serverCode == ServerCodes.tooLarge ||
            e.serverCode == ServerCodes.invalidContent ||
            e.statusCode == 413) {
          throw const OfferPhotoException();
        }
        rethrow;
      }
    }
  }
}

/// Clé de texte traduit pour une erreur d'enregistrement ou de suppression. Jamais le texte du serveur.
String offerErrorKey(Object error) {
  if (error is OfferPhotoException) return 'offers.error.photo';
  if (error is ApiException) {
    if (error.code == ApiErrorCode.network) return 'offers.error.network';
    if (error.statusCode == 403 && error.serverCode == 'business_not_active') {
      return 'offers.error.notActive';
    }
    if (error.code == ApiErrorCode.invalid) return 'offers.error.invalid';
  }
  return 'offers.error.unknown';
}

/// Vrai si l'erreur dit « compte business pas encore actif » (403 `business_not_active`).
bool isNotActiveError(Object error) =>
    error is ApiException && error.statusCode == 403 && error.serverCode == 'business_not_active';
