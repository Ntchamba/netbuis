import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/account/data/models/me.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';

import '../account/account_test_helpers.dart';
import 'business_test_helpers.dart';

Finder get _card => find.byKey(const ValueKey('profile-create-business'));
Finder get _button => find.byKey(const ValueKey('profile-create-business-button'));

Me _me({required bool hasBusiness}) => Me(
      id: 1,
      name: 'Jeff N.',
      phoneMasked: '+237 6•• •• •• 12',
      hasBusiness: hasBusiness,
    );

void main() {
  testWidgets('Profil sans compte business : l\'encart de la maquette est là et ouvre l\'étape 1',
      (tester) async {
    await pumpBusinessApp(
      tester,
      initialLocation: Routes.profile,
      account: ScriptedAccountRepository(me: _me(hasBusiness: false)),
    );

    expect(_card, findsOneWidget);
    expect(find.text('Vous vendez un produit ou un service ?'), findsOneWidget);
    expect(
      find.text('Activez votre compte Business pour publier vos produits et apparaître dans les recherches.'),
      findsOneWidget,
    );
    expect(find.text('Activer mon compte Business'), findsOneWidget);
    expect(tester.getSize(_button).height, greaterThanOrEqualTo(48));

    await tester.tap(_button);
    await tester.pumpAndSettle();

    expect(find.text('Créer mon compte business'), findsOneWidget);
    expect(find.text('Étape 1 sur 4'), findsOneWidget);
    // Brouillon neuf : Commerce, rien de rempli.
    expect(currentDraft(tester).typeCompte, BusinessAccountType.boutique);
    expect(currentDraft(tester).name, '');
  });

  testWidgets('Profil avec compte business : aucune entrée de création', (tester) async {
    await pumpBusinessApp(
      tester,
      initialLocation: Routes.profile,
      account: ScriptedAccountRepository(me: _me(hasBusiness: true)),
    );

    expect(find.text('Mon profil'), findsOneWidget);
    expect(_card, findsNothing);
    expect(find.text('Activer mon compte Business'), findsNothing);
  });

  testWidgets('Profil : pas d\'entrée tant que le profil n\'est pas chargé ou en erreur',
      (tester) async {
    final repo = ScriptedAccountRepository(me: _me(hasBusiness: false))
      ..getError = const ApiException(ApiErrorCode.network);
    await pumpBusinessApp(tester, initialLocation: Routes.profile, account: repo);

    expect(_card, findsNothing);
  });

  testWidgets('quitter puis rouvrir le parcours repart d\'un brouillon neuf', (tester) async {
    await pumpBusinessApp(
      tester,
      initialLocation: Routes.profile,
      account: ScriptedAccountRepository(me: _me(hasBusiness: false)),
    );
    await tester.tap(_button);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('business-name')), 'Chez Aïcha');
    await tester.tap(typeButton('structure'));
    await tester.pumpAndSettle();
    expect(currentDraft(tester).name, 'Chez Aïcha');

    await tester.tap(find.byKey(const ValueKey('business-back')));
    await tester.pumpAndSettle();
    await tester.tap(_button);
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byKey(const ValueKey('business-name'))).controller!.text, '');
    expect(currentDraft(tester).typeCompte, BusinessAccountType.boutique);
  });

  testWidgets('Profil à 360 px, police 130 %, clair et sombre : encart sans débordement',
      (tester) async {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      await pumpBusinessApp(
        tester,
        initialLocation: Routes.profile,
        account: ScriptedAccountRepository(me: _me(hasBusiness: false)),
        textScale: 1.3,
        mode: mode,
      );
      expect(_card, findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$mode');
    }
  });
}
