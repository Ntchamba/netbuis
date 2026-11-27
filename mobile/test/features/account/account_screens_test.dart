import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/guards.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/account/presentation/screens/edit_profile_screen.dart';
import 'package:netbuis/features/auth/application/auth_state.dart';
import 'package:netbuis/features/auth/data/repositories/auth_repository_fake.dart';

import '../auth/login_test_helpers.dart';
import 'account_test_helpers.dart';

final _nameField = find.byKey(const ValueKey('name-field'));

void main() {
  group('garde : première connexion', () {
    test(
        'compte neuf : la connexion mène à la saisie du nom, un compte connu à l\'Accueil',
        () {
      expect(authRedirect(const AuthAuthenticated(isNew: true), Routes.otp),
          Routes.yourName);
      expect(authRedirect(const AuthAuthenticated(isNew: true), Routes.login),
          Routes.yourName);
      expect(authRedirect(const AuthAuthenticated(), Routes.otp), Routes.home);
    });

    test(
        'la saisie du nom reste ouverte une fois connecté, fermée sans session',
        () {
      expect(
          authRedirect(const AuthAuthenticated(isNew: true), Routes.yourName),
          isNull);
      expect(
          authRedirect(const AuthLoggedOut(), Routes.yourName), Routes.login);
    });
  });

  group('saisie du nom', () {
    testWidgets('un nom est envoyé (espaces retirés) puis on va à l\'Accueil',
        (tester) async {
      final repo = ScriptedAccountRepository();
      await pumpAccountApp(tester,
          account: repo, initialLocation: Routes.yourName);

      expect(find.text('Comment vous appelez-vous ?'), findsOneWidget);
      expect(tester.widget<TextField>(_nameField).keyboardType,
          TextInputType.name);
      await tester.enterText(_nameField, '  Jeff N.  ');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(repo.sentNames, ['Jeff N.']);
      expect(onHome(), isTrue);
    });

    testWidgets('un champ vide n\'envoie rien', (tester) async {
      final repo = ScriptedAccountRepository();
      await pumpAccountApp(tester,
          account: repo, initialLocation: Routes.yourName);
      await tester.enterText(_nameField, '   ');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(onHome(), isTrue);
      expect(repo.sentNames, isEmpty);
    });

    testWidgets('« Passer » mène à l\'Accueil sans rien envoyer',
        (tester) async {
      final repo2 = ScriptedAccountRepository();
      await pumpAccountApp(tester,
          account: repo2, initialLocation: Routes.yourName);
      await tester.enterText(_nameField, 'Jeff');
      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();
      expect(onHome(), isTrue);
      expect(repo2.sentNames, isEmpty);
    });

    testWidgets('le nom est limité à 120 caractères', (tester) async {
      final repo = ScriptedAccountRepository();
      await pumpAccountApp(tester,
          account: repo, initialLocation: Routes.yourName);
      await tester.enterText(_nameField, 'a' * 150);
      await tester.pump();
      expect(tester.widget<TextField>(_nameField).controller!.text.length, 120);
    });

    testWidgets('réseau coupé : message, on reste, « Réessayer » puis succès',
        (tester) async {
      final repo = ScriptedAccountRepository()
        ..patchErrors.add(const ApiException(ApiErrorCode.network));
      await pumpAccountApp(tester,
          account: repo, initialLocation: Routes.yourName);
      await tester.enterText(_nameField, 'Jeff');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('Pas de connexion. Réessayez ou passez cette étape.'),
          findsOneWidget);
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.text('Passer'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(repo.sentNames, ['Jeff', 'Jeff']);
      expect(onHome(), isTrue);
    });

    testWidgets('après un échec, « Passer » mène à l\'Accueil', (tester) async {
      final repo = ScriptedAccountRepository()
        ..patchErrors.add(const ApiException(ApiErrorCode.unknown));
      await pumpAccountApp(tester,
          account: repo, initialLocation: Routes.yourName);
      await tester.enterText(_nameField, 'Jeff');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Une erreur est survenue. Réessayez ou passez cette étape.'),
          findsOneWidget);
      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();
      expect(onHome(), isTrue);
    });

    testWidgets(
        '360 px, police 130 % : pas de débordement, pas de défilement horizontal, cibles >= 48 dp',
        (tester) async {
      await pumpAccountApp(tester,
          account: ScriptedAccountRepository(),
          initialLocation: Routes.yourName,
          textScale: 1.3);
      expect(tester.takeException(), isNull);
      expectNoHorizontalScroll(tester);
      for (final f in [
        find.byType(FilledButton),
        find.byKey(const ValueKey('name-skip'))
      ]) {
        expect(tester.getSize(f).height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets(
        'parcours complet : compte neuf, code, nom, Accueil, puis Profil avec les initiales',
        (tester) async {
      final repo = ScriptedAccountRepository();
      await pumpAccountApp(
        tester,
        account: repo,
        auth: AuthRepositoryFake(),
        initialLocation: Routes.login,
        signedIn: false,
      );
      await submitPhone(tester, '612345678');
      await tester.enterText(otpField, AuthRepositoryFake.acceptedCode);
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileScreen), findsOneWidget);
      await tester.enterText(_nameField, 'Jeff Ndongo');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(onHome(), isTrue);
      expect(repo.sentNames, ['Jeff Ndongo']);

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      expect(find.text('Jeff Ndongo'), findsOneWidget);
      expect(find.text('JN'), findsOneWidget);
    });
  });
}
