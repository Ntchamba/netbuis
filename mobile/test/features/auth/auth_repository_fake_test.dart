import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/features/auth/data/repositories/auth_repository_fake.dart';

Matcher _code(ApiErrorCode c) =>
    throwsA(isA<ApiException>().having((e) => e.code, 'code', c));

void main() {
  late AuthRepositoryFake repo;
  setUp(() => repo = AuthRepositoryFake());

  test('demande de code : numéro valide -> validité de 5 minutes', () async {
    final r = await repo.requestOtp('691234567');
    expect(r.expiresIn, const Duration(minutes: 5));
    await repo.requestOtp('+237 691 234 567');
  });

  test('demande de code : numéro invalide -> invalid_phone', () async {
    await expectLater(
        repo.requestOtp('12345'), _code(ApiErrorCode.invalidPhone));
    await expectLater(
        repo.requestOtp('791234567'), _code(ApiErrorCode.invalidPhone));
  });

  test('le code 123456 est accepté ; premier compte is_new puis plus',
      () async {
    final first = await repo.verifyOtp(phone: '691234567', code: '123456');
    expect(first.isNew, isTrue);
    expect(first.access, isNotEmpty);
    final second = await repo.verifyOtp(phone: '+237691234567', code: '123456');
    expect(second.isNew, isFalse);
  });

  test('un autre code -> otp_invalid', () async {
    await expectLater(repo.verifyOtp(phone: '691234567', code: '000000'),
        _code(ApiErrorCode.otpInvalid));
  });

  test('vérification avec numéro invalide -> invalid_phone', () async {
    await expectLater(repo.verifyOtp(phone: 'abc', code: '123456'),
        _code(ApiErrorCode.invalidPhone));
  });

  test(
      'rafraîchissement : nouveau couple différent ; jeton inconnu -> token_invalid',
      () async {
    final t = await repo.verifyOtp(phone: '691234567', code: '123456');
    final r = await repo.refresh(t.refresh);
    expect(r.refresh, isNot(t.refresh));
    expect(r.access, isNot(t.access));
    await expectLater(repo.refresh('autre'), _code(ApiErrorCode.tokenInvalid));
  });

  test('déconnexion : jeton connu accepté, inconnu -> token_invalid', () async {
    final t = await repo.verifyOtp(phone: '691234567', code: '123456');
    await repo.logout(t.refresh);
    await expectLater(repo.logout('autre'), _code(ApiErrorCode.tokenInvalid));
  });
}
