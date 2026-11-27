// Jetons JWT (flutter_secure_storage) : seul endroit où ils sont conservés
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Jetons de la session.
class StoredTokens {
  const StoredTokens({this.access, this.refresh});

  final String? access;
  final String? refresh;

  bool get hasRefresh => refresh != null && refresh!.isNotEmpty;
}

/// Accès au stockage des jetons (interface pour pouvoir le remplacer dans les tests).
abstract class TokenStorage {
  Future<StoredTokens> read();
  Future<void> save({required String access, required String refresh});
  Future<void> clear();
}

/// Version réelle : Keystore Android / Keychain iOS.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const accessKey = 'netbuis_access';
  static const refreshKey = 'netbuis_refresh';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredTokens> read() async => StoredTokens(
        access: await _storage.read(key: accessKey),
        refresh: await _storage.read(key: refreshKey),
      );

  @override
  Future<void> save({required String access, required String refresh}) async {
    await _storage.write(key: accessKey, value: access);
    await _storage.write(key: refreshKey, value: refresh);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: accessKey);
    await _storage.delete(key: refreshKey);
  }
}
