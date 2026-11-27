// Photos choisies par l'utilisateur : fichier sur le téléphone, adresse `blob:` dans le navigateur.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart' show XFile;

/// Affiche une photo choisie ([path] renvoyé par le sélecteur de photos). Sur Android c'est un
/// fichier ; dans le navigateur (PWA) c'est une adresse `blob:` que `Image.file` ne sait pas lire.
Widget localImage(
  String path, {
  Key? key,
  BoxFit? fit,
  int? cacheWidth,
  ImageErrorWidgetBuilder? errorBuilder,
  bool isWeb = kIsWeb,
}) {
  if (isWeb) {
    return Image.network(path,
        key: key, fit: fit, cacheWidth: cacheWidth, errorBuilder: errorBuilder);
  }
  return Image.file(File(path),
      key: key, fit: fit, cacheWidth: cacheWidth, errorBuilder: errorBuilder);
}

/// Contenu d'une photo choisie, pour l'envoyer au serveur. Sur Android on lit le fichier ; dans le
/// navigateur le « chemin » est une adresse `blob:` qu'on lit par [XFile].
Future<Uint8List> readLocalFileBytes(String path, {bool isWeb = kIsWeb}) {
  if (isWeb) return XFile(path).readAsBytes();
  return File(path).readAsBytes();
}
