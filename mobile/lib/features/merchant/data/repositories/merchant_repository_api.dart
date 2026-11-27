// Version réelle
import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import 'merchant_repository.dart';

class MerchantRepositoryApi implements MerchantRepository {
  MerchantRepositoryApi(this._dio);

  final Dio _dio;

  static const String _offers = '/business/me/offers/';
  static const int _maxPages = 50;

  @override
  Future<List<MerchantOffer>> listOffers() async {
    final all = <MerchantOffer>[];
    try {
      for (var page = 1; page <= _maxPages; page++) {
        final response = await _dio.get<Object?>(_offers, queryParameters: {'page': page});
        final data = response.data;
        if (data is! Map<String, dynamic> || data['results'] is! List) {
          throw const ApiException(ApiErrorCode.unknown);
        }
        for (final item in data['results'] as List) {
          if (item is! Map<String, dynamic>) throw const ApiException(ApiErrorCode.unknown);
          all.add(MerchantOffer.fromJson(item));
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
  Future<MerchantOffer> createOffer(OfferInput input) async {
    try {
      final response = await _dio.post<Object?>(_offers, data: input.toJson());
      return _parse(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<MerchantOffer> updateOffer(int id, OfferInput input) async {
    try {
      final response = await _dio.patch<Object?>('$_offers$id/', data: input.toJson());
      return _parse(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> deleteOffer(int id) async {
    try {
      await _dio.delete<Object?>('$_offers$id/');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  MerchantOffer _parse(Object? data) {
    try {
      if (data is Map<String, dynamic>) return MerchantOffer.fromJson(data);
    } on FormatException {
      // tombe sur l'erreur ci-dessous
    }
    throw const ApiException(ApiErrorCode.unknown);
  }
}
