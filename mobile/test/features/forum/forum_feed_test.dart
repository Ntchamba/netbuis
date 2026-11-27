import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/forum/application/forum_services.dart';
import 'package:netbuis/features/business/data/models/business.dart';
import 'package:netbuis/features/forum/data/forum_feed_cache.dart';
import 'package:netbuis/features/forum/data/models/feed_post.dart';
import 'package:netbuis/features/forum/data/models/post.dart';
import 'package:netbuis/features/forum/presentation/widgets/feed_post_card.dart';
import 'package:netbuis/features/search/application/offline_controller.dart';

import '../business/business_test_helpers.dart';
import 'forum_test_helpers.dart';
import 'post_test_helpers.dart';

List<FeedPost> threeFeedPosts() => [
      feedPost(1, 'Nouveau lot de riz parfumé disponible',
          comments: 6, offer: 'Riz 25kg'),
      feedPost(2, 'Modèles de boubous pour la rentrée',
          name: 'Couturier Ibrahim',
          initials: 'IB',
          zone: 'Domayo',
          age: const Duration(hours: 5),
          comments: 1),
      feedPost(3, 'Panneaux solaires, devis gratuit',
          name: 'Électricien qualifié',
          initials: 'EL',
          zone: 'Hardé',
          age: const Duration(days: 1, hours: 2)),
    ];

ForumHarness harness(
    {int count = 3, int pageSize = 20, BusinessStatus? status}) {
  final posts = [
    ...threeFeedPosts(),
    for (var i = 4; i <= count; i++)
      feedPost(i, 'Publication n°$i', age: Duration(days: i)),
  ];
  return ForumHarness(
    posts: posts.take(count).toList(),
    pageSize: pageSize,
    businessStatus: status ?? BusinessStatus.active,
  );
}

