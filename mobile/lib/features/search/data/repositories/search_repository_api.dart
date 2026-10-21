// Version réelle
import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/search_query.dart';
import '../models/search_result.dart';
import '../models/suggestion.dart';
import 'search_repository.dart';

class SearchRepositoryApi implements SearchRepository {
  SearchRepositoryApi(this._dio);

  final Dio _dio;

  static const String _search = '/search/';
  static const String _suggestions = '/search/suggestions/';
  static const String _voice = '/search/voice/';
  static const int _maxVoiceChars = 300;

  @override
  Future<SearchPage> search(SearchQuery query, {int page = 1}) async {
    try {
      final response = await _dio.get<Object?>(_search, queryParameters: query.toParams(page));
      return SearchPage.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException(ApiErrorCode.unknown);
    }
  }

  @override
  Future<List<Suggestion>> suggestions(String q) async {
    final text = q.trim();
    if (text.length < kMinSuggestionChars) return const [];
    try {
      final response = await _dio.get<Object?>(_suggestions, queryParameters: {'q': text});
      final data = response.data;
      if (data is! List) throw const ApiException(ApiErrorCode.unknown);
      final all = [
        for (final item in data)
          if (item is Map<String, dynamic>)
            Suggestion.fromJson(item)
          else
            throw const FormatException('Suggestion inattendue'),
      ];
      return List.unmodifiable(all.take(kMaxSuggestions));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException(ApiErrorCode.unknown);
    }
  }

  @override
  Future<SearchPage> voiceSearch(String text, {int? zone, String? sector, int page = 1}) async {
    final spoken = text.trim();
    try {
      final response = await _dio.post<Object?>(
        _voice,
        queryParameters: {'page': page},
        data: {
          'text': spoken.length > _maxVoiceChars ? spoken.substring(0, _maxVoiceChars) : spoken,
          if (zone != null) 'zone': zone,
          if (sector != null && sector.isNotEmpty) 'sector': sector,
        },
      );
      return SearchPage.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException(ApiErrorCode.unknown);
    }
  }
}
