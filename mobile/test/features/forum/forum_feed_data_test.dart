import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/guards.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/auth/application/auth_state.dart';
import 'package:netbuis/features/forum/application/comment_errors.dart';
import 'package:netbuis/features/forum/data/forum_feed_cache.dart';
import 'package:netbuis/features/forum/data/models/feed_post.dart';
import 'package:netbuis/features/forum/data/models/post.dart';
import 'package:netbuis/features/forum/data/repositories/forum_feed_repository_api.dart';
import 'package:netbuis/features/forum/data/repositories/forum_feed_repository_fake.dart';

import '../auth/auth_test_helpers.dart';
import 'forum_test_helpers.dart';

Map<String, Object?> postJson({int id = 1, Object? offer, String? mediaUrl}) =>
    {
      'id': id,
      'author': {
        'business_id': 5,
        'name': 'Boutique Mama Aïcha',
        'initials': 'MA',
        'photo': null,
        'zone': {'id': 18, 'name': 'Dougoï'},
      },
      'media_type': 'image',
      'media_url': mediaUrl,
      'caption': 'Riz',
      'offer': offer,
      'created_at': '2026-03-04T10:00:00Z',
      'comments_count': 6,
      'is_mine': false,
    };

void main() {
  group('FeedPost.fromJson', () {
    test('lit commerce, zone, produit, média et nombre de commentaires', () {
      final p = FeedPost.fromJson(postJson(
          offer: {'id': 3, 'name': 'Riz 25kg'}, mediaUrl: '/media/p.jpg'));
      expect(p.authorName, 'Boutique Mama Aïcha');
      expect(p.initials, 'MA');
      expect(p.zoneName, 'Dougoï');
      expect(p.offerName, 'Riz 25kg');
      expect(p.mediaUrl, '/media/p.jpg');
      expect(p.mediaType, PostMediaType.image);
      expect(p.commentsCount, 6);
      expect(p.authorPhoto, isNull);
    });

    test('initiales de secours quand le serveur n\'en donne pas', () {
      final json = postJson();
      (json['author'] as Map)['initials'] = '';
      expect(FeedPost.fromJson(json).initials, 'BM');
      expect(initialsOf('  '), '?');
      expect(initialsOf('électricien'), 'É');
    });

    test('réponse incomplète : FormatException', () {
      expect(() => FeedPost.fromJson(null), throwsFormatException);
      expect(() => FeedPost.fromJson({'id': 1}), throwsFormatException);
      final noAuthor = postJson()..remove('author');
      expect(() => FeedPost.fromJson(noAuthor), throwsFormatException);
      final badDate = postJson()..['created_at'] = 'hier';
      expect(() => FeedPost.fromJson(badDate), throwsFormatException);
    });

    test('un champ « phone » éventuel est ignoré : jamais mémorisé ni gardé',
        () {
      final json = postJson()..['phone'] = '+237600000000';
      (json['author'] as Map)['phone'] = '+237600000000';
      final p = FeedPost.fromJson(json);
      expect(jsonEncode(p.toJson()), isNot(contains('237')));
      expect(jsonEncode(p.toJson()), isNot(contains('phone')));
    });
  });

  group('ForumComment.fromJson et ForumPage', () {
    test('commentaire valide', () {
      final c = ForumComment.fromJson({
        'id': 4,
        'author': {
          'name': 'Sali A.',
          'initials': 'SA',
          'photo': null,
          'is_business': false
        },
        'text': 'Bonjour',
        'created_at': '2026-03-04T10:00:00Z',
        'is_mine': true,
      });
      expect(c.text, 'Bonjour');
      expect(c.isMine, isTrue);
      expect(c.pending, isFalse);
    });

    test('commentaire sans texte : FormatException', () {
      expect(
          () => ForumComment.fromJson({
                'id': 1,
                'author': {'name': 'x'}
              }),
          throwsFormatException);
    });

    test('page : count, next, results', () {
      final page = ForumPage.fromJson({
        'count': 30,
        'next': 'http://x/?page=2',
        'results': [postJson(), postJson(id: 2)]
      }, FeedPost.fromJson);
      expect(page.items.length, 2);
      expect(page.count, 30);
      expect(page.hasNext, isTrue);
      expect(() => ForumPage.fromJson({'count': 1}, FeedPost.fromJson),
          throwsFormatException);
    });
  });

  group('cache du fil', () {
    test('écrit puis relit les mêmes publications, sans numéro', () async {
      final cache = MemoryForumFeedCache();
      await cache.write(CachedFeed(
          zone: 16, items: [feedPost(1, 'Riz', comments: 2)], count: 1));
      expect(cache.raw, isNot(contains('phone')));
      final back = (await cache.read())!;
      expect(back.zone, 16);
      expect(back.items.single.caption, 'Riz');
      expect(back.items.single.commentsCount, 2);
      await cache.clear();
      expect(await cache.read(), isNull);
    });

    test('contenu inattendu ou autre version : ignoré', () {
      expect(CachedFeed.fromJson('x'), isNull);
      expect(CachedFeed.fromJson({'v': 99, 'count': 0, 'results': []}), isNull);
      expect(
          CachedFeed.fromJson({
            'v': kForumFeedCacheVersion,
            'count': 0,
            'results': [1]
          }),
          isNull);
    });
  });

  group('messages d\'erreur', () {
    test('commentaire : 429, 403, réseau, 404, autre', () {
      expect(commentErrorKey(kRateLimit), 'forum.comment.error.rate');
      expect(commentErrorKey(kBlocked), 'forum.comment.error.blocked');
      expect(commentErrorKey(const ApiException(ApiErrorCode.network)),
          'forum.comment.error.network');
      expect(commentErrorKey(kGone), 'forum.comment.error.gone');
      expect(commentErrorKey(StateError('x')), 'forum.comment.error.unknown');
    });

    test('chargement', () {
      expect(forumLoadErrorKey(const ApiException(ApiErrorCode.network)),
          'forum.error.network');
      expect(forumLoadErrorKey(kGone), 'forum.post.gone');
      expect(forumLoadErrorKey(null), 'forum.error.unknown');
    });
  });

  group('dépôt réel (faux serveur)', () {
    ForumFeedRepositoryApi api(FakeAdapter adapter) {
      final dio = Dio(BaseOptions(baseUrl: 'http://test/api'))
        ..httpClientAdapter = adapter;
      return ForumFeedRepositoryApi(dio);
    }

    test('fil : zone et page envoyées, résultats lus', () async {
      final adapter = FakeAdapter((r) => FakeAdapter.reply(200, {
            'count': 1,
            'next': null,
            'results': [postJson()],
          }));
      final page = await api(adapter).feed(zone: 16, page: 2);
      expect(page.items.single.caption, 'Riz');
      expect(adapter.seen.single.path, '/forum/posts/');
    });

    test('commentaire : POST du texte seul', () async {
      final adapter = FakeAdapter((r) => FakeAdapter.reply(201, {
            'id': 9,
            'author': {
              'name': 'Moi',
              'initials': 'M',
              'photo': null,
              'is_business': false
            },
            'text': 'Merci',
            'created_at': '2026-03-04T10:00:00Z',
            'is_mine': true,
          }));
      final c = await api(adapter).addComment(3, 'Merci');
      expect(c.id, 9);
      final seen = adapter.seen.single;
      expect(seen.method, 'POST');
      expect(seen.path, '/forum/posts/3/comments/');
      expect(seen.body, {'text': 'Merci'});
    });

    test('429 comment_rate_limit : ApiException avec le code du serveur',
        () async {
      final adapter = FakeAdapter((r) => FakeAdapter.reply(429,
          {'code': 'comment_rate_limit', 'message': 'Trop de commentaires'}));
      await expectLater(
        api(adapter).addComment(3, 'x'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 429)
            .having((e) => e.serverCode, 'code', 'comment_rate_limit')),
      );
    });

    test('403 account_blocked : code typé', () async {
      final adapter = FakeAdapter((r) =>
          FakeAdapter.reply(403, {'code': 'account_blocked', 'message': ''}));
      await expectLater(
          api(adapter).feed(),
          throwsA(isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.accountBlocked)));
    });

    test('réponse illisible : ApiException inconnue, pas de plantage',
        () async {
      final adapter =
          FakeAdapter((r) => FakeAdapter.reply(200, {'oups': true}));
      await expectLater(
          api(adapter).feed(),
          throwsA(isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.unknown)));
    });
  });

  group('dépôt factice', () {
    test('publications et commentaires fictifs, sans numéro', () async {
      final fake = ForumFeedRepositoryFake();
      final feed = await fake.feed();
      final comments = await fake.comments(1);
      final everything = [
        for (final p in feed.items)
          '${p.authorName} ${p.caption} ${p.zoneName}',
        for (final c in comments.items) '${c.authorName} ${c.text}',
      ].join(' ');
      expect(RegExp(r'(\+?237)|\d{6,}').hasMatch(everything), isFalse);
      expect(comments.items.length, 3);
    });

    test('filtre par zone (la zone et ses sous-zones) et pagine par 20',
        () async {
      final fake = ForumFeedRepositoryFake();
      final city = await fake.feed(zone: 16);
      expect(city.items.length, 20);
      expect(city.hasNext, isTrue);
      expect((await fake.feed(zone: 16, page: 2)).items.length, 4);
      // Un quartier de la ville : seulement ses publications.
      final quartier = await fake.feed(zone: 18);
      expect(quartier.items.map((p) => p.zoneName).toSet(), {'Dougoï'});
      // Une autre ville.
      expect((await fake.feed(zone: 90)).items.single.authorName,
          'Atelier Garoua');
      expect((await fake.feed()).count, 25);
    });

    test('commentaire ajouté : renvoyé, compté, publication inconnue : 404',
        () async {
      final fake = ForumFeedRepositoryFake();
      final before = (await fake.getPost(2)).commentsCount;
      final c = await fake.addComment(2, 'Merci');
      expect(c.isMine, isTrue);
      expect((await fake.getPost(2)).commentsCount, before + 1);
      await expectLater(
          fake.getPost(999),
          throwsA(
              isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
    });
  });

  group('compte non connecté', () {
    test(
        'le Forum et la page d\'une publication mènent à la connexion (garde existante)',
        () {
      for (final path in [Routes.forum, Routes.forumPostPath(7)]) {
        expect(authRedirect(const AuthLoggedOut(), path), Routes.login,
            reason: path);
        expect(authRedirect(const AuthAuthenticated(), path), isNull,
            reason: path);
      }
    });
  });
}
