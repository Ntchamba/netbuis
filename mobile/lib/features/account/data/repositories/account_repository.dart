// Contrat du dépôt « compte »
import '../models/me.dart';

abstract class AccountRepository {
  /// GET /api/me/
  Future<Me> getMe();

  /// PATCH /api/me/ avec `{"name": …}` ; renvoie le profil à jour.
  Future<Me> updateName(String name);

  /// DELETE /api/me/ : suppression douce du compte (204, sans corps).
  Future<void> deleteAccount();
}
