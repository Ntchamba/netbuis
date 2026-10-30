import 'package:image_picker/image_picker.dart';

import '../../business/data/photo_service.dart' show PhotoSource;

/// Prise ou choix d'une photo ou d'une vidéo pour une publication. Renvoie le chemin du
/// fichier, ou null si la personne annule. Lève une exception si l'appareil photo ou la
/// galerie est inaccessible.
abstract class PostMediaPicker {
  Future<String?> pick(PhotoSource source, {required bool video});
}

/// Durée maximale d'une vidéo filmée avec l'appareil photo.
const Duration kMaxVideoDuration = Duration(seconds: 30);

/// Version réelle, sur `image_picker`. Photo réduite à 1024 px, qualité 70, comme les autres photos.
class ImagePickerPostMediaPicker implements PostMediaPicker {
  ImagePickerPostMediaPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pick(PhotoSource source, {required bool video}) async {
    final from = source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery;
    final XFile? file = video
        ? await _picker.pickVideo(source: from, maxDuration: kMaxVideoDuration)
        : await _picker.pickImage(source: from, maxWidth: 1024, imageQuality: 70);
    return file?.path;
  }
}
