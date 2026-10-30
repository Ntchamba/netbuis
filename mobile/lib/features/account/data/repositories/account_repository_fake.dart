// Version factice (USE_FAKE_API) : aucun réseau, état gardé en mémoire
import '../../../../core/network/api_exception.dart';
import '../models/me.dart';
import 'account_repository.dart';

class AccountRepositoryFake implements AccountRepository {
  AccountRepositoryFake();

  /// Valeur fictive au format du serveur (pas un vrai numéro).
  static const fakePhoneMasked = '+237 6•• •• •• 12';

  Me _me = const Me(id: 1, name: '', phoneMasked: fakePhoneMasked);

  /// Le faux compte a maintenant un compte business (appelé par le faux dépôt « business »).
  void markHasBusiness() => _me = _me.copyWith(hasBusiness: true);

  @override
  Future<Me> getMe() async => _me;

  @override
  Future<Me> updateName(String name) async {
    final value = name.trim();
    if (value.isEmpty || value.length > maxNameLength) {
      throw const ApiException(ApiErrorCode.invalid, statusCode: 400);
    }
    _me = _me.copyWith(name: value);
    return _me;
  }

  @override
  Future<void> deleteAccount() async {
    _me = const Me(id: 1, name: '', phoneMasked: fakePhoneMasked);
  }
}
