import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';
import 'package:netbuis/core/router/routes.dart';

import '../auth/login_test_helpers.dart';
import 'business_test_helpers.dart';

Finder _form(String code) => find.byKey(ValueKey('business-legal-$code'));
Finder get _rccm => find.byKey(const ValueKey('business-rccm'));

/// Va jusqu'à l'écran Forme juridique par le vrai parcours : Entreprise, champs remplis.
Future<void> _openLegalForm(WidgetTester tester, {FakePhotoPicker? photos}) async {
  await pumpBusinessApp(tester, photos: photos);
  await tester.ensureVisible(typeButton('entreprise'));
  await tester.tap(typeButton('entreprise'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('business-name')), 'NetBuis Services');
  await tester.enterText(find.byKey(const ValueKey('business-owner')), 'Jeff N.');
  await tester.ensureVisible(find.byKey(const ValueKey('business-owner-photo')));
  await tester.tap(find.byKey(const ValueKey('business-owner-photo')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('photo-camera')));
  await tester.pumpAndSettle();
  await tester.tap(continueButton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('textes de la maquette et les 8 formes de la spec', (tester) async {
    await _openLegalForm(tester);

    expect(find.text('Étape 2 sur 5'), findsOneWidget);
    expect(find.text('Forme juridique'), findsOneWidget);
    expect(find.text('Quelle est la forme juridique de votre entreprise ?'), findsOneWidget);
    expect(
      find.text(
        "Cette information apparaît sur votre profil public et aide les utilisateurs à mieux connaître votre structure. Une entreprise suit un parcours différent de celui d'une boutique.",
      ),
      findsOneWidget,
    );
    const labels = [
      'Entreprise individuelle / Auto-entrepreneur',
      'SARL',
      'SARL Unipersonnelle',
      'SA (Société Anonyme)',
      'GIC / Coopérative',
      'Association / ONG',
      'Établissement public ou parapublic',
      'Autre',
    ];
    for (final l in labels) {
      await tester.ensureVisible(find.text(l));
      expect(find.text(l), findsOneWidget, reason: l);
    }
    expect(LegalForm.values.length, labels.length);
    await tester.ensureVisible(_rccm);
    expect(find.text('Numéro RCCM / immatriculation (optionnel)'), findsOneWidget);
    expect(find.text('Ex. RC/MRA/2023/B/0456'), findsOneWidget);
  });

  testWidgets('« Entreprise individuelle » est préchoisie ; un choix est gardé dans le brouillon',
      (tester) async {
    await _openLegalForm(tester);
    expect(find.bySemanticsLabel(RegExp(r'^Entreprise individuelle.*, choisi$')), findsOneWidget);

    await tester.ensureVisible(_form('sarl'));
    await tester.tap(_form('sarl'));
    await tester.pumpAndSettle();

    expect(currentDraft(tester).formeJuridique, LegalForm.sarl);
    expect(find.bySemanticsLabel('SARL, choisi'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Entreprise individuelle.*, choisi$')), findsNothing);
  });

  testWidgets('chaque forme envoie le code du serveur', (tester) async {
    const expected = {
      'individuelle': 'individuelle',
      'sarl': 'sarl',
      'sarlu': 'sarlu',
      'sa': 'sa',
      'gic_cooperative': 'gic_cooperative',
      'association': 'association',
      'etablissement_public': 'etablissement_public',
      'autre': 'autre',
    };
    await _openLegalForm(tester);
    for (final e in expected.entries) {
      await tester.ensureVisible(_form(e.key));
      await tester.tap(_form(e.key));
      await tester.pumpAndSettle();
      expect(currentDraft(tester).formeJuridique!.value, e.value);
    }
  });

  testWidgets('RCCM facultatif : on peut continuer sans, avec il est gardé, 50 caractères au plus',
      (tester) async {
    await _openLegalForm(tester);

    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    // Aucune erreur : on passe à l'étape Secteur (3 sur 5).
    expect(find.text('Étape 3 sur 5'), findsOneWidget);
    expect(currentDraft(tester).rccm, '');
    // La forme préchoisie est enregistrée au passage.
    expect(currentDraft(tester).formeJuridique, LegalForm.individuelle);
    await tester.tap(find.byKey(const ValueKey('business-back')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(_rccm);
    await tester.enterText(_rccm, 'RC/MRA/2023/B/0456');
    await tester.pump();
    expect(currentDraft(tester).rccm, 'RC/MRA/2023/B/0456');

    await tester.enterText(_rccm, 'X' * 80);
    await tester.pump();
    expect(currentDraft(tester).rccm.length, 50);
  });

  testWidgets('retour arrière depuis la forme juridique : le brouillon est intact', (tester) async {
    await _openLegalForm(tester);
    await tester.ensureVisible(_form('sa'));
    await tester.tap(_form('sa'));
    await tester.enterText(_rccm, 'RC/1');
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('business-back')));
    await tester.pumpAndSettle();
    expect(find.text('Étape 1 sur 5'), findsOneWidget);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Étape 2 sur 5'), findsOneWidget);
    expect(currentDraft(tester).formeJuridique, LegalForm.sa);
    expect(tester.widget<TextField>(_rccm).controller!.text, 'RC/1');
    expect(find.bySemanticsLabel('SA (Société Anonyme), choisi'), findsOneWidget);
  });

  testWidgets('réservé aux Entreprises : ouvert pour un autre type, renvoie à Informations',
      (tester) async {
    await pumpBusinessApp(tester, initialLocation: Routes.createBusinessLegalForm);

    expect(find.text('Quelle est la forme juridique de votre entreprise ?'), findsNothing);
    expect(find.text('Étape 1 sur 4'), findsOneWidget);
    expect(find.text('Informations de base'), findsOneWidget);
  });

  testWidgets('cibles de 48 dp, police 130 %, 360 px, thèmes clair et sombre', (tester) async {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      await _openLegalFormWith(tester, mode);
      for (final f in LegalForm.values) {
        await tester.ensureVisible(_form(f.value));
        expect(tester.getSize(_form(f.value)).height, greaterThanOrEqualTo(48), reason: f.value);
        expect(tester.getSize(_form(f.value)).width, lessThanOrEqualTo(360), reason: f.value);
      }
      expect(tester.takeException(), isNull);
      expectNoHorizontalScroll(tester);
    }
  });
}

Future<void> _openLegalFormWith(WidgetTester tester, ThemeMode mode) async {
  await pumpBusinessApp(tester, textScale: 1.3, mode: mode);
  await tester.ensureVisible(typeButton('entreprise'));
  await tester.tap(typeButton('entreprise'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('business-name')), 'NetBuis Services');
  await tester.enterText(find.byKey(const ValueKey('business-owner')), 'Jeff N.');
  await tester.ensureVisible(find.byKey(const ValueKey('business-owner-photo')));
  await tester.tap(find.byKey(const ValueKey('business-owner-photo')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('photo-camera')));
  await tester.pumpAndSettle();
  await tester.tap(continueButton);
  await tester.pumpAndSettle();
}
