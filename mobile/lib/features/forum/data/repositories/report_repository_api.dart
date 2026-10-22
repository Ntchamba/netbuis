// Version réelle
import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/report.dart';
import 'report_repository.dart';

class ReportRepositoryApi implements ReportRepository {
  ReportRepositoryApi(this._dio);

  final Dio _dio;

  @override
  Future<void> report(ReportTarget target, int id, ReportReason reason) async {
    try {
      await _dio.post<Object?>('/reports/', data: {
        'target_type': target.value,
        'target_id': id,
        'reason': reason.value,
      });
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
