// Contrat du dépôt « espace commerçant » : Mes produits (GET/POST/PATCH/DELETE /api/business/me/offers/)

/// Une offre (« produit ») du commerçant, telle que le serveur la renvoie.
class MerchantOffer {
  const MerchantOffer({
    required this.id,
    required this.name,
    this.description = '',
    this.priceFcfa,
    this.photos = const [],
    this.catalogProduct,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String description;

  /// Prix en FCFA (entier ≥ 0) ; `null` = « sur demande ».
  final int? priceFcfa;

  /// Clés de stockage des photos (4 au plus), jamais des adresses.
  final List<String> photos;
  final int? catalogProduct;
  final bool isActive;

  bool get onRequest => priceFcfa == null;

  /// Lève [FormatException] si la réponse n'a pas la forme du contrat.
  factory MerchantOffer.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! int || name is! String) {
      throw const FormatException('Offre inattendue');
    }
    final description = json['description'];
    final price = json['price_fcfa'];
    final photos = json['photos'];
    final catalog = json['catalog_product'];
    return MerchantOffer(
      id: id,
      name: name,
      description: description is String ? description : '',
      priceFcfa: price is int ? price : null,
      photos: [
        if (photos is List)
          for (final p in photos)
            if (p is String) p,
      ],
      catalogProduct: catalog is int ? catalog : null,
      isActive: json['is_active'] != false,
    );
  }
}

/// Ce que le formulaire envoie : les photos sont déjà des clés de stockage.
class OfferInput {
  const OfferInput({
    required this.name,
    this.description = '',
    this.priceFcfa,
    this.photoKeys = const [],
  });

  final String name;
  final String description;

  /// `null` = « sur demande ».
  final int? priceFcfa;
  final List<String> photoKeys;

  Map<String, Object?> toJson() => {
        'name': name,
        'description': description,
        'price_fcfa': priceFcfa,
        'photos': photoKeys,
      };
}

/// Prix lisible : `1500` → `1 500 FCFA`.
String formatFcfa(int value) {
  final digits = value.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
    out.write(digits[i]);
  }
  return '$out FCFA';
}

abstract class MerchantRepository {
  /// Toutes les offres du commerçant (le dépôt suit les pages `next`).
  Future<List<MerchantOffer>> listOffers();

  Future<MerchantOffer> createOffer(OfferInput input);

  Future<MerchantOffer> updateOffer(int id, OfferInput input);

  Future<void> deleteOffer(int id);
}
