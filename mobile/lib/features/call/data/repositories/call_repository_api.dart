// Version réelle : /api/calls/initiate/, /calls/{id}/feedback/, /calls/whatsapp-report/
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../models/call_feedback.dart';
import '../models/call_session.dart';
import 'call_repository.dart';

class CallRepositoryApi implements CallRepository {
  CallRepositoryApi(this._dio);

  final Dio _dio;

  /// Chemins relatifs à `Env.apiUrl`.
  static const String path = '/calls/initiate/';
  static const String reportPath = '/calls/whatsapp-report/';
  static String feedbackPath(int callId) => '/calls/$callId/feedback/';

  @override
  Future<CallSession> initiate({required int businessId, CallLine? line}) async {
    try {
      final response = await _dio.post<Object?>(path, data: {
        'business_id': businessId,
        'channel': 'call',
        'platform': 'android',
        if (line != null) 'operator': line.value,
      });
      return CallSession.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      // Message volontairement vide de détail : le corps de la réponse contient le numéro.
      throw const ApiException(ApiErrorCode.unknown);
    }
  }

  @override
  Future<WhatsappLink> initiateWhatsapp({required int businessId}) async {
    try {
      final response = await _dio.post<Object?>(path, data: {
        'business_id': businessId,
        'channel': 'whatsapp',
        'platform':
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      });
      return WhatsappLink.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      // Le corps de la réponse contient le numéro (dans le lien) : aucun détail conservé.
      throw const ApiException(ApiErrorCode.unknown);
    }
  }

  @override
  Future<void> sendFeedback(
      {required int callId, required CallOutcome outcome}) async {
    try {
      await _dio.post<Object?>(feedbackPath(callId),
          data: {'outcome': outcome.value});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> reportNoWhatsapp({required int businessId}) async {
    try {
      await _dio.post<Object?>(reportPath, data: {'business_id': businessId});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
