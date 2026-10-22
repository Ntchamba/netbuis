// Version réelle
import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/post.dart';
import 'forum_repository.dart';

class ForumRepositoryApi implements ForumRepository {
  ForumRepositoryApi(this._dio);

  final Dio _dio;

  static const String _posts = '/forum/posts/';
  static const String _mine = '/forum/mine/';
  static const int _maxPages = 50;

  @override
  Future<List<MyPost>> listMine() async {
    final all = <MyPost>[];
    try {
      for (var page = 1; page <= _maxPages; page++) {
        final response = await _dio.get<Object?>(_mine, queryParameters: {'page': page});
        final data = response.data;
        if (data is! Map<String, dynamic> || data['results'] is! List) {
          throw const ApiException(ApiErrorCode.unknown);
        }
        for (final item in data['results'] as List) {
          all.add(MyPost.fromJson(item));
        }
        if (data['next'] == null) break;
      }
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException(ApiErrorCode.unknown);
    }
    return all;
  }

  @override
  Future<MyPost> createPost({
    required String mediaKey,
    required String caption,
    int? offerId,
  }) async {
    try {
      final response = await _dio.post<Object?>(_posts, data: {
        'media': mediaKey,
        'caption': caption,
        if (offerId != null) 'offer': offerId,
      });
      return MyPost.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException(ApiErrorCode.unknown);
    }
  }

  @override
  Future<void> deletePost(int id) async {
    try {
      await _dio.delete<Object?>('$_posts$id/');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
