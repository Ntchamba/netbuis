import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/auth/presentation/screens/login_screen.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';
import 'package:netbuis/features/business/presentation/widgets/account_type_selector.dart';

import '../account/account_test_helpers.dart';
import '../auth/login_test_helpers.dart';
import 'business_test_helpers.dart';

Finder get _name => find.byKey(const ValueKey('business-name'));
Finder get _owner => find.byKey(const ValueKey('business-owner'));
Finder get _repere => find.byKey(const ValueKey('business-repere'));
Finder get _ownerPhoto => find.byKey(const ValueKey('business-owner-photo'));
Finder get _photo => find.byKey(const ValueKey('business-photo'));

Future<void> _show(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String code) async {
  await _show(tester, typeButton(code));
  await tester.tap(typeButton(code));
  await tester.pumpAndSettle();
}

Future<void> _addOwnerPhoto(WidgetTester tester) async {
  await _show(tester, _ownerPhoto);
  await tester.tap(_ownerPhoto);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('photo-camera')));
  await tester.pumpAndSettle();
}

Future<void> _fillValid(WidgetTester tester) async {
  await tester.enterText(_name, 'Chez Aïcha');
  await tester.enterText(_owner, 'Aïcha B.');
  await _addOwnerPhoto(tester);
}

void main() {
  testWidgets('5 boutons de type, icône + mot, sur deux rangées (3 puis 2)', (tester) async {
    await pumpBusinessApp(tester);

    for (final label in ['Commerce', 'Entreprise', 'Structure', 'Particulier', 'Prestataire']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final icon in ['🏪', '🏢', '🏛️', '🙋', '🧰']) {
      expect(find.descendant(of: find.byType(AccountTypeSelector), matching: find.text(icon)),
          findsOneWidget,
          reason: icon);
    }
    final row1 = ['boutique', 'entreprise', 'structure'].map((c) => tester.getTopLeft(typeButton(c)).dy);
    final row2 =
        ['particulier_vendeur', 'prestataire_service'].map((c) => tester.getTopLeft(typeButton(c)).dy);
    expect(row1.toSet().length, 1);
    expect(row2.toSet().length, 1);
    expect(row2.first, greaterThan(row1.first));
    // Cibles tactiles d'au moins 48 dp.
    for (final code in BusinessAccountType.values.map((t) => t.value)) {
      final size = tester.getSize(typeButton(code));
      expect(size.height, greaterThanOrEqualTo(48), reason: code);
      expect(size.width, greaterThanOrEqualTo(48), reason: code);
    }
    // Commerce est choisi au départ, comme dans la maquette.
    expect(currentDraft(tester).typeCompte, BusinessAccountType.boutique);
  });

  testWidgets('en-tête de la maquette et barre « Étape 1 sur 4 » pour Commerce', (tester) async {
    await pumpBusinessApp(tester);

    expect(find.text('Créer mon compte business'), findsOneWidget);
    expect(find.text('Étape 1 sur 4'), findsOneWidget);
    expect(find.bySemanticsLabel('Étape 1 sur 4'), findsOneWidget);
    expect(find.text('Informations de base'), findsOneWidget);
    expect(find.text('Continuer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le total « Étape X sur Y » change avec le type', (tester) async {
    await pumpBusinessApp(tester);
    const expected = {
      'boutique': 4,
      'entreprise': 5,
      'structure': 4,
      'particulier_vendeur': 4,
      'prestataire_service': 3,
    };
    for (final e in expected.entries) {
      await _choose(tester, e.key);
      expect(find.text('Étape 1 sur ${e.value}'), findsOneWidget, reason: e.key);
    }
  });

  testWidgets('libellés du nom et du représentant selon le type (maquette et spec)', (tester) async {
    await pumpBusinessApp(tester);

    // Commerce : propriétaire, pas d'aide.
    expect(find.text('Nom du commerce'), findsOneWidget);
    expect(find.text('Ex. Boutique Mama Aïcha'), findsOneWidget);
    expect(find.text('Nom du propriétaire'), findsOneWidget);
    expect(find.text('Photo de votre commerce'), findsOneWidget);
    expect(find.textContaining('Photo du propriétaire'), findsOneWidget);
    expect(find.textContaining('Gérant'), findsNothing);
    expect(find.textContaining('Pour la vérification'), findsNothing);

    await _choose(tester, 'entreprise');
    expect(find.text('Nom de l’entreprise'), findsOneWidget);
    expect(find.text('Ex. NetBuis Services SARL'), findsOneWidget);
    expect(find.text('Nom du représentant légal'), findsOneWidget);
    expect(find.text('Gérant, Directeur Général, PDG... selon la forme juridique de votre entreprise.'),
        findsOneWidget);
    expect(find.text('Photo de l’entreprise'), findsOneWidget);
    expect(find.textContaining('Photo du représentant légal'), findsOneWidget);

    await _choose(tester, 'structure');
    expect(find.text('Nom de l’établissement'), findsOneWidget);
    expect(find.text('Ex. Hôtel Le Sahel, Clinique Bonne Santé'), findsOneWidget);
    expect(find.text('Nom du responsable'), findsOneWidget);
    expect(find.text('Directeur, gérant, responsable de l’établissement...'), findsOneWidget);
    expect(find.text('Photo de l’établissement'), findsOneWidget);
    expect(find.textContaining('Photo du responsable'), findsOneWidget);

    for (final code in ['particulier_vendeur', 'prestataire_service']) {
      await _choose(tester, code);
      expect(find.text('Comment souhaitez-vous apparaître ?'), findsOneWidget, reason: code);
      expect(find.text('Votre nom complet'), findsOneWidget, reason: code);
      expect(
        find.text('Pour la vérification de votre identité — peut différer du nom affiché publiquement ci-dessus.'),
        findsOneWidget,
        reason: code,
      );
      expect(find.text('Photo de votre activité'), findsOneWidget, reason: code);
      expect(find.textContaining('Votre photo (vérification)'), findsOneWidget, reason: code);
    }
    expect(find.text('Ex. Aïcha, couturière'), findsNothing);
    expect(find.text('Ex. Moussa, technicien frigoriste'), findsOneWidget);
  });

  testWidgets('encart explicatif propre à chaque type', (tester) async {
    await pumpBusinessApp(tester);
    const starts = {
      'boutique': 'Commerce : pour une boutique',
      'entreprise': 'Entreprise : parcours dédié',
      'structure': 'Structure : pour un supermarché',
      'particulier_vendeur': 'Particulier vendeur : parcours simplifié',
      'prestataire_service': 'Prestataire de service (technicien',
    };
    for (final e in starts.entries) {
      await _choose(tester, e.key);
      final text = tester.widget<Text>(find.byKey(const ValueKey('business-note-text'))).data!;
      expect(text, startsWith(e.value), reason: e.key);
    }
  });

  testWidgets('le lieu est un résumé non modifiable : la ville choisie en T022', (tester) async {
    await pumpBusinessApp(tester);
    await _show(tester, find.byKey(const ValueKey('business-location')));

    expect(find.text('Ville / Quartier'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('business-location')), matching: find.text('Maroua')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('business-location')));
    await tester.pumpAndSettle();
    // Rien ne s'ouvre avant T034 : on reste sur l'écran Informations.
    expect(find.text('Étape 1 sur 4'), findsOneWidget);
    expect(find.byType(EditableText), findsWidgets);
  });

  testWidgets('repère optionnel et numéro masqué « ✓ vérifié » (jamais le numéro complet)',
      (tester) async {
    await pumpBusinessApp(tester);
    await _show(tester, _repere);

    expect(find.text('Repère (optionnel)'), findsOneWidget);
    expect(find.text('Ex. à côté du Grand Manguier'), findsOneWidget);
    await _show(tester, find.byKey(const ValueKey('business-phone')));
    expect(find.text('Numéro de téléphone'), findsOneWidget);
    expect(find.text('+237 6•• •• •• 12'), findsOneWidget);
    expect(find.text('✓ vérifié'), findsOneWidget);
  });

  testWidgets('« Continuer » vide : erreurs claires, aucun passage à l\'étape suivante',
      (tester) async {
    await pumpBusinessApp(tester);
    expect(find.text('Entrez un nom.'), findsNothing);

    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Entrez un nom.'), findsOneWidget);
    expect(find.text('Entrez le nom de la personne.'), findsOneWidget);
    expect(find.text('Ajoutez une photo.'), findsOneWidget);
    expect(find.text('Étape 1 sur 4'), findsOneWidget);
    expect(find.text('Cette étape arrive bientôt'), findsNothing);
  });

  testWidgets('les erreurs partent quand le champ est rempli', (tester) async {
    await pumpBusinessApp(tester);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    await tester.enterText(_name, 'Chez Aïcha');
    await tester.pumpAndSettle();
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Entrez un nom.'), findsNothing);
    expect(find.text('Entrez le nom de la personne.'), findsOneWidget);
  });

  testWidgets('nom à espaces seulement : refusé', (tester) async {
    await pumpBusinessApp(tester);
    await tester.enterText(_name, '    ');
    await tester.enterText(_owner, 'Aïcha B.');
    await _addOwnerPhoto(tester);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Entrez un nom.'), findsOneWidget);
    expect(find.text('Entrez le nom de la personne.'), findsNothing);
    expect(find.text('Ajoutez une photo.'), findsNothing);
  });

  testWidgets('longueur limitée à 150 caractères comme le serveur', (tester) async {
    await pumpBusinessApp(tester);
    await tester.enterText(_name, 'a' * 200);
    await tester.pump();

    expect(currentDraft(tester).name.length, 150);
  });

  testWidgets('Commerce, tout rempli : passe à l\'étape Secteur (2 sur 4), brouillon complet',
      (tester) async {
    await pumpBusinessApp(tester);
    await _fillValid(tester);
    await tester.enterText(_repere, 'près du manguier');
    await tester.tap(continueButton);
    await tester.pump();

    await tester.pumpAndSettle();
    expect(find.text('Quel est votre secteur d\'activité ?'), findsOneWidget);
    expect(find.text('Étape 2 sur 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final d = currentDraft(tester);
    expect(d.name, 'Chez Aïcha');
    expect(d.representantNom, 'Aïcha B.');
    expect(d.repere, 'près du manguier');
    expect(d.representantPhotoPath, '/fictif/photo.jpg');
  });

  testWidgets('Entreprise passe par Forme juridique (étape 2 sur 5)', (tester) async {
    await pumpBusinessApp(tester);
    await _choose(tester, 'entreprise');
    await _fillValid(tester);

    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Étape 2 sur 5'), findsOneWidget);
    expect(find.text('Quelle est la forme juridique de votre entreprise ?'), findsOneWidget);
    expect(find.text('Cette étape arrive bientôt'), findsNothing);
  });

  testWidgets('les 4 autres types ne passent pas par la forme juridique', (tester) async {
    for (final code in ['boutique', 'structure', 'particulier_vendeur', 'prestataire_service']) {
      await pumpBusinessApp(tester);
      await _choose(tester, code);
      await _fillValid(tester);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.text('Quelle est la forme juridique de votre entreprise ?'), findsNothing,
          reason: code);
      // Commerce et Particulier passent au Secteur (étape 2) ; les deux autres parcours
      // n'ont pas encore leur écran suivant (T032, T033) et restent à l'étape 1.
      final next = (code == 'boutique' || code == 'particulier_vendeur') ? 2 : 1;
      expect(find.text('Étape $next sur ${code == 'prestataire_service' ? 3 : 4}'),
          findsOneWidget,
          reason: code);
    }
  });

  testWidgets('retour arrière : tout est retrouvé (type, textes, photos)', (tester) async {
    await pumpBusinessApp(tester);
    await _choose(tester, 'entreprise');
    await _fillValid(tester);
    await _show(tester, _repere);
    await tester.enterText(_repere, 'près du pont');
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(find.text('Étape 2 sur 5'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('business-back')));
    await tester.pumpAndSettle();

    expect(find.text('Étape 1 sur 5'), findsOneWidget);
    expect(currentDraft(tester).typeCompte, BusinessAccountType.entreprise);
    expect(tester.widget<TextField>(_name).controller!.text, 'Chez Aïcha');
    expect(tester.widget<TextField>(_owner).controller!.text, 'Aïcha B.');
    expect(tester.widget<TextField>(_repere).controller!.text, 'près du pont');
    await _show(tester, _ownerPhoto);
    expect(find.text('Photo ajoutée'), findsOneWidget);
    expect(find.text('Nom du représentant légal'), findsOneWidget);
  });

  testWidgets('changer de type après coup recalcule les étapes et vide la forme juridique',
      (tester) async {
    await pumpBusinessApp(tester);
    await _choose(tester, 'entreprise');
    await _fillValid(tester);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    // Sur Forme juridique : on choisit une forme et un RCCM, puis on revient.
    await tester.tap(find.byKey(const ValueKey('business-legal-sarl')));
    await tester.enterText(find.byKey(const ValueKey('business-rccm')), 'RC/1');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('business-back')));
    await tester.pumpAndSettle();
    expect(currentDraft(tester).formeJuridique, LegalForm.sarl);

    await _choose(tester, 'boutique');

    final d = currentDraft(tester);
    expect(d.typeCompte, BusinessAccountType.boutique);
    expect(d.formeJuridique, isNull);
    expect(d.rccm, '');
    expect(d.name, 'Chez Aïcha');
    expect(find.text('Étape 1 sur 4'), findsOneWidget);
  });

  testWidgets('photo : annulation sans effet, erreur d\'appareil photo sans plantage',
      (tester) async {
    final photos = FakePhotoPicker()..result = null;
    await pumpBusinessApp(tester, photos: photos);
    await _show(tester, _photo);
    await tester.tap(_photo);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photo-gallery')));
    await tester.pumpAndSettle();
    expect(photos.asked.single.name, 'gallery');
    expect(currentDraft(tester).photoPath, isNull);

    photos.fail = true;
    await tester.tap(_photo);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photo-camera')));
    await tester.pumpAndSettle();
    expect(find.text('Photo impossible. Réessayez.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    photos.fail = false;
    photos.result = '/fictif/commerce.jpg';
    await tester.pump(const Duration(seconds: 5));
    await tester.tap(_photo);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('photo-camera')));
    await tester.pumpAndSettle();
    expect(currentDraft(tester).photoPath, '/fictif/commerce.jpg');
  });

  testWidgets('route protégée : sans connexion, /create-business mène à la connexion',
      (tester) async {
    await pumpBusinessApp(tester, signedIn: false);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Créer mon compte business'), findsNothing);
  });

  testWidgets('police à 130 %, 360 px, thèmes sombre et clair : pas de débordement', (tester) async {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      await pumpBusinessApp(tester, textScale: 1.3, mode: mode);
      for (final code in BusinessAccountType.values.map((t) => t.value)) {
        await _choose(tester, code);
        await tester.tap(continueButton);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$code / $mode');
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -3000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$code / $mode (bas)');
        await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 3000));
        await tester.pumpAndSettle();
      }
      expectNoHorizontalScroll(tester);
    }
  });

  testWidgets('bouton retour sans pile (ouverture directe) : retour au Profil', (tester) async {
    await pumpBusinessApp(tester, account: ScriptedAccountRepository(me: meWith(name: 'Jeff N.')));
    expect(tester.getSize(find.byKey(const ValueKey('business-back'))).height, greaterThanOrEqualTo(48));

    await tester.tap(find.byKey(const ValueKey('business-back')));
    await tester.pumpAndSettle();

    expect(find.text('Mon profil'), findsOneWidget);
    expect(Routes.profile, '/profile');
  });
}
