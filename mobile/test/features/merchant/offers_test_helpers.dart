import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/account/data/models/me.dart';
import 'package:netbuis/features/business/application/business_services.dart';
import 'package:netbuis/features/business/data/models/business.dart';
import 'package:netbuis/features/business/data/repositories/business_repository.dart';
import 'package:netbuis/features/merchant/application/offers_controller.dart';
import 'package:netbuis/features/merchant/data/repositories/merchant_repository.dart';

import '../account/account_test_helpers.dart';
import '../business/business_submit_helpers.dart';
import '../business/business_test_helpers.dart';

/// Dépôt « commerçant » scénarisé : garde les appels reçus, peut échouer à la demande.
class ScriptedMerchantRepository implements MerchantRepository {
  ScriptedMerchantRepository(List<MerchantOffer> initial) : offers = [...initial];

  final List<MerchantOffer> offers;
  ApiException? listError;
  ApiException? saveError;
  ApiException? deleteError;
  int listCalls = 0;
  final List<OfferInput> created = [];
  final List<(int, OfferInput)> updated = [];
  final List<int> deleted = [];
  int _next = 500;

  @override
  Future<List<MerchantOffer>> listOffers() async {
    listCalls++;
    final e = listError;
    if (e != null) throw e;
    return List.of(offers);
  }

  @override
  Future<MerchantOffer> createOffer(OfferInput input) async {
    final e = saveError;
    if (e != null) throw e;
    created.add(input);
    final o = MerchantOffer(
        id: _next++,
        name: input.name,
        description: input.description,
        priceFcfa: input.priceFcfa,
        photos: input.photoKeys);
    offers.add(o);
    return o;
  }

  @override
  Future<MerchantOffer> updateOffer(int id, OfferInput input) async {
    final e = saveError;
    if (e != null) throw e;
    updated.add((id, input));
    final o = MerchantOffer(
        id: id,
        name: input.name,
        description: input.description,
        priceFcfa: input.priceFcfa,
        photos: input.photoKeys);
    final i = offers.indexWhere((x) => x.id == id);
    offers[i] = o;
    return o;
  }

  @override
  Future<void> deleteOffer(int id) async {
    final e = deleteError;
    if (e != null) throw e;
    deleted.add(id);
    offers.removeWhere((o) => o.id == id);
  }
}

/// Dépôt du compte business : statut choisi par le test, envois de photos enregistrés.
class ScriptedBusinessRepository implements BusinessRepository {
  ScriptedBusinessRepository(this.status);

  BusinessStatus status;
  final List<String> signedKinds = [];
  final List<String> signedTypes = [];
  int puts = 0;
  int _n = 0;

  @override
  Future<UploadTicket> signUpload(
      {required String kind, required String contentType, required int size}) async {
    signedKinds.add(kind);
    signedTypes.add(contentType);
    _n++;
    return UploadTicket(key: 'cle/$kind/$_n', uploadUrl: '/x/$_n/', headers: const {});
  }

  @override
  Future<void> putFile(UploadTicket ticket, Uint8List bytes) async => puts++;

  @override
  Future<MyBusiness> create(Map<String, Object?> body) async =>
      throw const ApiException(ApiErrorCode.unknown, statusCode: 409, serverCode: 'business_exists');

  @override
  Future<MyBusiness> getMine() async => MyBusiness(status: status, name: 'Chez Aïcha');
}

const kOfferA = MerchantOffer(id: 1, name: 'Riz parfumé 5 kg', priceFcfa: 4500, description: 'Sac de riz');
const kOfferB = MerchantOffer(id: 2, name: 'Plomberie à domicile', photos: ['cle/photo/0']);

Me get activeMe => const Me(id: 1, name: 'Jeff N.', phoneMasked: '+237 6•• •• •• 12', hasBusiness: true);

/// Lance l'application sur le Profil d'un compte avec compte business.
Future<void> pumpOffersApp(
  WidgetTester tester, {
  required ScriptedMerchantRepository merchant,
  required ScriptedBusinessRepository business,
  FakePhotoPicker? photos,
  Map<String, Uint8List>? files,
}) async {
  await pumpBusinessApp(
    tester,
    initialLocation: Routes.profile,
    account: ScriptedAccountRepository(me: activeMe),
    photos: photos,
    overrides: [
      merchantRepositoryProvider.overrideWithValue(merchant),
      businessRepositoryProvider.overrideWithValue(business),
      photoBytesReaderProvider.overrideWithValue((path) async => files?[path] ?? fakeJpeg(64)),
    ],
  );
}

Finder get productsEntry => find.byKey(const ValueKey('profile-my-products'));
