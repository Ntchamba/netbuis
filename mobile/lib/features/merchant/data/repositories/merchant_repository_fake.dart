// Version factice (USE_FAKE_API) : aucun réseau, état gardé en mémoire
import '../../../../core/network/api_exception.dart';
import 'merchant_repository.dart';

class MerchantRepositoryFake implements MerchantRepository {
  MerchantRepositoryFake({List<MerchantOffer>? initial}) : _offers = [...?initial];

  final List<MerchantOffer> _offers;
  int _nextId = 1000;

  @override
  Future<List<MerchantOffer>> listOffers() async => List.unmodifiable(_offers);

  @override
  Future<MerchantOffer> createOffer(OfferInput input) async {
    final offer = MerchantOffer(
      id: _nextId++,
      name: input.name,
      description: input.description,
      priceFcfa: input.priceFcfa,
      photos: input.photoKeys,
    );
    _offers.add(offer);
    return offer;
  }

  @override
  Future<MerchantOffer> updateOffer(int id, OfferInput input) async {
    final index = _offers.indexWhere((o) => o.id == id);
    if (index < 0) {
      throw const ApiException(ApiErrorCode.unknown, statusCode: 404, serverCode: 'not_found');
    }
    final updated = MerchantOffer(
      id: id,
      name: input.name,
      description: input.description,
      priceFcfa: input.priceFcfa,
      photos: input.photoKeys,
      catalogProduct: _offers[index].catalogProduct,
      isActive: _offers[index].isActive,
    );
    _offers[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteOffer(int id) async {
    _offers.removeWhere((o) => o.id == id);
  }
}
