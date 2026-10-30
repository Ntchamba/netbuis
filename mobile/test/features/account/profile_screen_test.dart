import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/features/auth/presentation/screens/login_screen.dart';

import '../auth/login_test_helpers.dart';
import 'account_test_helpers.dart';

Finder get _name => find.byKey(const ValueKey('profile-name'));
Finder get _phone => find.byKey(const ValueKey('profile-phone'));
Finder get _avatar => find.byKey(const ValueKey('profile-avatar'));

void main() {
  testWidgets(
      'identité : initiales, nom, numéro masqué « numéro vérifié », déconnexion',
      (tester) async {
    await pumpAccountApp(tester,
        account: ScriptedAccountRepository(me: meWith(name: 'Jeff N.')));

    expect(find.text('Mon profil'), findsOneWidget);
    expect(tester.widget<Text>(_name).data, 'Jeff N.');
    expect(
        tester.widget<Text>(_phone).data, '+237 6•• •• •• 12 — numéro vérifié');
    expect(find.descendant(of: _avatar, matching: find.text('JN')),
        findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'sans nom : « Utilisateur NetBuis » et icône personne, jamais le numéro',
      (tester) async {
    await pumpAccountApp(tester,
        account: ScriptedAccountRepository(me: meWith()));

    expect(tester.widget<Text>(_name).data, 'Utilisateur NetBuis');
    expect(find.descendant(of: _avatar, matching: find.byType(Icon)),
        findsOneWidget);
    expect(find.descendant(of: _avatar, matching: find.byType(Text)),
        findsNothing);
    // Aucun chiffre en dehors de la ligne du numéro masqué.
    expect(find.descendant(of: _avatar, matching: find.textContaining('12')),
        findsNothing);
    expect(tester.widget<Text>(_name).data!.contains(RegExp(r'\d')), isFalse);
  });

  testWidgets(
      'réseau coupé : message simple et « Réessayer » recharge le profil',
      (tester) async {
    final repo = ScriptedAccountRepository(me: meWith(name: 'Jeff N.'))
      ..getError = const ApiException(ApiErrorCode.network);
    await pumpAccountApp(tester, account: repo);

    expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'),
        findsOneWidget);
    expect(_name, findsNothing);
    expect(find.text('Se déconnecter'), findsOneWidget);

    repo.getError = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'),
        findsNothing);
    expect(tester.widget<Text>(_name).data, 'Jeff N.');
  });

  testWidgets(
      '401 : session expirée, sans texte du serveur, et la déconnexion reste possible',
      (tester) async {
    final repo = ScriptedAccountRepository()
      ..getError = const ApiException(ApiErrorCode.unknown,
          message: 'texte serveur', statusCode: 401);
    await pumpAccountApp(tester, account: repo);

    expect(
        find.text(
            'Votre session a expiré. Déconnectez-vous puis reconnectez-vous.'),
        findsOneWidget);
    expect(find.text('texte serveur'), findsNothing);

    await tester.ensureVisible(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets(
      '« Se déconnecter » : retour à la connexion (la déconnexion elle-même est testée en T009)',
      (tester) async {
    final auth = FlowRepository();
    await pumpAccountApp(tester,
        account: ScriptedAccountRepository(me: meWith(name: 'Jeff N.')),
        auth: auth);

    await tester.ensureVisible(find.text('Se déconnecter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se déconnecter'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(onHome(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      '360 px, police 130 %, nom très long : pas de débordement ni de défilement horizontal',
      (tester) async {
    final long = List.filled(6, 'Ndongomobassi').join(' ');
    await pumpAccountApp(tester,
        account: ScriptedAccountRepository(me: meWith(name: long)),
        textScale: 1.3);

    expect(tester.takeException(), isNull);
    expectNoHorizontalScroll(tester);
    final logout = find.byKey(const ValueKey('profile-logout'));
    expect(tester.getSize(logout).height, greaterThanOrEqualTo(48));
  });

  testWidgets('thème clair : l\'écran se construit sans erreur',
      (tester) async {
    await pumpAccountApp(tester,
        account: ScriptedAccountRepository(me: meWith(name: 'Jeff N.')),
        mode: ThemeMode.light);
    expect(tester.takeException(), isNull);
    expect(find.text('Se déconnecter'), findsOneWidget);
  });

  testWidgets('sémantique : titre en en-tête, bouton de déconnexion',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpAccountApp(tester,
        account: ScriptedAccountRepository(me: meWith(name: 'Jeff N.')));
    await tester.ensureVisible(find.byKey(const ValueKey('profile-logout')));
    await tester.pumpAndSettle();
    expect(
        tester.getSemantics(find.byKey(const ValueKey('profile-logout'))),
        matchesSemantics(
            label: 'Se déconnecter', isButton: true, hasTapAction: true));
    expect(find.bySemanticsLabel('Photo de profil : initiales JN'),
        findsOneWidget);
    handle.dispose();
  });
}
