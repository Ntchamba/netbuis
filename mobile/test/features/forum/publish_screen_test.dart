import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/business/data/models/business.dart';
import 'package:netbuis/features/business/data/photo_service.dart';

import '../business/business_submit_helpers.dart';
import '../merchant/offers_test_helpers.dart';
import 'post_test_helpers.dart';

/// Ouvre « Mes publications » puis « Publier » (comme l'utilisateur).
Future<void> openPublish(WidgetTester tester, PostsHarness h) async {
  await h.pump(tester);
  await tapKey(tester, 'posts-publish');
  expect(key('post-publish'), findsOneWidget);
}

Future<void> chooseMedia(WidgetTester tester, String optionKey, String path) async {
  await tapKey(tester, 'post-media');
  await tester.tap(key(optionKey));
  await tester.pumpAndSettle();
}

bool publishEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(key('post-publish')).onPressed != null;

void main() {
  testWidgets('publication réussie avec une photo, une légende et un produit', (tester) async {
    final h = PostsHarness(offers: [kOfferA, kOfferB]);
    h.picker.result = '/fictif/riz.jpg';
    h.files['/fictif/riz.jpg'] = fakeJpeg(900);
    await openPublish(tester, h);

    // Textes de la maquette.
    expect(find.text('Nouvelle publication'), findsOneWidget);
    expect(find.text('Ajouter une photo ou une vidéo'), findsOneWidget);
    expect(find.text('Légende'), findsOneWidget);
    expect(find.text('Associer un produit (optionnel)'), findsOneWidget);
    expect(find.text('Aucun produit sélectionné'), findsOneWidget);
    expect(
        find.text(
            'Visible par tous les utilisateurs de NetBuis dans le fil Forum, à partir de votre compte Business.'),
        findsOneWidget);
    expect(publishEnabled(tester), isFalse, reason: 'pas de média : Publier désactivé');

    await chooseMedia(tester, 'post-media-camera', '/fictif/riz.jpg');
    expect(h.picker.asked, [(PhotoSource.camera, false)]);
    expect(key('post-media-image'), findsOneWidget);
    expect(publishEnabled(tester), isTrue);

    await tester.enterText(key('post-caption'), 'Riz parfumé en promotion');
    await tester.pump();
    expect(find.text('24/500'), findsOneWidget);

    await tapKey(tester, 'post-offer');
    expect(key('post-offer-none'), findsOneWidget);
    expect(find.text('Plomberie à domicile'), findsOneWidget);
    await tester.tap(key('post-offer-1'));
    await tester.pumpAndSettle();
    expect(find.text('Riz parfumé 5 kg'), findsOneWidget);

    await tapKey(tester, 'post-publish');

    expect(h.business.signedKinds, ['post_image']);
    expect(h.business.signedTypes, ['image/jpeg']);
    expect(h.business.puts, 1);
    expect(h.forum.created, hasLength(1));
    expect(h.forum.created.single.mediaKey, 'cle/post_image/1');
    expect(h.forum.created.single.caption, 'Riz parfumé en promotion');
    expect(h.forum.created.single.offerId, 1);
    // Retour sur « Mes publications », qui montre la nouvelle publication.
    expect(find.text('Publication envoyée.'), findsOneWidget);
    expect(key('post-publish'), findsNothing);
    expect(find.text('Riz parfumé en promotion'), findsOneWidget);
  });

  testWidgets('une vidéo MP4 de la galerie est envoyée comme post_video', (tester) async {
    final h = PostsHarness();
    h.picker.result = '/fictif/film.mp4';
    h.files['/fictif/film.mp4'] = fakeMp4(2000);
    await openPublish(tester, h);

    await chooseMedia(tester, 'post-media-video-gallery', '/fictif/film.mp4');
    expect(h.picker.asked, [(PhotoSource.gallery, true)]);
    expect(key('post-media-video'), findsOneWidget);

    await tapKey(tester, 'post-publish');
    expect(h.business.signedKinds, ['post_video']);
    expect(h.business.signedTypes, ['video/mp4']);
    expect(h.forum.created.single.mediaKey, 'cle/post_video/1');
    expect(h.forum.created.single.caption, '');
    expect(h.forum.created.single.offerId, isNull);
  });

  testWidgets('légende trop longue : compteur rouge, message, Publier désactivé', (tester) async {
    final h = PostsHarness();
    await openPublish(tester, h);
    await chooseMedia(tester, 'post-media-gallery', '/fictif/photo.jpg');
    expect(publishEnabled(tester), isTrue);

    await tester.enterText(key('post-caption'), 'a' * 500);
    await tester.pump();
    expect(find.text('500/500'), findsOneWidget);
    expect(key('post-caption-error'), findsNothing);
    expect(publishEnabled(tester), isTrue);

    await tester.enterText(key('post-caption'), 'a' * 501);
    await tester.pump();
    expect(find.text('501/500'), findsOneWidget);
    expect(key('post-caption-error'), findsOneWidget);
    expect(find.text('La légende est trop longue : 500 caractères au plus.'), findsOneWidget);
    expect(publishEnabled(tester), isFalse);
    expect(h.forum.created, isEmpty);

    await tester.enterText(key('post-caption'), 'a' * 12);
    await tester.pump();
    expect(key('post-caption-error'), findsNothing);
    expect(publishEnabled(tester), isTrue);
  });

  testWidgets('plafond de 5 publications atteint : message clair, rien ne se bloque',
      (tester) async {
    final h = PostsHarness()..forum.createError = kCapError;
    await openPublish(tester, h);
    await chooseMedia(tester, 'post-media-gallery', '/fictif/photo.jpg');
    await tapKey(tester, 'post-publish');

    expect(find.textContaining('maximum de 5 publications actives'), findsOneWidget);
    expect(key('post-see-mine'), findsOneWidget);
    expect(find.textContaining('abonnement'), findsNothing, reason: 'pas de paiement proposé');
    expect(h.forum.created, isEmpty);
    expect(publishEnabled(tester), isTrue, reason: 'la personne peut corriger puis réessayer');

    await tapKey(tester, 'post-see-mine');
    expect(find.text('Mes publications'), findsWidgets);
    expect(key('post-publish'), findsNothing);
  });

  testWidgets('limite du jour atteinte (429) : message « demain »', (tester) async {
    final h = PostsHarness()..forum.createError = kDailyError;
    await openPublish(tester, h);
    await chooseMedia(tester, 'post-media-gallery', '/fictif/photo.jpg');
    await tapKey(tester, 'post-publish');

    expect(find.text('Vous avez atteint la limite de 5 publications par jour. Réessayez demain.'),
        findsOneWidget);
    expect(key('post-see-mine'), findsNothing);
    expect(h.forum.created, isEmpty);
  });

  testWidgets('compte en attente : « en attente de validation », aucun formulaire',
      (tester) async {
    final h = PostsHarness(status: BusinessStatus.pending);
    await h.pump(tester, location: Routes.publish);
    expect(key('posts-not-active'), findsOneWidget);
    expect(find.text('En attente de validation'), findsOneWidget);
    expect(key('post-media'), findsNothing);
    expect(key('post-caption'), findsNothing);
    expect(publishEnabled(tester), isFalse);
  });

  testWidgets('compte rejeté : message dédié', (tester) async {
    final h = PostsHarness(status: BusinessStatus.rejected);
    await h.pump(tester, location: Routes.publish);
    expect(find.text('Compte business non actif'), findsOneWidget);
    expect(key('post-media'), findsNothing);
  });

  testWidgets('hors connexion : Publier désactivé avec message, puis réactivé au retour du réseau',
      (tester) async {
    final h = PostsHarness();
    await h.pump(tester, location: Routes.publish);
    await chooseMedia(tester, 'post-media-gallery', '/fictif/photo.jpg');
    expect(publishEnabled(tester), isTrue);

    setOffline(tester, true);
    await tester.pumpAndSettle();
    expect(key('post-offline'), findsOneWidget);
    expect(find.textContaining('Hors connexion'), findsOneWidget);
    expect(publishEnabled(tester), isFalse);

    // Le réseau revient : « Réessayer » interroge le serveur et lève le blocage.
    await tapKey(tester, 'post-offline-retry');
    expect(h.forum.listCalls, greaterThan(0));
    expect(key('post-offline'), findsNothing);
    expect(publishEnabled(tester), isTrue);
  });

  testWidgets('hors connexion : « Réessayer » sans réseau garde Publier désactivé', (tester) async {
    final h = PostsHarness();
    await h.pump(tester, location: Routes.publish);
    await chooseMedia(tester, 'post-media-gallery', '/fictif/photo.jpg');
    h.forum.listError = kNetworkError;
    setOffline(tester, true);
    await tester.pumpAndSettle();
    await tapKey(tester, 'post-offline-retry');
    expect(key('post-offline'), findsOneWidget);
    expect(publishEnabled(tester), isFalse);
  });

  testWidgets('échec d\'envoi du fichier : aucune publication créée, message, on peut réessayer',
      (tester) async {
    final h = PostsHarness();
    h.business.putError = kNetworkError;
    await openPublish(tester, h);
    await chooseMedia(tester, 'post-media-gallery', '/fictif/photo.jpg');
    await tester.enterText(key('post-caption'), 'Bonjour');
    await tapKey(tester, 'post-publish');

    expect(h.forum.created, isEmpty, reason: 'pas de publication sans fichier');
    expect(h.forum.posts, isEmpty);
    expect(find.textContaining('Rien n\'a été publié'), findsOneWidget);
    expect(find.text('Bonjour'), findsOneWidget, reason: 'la légende n\'est pas perdue');

    // Le fichier passe au second essai : la publication est créée.
    h.business.putError = null;
    setOffline(tester, false);
    await tester.pumpAndSettle();
    await tapKey(tester, 'post-publish');
    expect(h.forum.created, hasLength(1));
  });

  testWidgets('échec de l\'envoi refusé par le serveur (type) : aucune publication', (tester) async {
    final h = PostsHarness();
    h.business.putError =
        const ApiException(ApiErrorCode.invalid, statusCode: 400, serverCode: 'invalid_type');
    await openPublish(tester, h);
    await chooseMedia(tester, 'post-media-gallery', '/fictif/photo.jpg');
    await tapKey(tester, 'post-publish');
    expect(h.forum.created, isEmpty);
    expect(find.textContaining('Ce fichier est refusé'), findsOneWidget);
  });

  testWidgets('type de fichier refusé (GIF) : message, aucun envoi', (tester) async {
    final h = PostsHarness();
    h.picker.result = '/fictif/anime.jpg'; // extension trompeuse : seuls les octets comptent
    h.files['/fictif/anime.jpg'] = fakeGif(500);
    await openPublish(tester, h);
    await chooseMedia(tester, 'post-media-gallery', '/fictif/anime.jpg');

    expect(key('post-media-error'), findsOneWidget);
    expect(find.textContaining('Ce fichier est refusé'), findsOneWidget);
    expect(key('post-media-image'), findsNothing);
    expect(publishEnabled(tester), isFalse);
    expect(h.business.signedKinds, isEmpty);
    expect(h.business.puts, 0);
    expect(h.forum.created, isEmpty);
  });

  testWidgets('photo de plus de 5 Mo : refusée avant tout envoi', (tester) async {
    final h = PostsHarness();
    h.files['/fictif/photo.jpg'] = fakeJpeg(5 * 1024 * 1024 + 1);
    await openPublish(tester, h);
    await chooseMedia(tester, 'post-media-gallery', '/fictif/photo.jpg');
    expect(find.textContaining('trop gros'), findsOneWidget);
    expect(publishEnabled(tester), isFalse);
    expect(h.business.signedKinds, isEmpty);
  });

  testWidgets('appareil photo inaccessible : message, rien de choisi', (tester) async {
    final h = PostsHarness()..picker.fail = true;
    await openPublish(tester, h);
    await chooseMedia(tester, 'post-media-camera', '/fictif/photo.jpg');
    expect(find.textContaining('Impossible d\'ouvrir l\'appareil photo'), findsOneWidget);
    expect(publishEnabled(tester), isFalse);
  });

  testWidgets('double appui sur Publier : un seul envoi, bouton désactivé, progression visible',
      (tester) async {
    final h = PostsHarness();
    final gate = Completer<void>();
    h.forum.createGate = gate;
    await openPublish(tester, h);
    await chooseMedia(tester, 'post-media-gallery', '/fictif/photo.jpg');

    await tester.tap(key('post-publish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Second appui immédiat : sans effet.
    await tester.tap(key('post-publish'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));

    expect(publishEnabled(tester), isFalse);
    expect(key('post-progress'), findsOneWidget);
    expect(find.text('Publication en cours...'), findsOneWidget);
    expect(h.business.puts, 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(h.forum.created, hasLength(1));
    expect(h.business.puts, 1);
  });

  testWidgets('produit associé : « Aucun produit » remet à zéro, liste vide expliquée',
      (tester) async {
    final h = PostsHarness(offers: [kOfferA]);
    await openPublish(tester, h);
    await tapKey(tester, 'post-offer');
    await tester.tap(key('post-offer-1'));
    await tester.pumpAndSettle();
    expect(find.text('Riz parfumé 5 kg'), findsOneWidget);
    await tapKey(tester, 'post-offer');
    await tester.tap(key('post-offer-none'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun produit sélectionné'), findsOneWidget);
  });

  testWidgets('produit associé : aucun produit enregistré -> message', (tester) async {
    final h = PostsHarness();
    await openPublish(tester, h);
    await tapKey(tester, 'post-offer');
    expect(key('post-offers-message'), findsOneWidget);
    expect(find.textContaining('pas encore de produit'), findsOneWidget);
  });
}
