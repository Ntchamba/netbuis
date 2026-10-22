import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/business/application/business_services.dart';
import 'package:netbuis/features/business/data/models/business.dart';
import 'package:netbuis/features/business/data/photo_service.dart';
import 'package:netbuis/features/forum/application/forum_services.dart';
import 'package:netbuis/features/forum/data/models/post.dart';
import 'package:netbuis/features/forum/data/post_media_service.dart';
import 'package:netbuis/features/forum/data/repositories/forum_repository.dart';
import 'package:netbuis/features/merchant/application/offers_controller.dart';
import 'package:netbuis/features/merchant/data/repositories/merchant_repository.dart';
import 'package:netbuis/features/search/application/offline_controller.dart';

import '../account/account_test_helpers.dart';
import '../business/business_submit_helpers.dart';
import '../business/business_test_helpers.dart';
import '../merchant/offers_test_helpers.dart';

/// Dépôt du forum scénarisé : garde les appels reçus, peut échouer ou attendre à la demande.
class ScriptedForumRepository implements ForumRepository {
  ScriptedForumRepository([List<MyPost> initial = const []]) : posts = [...initial];

  final List<MyPost> posts;
  ApiException? listError;
  ApiException? createError;
  ApiException? deleteError;
  Completer<void>? createGate;
  int listCalls = 0;
  final List<({String mediaKey, String caption, int? offerId})> created = [];
  final List<int> deleted = [];
  int _next = 700;

  @override
  Future<List<MyPost>> listMine() async {
    listCalls++;
    final e = listError;
    if (e != null) throw e;
    return List.of(posts);
  }

  @override
  Future<MyPost> createPost({
    required String mediaKey,
    required String caption,
    int? offerId,
  }) async {
    await createGate?.future;
    final e = createError;
    if (e != null) throw e;
    created.add((mediaKey: mediaKey, caption: caption, offerId: offerId));
    final post = MyPost(
      id: _next++,
      mediaType: mediaKey.contains('video') ? PostMediaType.video : PostMediaType.image,
      caption: caption,
      offerId: offerId,
      createdAt: DateTime.now(),
    );
    posts.insert(0, post);
    return post;
  }

  @override
  Future<void> deletePost(int id) async {
    final e = deleteError;
    if (e != null) throw e;
    deleted.add(id);
    posts.removeWhere((p) => p.id == id);
  }
}

/// Dépôt du compte business dont l'envoi du fichier (PUT) peut échouer.
class UploadFailingBusinessRepository extends ScriptedBusinessRepository {
  UploadFailingBusinessRepository(super.status);

  ApiException? putError;

  @override
  Future<void> putFile(UploadTicket ticket, Uint8List bytes) async {
    final e = putError;
    if (e != null) throw e;
    return super.putFile(ticket, bytes);
  }
}

/// Appareil photo / caméra / galerie factice des publications.
class FakePostMediaPicker implements PostMediaPicker {
  String? result = '/fictif/photo.jpg';
  bool fail = false;
  final List<(PhotoSource, bool)> asked = [];

  @override
  Future<String?> pick(PhotoSource source, {required bool video}) async {
    asked.add((source, video));
    if (fail) throw StateError('appareil photo inaccessible');
    return result;
  }
}

Uint8List fakeMp4(int length) => Uint8List.fromList(
    [0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D, ...List.filled(length - 12, 7)]);

MyPost postAt(int id, String caption, Duration age,
        {int comments = 0, PostStatus status = PostStatus.active, DateTime? now}) =>
    MyPost(
      id: id,
      mediaType: PostMediaType.image,
      caption: caption,
      createdAt: (now ?? DateTime.now()).subtract(age),
      commentsCount: comments,
      status: status,
    );

const ApiException kCapError =
    ApiException(ApiErrorCode.unknown, statusCode: 400, serverCode: 'SUBSCRIPTION_REQUIRED');
const ApiException kDailyError =
    ApiException(ApiErrorCode.unknown, statusCode: 429, serverCode: 'daily_post_limit');
const ApiException kNetworkError = ApiException(ApiErrorCode.network);

class PostsHarness {
  PostsHarness({
    List<MyPost> posts = const [],
    BusinessStatus status = BusinessStatus.active,
    List<MerchantOffer> offers = const [],
  })  : forum = ScriptedForumRepository(posts),
        business = UploadFailingBusinessRepository(status),
        merchant = ScriptedMerchantRepository(offers),
        picker = FakePostMediaPicker();

  final ScriptedForumRepository forum;
  final UploadFailingBusinessRepository business;
  final ScriptedMerchantRepository merchant;
  final FakePostMediaPicker picker;
  final Map<String, Uint8List> files = {};

  Future<void> pump(WidgetTester tester, {String location = Routes.myPosts}) async {
    await pumpBusinessApp(
      tester,
      initialLocation: location,
      account: ScriptedAccountRepository(me: activeMe),
      overrides: [
        forumRepositoryProvider.overrideWithValue(forum),
        merchantRepositoryProvider.overrideWithValue(merchant),
        businessRepositoryProvider.overrideWithValue(business),
        postMediaPickerProvider.overrideWithValue(picker),
        photoBytesReaderProvider
            .overrideWithValue((path) async => files[path] ?? fakeJpeg(64)),
      ],
    );
  }
}

ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

void setOffline(WidgetTester tester, bool value) =>
    containerOf(tester).read(offlineProvider.notifier).set(value);

Finder key(String k) => find.byKey(ValueKey(k));

Future<void> tapKey(WidgetTester tester, String k) async {
  final f = key(k);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}
