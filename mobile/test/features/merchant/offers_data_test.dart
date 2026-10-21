import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/dio_client.dart';
import 'package:netbuis/features/merchant/data/repositories/merchant_repository.dart';
import 'package:netbuis/features/merchant/data/repositories/merchant_repository_api.dart';
import 'package:netbuis/features/merchant/data/repositories/merchant_repository_fake.dart';

import '../auth/auth_test_helpers.dart';
import '../business/business_submit_helpers.dart';

Map<String, Object?> _json(int id, {Object? price = 1500}) => {
      'id': id,
      'name': 'Produit $id',
      'description': '',
      'price_fcfa': price,
      'on_request': price == null,
      'photos': ['k/photo/$id'],
      'catalog_product': null,
      'is_active': true,
    };

MerchantRepositoryApi _repo(FakeAdapter adapter) => MerchantRepositoryApi(
    buildDio(baseUrl: kApiUrl, readAccessToken: () async => 'acc-test')..httpClientAdapter = adapter);

void main() {
  test('MerchantOffer.fromJson : prix entier, null = sur demande, photos = clés', () {
    final a = MerchantOffer.fromJson(_json(1));
    expect(a.priceFcfa, 1500);
    expect(a.onRequest, isFalse);
    expect(a.photos, ['k/photo/1']);
    expect(MerchantOffer.fromJson(_json(2, price: null)).onRequest, isTrue);
  });

  test('MerchantOffer.fromJson : réponse mal formée -> FormatException', () {
    expect(() => MerchantOffer.fromJson({'id': 'x'}), throwsFormatException);
  });

  test('listOffers lit `results` et suit les pages', () async {
    var call = 0;
    final adapter = FakeAdapter((r) {
      call++;
      return FakeAdapter.reply(200, {
        'count': 3,
        'next': call == 1 ? 'http://x/api/business/me/offers/?page=2' : null,
        'previous': null,
        'results': call == 1 ? [_json(1), _json(2)] : [_json(3)],
      });
    });
    final offers = await _repo(adapter).listOffers();
    expect(offers.map((o) => o.id), [1, 2, 3]);
    expect(adapter.seen.map((r) => r.path), ['/business/me/offers/', '/business/me/offers/']);
  });

  test('listOffers : 403 business_not_active -> ApiException avec le code du serveur', () async {
    final adapter = FakeAdapter((r) =>
        FakeAdapter.reply(403, {'code': 'business_not_active', 'message': 'non actif'}));
    await expectLater(
      _repo(adapter).listOffers(),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'status', 403)
          .having((e) => e.serverCode, 'code', 'business_not_active')),
    );
  });

  test('listOffers : corps sans `results` -> erreur inconnue', () async {
    final adapter = FakeAdapter((r) => FakeAdapter.reply(200, {'oops': 1}));
    await expectLater(_repo(adapter).listOffers(),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.unknown)));
  });

  test('createOffer / updateOffer / deleteOffer : bonnes routes et corps (prix null gardé)', () async {
    final adapter = FakeAdapter((r) => r.method == 'DELETE'
        ? FakeAdapter.reply(204, null)
        : FakeAdapter.reply(r.method == 'POST' ? 201 : 200, _json(7, price: null)));
    final repo = _repo(adapter);
    const input = OfferInput(name: 'Savon', priceFcfa: null, photoKeys: ['k/photo/1']);

    await repo.createOffer(input);
    await repo.updateOffer(7, input);
    await repo.deleteOffer(7);

    expect(adapter.seen.map((r) => '${r.method} ${r.path}'), [
      'POST /business/me/offers/',
      'PATCH /business/me/offers/7/',
      'DELETE /business/me/offers/7/',
    ]);
    expect(adapter.seen.first.body,
        {'name': 'Savon', 'description': '', 'price_fcfa': null, 'photos': ['k/photo/1']});
  });

  test('dépôt factice : création, modification, suppression en mémoire', () async {
    final repo = MerchantRepositoryFake();
    final a = await repo.createOffer(const OfferInput(name: 'A', priceFcfa: 10));
    final b = await repo.createOffer(const OfferInput(name: 'B'));
    expect((await repo.listOffers()).length, 2);
    final changed = await repo.updateOffer(a.id, const OfferInput(name: 'A2', priceFcfa: 20));
    expect(changed.name, 'A2');
    await repo.deleteOffer(b.id);
    expect((await repo.listOffers()).map((o) => o.name), ['A2']);
    await expectLater(repo.updateOffer(999, const OfferInput(name: 'x')), throwsA(isA<ApiException>()));
  });
}
