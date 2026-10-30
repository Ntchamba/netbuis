import '../data/models/business_draft.dart';
import 'business_creation_flow.dart';

/// Une photo du brouillon à envoyer avant le profil.
class PhotoToSend {
  const PhotoToSend(this.kind, this.path);

  /// `photo`, `representant_photo`, `cni_photo` ou `diplome_photo`.
  final String kind;

  /// Chemin local (en mémoire seulement ; jamais journalisé).
  final String path;
}

/// Photos présentes, dans l'ordre d'envoi : photo, représentant, puis (prestataire) CNI
/// et diplôme s'il est renseigné.
List<PhotoToSend> photosToSend(BusinessDraft d) {
  final isProvider = d.typeCompte == BusinessAccountType.prestataireService;
  return [
    if (d.photoPath != null) PhotoToSend(kPhotoKind, d.photoPath!),
    if (d.representantPhotoPath != null)
      PhotoToSend(kRepresentantPhotoKind, d.representantPhotoPath!),
    if (isProvider && d.cniPhotoPath != null) PhotoToSend(kCniPhotoKind, d.cniPhotoPath!),
    if (isProvider && d.diplomePhotoPath != null)
      PhotoToSend(kDiplomePhotoKind, d.diplomePhotoPath!),
  ];
}

/// Corps de `POST /api/business/` : les champs communs puis **seulement** ceux du type
/// choisi (le serveur refuse les champs d'un autre type). [keys] : clés de stockage par
/// `kind`. Le numéro de téléphone n'y figure pas : le mobile ne le connaît jamais en entier.
Map<String, Object?> buildBusinessBody(BusinessDraft d, Map<String, String> keys) {
  String? text(String v) {
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  final body = <String, Object?>{
    'type_compte': d.typeCompte.value,
    'name': d.name.trim(),
    'zone': d.zoneId,
    if (text(d.repere) != null) 'repere': text(d.repere),
    if (text(d.description) != null) 'description': text(d.description),
    'representant_nom': d.representantNom.trim(),
    if (keys[kPhotoKind] != null) 'photo': keys[kPhotoKind],
    if (keys[kRepresentantPhotoKind] != null)
      'representant_photo': keys[kRepresentantPhotoKind],
  };

  switch (d.typeCompte) {
    case BusinessAccountType.entreprise:
      body['forme_juridique'] = d.formeJuridique?.value;
      if (text(d.rccm) != null) body['rccm'] = text(d.rccm);
      _addSector(body, d);
    case BusinessAccountType.boutique:
    case BusinessAccountType.particulierVendeur:
      _addSector(body, d);
    case BusinessAccountType.prestataireService:
      body['categorie_service'] = d.categorieServiceId;
      if (text(d.categorieServiceLibre) != null) {
        body['categorie_service_libre'] = text(d.categorieServiceLibre);
      }
      if (keys[kCniPhotoKind] != null) body['cni_photo'] = keys[kCniPhotoKind];
      if (keys[kDiplomePhotoKind] != null) body['diplome_photo'] = keys[kDiplomePhotoKind];
    case BusinessAccountType.structure:
      body['structure_type'] = d.structureTypeId;
      if (text(d.structureTypeLibre) != null) {
        body['structure_type_libre'] = text(d.structureTypeLibre);
      }
      switch (d.structureCode) {
        case kStructureSupermarche:
          body['rayons'] = d.rayons;
        case kStructureRestaurant:
          body['cuisine'] = d.cuisine;
          body['livraison'] = d.livraison;
          if (text(d.horaires) != null) body['horaires'] = text(d.horaires);
        case kStructureHotel:
          body['standing'] = d.standing;
          if (d.nombreChambres != null) body['nombre_chambres'] = d.nombreChambres;
          body['equipements'] = d.equipements;
        case kStructureSante:
          if (text(d.numeroAgrement) != null) body['numero_agrement'] = text(d.numeroAgrement);
          body['specialites'] = d.specialites;
      }
  }
  return body;
}

void _addSector(Map<String, Object?> body, BusinessDraft d) {
  body['secteur'] = d.secteurId;
  if (d.secteurLibre.trim().isNotEmpty) body['secteur_libre'] = d.secteurLibre.trim();
  body['sous_categories'] = d.sousCategorieIds;
  if (d.descriptionActivite.trim().isNotEmpty) {
    body['description_activite'] = d.descriptionActivite.trim();
  }
}

/// Première étape du parcours dont les champs obligatoires manquent, ou `null` si le
/// brouillon est complet (le récapitulatif ne s'ouvre que s'il l'est).
BusinessStep? firstIncompleteStep(BusinessDraft d) {
  if (!d.infoIsValid) return BusinessStep.info;
  switch (d.typeCompte) {
    case BusinessAccountType.entreprise:
      if (d.formeJuridique == null) return BusinessStep.legalForm;
      if (!d.detailsIsValid) {
        return d.sectorMissing ? BusinessStep.sector : BusinessStep.details;
      }
    case BusinessAccountType.boutique:
    case BusinessAccountType.particulierVendeur:
      if (!d.detailsIsValid) {
        return d.sectorMissing ? BusinessStep.sector : BusinessStep.details;
      }
    case BusinessAccountType.prestataireService:
      if (!d.serviceStepIsValid) return BusinessStep.serviceCategory;
    case BusinessAccountType.structure:
      if (!d.structureTypeStepIsValid) return BusinessStep.structureType;
      if (!d.structureDetailsIsValid) return BusinessStep.structureDetails;
  }
  return null;
}
