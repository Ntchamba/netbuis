import 'dart:typed_data';

import '../../business/data/image_type.dart';
import 'models/post.dart';

/// Taille maximale d'une vidéo de publication (30 Mo = 31 457 280 octets, contrat de l'API).
const int kMaxVideoBytes = 30 * 1024 * 1024;

/// Ce que l'on sait d'un fichier à publier, d'après ses **premiers octets**.
class PostMediaInfo {
  const PostMediaInfo({required this.type, required this.contentType, required this.signKind});

  final PostMediaType type;

  /// Type à déclarer à `POST /api/uploads/sign/`.
  final String contentType;

  /// `kind` de `POST /api/uploads/sign/` : `post_image` ou `post_video`.
  final String signKind;
}

const String kPostImageKind = 'post_image';
const String kPostVideoKind = 'post_video';

/// Un fichier est refusé avant tout envoi : format non accepté ou trop gros.
class PostMediaException implements Exception {
  const PostMediaException({required this.tooLarge});

  final bool tooLarge;
}

/// Type du fichier d'après ses octets (jamais d'après son extension) : image JPEG, PNG ou
/// WebP, ou vidéo MP4 (boîte `ftyp` aux octets 4 à 7). `null` pour tout autre format.
PostMediaInfo? detectPostMedia(Uint8List bytes) {
  final image = detectImageContentType(bytes);
  if (image != null) {
    return PostMediaInfo(type: PostMediaType.image, contentType: image, signKind: kPostImageKind);
  }
  if (bytes.length >= 12 &&
      bytes[4] == 0x66 && // f
      bytes[5] == 0x74 && // t
      bytes[6] == 0x79 && // y
      bytes[7] == 0x70) {
    // p
    return const PostMediaInfo(
      type: PostMediaType.video,
      contentType: 'video/mp4',
      signKind: kPostVideoKind,
    );
  }
  return null;
}

/// Vérifie le format et la taille ; lève [PostMediaException] sinon.
PostMediaInfo checkPostMedia(Uint8List bytes) {
  final info = detectPostMedia(bytes);
  if (info == null || bytes.isEmpty) throw const PostMediaException(tooLarge: false);
  final max = info.type == PostMediaType.video ? kMaxVideoBytes : kMaxImageBytes;
  if (bytes.length > max) throw const PostMediaException(tooLarge: true);
  return info;
}
