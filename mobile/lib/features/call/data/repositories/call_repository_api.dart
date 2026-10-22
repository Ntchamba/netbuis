// Version réelle : /calls/sessions/…, /calls/whatsapp/, /calls/{id}/feedback/, /calls/whatsapp-report/
import 'dart:async';
import 'dart:convert';

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
  static const String sessionsPath = '/calls/sessions/';
  static const String whatsappPath = '/calls/whatsapp/';
  static const String reportPath = '/calls/whatsapp-report/';
  static String sessionPath(String id) => '/calls/sessions/$id/';
  static String eventsPath(String id) => '/calls/sessions/$id/events/';
  static String cancelPath(String id) => '/calls/sessions/$id/cancel/';
  static String endPath(String id) => '/calls/sessions/$id/end/';
  static String feedbackPath(int callId) => '/calls/$callId/feedback/';

  /// Traduit une erreur Dio ; le 409 `call_already_active` garde le numéro de session du serveur.
  ApiException _failure(DioException e) {
    final api = ApiException.fromDio(e);
    if (api.serverCode == 'call_already_active') {
      final data = e.response?.data;
      final id = data is Map && data['session_id'] is String
          ? data['session_id'] as String
          : '';
      return ActiveCallException(id);
    }
    return api;
  }

  @override
  Future<CallStart> startSession({int? businessId}) async {
    try {
      final response = await _dio.post<Object?>(sessionsPath, data: {
        if (businessId != null) 'business_id': businessId,
      });
      return CallStart.fromJson(response.data);
    } on DioException catch (e) {
      throw _failure(e);
    } on FormatException {
      // Aucun détail conservé : le corps de la réponse contient la salle et le jeton.
      throw const ApiException(ApiErrorCode.unknown);
    }
  }

  @override
  Future<CallStatus> status(String sessionId) => _state(
      () => _dio.get<Object?>(sessionPath(sessionId)));

  @override
  Future<CallStatus> cancel(String sessionId) => _state(
      () => _dio.post<Object?>(cancelPath(sessionId)));

  @override
  Future<CallStatus> end(String sessionId) => _state(
      () => _dio.post<Object?>(endPath(sessionId)));

  Future<CallStatus> _state(Future<Response<Object?>> Function() send) async {
    try {
      return CallStatus.fromJson((await send()).data);
    } on DioException catch (e) {
      throw _failure(e);
    } on FormatException {
      throw const ApiException(ApiErrorCode.unknown);
    }
  }

  @override
  Stream<CallStatus> watch(String sessionId) async* {
    final Response<ResponseBody> response;
    try {
      response = await _dio.get<ResponseBody>(
        eventsPath(sessionId),
        options: Options(
          responseType: ResponseType.stream,
          // Le flux reste ouvert tant que l'appel dure (des battements arrivent toutes les 5 s).
          receiveTimeout: Duration.zero,
          headers: {'Accept': 'text/event-stream'},
        ),
      );
    } on DioException catch (e) {
      throw _failure(e);
    }
    final body = response.data;
    if (body == null) throw const ApiException(ApiErrorCode.network);
    try {
      yield* parseCallEvents(body.stream);
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<void> warmUp() async {
    try {
      // OPTIONS sur la route d'appel : réponse sans effet, qui ouvre la connexion TLS.
      await _dio.request<Object?>(sessionsPath,
          options: Options(method: 'OPTIONS'));
    } on Object {
      // Réchauffer est un bonus : une panne ici ne regarde personne.
    }
  }

  @override
  Future<WhatsappLink> initiateWhatsapp({required int businessId}) async {
    try {
      final response = await _dio.post<Object?>(whatsappPath, data: {
        'business_id': businessId,
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

/// Lit un flux SSE et rend un [CallStatus] pour chaque événement `state`. Les commentaires
/// (`: keepalive`), les consignes `retry:` et les événements inconnus ou mal formés sont ignorés.
Stream<CallStatus> parseCallEvents(Stream<List<int>> bytes) async* {
  var event = '';
  final data = StringBuffer();
  await for (final line
      in utf8.decoder.bind(bytes).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (event == 'state' && data.isNotEmpty) {
        try {
          yield CallStatus.fromJson(jsonDecode(data.toString()));
        } on FormatException {
          // Événement illisible : on attend le suivant, le repli par consultation couvre le reste.
        }
      }
      event = '';
      data.clear();
    } else if (line.startsWith(':')) {
      continue;
    } else if (line.startsWith('event:')) {
      event = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      if (data.isNotEmpty) data.write('\n');
      data.write(line.substring(5).trimLeft());
    }
  }
}
