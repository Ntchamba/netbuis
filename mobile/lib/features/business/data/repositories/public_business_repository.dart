// Contrat du dépôt « fiche publique »
import '../models/public_business.dart';

abstract class PublicBusinessRepository {
  /// GET `/api/business/{id}/` ; 404 `not_found` si le profil est absent ou non actif.
  Future<PublicBusiness> get(int id);
}
