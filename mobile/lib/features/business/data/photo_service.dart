import 'package:image_picker/image_picker.dart';

/// D'où vient la photo.
enum PhotoSource { camera, gallery }

/// Prise ou choix d'une photo. Renvoie le chemin du fichier (réduit à 1024 px,
/// qualité 70, comme prévu pour l'envoi), ou null si la personne annule.
/// Lève une exception si l'appareil photo ou la galerie est inaccessible.
abstract class PhotoPickerService {
  Future<String?> pick(PhotoSource source);
}

/// Version réelle, sur `image_picker`.
class ImagePickerPhotoService implements PhotoPickerService {
  ImagePickerPhotoService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<String?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 70,
    );
    return file?.path;
  }
}
