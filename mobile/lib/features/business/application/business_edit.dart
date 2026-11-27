// Règles de « Modifier ma boutique » (PATCH /api/business/me/, T026, décision D-08)
import '../data/models/business.dart';
import '../data/models/business_draft.dart';

/// Ce que la personne a saisi dans l'écran de modification. Les photos sont des chemins
/// locaux (null = non changée) : l'envoi les convertit en clés de stockage.
class BusinessEditForm {
  const BusinessEditForm({
    required this.name,
    required this.representantNom,
    required this.repere,
    required this.description,
    required this.zoneId,
    this.photoPath,
    this.representantPhotoPath,
    this.cniPhotoPath,
    this.diplomePhotoPath,
  });

  /// État de départ : les valeurs enregistrées, aucune photo changée.
  factory BusinessEditForm.from(MyBusiness b) => BusinessEditForm(
        name: b.name,
        representantNom: b.representantNom,
        repere: b.repere,
        description: descriptionOf(b),
        zoneId: b.zoneId,
      );

  final String name;
  final String representantNom;
  final String repere;

  /// Texte du champ de description du type (voir [descriptionFieldOf]).
  final String description;
  final int? zoneId;
  final String? photoPath;
  final String? representantPhotoPath;
  final String? cniPhotoPath;
  final String? diplomePhotoPath;

  static const Object _keep = Object();

  BusinessEditForm copyWith({
    String? name,
    String? representantNom,
    String? repere,
    String? description,
    Object? zoneId = _keep,
    String? photoPath,
    String? representantPhotoPath,
    String? cniPhotoPath,
    String? diplomePhotoPath,
  }) =>
      BusinessEditForm(
        name: name ?? this.name,
        representantNom: representantNom ?? this.representantNom,
        repere: repere ?? this.repere,
        description: description ?? this.description,
        zoneId: identical(zoneId, _keep) ? this.zoneId : zoneId as int?,
        photoPath: photoPath ?? this.photoPath,
        representantPhotoPath: representantPhotoPath ?? this.representantPhotoPath,
        cniPhotoPath: cniPhotoPath ?? this.cniPhotoPath,
        diplomePhotoPath: diplomePhotoPath ?? this.diplomePhotoPath,
      );

  /// Photos choisies, dans l'ordre d'envoi : `kind` -> chemin local.
  List<({String kind, String path})> get pickedPhotos => [
        if (photoPath != null) (kind: kPhotoKind, path: photoPath!),
        if (representantPhotoPath != null)
          (kind: kRepresentantPhotoKind, path: representantPhotoPath!),
        if (cniPhotoPath != null) (kind: kCniPhotoKind, path: cniPhotoPath!),
        if (diplomePhotoPath != null) (kind: kDiplomePhotoKind, path: diplomePhotoPath!),
      ];
}

/// Champ du serveur qui porte la description modifiable pour ce type : `description_activite`
/// (500 car.) pour commerce, entreprise et particulier ; `description` (1000 car.) pour une
/// structure ; aucun pour un prestataire (le parcours de création n'en propose pas).
String? descriptionFieldOf(BusinessAccountType? type) {
  if (type == null) return null;
  if (type.hasSector) return 'description_activite';
  if (type == BusinessAccountType.structure) return 'description';
  return null;
}

int descriptionMaxOf(BusinessAccountType? type) =>
    type == BusinessAccountType.structure ? kBusinessDescriptionMax : kBusinessDescriptionActiviteMax;

String descriptionOf(MyBusiness b) => switch (descriptionFieldOf(b.typeCompte)) {
      'description_activite' => b.descriptionActivite,
      'description' => b.description,
      _ => '',
    };

/// Le nom ou le lieu change réellement : sur un compte actif, le serveur le remet alors en
/// attente de validation (D-08). Le type et le numéro ne se modifient pas ici.
bool isSensitiveChange(MyBusiness original, BusinessEditForm form) {
  if (form.name.trim() != original.name) return true;
  return form.zoneId != null && form.zoneId != original.zoneId;
}

/// Y a-t-il quelque chose à enregistrer (texte, lieu ou photo différents) ?
bool hasEditChanges(MyBusiness original, BusinessEditForm form) {
  if (isSensitiveChange(original, form)) return true;
  return form.representantNom.trim() != original.representantNom ||
      form.repere.trim() != original.repere ||
      (descriptionFieldOf(original.typeCompte) != null &&
          form.description.trim() != descriptionOf(original)) ||
      form.pickedPhotos.isNotEmpty;
}

/// Corps du PATCH : seulement les champs changés (le serveur n'agit que sur ce qui est envoyé).
/// [keys] : clés de stockage par `kind` des photos déjà envoyées. Ni numéro ni type.
Map<String, Object?> buildEditBody(
  MyBusiness original,
  BusinessEditForm form,
  Map<String, String> keys,
) {
  final body = <String, Object?>{};
  final name = form.name.trim();
  if (name != original.name) body['name'] = name;
  if (form.zoneId != null && form.zoneId != original.zoneId) body['zone'] = form.zoneId;
  final repere = form.repere.trim();
  if (repere != original.repere) body['repere'] = repere;
  final owner = form.representantNom.trim();
  if (owner != original.representantNom) body['representant_nom'] = owner;
  final descField = descriptionFieldOf(original.typeCompte);
  final description = form.description.trim();
  if (descField != null && description != descriptionOf(original)) {
    body[descField] = description;
  }
  for (final photo in form.pickedPhotos) {
    final key = keys[photo.kind];
    if (key != null) body[photo.kind] = key;
  }
  return body;
}

/// Erreurs locales avant l'envoi : nom, nom du représentant (obligatoires), description.
class EditErrors {
  const EditErrors({this.name, this.owner, this.description, this.repere});

  final FieldError? name;
  final FieldError? owner;
  final FieldError? description;
  final FieldError? repere;

  bool get any => name != null || owner != null || description != null || repere != null;
}

EditErrors editErrors(MyBusiness original, BusinessEditForm form) {
  FieldError? tooLong(String raw, int max) => raw.trim().runes.length > max ? FieldError.tooLong : null;
  return EditErrors(
    name: validateBusinessName(form.name),
    owner: validateRepresentantName(form.representantNom),
    repere: tooLong(form.repere, kBusinessRepereMax),
    description: descriptionFieldOf(original.typeCompte) == null
        ? null
        : tooLong(form.description, descriptionMaxOf(original.typeCompte)),
  );
}
