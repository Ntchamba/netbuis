// Fiche publique d'un commerce (`GET /api/business/{id}/`). Aucun numéro, aucune CNI,
// aucun motif de rejet : le serveur ne les renvoie pas et ce modèle n'a pas de champ pour eux.

/// Une offre active (produit ou service). [priceFcfa] null = « sur demande ».
class PublicOffer {
  const PublicOffer({
    required this.id,
    required this.name,
    this.description = '',
    this.priceFcfa,
    this.photos = const [],
  });

  final int id;
  final String name;
  final String description;
  final int? priceFcfa;
  final List<String> photos;

  bool get onRequest => priceFcfa == null;

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat.
  factory PublicOffer.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) throw const FormatException('Offre inattendue');
    final id = json['id'];
    final name = json['name'];
    final desc = json['description'];
    final price = json['price_fcfa'];
    if (id is! int || name is! String || (price != null && price is! int)) {
      throw const FormatException('Offre inattendue');
    }
    return PublicOffer(
      id: id,
      name: name,
      description: desc is String ? desc : '',
      priceFcfa: price as int?,
      photos: _strings(json['photos']),
    );
  }
}

class PublicZone {
  const PublicZone({required this.id, required this.name});

  final int id;
  final String name;
}

/// Détails de structure (champs publics seulement ; clés du serveur).
class StructureInfo {
  const StructureInfo({
    this.cuisine = '',
    this.livraison,
    this.horaires = '',
    this.standing = '',
    this.nombreChambres,
    this.equipements = const [],
    this.rayons = const [],
    this.specialites = const [],
  });

  final String cuisine;
  final bool? livraison;
  final String horaires;
  final String standing;
  final int? nombreChambres;
  final List<String> equipements;
  final List<String> rayons;
  final List<String> specialites;

  bool get isEmpty =>
      cuisine.isEmpty &&
      livraison == null &&
      horaires.isEmpty &&
      standing.isEmpty &&
      nombreChambres == null &&
      equipements.isEmpty &&
      rayons.isEmpty &&
      specialites.isEmpty;

  factory StructureInfo.fromJson(Object? json) {
    if (json is! Map) return const StructureInfo();
    String s(String k) => json[k] is String ? (json[k] as String).trim() : '';
    final rooms = json['nombre_chambres'];
    final delivery = json['livraison'];
    return StructureInfo(
      cuisine: s('cuisine'),
      livraison: delivery is bool ? delivery : null,
      horaires: s('horaires'),
      standing: s('standing'),
      nombreChambres: rooms is int ? rooms : null,
      equipements: _strings(json['equipements']),
      rayons: _strings(json['rayons']),
      specialites: _strings(json['specialites']),
    );
  }
}

class PublicBusiness {
  const PublicBusiness({
    required this.id,
    required this.name,
    required this.typeCompte,
    this.kind = 'produit',
    this.secteur = '',
    this.zone,
    this.repere = '',
    this.description = '',
    this.descriptionActivite = '',
    this.photos = const [],
    this.verifie = false,
    this.whatsappAvailable = true,
    this.formeJuridique = '',
    this.diplomeFourni = false,
    this.structureType = '',
    this.details = const StructureInfo(),
    this.offers = const [],
  });

  final int id;
  final String name;

  /// `boutique`, `entreprise`, `particulier_vendeur`, `prestataire_service`, `structure`.
  final String typeCompte;
  final String kind;
  final String secteur;
  final PublicZone? zone;
  final String repere;
  final String description;
  final String descriptionActivite;
  final List<String> photos;
  final bool verifie;
  final bool whatsappAvailable;

  /// Code de forme juridique (entreprise seulement), traduit par l'interface.
  final String formeJuridique;
  final bool diplomeFourni;

  /// Nom du type d'établissement (structure), tel que donné par le serveur.
  final String structureType;
  final StructureInfo details;

  /// Offres actives.
  final List<PublicOffer> offers;

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat.
  factory PublicBusiness.fromJson(Object? data) {
    if (data is! Map<String, dynamic>) throw const FormatException('Fiche inattendue');
    final id = data['id'];
    final name = data['name'];
    final type = data['type_compte'];
    final zone = data['zone'];
    final offers = data['offers'];
    if (id is! int || name is! String || type is! String) {
      throw const FormatException('Fiche inattendue');
    }
    PublicZone? parsedZone;
    if (zone is Map) {
      final zid = zone['id'];
      final zname = zone['name'];
      if (zid is! int || zname is! String) throw const FormatException('Fiche inattendue');
      parsedZone = PublicZone(id: zid, name: zname);
    }
    String s(String k) => data[k] is String ? (data[k] as String).trim() : '';
    return PublicBusiness(
      id: id,
      name: name,
      typeCompte: type,
      kind: s('kind').isEmpty ? 'produit' : s('kind'),
      secteur: s('secteur'),
      zone: parsedZone,
      repere: s('repere'),
      description: s('description'),
      descriptionActivite: s('description_activite'),
      photos: _strings(data['photos']),
      verifie: data['verifie'] == true,
      whatsappAvailable: data['whatsapp_available'] != false,
      formeJuridique: s('forme_juridique'),
      diplomeFourni: data['diplome_fourni'] == true,
      structureType: s('structure_type'),
      details: StructureInfo.fromJson(data['details']),
      offers: List.unmodifiable([
        if (offers is List) for (final o in offers) PublicOffer.fromJson(o),
      ]),
    );
  }
}

List<String> _strings(Object? v) =>
    v is List ? List.unmodifiable([for (final e in v) if (e is String) e]) : const [];
