import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/features/business/application/business_edit.dart';
import 'package:netbuis/features/business/data/models/business.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';
import 'package:netbuis/features/business/data/repositories/business_repository_api.dart';
import 'package:netbuis/features/business/data/repositories/business_repository_fake.dart';
import 'package:dio/dio.dart';
import 'package:netbuis/core/network/dio_client.dart';

import '../auth/auth_test_helpers.dart';
import 'business_submit_helpers.dart' show kApiUrl;

const _shop = MyBusiness(
  status: BusinessStatus.active,
  name: 'Boutique Mama Aïcha',
  typeCompte: BusinessAccountType.boutique,
  zoneId: 16,
  repere: 'Près du manguier',
  descriptionActivite: 'Fruits',
  representantNom: 'Aïcha Oumarou',
);

void main() {
  group('règles D-08 côté application', () {
    test('nom ou lieu réellement changés = sensible ; le reste non', () {
      final base = BusinessEditForm.from(_shop);
      expect(isSensitiveChange(_shop, base), isFalse);
      expect(isSensitiveChange(_shop, base.copyWith(name: 'Chez Aïcha')), isTrue);
      expect(isSensitiveChange(_shop, base.copyWith(name: '  Boutique Mama Aïcha  ')), isFalse);
      expect(isSensitiveChange(_shop, base.copyWith(zoneId: 17)), isTrue);
      expect(isSensitiveChange(_shop, base.copyWith(repere: 'Ailleurs')), isFalse);
      expect(isSensitiveChange(_shop, base.copyWith(description: 'Autre')), isFalse);
      expect(isSensitiveChange(_shop, base.copyWith(photoPath: '/p.jpg')), isFalse);
    });

    test('le corps ne contient que les champs changés, sans numéro ni type', () {
      final base = BusinessEditForm.from(_shop);
      expect(buildEditBody(_shop, base, {}), isEmpty);
      final body = buildEditBody(
        _shop,
        base.copyWith(
            name: ' Chez Aïcha ', zoneId: 17, description: 'Fruits et épices', photoPath: '/p.jpg'),
        {'photo': 'u1/photo/1'},
      );
      expect(body, {
        'name': 'Chez Aïcha',
        'zone': 17,
        'description_activite': 'Fruits et épices',
        'photo': 'u1/photo/1',
      });
      expect(body.keys, isNot(contains('phone_anchor')));
      expect(body.keys, isNot(contains('type_compte')));
    });

    test('champ de description selon le type', () {
      expect(descriptionFieldOf(BusinessAccountType.boutique), 'description_activite');
      expect(descriptionFieldOf(BusinessAccountType.entreprise), 'description_activite');
      expect(descriptionFieldOf(BusinessAccountType.particulierVendeur), 'description_activite');
      expect(descriptionFieldOf(BusinessAccountType.structure), 'description');
      expect(descriptionFieldOf(BusinessAccountType.prestataireService), isNull);
      expect(descriptionFieldOf(null), isNull);
    });

    test('erreurs locales : nom et représentant obligatoires, longueurs', () {
      final base = BusinessEditForm.from(_shop);
      expect(editErrors(_shop, base).any, isFalse);
      expect(editErrors(_shop, base.copyWith(name: ' ')).name, FieldError.required);
      expect(editErrors(_shop, base.copyWith(representantNom: '')).owner, FieldError.required);
      expect(editErrors(_shop, base.copyWith(repere: 'x' * 151)).repere, FieldError.tooLong);
      expect(editErrors(_shop, base.copyWith(description: 'x' * 501)).description,
          FieldError.tooLong);
      expect(editErrors(_shop, base.copyWith(description: 'x' * 500)).description, isNull);
    });
  });

  group('lecture du profil', () {
    test('GET /me/ : champs de modification lus, photos = présence seulement', () {
      final b = MyBusiness.fromJson({
        'status': 'rejete',
        'motif_rejet': ' CNI floue ',
        'name': 'X',
        'type_compte': 'prestataire_service',
        'zone': 17,
        'repere': 'R',
        'representant_nom': 'Y',
        'photo': 'u1/photo/abc.jpg',
        'representant_photo': '',
        'has_cni': true,
      });
      expect(b.status, BusinessStatus.rejected);
      expect(b.motifRejet, 'CNI floue');
      expect(b.typeCompte, BusinessAccountType.prestataireService);
      expect(b.zoneId, 17);
      expect(b.hasPhoto, isTrue);
      expect(b.hasRepresentantPhoto, isFalse);
      expect(b.hasCni, isTrue);
    });

    test('statut inconnu = FormatException', () {
      expect(() => MyBusiness.fromJson({'status': 'autre'}), throwsFormatException);
    });
  });

  group('dépôt API', () {
    test('update : PATCH /business/me/ avec le corps donné', () async {
      final main = FakeAdapter((r) => FakeAdapter.reply(200, {
            'status': 'en_attente_validation',
            'name': 'Chez Aïcha',
            'type_compte': 'boutique',
            'zone': 16,
          }));
      final dio = buildDio(baseUrl: kApiUrl, readAccessToken: () async => 'acc-test')
        ..httpClientAdapter = main;
      final repo = BusinessRepositoryApi(
          dio, buildUploadDio()..httpClientAdapter = FakeAdapter((r) => FakeAdapter.reply(204, null)), kApiUrl);
      final result = await repo.update({'name': 'Chez Aïcha'});
      expect(main.seen.single.method, 'PATCH');
      expect(main.seen.single.path, '/business/me/');
      expect(main.seen.single.body, {'name': 'Chez Aïcha'});
      expect(result.status, BusinessStatus.pending);
    });

    test('update : 400 avec champs -> ApiException(fieldNames) ; coupure -> network', () async {
      Future<ApiException> run(HttpClientAdapter a) async {
        final dio = buildDio(baseUrl: kApiUrl, readAccessToken: () async => 'acc-test')
          ..httpClientAdapter = a;
        final repo = BusinessRepositoryApi(dio, Dio(), kApiUrl);
        try {
          await repo.update({'name': 'x'});
        } on ApiException catch (e) {
          return e;
        }
        fail('aurait dû échouer');
      }

      final invalid = await run(FakeAdapter((r) => FakeAdapter.reply(400, {
            'code': 'invalid',
            'message': 'x',
            'fields': {'name': ['Trop long.']},
          })));
      expect(invalid.code, ApiErrorCode.invalid);
      expect(invalid.fieldNames, ['name']);
      final cut = await run(_Cut());
      expect(cut.code, ApiErrorCode.network);
    });
  });

  group('dépôt factice (USE_FAKE_API)', () {
    MyBusiness start(BusinessStatus status, {String motif = ''}) => MyBusiness(
          status: status,
          name: 'A',
          motifRejet: motif,
          typeCompte: BusinessAccountType.boutique,
          zoneId: 16,
        );

    test('actif : nom changé = en attente ; description seule = reste actif', () async {
      final repo = BusinessRepositoryFake(initial: start(BusinessStatus.active));
      expect((await repo.update({'description_activite': 'x'})).status, BusinessStatus.active);
      expect((await repo.update({'name': 'A'})).status, BusinessStatus.active);
      expect((await repo.update({'name': 'B'})).status, BusinessStatus.pending);
    });

    test('rejeté : toute modification renvoie en attente et efface le motif', () async {
      final repo = BusinessRepositoryFake(
          initial: start(BusinessStatus.rejected, motif: 'Photo floue'));
      final next = await repo.update({'repere': 'R'});
      expect(next.status, BusinessStatus.pending);
      expect(next.motifRejet, '');
      expect((await repo.getMine()).repere, 'R');
    });

    test('sans compte : 404 no_business', () async {
      expect(
        BusinessRepositoryFake().update({'name': 'x'}),
        throwsA(isA<ApiException>().having((e) => e.serverCode, 'code', ServerCodes.noBusiness)),
      );
    });
  });
}

class _Cut implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream,
      Future<void>? cancelFuture) async {
    throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
  }

  @override
  void close({bool force = false}) {}
}
