import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/forum/data/models/feed_post.dart';
import 'package:netbuis/features/forum/data/models/post.dart';

import 'forum_test_helpers.dart';
import 'post_test_helpers.dart';

ForumHarness harness(
        {int comments = 2, int pageSize = 20, List<ForumComment>? list}) =>
    ForumHarness(
      posts: [
        feedPost(1, 'Nouveau lot de riz parfumé disponible',
            comments: comments, offer: 'Riz 25kg'),
      ],
      comments: list ??
          [
            comment(10, 'Le riz 25kg est encore disponible ?',
                name: 'Jeff N.', initials: 'JN'),
            comment(11, 'Vous livrez vers Djarengol ?',
                age: const Duration(minutes: 30)),
          ],
      pageSize: pageSize,
    );

/// Ouvre la page de la première publication depuis le fil.
Future<void> openPost(WidgetTester tester, ForumHarness h) async {
  await h.pump(tester);
  await tapKey(tester, 'feed-comments-1');
}

bool fieldEnabled(WidgetTester tester) =>
    tester
        .widget<TextField>(find.byKey(const ValueKey('comment-field')))
        .enabled ??
    true;

bool sendEnabled(WidgetTester tester) =>
    tester
        .widget<IconButton>(find.byKey(const ValueKey('comment-send')))
        .onPressed !=
    null;

Future<void> write(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('comment-field')), text);
  await tester.pump();
}