void main() {
  testWidgets(
      'fil : commerce, zone · il y a x h, légende, étiquette produit, nombre de commentaires',
      (tester) async {
    final h = harness();
    await h.pump(tester);

    expect(find.text('Forum'), findsWidgets);
    expect(find.text('Publications des commerçants'), findsOneWidget);
    expect(find.text('Boutique Mama Aïcha'), findsOneWidget);
    expect(find.text('MA'), findsOneWidget);
    expect(find.text('Dougoï · Il y a 2h'), findsOneWidget);
    expect(find.text('Nouveau lot de riz parfumé disponible'), findsOneWidget);
    expect(find.text('Riz 25kg'), findsOneWidget);
    expect(find.text('6 commentaires · écrire un commentaire'), findsOneWidget);
    expect(find.text('1 commentaire · écrire un commentaire'), findsOneWidget);
    expect(find.text('Domayo · Il y a 5h'), findsOneWidget);
    // La 3ᵉ carte est plus bas : la liste ne la construit qu'en y arrivant (chargement paresseux).
    expect(find.text('Hardé · Il y a 1 jour'), findsNothing);
    await tester.scrollUntilVisible(
        find.text('0 commentaires · écrire un commentaire'), 300);
    expect(find.text('Hardé · Il y a 1 jour'), findsOneWidget);
  });

  testWidgets('fil : filtré sur la ville choisie (zone envoyée au serveur)',
      (tester) async {
    final h = harness();
    await h.pump(tester);
    // La ville de test est « Maroua » (identifiant 16).
    expect(h.repo.feedCalls.first, (zone: 16, page: 1));
  });

  testWidgets('aucune étiquette « abonné » dans le fil', (tester) async {
    final h = harness();
    await h.pump(tester);
    expect(screenTexts(tester).toLowerCase(), isNot(contains('abonn')));
  });

  testWidgets('pagination infinie : la page 2 se charge en bas de liste',
      (tester) async {
    final h = harness(count: 25);
    await h.pump(tester);
    expect(h.repo.feedCalls.map((c) => c.page), [1]);
    expect(find.text('Publication n°25'), findsNothing);

    await scrollDown(tester);
    expect(h.repo.feedCalls.map((c) => c.page), [1, 2]);
    expect(find.text('Publication n°25'), findsOneWidget);
    // Plus de page suivante : pas de troisième appel.
    await scrollDown(tester);
    expect(h.repo.feedCalls.map((c) => c.page), [1, 2]);
  });

  testWidgets(
      'la page suivante échoue : les publications restent, « Réessayer » relance',
      (tester) async {
    final h = harness(count: 25);
    await h.pump(tester);
    h.repo.feedError = kNetworkError;
    await scrollDown(tester);
    expect(find.text('La suite ne s\'est pas chargée.'), findsOneWidget);
    expect(find.byType(FeedPostCard), findsWidgets);

    h.repo.feedError = null;
    await tapKey(tester, 'forum-more-retry');
    await scrollDown(tester);
    expect(find.text('Publication n°25'), findsOneWidget);
  });

  testWidgets('aucune publication : « Aucune publication dans votre zone »',
      (tester) async {
    final h = ForumHarness();
    await h.pump(tester);
    expect(find.text('Aucune publication dans votre zone'), findsOneWidget);
    expect(key('forum-empty'), findsOneWidget);
  });

  testWidgets('erreur de chargement : message et « Réessayer »',
      (tester) async {
    final h = harness()..repo.feedError = kNetworkError;
    await h.pump(tester);
    expect(key('forum-error'), findsOneWidget);
    expect(find.textContaining('Pas de connexion'), findsOneWidget);

    h.repo.feedError = null;
    await tapKey(tester, 'forum-retry');
    expect(key('forum-error'), findsNothing);
    expect(find.text('Nouveau lot de riz parfumé disponible'), findsOneWidget);
  });

  testWidgets('tirer pour rafraîchir : nouvelle demande de la première page',
      (tester) async {
    final h = harness();
    await h.pump(tester);
    expect(h.repo.feedCalls.length, 1);
    h.repo.posts.insert(0, feedPost(50, 'Toute nouvelle publication'));

    await tester.fling(find.text('Nouveau lot de riz parfumé disponible'),
        const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(h.repo.feedCalls.length, 2);
    expect(h.repo.feedCalls.last.page, 1);
    expect(find.text('Toute nouvelle publication'), findsOneWidget);
  });

  testWidgets(
      'rafraîchissement refusé : le fil affiché reste, un message le dit',
      (tester) async {
    final h = harness();
    await h.pump(tester);
    h.repo.feedError = kNetworkError;
    await tester.fling(find.text('Nouveau lot de riz parfumé disponible'),
        const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Le fil n\'a pas pu être actualisé.'), findsOneWidget);
    expect(find.text('Nouveau lot de riz parfumé disponible'), findsOneWidget);
  });

  testWidgets(
      'hors connexion avec un fil enregistré : dernier fil + « Hors connexion »',
      (tester) async {
    final cache = MemoryForumFeedCache();
    // Première ouverture avec réseau : le fil est mémorisé.
    await ForumHarness(posts: threeFeedPosts(), cache: cache).pump(tester);
    expect(cache.writes, 1);

    // Ouverture suivante sans réseau.
    final offline = ForumHarness(posts: const [], cache: cache);
    offline.repo.feedError = kNetworkError;
    await offline.pump(tester);
    expect(key('forum-offline'), findsOneWidget);
    expect(find.textContaining('Hors connexion'), findsOneWidget);
    expect(find.text('Nouveau lot de riz parfumé disponible'), findsOneWidget);
    expect(key('forum-error'), findsNothing);
  });

  testWidgets('hors connexion sans fil enregistré : simple message d\'erreur',
      (tester) async {
    final h = ForumHarness()..repo.feedError = kNetworkError;
    await h.pump(tester);
    expect(key('forum-offline'), findsNothing);
    expect(key('forum-error'), findsOneWidget);
  });

  testWidgets('fil enregistré d\'une autre ville : pas montré', (tester) async {
    final cache = MemoryForumFeedCache();
    await cache.write(
        CachedFeed(zone: 99, items: [feedPost(1, 'Ailleurs')], count: 1));
    final h = ForumHarness(cache: cache)..repo.feedError = kNetworkError;
    await h.pump(tester);
    expect(find.text('Ailleurs'), findsNothing);
    expect(key('forum-error'), findsOneWidget);
  });

  testWidgets('une erreur serveur (non réseau) ne montre pas le fil enregistré',
      (tester) async {
    final cache = MemoryForumFeedCache();
    await cache
        .write(CachedFeed(zone: 16, items: [feedPost(1, 'Ancien')], count: 1));
    final h = ForumHarness(cache: cache)
      ..repo.feedError =
          const ApiException(ApiErrorCode.unknown, statusCode: 500);
    await h.pump(tester);
    expect(find.text('Ancien'), findsNothing);
    expect(key('forum-error'), findsOneWidget);
  });

  testWidgets(
      'hors connexion détecté après coup : l\'état « hors connexion » est partagé',
      (tester) async {
    final h = harness();
    await h.pump(tester);
    expect(containerOf(tester).read(offlineProvider), isFalse);
    h.repo.feedError = kNetworkError;
    await tester.fling(find.text('Nouveau lot de riz parfumé disponible'),
        const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(containerOf(tester).read(offlineProvider), isTrue);
  });

  testWidgets('bouton « + » seulement pour un compte business actif',
      (tester) async {
    final active = harness();
    await active.pump(tester);
    expect(key('forum-publish'), findsOneWidget);
    await tapKey(tester, 'forum-publish');
    expect(find.text('Nouvelle publication'), findsOneWidget);
  });

  testWidgets('bouton « + » absent si le compte business n\'est pas actif',
      (tester) async {
    final pending = harness(status: BusinessStatus.pending);
    await pending.pump(tester);
    expect(key('forum-publish'), findsNothing);
  });

  testWidgets(
      'vidéo : jamais chargée ni lancée toute seule, ouverte à la demande',
      (tester) async {
    final h = ForumHarness(posts: [
      feedPost(7, 'Visite de la boutique',
          type: PostMediaType.video, mediaUrl: 'https://exemple.test/v.mp4'),
      feedPost(8, 'Photo du jour', mediaUrl: null),
    ]);
    await h.pump(tester);
    // Affichage du fil : aucune ouverture, aucune image réseau pour la vidéo.
    expect(h.opened, isEmpty);
    expect(key('post-video'), findsOneWidget);
    expect(key('post-image'), findsNothing);
    expect(find.text('Voir la vidéo'), findsOneWidget);

    await tapKey(tester, 'post-video-play');
    expect(h.opened, [Uri.parse('https://exemple.test/v.mp4')]);
  });

  testWidgets('vidéo impossible à ouvrir : message', (tester) async {
    final h = ForumHarness(posts: [
      feedPost(7, 'Visite',
          type: PostMediaType.video, mediaUrl: 'https://exemple.test/v.mp4'),
    ])
      ..openResult = false;
    await h.pump(tester);
    await tapKey(tester, 'post-video-play');
    expect(find.text('Impossible d\'ouvrir la vidéo.'), findsOneWidget);
  });

  testWidgets('texte des publications affiché tel quel (jamais interprété)',
      (tester) async {
    const raw =
        '<b>gras</b> **x** [lien](https://a.test) <script>alert(1)</script>';
    final h = ForumHarness(posts: [feedPost(1, raw, name: '<i>Nom</i>')]);
    await h.pump(tester);
    expect(find.text(raw), findsOneWidget);
    expect(find.text('<i>Nom</i>'), findsOneWidget);
  });

  testWidgets('aucun numéro de téléphone à l\'écran', (tester) async {
    final h = harness();
    await h.pump(tester);
    final phone =
        RegExp(r'(\+?237)|(\d{2}[ .]?\d{2}[ .]?\d{2}[ .]?\d{2}[ .]?\d{2})');
    expect(phone.hasMatch(screenTexts(tester)), isFalse);
  });

  testWidgets(
      'dépôt factice (USE_FAKE_API) : le fil de la ville s\'affiche sans configuration',
      (tester) async {
    await pumpBusinessApp(tester, initialLocation: Routes.forum, overrides: [
      forumFeedCacheProvider.overrideWithValue(MemoryForumFeedCache()),
    ]);
    expect(find.text('Boutique Mama Aïcha'), findsOneWidget);
    expect(find.text('Atelier Garoua'), findsNothing);
  });
}
