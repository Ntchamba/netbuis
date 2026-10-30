// Version factice (USE_FAKE_API) : aucun réseau, tout est accepté, état gardé en mémoire
import 'dart:typed_data';

import '../../../../core/network/api_exception.dart';
import '../models/business.dart';
import '../models/business_draft.dart' show BusinessAccountType;
import 'business_repository.dart';

class BusinessRepositoryFake implements BusinessRepository {
  /// [onCreated] est appelé quand la demande est « créée » (le faux profil sait alors que le
  /// compte a un compte business). [initial] : compte déjà existant au départ (essais).
  BusinessRepositoryFake({this.onCreated, MyBusiness? initial}) : _mine = initial;

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
    _mine = _merge(const MyBusiness(status: BusinessStatus.pending), body);
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

  /// Applique le corps reçu comme le serveur (D-08) : un profil rejeté repart en attente et
  /// son motif est effacé ; un profil actif repart en attente si le nom ou la zone changent.
  @override
  Future<MyBusiness> update(Map<String, Object?> body) async {
    final mine = _mine;
    if (mine == null) {
      throw const ApiException(ApiErrorCode.unknown,
          statusCode: 404, serverCode: ServerCodes.noBusiness);
    }
    if (body.isEmpty) return mine;
    final changedName = body.containsKey('name') && body['name'] != mine.name;
    final changedZone = body.containsKey('zone') && body['zone'] != mine.zoneId;
    var next = _merge(mine, body);
    if (mine.status == BusinessStatus.rejected) {
      next = _copy(next, status: BusinessStatus.pending, motifRejet: '');
    } else if (mine.status == BusinessStatus.active && (changedName || changedZone)) {
      next = _copy(next, status: BusinessStatus.pending);
    }
    _mine = next;
    return next;
  }

  MyBusiness _merge(MyBusiness base, Map<String, Object?> body) {
    String text(String key, String old) {
      final v = body[key];
      return v is String ? v : old;
    }

    BusinessAccountType? type = base.typeCompte;
    for (final t in BusinessAccountType.values) {
      if (t.value == body['type_compte']) type = t;
    }
    final zone = body['zone'];
    return MyBusiness(
      status: base.status,
      name: text('name', base.name),
      motifRejet: base.motifRejet,
      typeCompte: type,
      zoneId: zone is int ? zone : base.zoneId,
      repere: text('repere', base.repere),
      description: text('description', base.description),
      descriptionActivite: text('description_activite', base.descriptionActivite),
      representantNom: text('representant_nom', base.representantNom),
      hasPhoto: base.hasPhoto || body['photo'] is String,
      hasRepresentantPhoto: base.hasRepresentantPhoto || body['representant_photo'] is String,
      hasCni: base.hasCni || body['cni_photo'] is String,
      hasDiplome: base.hasDiplome || body['diplome_photo'] is String,
    );
  }

  MyBusiness _copy(MyBusiness b, {BusinessStatus? status, String? motifRejet}) => MyBusiness(
        status: status ?? b.status,
        name: b.name,
        motifRejet: motifRejet ?? b.motifRejet,
        typeCompte: b.typeCompte,
        zoneId: b.zoneId,
        repere: b.repere,
        description: b.description,
        descriptionActivite: b.descriptionActivite,
        representantNom: b.representantNom,
        hasPhoto: b.hasPhoto,
        hasRepresentantPhoto: b.hasRepresentantPhoto,
        hasCni: b.hasCni,
        hasDiplome: b.hasDiplome,
      );
}