void main() {
  testWidgets(
      'page d\'une publication : commerce, légende, produit, commentaires, champ',
      (tester) async {
    final h = harness();
    await openPost(tester, h);

    expect(find.text('Boutique Mama Aïcha'), findsOneWidget);
    expect(find.text('Dougoï · Il y a 2h'), findsOneWidget);
    expect(find.text('Nouveau lot de riz parfumé disponible'), findsOneWidget);
    expect(find.text('Riz 25kg'), findsOneWidget);
    expect(find.text('Commentaires · 2'), findsOneWidget);
    expect(find.text('Jeff N.'), findsOneWidget);
    expect(find.text('Le riz 25kg est encore disponible ?'), findsOneWidget);
    expect(find.text('Il y a 45 min'), findsOneWidget);
    expect(find.text('Il y a 30 min'), findsOneWidget);
    expect(find.text('Écrire un commentaire...'), findsOneWidget);
    expect(key('comment-send'), findsOneWidget);
    expect(find.text('0/300'), findsOneWidget);
    expect(screenTexts(tester).toLowerCase(), isNot(contains('abonn')));
  });

  testWidgets('le bouton « Forum » ramène au fil', (tester) async {
    final h = harness();
    await openPost(tester, h);
    await tapKey(tester, 'post-back');
    expect(key('feed-post-1'), findsOneWidget);
    expect(key('comment-field'), findsNothing);
  });

  testWidgets(
      'champ : compteur, 300 caractères au plus, envoi désactivé tant qu\'il est vide',
      (tester) async {
    final h = harness();
    await openPost(tester, h);
    expect(sendEnabled(tester), isFalse);

    await write(tester, 'Bonjour');
    expect(find.text('7/300'), findsOneWidget);
    expect(sendEnabled(tester), isTrue);

    await write(tester, 'a' * 305);
    expect(find.text('300/300'), findsOneWidget);

    await write(tester, '   ');
    expect(sendEnabled(tester), isFalse);
  });

  testWidgets(
      'commentaire affiché tout de suite, champ désactivé, double clic impossible',
      (tester) async {
    final h = harness();
    h.repo.addGate = Completer<void>();
    await openPost(tester, h);

    await write(tester, 'Merci, je passe demain');
    await tester.tap(key('comment-send'));
    await tester.pump();
    await tester.pump();

    // Avant la réponse du serveur : déjà à l'écran, marqué « Envoi en cours... ».
    expect(find.text('Merci, je passe demain'), findsOneWidget);
    expect(find.text('Envoi en cours...'), findsOneWidget);
    expect(fieldEnabled(tester), isFalse);
    expect(sendEnabled(tester), isFalse);
    expect(find.text('Commentaires · 2'), findsOneWidget);

    // Un second clic ne fait rien.
    await tester.tap(key('comment-send'), warnIfMissed: false);
    await tester.pump();
    h.repo.addGate!.complete();
    await tester.pumpAndSettle();

    expect(h.repo.added, ['Merci, je passe demain']);
    expect(find.text('Merci, je passe demain'), findsOneWidget);
    expect(find.text('Envoi en cours...'), findsNothing);
    expect(find.text('Commentaires · 3'), findsOneWidget);
    expect(fieldEnabled(tester), isTrue);
    expect(find.text('0/300'), findsOneWidget);

    // De retour dans le fil : le nombre de commentaires est à jour.
    await tapKey(tester, 'post-back');
    expect(find.text('3 commentaires · écrire un commentaire'), findsOneWidget);
  });

  for (final scenario in <(String, ApiException, String)>[
    (
      '429 comment_rate_limit',
      kRateLimit,
      'Vous avez écrit trop de commentaires'
    ),
    ('403 account_blocked', kBlocked, 'Votre compte est bloqué'),
    (
      'réseau',
      kNetworkError,
      'Pas de connexion. Votre commentaire n\'a pas été envoyé.'
    ),
  ]) {
    final network = scenario.$2.code == ApiErrorCode.network;
    testWidgets(
        'commentaire refusé (${scenario.$1}) : retiré, message, texte conservé',
        (tester) async {
      final h = harness();
      h.repo.addError = scenario.$2;
      await openPost(tester, h);

      await write(tester, 'Mon commentaire refusé');
      await tester.tap(key('comment-send'));
      await tester.pumpAndSettle();

      expect(h.repo.added, isEmpty);
      // Retiré de la liste (le seul exemplaire du texte est dans le champ).
      expect(find.text('Mon commentaire refusé'), findsOneWidget);
      expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('comment-field')))
              .controller!
              .text,
          'Mon commentaire refusé');
      expect(
          find.byWidgetPredicate(
              (w) => w is Text && w.data == 'Envoi en cours...'),
          findsNothing);
      expect(find.textContaining(scenario.$3), findsOneWidget);
      expect(find.text('Commentaires · 2'), findsOneWidget);
      // Réseau coupé : on passe « hors connexion » (champ désactivé) ; sinon on peut réessayer.
      expect(fieldEnabled(tester), !network);
      expect(sendEnabled(tester), !network);
    });
  }

  testWidgets('commentaires paginés : la suite se charge en bas de liste',
      (tester) async {
    final list = [for (var i = 1; i <= 25; i++) comment(i, 'Avis numéro $i')];
    final h = harness(comments: 25, list: list);
    await openPost(tester, h);
    expect(h.repo.commentPages, [1]);
    expect(find.text('Avis numéro 25'), findsNothing);

    await scrollDown(tester);
    expect(h.repo.commentPages, [1, 2]);
    expect(find.text('Avis numéro 25'), findsOneWidget);
    await scrollDown(tester);
    expect(h.repo.commentPages, [1, 2]);
  });

  testWidgets('la suite des commentaires échoue : « Réessayer »',
      (tester) async {
    final list = [for (var i = 1; i <= 25; i++) comment(i, 'Avis numéro $i')];
    final h = harness(comments: 25, list: list);
    await openPost(tester, h);
    h.repo.commentsError = kNetworkError;
    await scrollDown(tester);
    expect(find.text('La suite ne s\'est pas chargée.'), findsOneWidget);
    h.repo.commentsError = null;
    await tapKey(tester, 'post-more-retry');
    await scrollDown(tester);
    expect(find.text('Avis numéro 25'), findsOneWidget);
  });

  testWidgets('aucun commentaire : invitation à écrire le premier',
      (tester) async {
    final h = harness(comments: 0, list: const []);
    await openPost(tester, h);
    expect(key('post-comments-empty'), findsOneWidget);
    expect(find.text('Commentaires · 0'), findsOneWidget);
  });

  testWidgets('publication introuvable (404) : message sans « Réessayer »',
      (tester) async {
    final h = harness();
    await h.pump(tester);
    h.repo.postError = kGone;
    await tapKey(tester, 'feed-comments-1');
    expect(key('post-error'), findsOneWidget);
    expect(
        find.text('Cette publication n\'est plus disponible.'), findsOneWidget);
    expect(key('post-retry'), findsNothing);
    expect(key('comment-field'), findsNothing);
  });

  testWidgets('erreur de chargement : « Réessayer » recharge la page',
      (tester) async {
    final h = harness();
    await h.pump(tester);
    h.repo.postError = kNetworkError;
    await tapKey(tester, 'feed-comments-1');
    expect(key('post-error'), findsOneWidget);
    h.repo.postError = null;
    await tapKey(tester, 'post-retry');
    expect(key('post-error'), findsNothing);
    expect(find.text('Commentaires · 2'), findsOneWidget);
  });

  testWidgets('hors connexion : envoi de commentaire désactivé, message',
      (tester) async {
    final h = harness();
    await openPost(tester, h);
    await write(tester, 'Bonjour');
    expect(sendEnabled(tester), isTrue);

    setOffline(tester, true);
    await tester.pumpAndSettle();
    expect(key('post-offline'), findsOneWidget);
    expect(find.textContaining('Hors connexion'), findsOneWidget);
    expect(fieldEnabled(tester), isFalse);
    expect(sendEnabled(tester), isFalse);

    setOffline(tester, false);
    await tester.pumpAndSettle();
    expect(fieldEnabled(tester), isTrue);
  });

  testWidgets('texte des commentaires affiché tel quel (jamais interprété)',
      (tester) async {
    const raw = '<b>gras</b> **x** [lien](https://a.test) &amp;';
    final h =
        harness(list: [comment(10, raw, name: '<i>Nom</i>')], comments: 1);
    await openPost(tester, h);
    expect(find.text(raw), findsOneWidget);
    expect(find.text('<i>Nom</i>'), findsOneWidget);

    await write(tester, '<u>moi</u> **moi**');
    await tester.tap(key('comment-send'));
    await tester.pumpAndSettle();
    expect(find.text('<u>moi</u> **moi**'), findsOneWidget);
  });

  testWidgets(
      'vidéo sur la page : jamais lancée toute seule, ouverte à la demande',
      (tester) async {
    final h = ForumHarness(
      posts: [
        feedPost(1, 'Visite',
            type: PostMediaType.video, mediaUrl: 'https://exemple.test/v.mp4'),
      ],
    );
    await h.pump(tester, location: Routes.forum);
    await tapKey(tester, 'feed-comments-1');
    expect(h.opened, isEmpty);
    expect(find.text('Voir la vidéo'), findsOneWidget);
    await tapKey(tester, 'post-video-play');
    expect(h.opened, [Uri.parse('https://exemple.test/v.mp4')]);
  });

  testWidgets('aucun numéro de téléphone sur la page', (tester) async {
    final h = harness();
    await openPost(tester, h);
    final phone =
        RegExp(r'(\+?237)|(\d{2}[ .]?\d{2}[ .]?\d{2}[ .]?\d{2}[ .]?\d{2})');
    expect(phone.hasMatch(screenTexts(tester)), isFalse);
  });

  testWidgets('route de la page : un identifiant invalide ne plante pas',
      (tester) async {
    final h = harness();
    await h.pump(tester, location: '/forum/post/abc');
    expect(key('comment-field'), findsNothing);
  });
}
