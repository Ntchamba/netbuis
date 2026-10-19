// Version réelle
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/upload_url.dart';
import '../models/business.dart';
import 'business_repository.dart';

class BusinessRepositoryApi implements BusinessRepository {
  /// [_dio] : client authentifié. [_uploadDio] : client SANS authentification pour les PUT.
  /// [_apiUrl] : adresse de l'API (`…/api`), dont on tire l'origine pour les chemins d'envoi.
  BusinessRepositoryApi(this._dio, this._uploadDio, this._apiUrl);

  final Dio _dio;
  final Dio _uploadDio;
  final String _apiUrl;

  @override
  Future<UploadTicket> signUpload({
    required String kind,
    required String contentType,
    required int size,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        Endpoints.uploadsSign,
        data: {'kind': kind, 'content_type': contentType, 'size': size},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) return UploadTicket.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      // tombe sur l'erreur ci-dessous
    }
    throw const ApiException(ApiErrorCode.unknown);
  }

  @override
  Future<void> putFile(UploadTicket ticket, Uint8List bytes) async {
    final url = resolveUploadUrl(_apiUrl, ticket.uploadUrl);
    try {
      await _uploadDio.put<Object?>(
        url,
        data: bytes,
        options: Options(headers: Map<String, Object?>.of(ticket.headers)),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<MyBusiness> create(Map<String, Object?> body) async {
    try {
      final response = await _dio.post<Object?>(Endpoints.businessCreate, data: body);
      return _parse(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<MyBusiness> getMine() async {
    try {
      final response = await _dio.get<Object?>(Endpoints.businessMe);
      return _parse(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  MyBusiness _parse(Object? data) {
    try {
      if (data is Map<String, dynamic>) return MyBusiness.fromJson(data);
    } on FormatException {
      // tombe sur l'erreur ci-dessous
    }
    throw const ApiException(ApiErrorCode.unknown);
  }
}
