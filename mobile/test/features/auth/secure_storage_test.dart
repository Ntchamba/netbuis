import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/storage/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('enregistre puis relit les deux jetons', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureTokenStorage();
    await storage.save(access: 'a', refresh: 'r');
    final t = await storage.read();
    expect((t.access, t.refresh, t.hasRefresh), ('a', 'r', true));
  });

  test('stockage vide : aucun jeton ; après clear aussi', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureTokenStorage();
    expect((await storage.read()).hasRefresh, isFalse);
    await storage.save(access: 'a', refresh: 'r');
    await storage.clear();
    final t = await storage.read();
    expect((t.access, t.refresh), (null, null));
  });
}
