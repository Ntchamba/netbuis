import 'dart:typed_data';

/// Taille maximale d'une image acceptée par le serveur (5 Mo = 5 242 880 octets).
const int kMaxImageBytes = 5 * 1024 * 1024;

/// Type d'une image d'après ses **premiers octets** (jamais d'après l'extension du fichier) :
/// JPEG, PNG ou WebP. Renvoie `null` pour tout autre format (GIF, SVG, HTML…).
/// Mêmes règles que `detect_content_type` du serveur.
String? detectImageContentType(Uint8List bytes) {
  bool starts(List<int> prefix, [int offset = 0]) {
    if (bytes.length < offset + prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[offset + i] != prefix[i]) return false;
    }
    return true;
  }

  if (starts(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return 'image/png';
  if (starts(const [0x52, 0x49, 0x46, 0x46]) && starts(const [0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  return null;
}
