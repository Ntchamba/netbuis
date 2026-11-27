// Choix proposés par l'écran « Détails de l'établissement » (maquette CreationBusiness-Structure-Details)

/// Un choix : [code] est la valeur du serveur (profile.py), envoyée telle quelle ;
/// le libellé affiché est la clé de traduction [labelKey].
class StructureOption {
  const StructureOption(this.code, this.labelKey);

  final String code;
  final String labelKey;
}

const String _p = 'business.create.structure.';

/// Rayons d'un supermarché (`Aisle`), dans l'ordre de la maquette.
const List<StructureOption> kAisleOptions = [
  StructureOption('alimentation_generale', '${_p}aisle.alimentation_generale'),
  StructureOption('produits_frais', '${_p}aisle.produits_frais'),
  StructureOption('boissons', '${_p}aisle.boissons'),
  StructureOption('hygiene_beaute', '${_p}aisle.hygiene_beaute'),
  StructureOption('entretien_maison', '${_p}aisle.entretien_maison'),
  StructureOption('bazar_electromenager', '${_p}aisle.bazar_electromenager'),
  StructureOption('produits_bebes', '${_p}aisle.produits_bebes'),
  StructureOption('autre', '${_p}aisle.autre'),
];

/// Cuisines d'un restaurant (`Cuisine`).
const List<StructureOption> kCuisineOptions = [
  StructureOption('camerounaise', '${_p}cuisine.camerounaise'),
  StructureOption('africaine_autre_pays', '${_p}cuisine.africaine_autre_pays'),
  StructureOption('fast_food', '${_p}cuisine.fast_food'),
  StructureOption('pizzeria_occidentale', '${_p}cuisine.pizzeria_occidentale'),
  StructureOption('autre', '${_p}cuisine.autre'),
];

/// Standing d'un hôtel (`Standing`).
const List<StructureOption> kStandingOptions = [
  StructureOption('economique', '${_p}standing.economique'),
  StructureOption('standard', '${_p}standing.standard'),
  StructureOption('confort', '${_p}standing.confort'),
  StructureOption('haut_standing', '${_p}standing.haut_standing'),
];

/// Équipements d'un hôtel (`Amenity`).
const List<StructureOption> kAmenityOptions = [
  StructureOption('petit_dejeuner', '${_p}amenity.petit_dejeuner'),
  StructureOption('wifi', '${_p}amenity.wifi'),
  StructureOption('parking', '${_p}amenity.parking'),
  StructureOption('climatisation', '${_p}amenity.climatisation'),
];

/// Spécialités d'un centre de santé (`Speciality`).
const List<StructureOption> kSpecialityOptions = [
  StructureOption('medecine_generale', '${_p}speciality.medecine_generale'),
  StructureOption('pediatrie', '${_p}speciality.pediatrie'),
  StructureOption('gynecologie', '${_p}speciality.gynecologie'),
  StructureOption('dentisterie', '${_p}speciality.dentisterie'),
  StructureOption('laboratoire', '${_p}speciality.laboratoire'),
  StructureOption('pharmacie_interne', '${_p}speciality.pharmacie_interne'),
  StructureOption('autre', '${_p}speciality.autre'),
];
