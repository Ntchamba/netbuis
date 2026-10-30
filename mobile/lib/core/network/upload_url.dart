// Adresse d'envoi d'un fichier
import 'package:flutter/foundation.dart';

import 'api_exception.dart';

/// Résout l'`upload_url` renvoyée par `POST /api/uploads/sign/`.
///
/// - Adresse complète (`http://` ou `https://`) : utilisée telle quelle (stockage compatible S3).
/// - Chemin du serveur commençant par `/` (ex. `/api/uploads/local/<jeton>/`) : résolu contre
///   l'**origine** de l'API (schéma + hôte + port de [apiUrl]), jamais ajouté à [apiUrl] qui
///   contient déjà `/api`.
/// - Tout autre contenu : refusé ([ApiErrorCode.unknown]).
/// - En release ([release] = `kReleaseMode`), une adresse `http://` est refusée (T121).
String resolveUploadUrl(String apiUrl, String uploadUrl, {bool release = kReleaseMode}) {
  final lower = uploadUrl.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    if (release && !lower.startsWith('https://')) {
      throw const ApiException(ApiErrorCode.unknown);
    }
    if (Uri.tryParse(uploadUrl)?.host.isNotEmpty ?? false) return uploadUrl;
    throw const ApiException(ApiErrorCode.unknown);
  }
  if (uploadUrl.startsWith('/') && !uploadUrl.startsWith('//')) {
    final base = Uri.tryParse(apiUrl);
    if (base != null && base.hasScheme && base.host.isNotEmpty) {
      final port = base.hasPort ? ':${base.port}' : '';
      return '${base.scheme}://${base.host}$port$uploadUrl';
    }
  }
  throw const ApiException(ApiErrorCode.unknown);
}
