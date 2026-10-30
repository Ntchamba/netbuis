// Contrat du dépôt « compte business »
import 'dart:typed_data';

import '../models/business.dart';

abstract class BusinessRepository {
  /// POST /api/uploads/sign/ : adresse d'envoi et clé pour UN fichier. [size] est la taille
  /// exacte en octets et [contentType] le type réel (d'après les premiers octets).
  Future<UploadTicket> signUpload({
    required String kind,
    required String contentType,
    required int size,
  });

  /// PUT du fichier vers l'adresse du [ticket], avec exactement ses en-têtes et sans jeton.
  Future<void> putFile(UploadTicket ticket, Uint8List bytes);

  /// POST /api/business/ : crée la demande (corps déjà limité aux champs du type).
  Future<MyBusiness> create(Map<String, Object?> body);

  /// GET /api/business/me/ (404 `no_business` si le compte n'en a pas).
  Future<MyBusiness> getMine();

  /// PATCH /api/business/me/ : modifie le compte. [body] ne contient QUE les champs changés
  /// (le serveur ne regarde que ce qui est envoyé). Règle D-08 appliquée par le serveur.
  Future<MyBusiness> update(Map<String, Object?> body);
}
