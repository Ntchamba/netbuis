// Version factice (USE_FAKE_API) : aucun réseau, tout est accepté, état gardé en mémoire
import 'dart:typed_data';

import '../../../../core/network/api_exception.dart';
import '../models/business.dart';
import 'business_repository.dart';

class BusinessRepositoryFake implements BusinessRepository {
  /// [onCreated] est appelé quand la demande est « créée » (le faux profil sait alors que le
  /// compte a un compte business).
  BusinessRepositoryFake({this.onCreated});

  final void Function()? onCreated;

  MyBusiness? _mine;
  int _counter = 0;

  @override
  Future<UploadTicket> signUpload({
    required String kind,
    required String contentType,
    required int size,
  }) async {
    _counter++;
    // Clé fictive : ne ressemble à aucune clé réelle du serveur.
    return UploadTicket(
      key: 'fictif/$kind/$_counter',
      uploadUrl: 'https://fictif.invalid/$_counter',
      headers: {'Content-Type': contentType},
      expiresIn: 900,
    );
  }

  @override
  Future<void> putFile(UploadTicket ticket, Uint8List bytes) async {}

  @override
  Future<MyBusiness> create(Map<String, Object?> body) async {
    if (_mine != null) {
      throw const ApiException(ApiErrorCode.unknown,
          statusCode: 409, serverCode: ServerCodes.businessExists);
    }
    final name = body['name'];
    _mine = MyBusiness(
      status: BusinessStatus.pending,
      name: name is String ? name : '',
    );
    onCreated?.call();
    return _mine!;
  }

  @override
  Future<MyBusiness> getMine() async {
    final mine = _mine;
    if (mine == null) {
      throw const ApiException(ApiErrorCode.unknown,
          statusCode: 404, serverCode: ServerCodes.noBusiness);
    }
    return mine;
  }
}
