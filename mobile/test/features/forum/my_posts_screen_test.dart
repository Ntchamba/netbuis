import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/business/data/models/business.dart';
import 'package:netbuis/features/forum/data/models/post.dart';

import '../account/account_test_helpers.dart';
import '../business/business_test_helpers.dart';
import 'post_test_helpers.dart';

List<MyPost> threePosts() => [
      postAt(1, 'Nouveau lot de riz parfumé disponible', const Duration(hours: 2, minutes: 5),
          comments: 6),
      postAt(2, 'Promotion sur l\'huile de palme', const Duration(days: 3, hours: 1), comments: 1),
      postAt(3, 'Nouveaux arrivages d\'épices', const Duration(days: 8),
          comments: 0, status: PostStatus.hidden),
    ];

void main() {
  testWidgets('liste : légende, date relative, nombre de commentaires, statut « masquée »',
      (tester) async {
    final h = PostsHarness(posts: threePosts());
    await h.pump(tester);

    expect(find.text('Mes publications'), findsOneWidget);
    expect(find.text('Publier'), findsOneWidget);
    expect(find.text('Nouveau lot de riz parfumé disponible'), findsOneWidget);
    expect(find.text('Il y a 2h'), findsOneWidget);
    expect(find.text('6 commentaires'), findsOneWidget);
    expect(find.text('Il y a 3 jours'), findsOneWidget);
    expect(find.text('1 commentaire'), findsOneWidget);
    expect(find.text('Il y a 1 semaine'), findsOneWidget);
    expect(find.text('Aucun commentaire'), findsOneWidget);

    // Seule la 3ᵉ est masquée.
    expect(key('post-hidden-3'), findsOneWidget);
    expect(key('post-hidden-1'), findsNothing);
    expect(find.text('Masquée'), findsOneWidget);
  });

  testWidgets('suppression : confirmation, « Annuler » ne supprime rien, « Supprimer » supprime',
      (tester) async {
    final h = PostsHarness(posts: threePosts());
    await h.pump(tester);

    await tapKey(tester, 'post-delete-1');
    expect(find.text('Supprimer cette publication ?'), findsOneWidget);
    await tester.tap(key('posts-delete-cancel'));
    await tester.pumpAndSettle();
    expect(h.forum.deleted, isEmpty);
    expect(find.text('Nouveau lot de riz parfumé disponible'), findsOneWidget);

    await tapKey(tester, 'post-delete-1');
    await tester.tap(key('posts-delete-confirm'));
    await tester.pumpAndSettle();
    expect(h.forum.deleted, [1]);
    expect(find.text('Nouveau lot de riz parfumé disponible'), findsNothing);
    expect(find.text('Promotion sur l\'huile de palme'), findsOneWidget);
  });

  testWidgets('suppression refusée par le serveur : message, la publication reste', (tester) async {
    final h = PostsHarness(posts: threePosts())..forum.deleteError = kNetworkError;
    await h.pump(tester);
    await tapKey(tester, 'post-delete-2');
    await tester.tap(key('posts-delete-confirm'));
    await tester.pumpAndSettle();
    expect(h.forum.deleted, isEmpty);
    expect(find.textContaining('Pas de connexion'), findsOneWidget);
    expect(find.text('Promotion sur l\'huile de palme'), findsOneWidget);
  });

  testWidgets('aucune publication : message et bouton Publier', (tester) async {
    final h = PostsHarness();
    await h.pump(tester);
    expect(key('posts-empty'), findsOneWidget);
    expect(key('posts-publish'), findsOneWidget);
  });

  testWidgets('erreur de chargement : message et « Réessayer »', (tester) async {
    final h = PostsHarness(posts: threePosts())..forum.listError = kNetworkError;
    await h.pump(tester);
    expect(key('posts-list-error'), findsOneWidget);
    expect(find.text('Nouveau lot de riz parfumé disponible'), findsNothing);

    h.forum.listError = null;
    await tapKey(tester, 'posts-retry');
    expect(find.text('Nouveau lot de riz parfumé disponible'), findsOneWidget);
  });

  testWidgets('compte en attente : « en attente de validation », rien n\'est chargé',
      (tester) async {
    final h = PostsHarness(posts: threePosts(), status: BusinessStatus.pending);
    await h.pump(tester);
    expect(key('posts-not-active'), findsOneWidget);
    expect(find.text('En attente de validation'), findsOneWidget);
    expect(find.text('Nouveau lot de riz parfumé disponible'), findsNothing);
    expect(h.forum.listCalls, 0);
  });

  testWidgets('Profil : « Mes publications » ouvre la liste (compte actif)', (tester) async {
    final h = PostsHarness(posts: threePosts());
    await h.pump(tester, location: Routes.profile);
    expect(key('profile-my-posts'), findsOneWidget);
    expect(find.text('Mes produits'), findsOneWidget);
    await tapKey(tester, 'profile-my-posts');
    expect(find.text('Nouveau lot de riz parfumé disponible'), findsOneWidget);
    // Retour au Profil.
    await tapKey(tester, 'posts-back');
    expect(key('profile-my-posts'), findsOneWidget);
  });

  testWidgets('Profil : sans compte business, pas d\'entrée « Mes publications »', (tester) async {
    await pumpBusinessApp(
      tester,
      initialLocation: Routes.profile,
      account: ScriptedAccountRepository(me: meWith(name: 'Jeff N.')),
    );
    expect(key('profile-my-posts'), findsNothing);
  });
}
