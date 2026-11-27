// Version réelle
import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/feed_post.dart';
import 'forum_feed_repository.dart';

class ForumFeedRepositoryApi implements ForumFeedRepository {
  ForumFeedRepositoryApi(this._dio);

  final Dio _dio;

  static const String _posts = '/forum/posts/';

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException(ApiErrorCode.unknown);
    }
  }

  @override
  Future<ForumPage<FeedPost>> feed({int? zone, int page = 1}) =>
      _guard(() async {
        final response = await _dio.get<Object?>(_posts, queryParameters: {
          if (zone != null) 'zone': zone,
          'page': page,
        });
        return ForumPage.fromJson(response.data, FeedPost.fromJson);
      });

  @override
  Future<FeedPost> getPost(int id) => _guard(() async {
        final response = await _dio
            .get<Object?>('$_posts$id/', queryParameters: {'page_size': 1});
        return FeedPost.fromJson(response.data);
      });

  @override
  Future<ForumPage<ForumComment>> comments(int postId, {int page = 1}) =>
      _guard(() async {
        final response = await _dio.get<Object?>('$_posts$postId/comments/',
            queryParameters: {'page': page});
        return ForumPage.fromJson(response.data, ForumComment.fromJson);
      });

  @override
  Future<ForumComment> addComment(int postId, String text) => _guard(() async {
        final response = await _dio
            .post<Object?>('$_posts$postId/comments/', data: {'text': text});
        return ForumComment.fromJson(response.data);
      });
}
