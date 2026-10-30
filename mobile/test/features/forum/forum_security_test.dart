import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/features/auth/application/auth_controller.dart';
import 'package:netbuis/features/auth/application/auth_state.dart';
import 'package:netbuis/features/forum/data/forum_feed_cache.dart';
import 'package:netbuis/features/forum/data/models/post.dart';

import 'forum_test_helpers.dart';
import 'post_test_helpers.dart';

ForumHarness _videoHarness(String url) => ForumHarness(posts: [
      feedPost(7, 'Visite de la boutique',
          type: PostMediaType.video, mediaUrl: url),
    ]);

void main() {
  group(
      'vidéo : seules les adresses http(s) ou un chemin relatif résolu sont ouvrables',
      () {
    for (final url in [
      'javascript:alert(1)',
      'JavaScript:alert(1)',
      'file:///etc/passwd',
      'intent://scan/#Intent;scheme=zxing;end',
      'data:text/html;base64,PHNjcmlwdD4=',
      'content://media/external/video/1',
      '//autre.test/v.mp4',
      'v.mp4',
      '',
    ]) {
      testWidgets('refusée : « $url » -> aucun bouton, aucun lancement',
          (tester) async {
        final h = _videoHarness(url);
        await h.pump(tester);
        expect(key('post-video'), findsOneWidget);
        expect(key('post-video-play'), findsNothing);
        expect(find.text('Voir la vidéo'), findsNothing);
        expect(h.opened, isEmpty);
      });
    }

    testWidgets('refusée aussi sur la page de la publication', (tester) async {
      final h = _videoHarness('javascript:alert(1)');
      await h.pump(tester);
      await tapKey(tester, 'feed-comments-7');
      expect(key('post-video'), findsOneWidget);
      expect(key('post-video-play'), findsNothing);
      expect(h.opened, isEmpty);
    });

    for (final url in [
      'https://exemple.test/v.mp4',
      'http://exemple.test/v.mp4'
    ]) {
      testWidgets('acceptée : $url -> lancée seulement au toucher',
          (tester) async {
        final h = _videoHarness(url);
        await h.pump(tester);
        expect(h.opened, isEmpty);
        await tapKey(tester, 'post-video-play');
        expect(h.opened, [Uri.parse(url)]);
      });
    }

    testWidgets('chemin relatif du serveur : résolu en adresse http(s)',
        (tester) async {
      final h = _videoHarness('/media/v.mp4');
      await h.pump(tester);
      await tapKey(tester, 'post-video-play');
      expect(h.opened, hasLength(1));
      expect(h.opened.single.scheme, anyOf('http', 'https'));
      expect(h.opened.single.host, isNotEmpty);
      expect(h.opened.single.path, '/media/v.mp4');
    });
  });

  group('déconnexion', () {
    testWidgets('le cache du fil est effacé quand le fil est affiché',
        (tester) async {
      final cache = MemoryForumFeedCache();
      final h = ForumHarness(cache: cache, posts: [feedPost(1, 'Riz')]);
      await h.pump(tester);
      expect(find.text('Riz'), findsOneWidget);
      expect(cache.raw, isNotNull);

      await containerOf(tester).read(authControllerProvider.notifier).logout();
      await tester.pumpAndSettle();

      expect(containerOf(tester).read(authControllerProvider),
          isA<AuthLoggedOut>());
      expect(cache.raw, isNull);
      expect(await cache.read(), isNull);
    });
  });
}
