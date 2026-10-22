import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/features/business/data/models/business.dart';
import 'package:netbuis/features/forum/application/forum_services.dart';
import 'package:netbuis/features/forum/data/forum_feed_cache.dart';
import 'package:netbuis/features/forum/data/models/feed_post.dart';
import 'package:netbuis/features/forum/data/models/post.dart';
import 'package:netbuis/features/forum/data/repositories/forum_feed_repository.dart';

import '../account/account_test_helpers.dart';
import '../business/business_test_helpers.dart';
import '../merchant/offers_test_helpers.dart';
import 'post_test_helpers.dart';

FeedPost feedPost(
  int id,
  String caption, {
  String name = 'Boutique Mama Aïcha',
  String initials = 'MA',
  String zone = 'Dougoï',
  Duration age = const Duration(hours: 2, minutes: 5),
  int comments = 0,
  String? offer,
  PostMediaType type = PostMediaType.image,
  String? mediaUrl,
}) =>
    FeedPost(
      id: id,
      businessId: 100 + id,
      authorName: name,
      initials: initials,
      zoneName: zone,
      mediaType: type,
      mediaUrl: mediaUrl,
      caption: caption,
      offerName: offer,
      createdAt: DateTime.now().subtract(age),
      commentsCount: comments,
    );

ForumComment comment(int id, String text,
        {String name = 'Sali A.',
        String initials = 'SA',
        Duration age = const Duration(minutes: 45)}) =>
    ForumComment(
      id: id,
      authorName: name,
      initials: initials,
      text: text,
      createdAt: DateTime.now().subtract(age),
    );

const ApiException kRateLimit = ApiException(ApiErrorCode.unknown,
    statusCode: 429, serverCode: 'comment_rate_limit');
const ApiException kBlocked = ApiException(ApiErrorCode.accountBlocked,
    statusCode: 403, serverCode: 'account_blocked');
const ApiException kGone = ApiException(ApiErrorCode.unknown,
    statusCode: 404, serverCode: 'not_found');

/// Dépôt du fil scénarisé : garde les appels reçus, peut échouer ou attendre à la demande.
class ScriptedFeedRepository implements ForumFeedRepository {
  ScriptedFeedRepository({
    List<FeedPost> posts = const [],
    List<ForumComment> comments = const [],
    this.pageSize = 20,
  })  : posts = [...posts],
        commentList = [...comments];

  final List<FeedPost> posts;
  final List<ForumComment> commentList;
  final int pageSize;

  /// Erreurs levées par chaque appel (null = succès).
  ApiException? feedError;
  ApiException? postError;
  ApiException? commentsError;
  ApiException? addError;
  Completer<void>? addGate;

  final List<({int? zone, int page})> feedCalls = [];
  final List<int> commentPages = [];
  final List<String> added = [];
  int _next = 900;

  ForumPage<T> _page<T>(List<T> all, int page) {
    final start = (page - 1) * pageSize;
    final items = start >= all.length
        ? <T>[]
        : all.sublist(start, (start + pageSize).clamp(0, all.length));
    return ForumPage(
        items: items,
        count: all.length,
        hasNext: start + pageSize < all.length);
  }

  @override
  Future<ForumPage<FeedPost>> feed({int? zone, int page = 1}) async {
    feedCalls.add((zone: zone, page: page));
    final e = feedError;
    if (e != null) throw e;
    return _page(posts, page);
  }

  @override
  Future<FeedPost> getPost(int id) async {
    final e = postError;
    if (e != null) throw e;
    return posts.firstWhere((p) => p.id == id);
  }

  @override
  Future<ForumPage<ForumComment>> comments(int postId, {int page = 1}) async {
    commentPages.add(page);
    final e = commentsError;
    if (e != null) throw e;
    return _page(commentList, page);
  }

  @override
  Future<ForumComment> addComment(int postId, String text) async {
    await addGate?.future;
    final e = addError;
    if (e != null) throw e;
    added.add(text);
    final c = ForumComment(
      id: _next++,
      authorName: 'Moi',
      initials: 'M',
      text: text,
      createdAt: DateTime.now(),
      isMine: true,
    );
    commentList.add(c);
    return c;
  }
}

class ForumHarness {
  ForumHarness({
    List<FeedPost> posts = const [],
    List<ForumComment> comments = const [],
    int pageSize = 20,
    BusinessStatus businessStatus = BusinessStatus.active,
    ForumFeedCache? cache,
  })  : repo = ScriptedFeedRepository(
            posts: posts, comments: comments, pageSize: pageSize),
        business = UploadFailingBusinessRepository(businessStatus),
        cache = cache ?? MemoryForumFeedCache();

  final ScriptedFeedRepository repo;
  final UploadFailingBusinessRepository business;
  final ForumFeedCache cache;
  final List<Uri> opened = [];
  bool openResult = true;

  Future<void> pump(WidgetTester tester,
      {String location = Routes.forum}) async {
    await pumpBusinessApp(
      tester,
      initialLocation: location,
      account: ScriptedAccountRepository(me: activeMe),
      overrides: [
        forumFeedRepositoryProvider.overrideWithValue(repo),
        forumFeedCacheProvider.overrideWithValue(cache),
        businessRepositoryProvider.overrideWithValue(business),
        externalUrlOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return openResult;
        }),
      ],
    );
  }
}

/// Tous les textes affichés à l'écran, séparés par un retour à la ligne.
String screenTexts(WidgetTester tester) => [
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        if (t.data != null) t.data!,
    ].join('\n');

Future<void> scrollDown(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.drag(find.byType(ListView).first, const Offset(0, -2500));
    await tester.pumpAndSettle();
  }
}
