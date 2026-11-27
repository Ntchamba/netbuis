import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/router/guards.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/auth/application/auth_state.dart';

void main() {
  test('le choix de la ville est ouvert sans connexion (il précède la connexion)', () {
    expect(authRedirect(const AuthLoggedOut(), Routes.chooseCity), isNull);
  });

  test('un écran protégé reste protégé : non connecté, le profil mène à la connexion', () {
    expect(authRedirect(const AuthLoggedOut(), Routes.profile), Routes.login);
  });
}
