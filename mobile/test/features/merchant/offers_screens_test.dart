import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/features/business/data/models/business.dart';
import 'package:netbuis/features/business/data/photo_service.dart';
import 'package:netbuis/features/merchant/data/repositories/merchant_repository.dart';

import '../business/business_submit_helpers.dart';
import '../business/business_test_helpers.dart';
import 'offers_test_helpers.dart';

Finder _field(String key) => find.byKey(ValueKey(key));

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _openList(WidgetTester tester) async {
  await tester.tap(productsEntry);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Profil (compte actif) : « Mes produits » affiche le nombre et ouvre la liste',
      (tester) async {
    final merchant = ScriptedMerchantRepository([kOfferA, kOfferB]);
    await pumpOffersApp(tester,
        merchant: merchant, business: ScriptedBusinessRepository(BusinessStatus.active));

    expect(find.text('Mes produits'), findsOneWidget);
    expect(find.text('2 →'), findsOneWidget);

    await _openList(tester);
    expect(find.text('Riz parfumé 5 kg'), findsOneWidget);
    expect(find.text('4 500 FCFA'), findsOneWidget);
    expect(find.text('Plomberie à domicile'), findsOneWidget);
    expect(find.text('Sur demande'), findsOneWidget);
    expect(find.text('Ajouter un produit'), findsOneWidget);
  });

  testWidgets('liste vide : message et bouton d\'ajout', (tester) async {
    await pumpOffersApp(tester,
        merchant: ScriptedMerchantRepository([]),
        business: ScriptedBusinessRepository(BusinessStatus.active));
    expect(find.text('0 →'), findsOneWidget);
    await _openList(tester);
    expect(_field('offers-empty'), findsOneWidget);
    expect(_field('offers-add'), findsOneWidget);
  });

  testWidgets('compte en attente : message « en attente de validation », rien n\'est chargé',
      (tester) async {
    final merchant = ScriptedMerchantRepository([kOfferA]);
    await pumpOffersApp(tester,
        merchant: merchant, business: ScriptedBusinessRepository(BusinessStatus.pending));

    expect(find.text('Mes produits'), findsOneWidget);
    expect(find.text('1 →'), findsNothing);
    await _openList(tester);

    expect(_field('offers-not-active'), findsOneWidget);
    expect(find.text('En attente de validation'), findsWidgets);
    expect(find.text('Riz parfumé 5 kg'), findsNothing);
    expect(_field('offers-add'), findsNothing);
    expect(merchant.listCalls, 0);
  });

  testWidgets('compte rejeté : message dédié, pas de liste', (tester) async {
    final merchant = ScriptedMerchantRepository([kOfferA]);
    await pumpOffersApp(tester,
        merchant: merchant, business: ScriptedBusinessRepository(BusinessStatus.rejected));
    await _openList(tester);
    expect(find.text('Compte business non actif'), findsOneWidget);
    expect(_field('offers-add'), findsNothing);
    expect(merchant.listCalls, 0);
  });

  testWidgets('le serveur répond 403 business_not_active : même message, pas de liste',
      (tester) async {
    final merchant = ScriptedMerchantRepository([kOfferA])
      ..listError = const ApiException(ApiErrorCode.unknown,
          statusCode: 403, serverCode: 'business_not_active');
    await pumpOffersApp(tester,
        merchant: merchant, business: ScriptedBusinessRepository(BusinessStatus.active));
    await _openList(tester);
    expect(_field('offers-not-active'), findsOneWidget);
    expect(_field('offers-add'), findsNothing);
  });

  testWidgets('erreur réseau sur la liste : message et « Réessayer » recharge', (tester) async {
    final merchant = ScriptedMerchantRepository([kOfferA])
      ..listError = const ApiException(ApiErrorCode.network);
    await pumpOffersApp(tester,
        merchant: merchant, business: ScriptedBusinessRepository(BusinessStatus.active));
    await _openList(tester);
    expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsOneWidget);

    merchant.listError = null;
    await tester.tap(_field('offers-retry'));
    await tester.pumpAndSettle();
    expect(find.text('Riz parfumé 5 kg'), findsOneWidget);
  });

  testWidgets('ajout avec photo : prix au clavier numérique, photo envoyée (kind photo), clés envoyées',
      (tester) async {
    final merchant = ScriptedMerchantRepository([kOfferA]);
    final business = ScriptedBusinessRepository(BusinessStatus.active);
    final picker = FakePhotoPicker();
    await pumpOffersApp(tester, merchant: merchant, business: business, photos: picker);
    await _openList(tester);
    await tester.tap(_field('offers-add'));
    await tester.pumpAndSettle();

    final price = tester.widget<TextField>(_field('offer-price'));
    expect(price.keyboardType, TextInputType.number);

    await tester.enterText(_field('offer-name'), 'Savon de Marseille');
    await tester.enterText(_field('offer-price'), '12a50');
    expect(tester.widget<TextField>(_field('offer-price')).controller!.text, '1250');

    await _tapVisible(tester, _field('offer-photo-add'));
    await tester.tap(_field('offer-photo-gallery'));
    await tester.pumpAndSettle();
    expect(picker.asked, [PhotoSource.gallery]);
    expect(_field('offer-photo-0'), findsOneWidget);

    await _tapVisible(tester, _field('offer-save'));

    expect(business.signedKinds, ['photo']);
    expect(business.signedTypes, ['image/jpeg']);
    expect(business.puts, 1);
    expect(merchant.created.single.name, 'Savon de Marseille');
    expect(merchant.created.single.priceFcfa, 1250);
    expect(merchant.created.single.photoKeys, ['cle/photo/1']);
    // retour à la liste, avec le nouveau produit
    expect(find.text('Savon de Marseille'), findsOneWidget);
    expect(find.text('1 250 FCFA'), findsOneWidget);
  });

  testWidgets('ajout sans prix : « sur demande » (price_fcfa null)', (tester) async {
    final merchant = ScriptedMerchantRepository([]);
    await pumpOffersApp(tester,
        merchant: merchant, business: ScriptedBusinessRepository(BusinessStatus.active));
    await _openList(tester);
    await tester.tap(_field('offers-add'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('offer-name'), 'Coiffure');
    await _tapVisible(tester, _field('offer-save'));
    expect(merchant.created.single.priceFcfa, isNull);
    expect(find.text('Sur demande'), findsOneWidget);
  });

  testWidgets('ajout sans nom : refusé, rien n\'est envoyé', (tester) async {
    final merchant = ScriptedMerchantRepository([]);
    await pumpOffersApp(tester,
        merchant: merchant, business: ScriptedBusinessRepository(BusinessStatus.active));
    await _openList(tester);
    await tester.tap(_field('offers-add'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, _field('offer-save'));
    expect(find.text('Donnez un nom à votre produit.'), findsOneWidget);
    expect(merchant.created, isEmpty);
  });

  testWidgets('prix trop grand : refusé', (tester) async {
    final merchant = ScriptedMerchantRepository([]);
    await pumpOffersApp(tester,
        merchant: merchant, business: ScriptedBusinessRepository(BusinessStatus.active));
    await _openList(tester);
    await tester.tap(_field('offers-add'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('offer-name'), 'Or');
    await tester.enterText(_field('offer-price'), '9999999999');
    await _tapVisible(tester, _field('offer-save'));
    expect(find.text('Entrez un prix valide, en chiffres seulement.'), findsOneWidget);
    expect(merchant.created, isEmpty);
  });

  testWidgets('photo au format refusé (GIF) : message, rien n\'est créé', (tester) async {
    final merchant = ScriptedMerchantRepository([]);
    final business = ScriptedBusinessRepository(BusinessStatus.active);
    await pumpOffersApp(tester,
        merchant: merchant, business: business, files: {'/fictif/photo.jpg': fakeGif(64)});
    await _openList(tester);
    await tester.tap(_field('offers-add'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('offer-name'), 'Savon');
    await _tapVisible(tester, _field('offer-photo-add'));
    await tester.tap(_field('offer-photo-camera'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, _field('offer-save'));
    expect(find.textContaining('Une photo est refusée'), findsOneWidget);
    expect(business.signedKinds, isEmpty);
    expect(merchant.created, isEmpty);
    // le formulaire reste rempli
    expect(find.text('Savon'), findsOneWidget);
  });

  testWidgets('quatre photos au plus : la case « Ajouter une photo » disparaît', (tester) async {
    await pumpOffersApp(tester,
        merchant: ScriptedMerchantRepository([]),
        business: ScriptedBusinessRepository(BusinessStatus.active));
    await _openList(tester);
    await tester.tap(_field('offers-add'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      expect(_field('offer-photo-add'), findsOneWidget);
      await _tapVisible(tester, _field('offer-photo-add'));
      await tester.tap(_field('offer-photo-gallery'));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('offer-photo-3')), findsOneWidget);
    expect(_field('offer-photo-add'), findsNothing);
  });

  testWidgets('modification : champs préremplis, prix vidé = sur demande, photo enregistrée gardée',
      (tester) async {
    final merchant = ScriptedMerchantRepository([kOfferA, kOfferB]);
    final business = ScriptedBusinessRepository(BusinessStatus.active);
    await pumpOffersApp(tester, merchant: merchant, business: business);
    await _openList(tester);

    await tester.tap(_field('offer-2'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier le produit'), findsOneWidget);
    expect(find.text('Plomberie à domicile'), findsOneWidget);
    expect(_field('offer-photo-0'), findsOneWidget);

    await tester.enterText(_field('offer-price'), '15000');
    await tester.enterText(_field('offer-name'), 'Plomberie 24h');
    await _tapVisible(tester, _field('offer-save'));

    final (id, input) = merchant.updated.single;
    expect(id, 2);
    expect(input.name, 'Plomberie 24h');
    expect(input.priceFcfa, 15000);
    expect(input.photoKeys, ['cle/photo/0']);
    expect(business.signedKinds, isEmpty); // rien à renvoyer
    expect(find.text('15 000 FCFA'), findsOneWidget);

    // vider le prix
    await tester.tap(_field('offer-1'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('offer-price'), '');
    await _tapVisible(tester, _field('offer-save'));
    expect(merchant.updated.last.$2.priceFcfa, isNull);
  });

  testWidgets('enregistrement refusé (réseau) : message, le formulaire reste ouvert', (tester) async {
    final merchant = ScriptedMerchantRepository([])
      ..saveError = const ApiException(ApiErrorCode.network);
    await pumpOffersApp(tester,
        merchant: merchant, business: ScriptedBusinessRepository(BusinessStatus.active));
    await _openList(tester);
    await tester.tap(_field('offers-add'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('offer-name'), 'Savon');
    await _tapVisible(tester, _field('offer-save'));
    expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsOneWidget);
    expect(find.text('Ajouter un produit'), findsOneWidget); // titre de l'écran d'ajout
    expect(find.text('Savon'), findsOneWidget);
  });

  testWidgets('suppression : confirmation, « Annuler » ne supprime rien, « Supprimer » supprime',
      (tester) async {
    final merchant = ScriptedMerchantRepository([kOfferA, kOfferB]);
    await pumpOffersApp(tester,
        merchant: merchant, business: ScriptedBusinessRepository(BusinessStatus.active));
    await _openList(tester);

    await tester.tap(_field('offer-delete-1'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer ce produit ?'), findsOneWidget);
    expect(find.textContaining('Riz parfumé 5 kg'), findsWidgets);
    await tester.tap(_field('offers-delete-cancel'));
    await tester.pumpAndSettle();
    expect(merchant.deleted, isEmpty);
    expect(find.text('Riz parfumé 5 kg'), findsOneWidget);

    await tester.tap(_field('offer-delete-1'));
    await tester.pumpAndSettle();
    await tester.tap(_field('offers-delete-confirm'));
    await tester.pumpAndSettle();
    expect(merchant.deleted, [1]);
    expect(find.text('Riz parfumé 5 kg'), findsNothing);
    expect(find.text('Plomberie à domicile'), findsOneWidget);
  });

  testWidgets('suppression refusée par le serveur : message, le produit reste', (tester) async {
    final merchant = ScriptedMerchantRepository([kOfferA])
      ..deleteError = const ApiException(ApiErrorCode.network);
    await pumpOffersApp(tester,
        merchant: merchant, business: ScriptedBusinessRepository(BusinessStatus.active));
    await _openList(tester);
    await tester.tap(_field('offer-delete-1'));
    await tester.pumpAndSettle();
    await tester.tap(_field('offers-delete-confirm'));
    await tester.pumpAndSettle();
    expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsOneWidget);
    expect(find.text('Riz parfumé 5 kg'), findsOneWidget);
  });

  testWidgets('le compteur du Profil suit les ajouts et suppressions', (tester) async {
    final merchant = ScriptedMerchantRepository([kOfferA]);
    await pumpOffersApp(tester,
        merchant: merchant, business: ScriptedBusinessRepository(BusinessStatus.active));
    expect(find.text('1 →'), findsOneWidget);
    await _openList(tester);
    await tester.tap(_field('offer-delete-1'));
    await tester.pumpAndSettle();
    await tester.tap(_field('offers-delete-confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('0 →'), findsOneWidget);
  });

  test('formatFcfa regroupe les milliers', () {
    expect(formatFcfa(0), '0 FCFA');
    expect(formatFcfa(999), '999 FCFA');
    expect(formatFcfa(1000), '1 000 FCFA');
    expect(formatFcfa(2000000000), '2 000 000 000 FCFA');
  });
}
