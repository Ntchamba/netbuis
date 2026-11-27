// Version factice (USE_FAKE_API) : quelques fiches de Maroua en mémoire, sans numéro
import '../../../../core/network/api_exception.dart';
import '../models/public_business.dart';
import 'public_business_repository.dart';

class PublicBusinessRepositoryFake implements PublicBusinessRepository {
  PublicBusinessRepositoryFake({List<PublicBusiness>? data}) : _data = data ?? _demo;

  final List<PublicBusiness> _data;

  @override
  Future<PublicBusiness> get(int id) async {
    for (final b in _data) {
      if (b.id == id) return b;
    }
    throw const ApiException(ApiErrorCode.unknown, statusCode: 404, serverCode: 'not_found');
  }

  static const _demo = [
    PublicBusiness(
      id: 1,
      name: 'Boutique Aminatou',
      typeCompte: 'boutique',
      secteur: 'Alimentation',
      zone: PublicZone(id: 17, name: 'Hardé'),
      repere: 'Près du marché',
      description: 'Boutique de quartier ouverte tous les jours.',
      descriptionActivite: 'Riz, huile et condiments',
      verifie: true,
      offers: [
        PublicOffer(id: 11, name: 'Riz local (sac)', priceFcfa: 18000),
        PublicOffer(id: 12, name: 'Huile de palme', description: 'Le litre'),
      ],
    ),
    PublicBusiness(
      id: 2,
      name: 'Chez Mama Riz',
      typeCompte: 'structure',
      secteur: 'Restaurant',
      structureType: 'Restaurant',
      zone: PublicZone(id: 18, name: 'Dougoï'),
      repere: 'Face à la mosquée',
      descriptionActivite: 'Cuisine camerounaise',
      whatsappAvailable: false,
      details: StructureInfo(
        cuisine: 'camerounaise',
        livraison: true,
        horaires: 'Tous les jours, 11h–22h',
      ),
    ),
  ];
}
