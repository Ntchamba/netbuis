import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/data/referentials/referential_repository_fake.dart';
import 'package:netbuis/features/business/application/business_draft_controller.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';

import 'business_submit_helpers.dart';

const _phone = '+237 6•• •• •• 12 ✓';
const _pendingNote =
    "Votre demande sera examinée par l'équipe NetBuis avant publication — généralement sous 24 heures.";

Finder get _name => find.byKey(const ValueKey('recap-name'));
Finder get _submit => find.text('Publier ma demande');

Set<String> _imagePaths(WidgetTester tester) {
  final paths = <String>{};
  for (final w in tester.widgetList<Image>(find.byType(Image))) {
    // `cacheWidth` enveloppe le fichier dans un ResizeImage.
    ImageProvider p = w.image;
    if (p is ResizeImage) p = p.imageProvider;
    if (p is FileImage) paths.add(p.file.path);
  }
  return paths;
}

void main() {
  group('contenu selon le type (maquette CreationBusiness-Recap)', () {
    testWidgets('Commerce : textes de la maquette, numéro masqué avec ✓', (tester) async {
      await openRecap(tester, await completeDraft(BusinessAccountType.boutique));

      expect(find.text('Étape 4 sur 4'), findsOneWidget);
      expect(find.text('Récapitulatif'), findsOneWidget);
      expect(find.text('Créer mon compte business'), findsOneWidget);
      expect(find.text('Boutique Mama Aïcha'), findsOneWidget);
      expect(find.text('Propriétaire : Aïcha Oumarou'), findsOneWidget);
      expect(find.text('Zone'), findsOneWidget);
      expect(find.text('Maroua, Hardé'), findsOneWidget);
      expect(find.text('Téléphone'), findsOneWidget);
      expect(find.text(_phone), findsOneWidget);
      expect(find.text("SECTEUR D'ACTIVITÉ"), findsOneWidget);
      expect(find.text('🍌 Alimentation'), findsOneWidget);
      expect(find.text('Fruits'), findsOneWidget);
      expect(find.text('Légumes'), findsOneWidget);
      expect(find.text('« Vente de fruits et légumes frais »'), findsOneWidget);
      expect(find.text('🏪'), findsOneWidget);
      expect(find.text('⏳'), findsOneWidget);
      expect(find.text(_pendingNote), findsOneWidget);
      expect(_submit, findsOneWidget);
      // Le numéro entier n'apparaît nulle part : jamais plus de « 6•• •• •• 12 ».
      expect(find.textContaining(RegExp(r'6\d{8}')), findsNothing);
      // Les sous-catégories non choisies ne sont pas listées.
      expect(find.text('Tubercules'), findsNothing);
    });

    testWidgets('Entreprise : forme juridique et RCCM, 5 étapes', (tester) async {
      await openRecap(tester, await completeDraft(BusinessAccountType.entreprise));

      expect(find.text('Étape 5 sur 5'), findsOneWidget);
      expect(find.text('Représentant légal : Aïcha Oumarou'), findsOneWidget);
      expect(find.text('Forme juridique'), findsOneWidget);
      expect(find.text('SARL'), findsOneWidget);
      expect(find.text('RCCM'), findsOneWidget);
      expect(find.text('RC/MRA/2023/B/0456'), findsOneWidget);
      expect(find.text("SECTEUR D'ACTIVITÉ"), findsOneWidget);
      expect(find.text(_phone), findsOneWidget);
      expect(find.text('🏢'), findsOneWidget);
    });

    testWidgets('Particulier : même carte secteur, libellé « Nom complet »', (tester) async {
      await openRecap(tester, await completeDraft(BusinessAccountType.particulierVendeur));

      expect(find.text('Étape 4 sur 4'), findsOneWidget);
      expect(find.text('Nom complet : Aïcha Oumarou'), findsOneWidget);
      expect(find.text("SECTEUR D'ACTIVITÉ"), findsOneWidget);
      expect(find.text('Forme juridique'), findsNothing);
      expect(find.text(_phone), findsOneWidget);
    });

    testWidgets('Prestataire : catégorie, CNI « ✓ fournie » SANS jamais l\'afficher, diplôme',
        (tester) async {
      await openRecap(tester, await completeDraft(BusinessAccountType.prestataireService));

      expect(find.text('Étape 3 sur 3'), findsOneWidget);
      expect(find.text('CATÉGORIE DE SERVICE'), findsOneWidget);
      expect(find.text('Technique & Réparation'), findsOneWidget);
      expect(find.text("Carte d'identité (CNI)"), findsOneWidget);
      expect(find.text('✓ fournie'), findsOneWidget);
      expect(find.text('Diplôme / Certificat'), findsOneWidget);
      expect(find.text('✓ fourni'), findsOneWidget);
      expect(find.text(_phone), findsOneWidget);
      expect(find.text("SECTEUR D'ACTIVITÉ"), findsNothing);

      // Miniatures locales : photo, représentant et diplôme — JAMAIS la CNI.
      final paths = _imagePaths(tester);
      expect(paths, {'/fictif/commerce.png', '/fictif/personne.jpg', '/fictif/diplome.jpeg'});
      expect(paths.any((p) => p.contains('cni')), isFalse);
      // Ni le chemin ni le nom du fichier de la CNI ne sont écrits à l'écran.
      expect(find.textContaining('cni-secrete'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('cni-secrete')), findsNothing);
    });

    testWidgets('Prestataire « Autre » : le texte libre remplace la catégorie ; sans diplôme',
        (tester) async {
      final base = await completeDraft(BusinessAccountType.prestataireService);
      final other = base.withServiceCategory(
          (await const ReferentialRepositoryFake().getServiceCategories()).last);
      await openRecap(
          tester, other.copyWith(categorieServiceLibre: 'Mototaxi', diplomePhotoPath: null));

      expect(find.text('Mototaxi'), findsOneWidget);
      expect(find.text('Diplôme / Certificat'), findsNothing);
      expect(find.text('✓ fournie'), findsOneWidget);
    });

    testWidgets('Structure (restaurant) : type, cuisine, livraison, horaires, description',
        (tester) async {
      await openRecap(tester, await completeDraft(BusinessAccountType.structure));

      expect(find.text('Étape 4 sur 4'), findsOneWidget);
      expect(find.text("TYPE D'ÉTABLISSEMENT"), findsOneWidget);
      expect(find.text('🍲 Restaurant'), findsOneWidget);
      expect(find.text('Cuisine'), findsOneWidget);
      expect(find.text('Camerounaise'), findsOneWidget);
      expect(find.text('Livraison'), findsOneWidget);
      expect(find.text('Oui'), findsOneWidget);
      expect(find.text('Horaires'), findsOneWidget);
      expect(find.text('Tous les jours, 11h–22h'), findsOneWidget);
      expect(find.text('« Cadre climatisé »'), findsOneWidget);
      expect(find.text('Responsable : Aïcha Oumarou'), findsOneWidget);
    });

    testWidgets('lieu : ville seule quand il n\'y a pas de quartier ; repère facultatif',
        (tester) async {
      final base = await completeDraft(BusinessAccountType.boutique, withDistrict: false);
      await openRecap(tester, base.copyWith(repere: ''));
      expect(find.text('Maroua'), findsOneWidget);
      expect(find.text('Repère'), findsNothing);
    });

    testWidgets('le repère est affiché quand il existe', (tester) async {
      await openRecap(tester, await completeDraft(BusinessAccountType.boutique));
      expect(find.text('Repère'), findsOneWidget);
      expect(find.text('Près du grand manguier'), findsOneWidget);
    });
  });

  group('liens « Modifier » : on revient au récapitulatif, le brouillon est conservé', () {
    testWidgets('le lieu ouvre le choix du lieu', (tester) async {
      final container = await openRecap(tester, await completeDraft(BusinessAccountType.boutique));
      await tester.tap(find.byKey(const ValueKey('recap-zone')));
      await tester.pumpAndSettle();
      expect(find.text('Choisir le lieu de votre commerce'), findsOneWidget);
      expect(_submit, findsNothing);

      Navigator.of(tester.element(find.byType(Scaffold).first)).pop();
      await tester.pumpAndSettle();
      expect(_submit, findsOneWidget);
      expect(container.read(businessDraftProvider).name, 'Boutique Mama Aïcha');
      expect(find.text('Maroua, Hardé'), findsOneWidget);
    });

    testWidgets('la carte du commerce ouvre Informations, remplies', (tester) async {
      final container = await openRecap(tester, await completeDraft(BusinessAccountType.boutique));
      await tester.ensureVisible(find.byKey(const ValueKey('recap-edit-identity')));
      await tester.tap(find.byKey(const ValueKey('recap-edit-identity')));
      await tester.pumpAndSettle();

      expect(find.text('Informations de base'), findsOneWidget);
      expect(find.text('Étape 1 sur 4'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('business-name'))).controller!.text,
          'Boutique Mama Aïcha');

      await tester.tap(find.byKey(const ValueKey('business-back')));
      await tester.pumpAndSettle();
      expect(_submit, findsOneWidget);
      expect(container.read(businessDraftProvider).representantNom, 'Aïcha Oumarou');
    });

    testWidgets('la carte de détails ouvre l\'étape du type (secteur / catégorie / établissement)',
        (tester) async {
      final expected = {
        BusinessAccountType.boutique: "Quel est votre secteur d'activité ?",
        BusinessAccountType.entreprise: "Quel est votre secteur d'activité ?",
        BusinessAccountType.particulierVendeur: "Quel est votre secteur d'activité ?",
        BusinessAccountType.prestataireService: 'Quel type de service proposez-vous ?',
        BusinessAccountType.structure: "Quel type d'établissement gérez-vous ?",
      };
      for (final entry in expected.entries) {
        final container = await openRecap(tester, await completeDraft(entry.key));
        await tester.ensureVisible(find.byKey(const ValueKey('recap-edit-details')));
        await tester.tap(find.byKey(const ValueKey('recap-edit-details')));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget, reason: entry.key.value);
        // Les choix déjà faits sont gardés dans le brouillon.
        expect(container.read(businessDraftProvider).name, 'Boutique Mama Aïcha');
        await tester.tap(find.byKey(const ValueKey('business-back')));
        await tester.pumpAndSettle();
        expect(_submit, findsOneWidget, reason: entry.key.value);
      }
    });
  });

  group('garde', () {
    testWidgets('brouillon vide (écran ouvert à la main) : renvoi aux Informations', (tester) async {
      await openRecap(tester, const BusinessDraft());
      expect(_submit, findsNothing);
      expect(find.text('Informations de base'), findsOneWidget);
    });

    testWidgets('brouillon incomplet (détails manquants) : renvoi à l\'étape à compléter',
        (tester) async {
      final base = await completeDraft(BusinessAccountType.prestataireService);
      await openRecap(tester, base.copyWith(cniPhotoPath: null));
      expect(_submit, findsNothing);
      expect(find.text('Quel type de service proposez-vous ?'), findsOneWidget);
    });
  });

  group('affichage', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final scale in [1.0, 1.3]) {
        for (final type in BusinessAccountType.values) {
          testWidgets('${type.value}, 360 px, police ${(scale * 100).round()} %, $mode',
              (tester) async {
            await openRecap(tester, await completeDraft(type), textScale: scale, mode: mode);

            expect(tester.takeException(), isNull);
            expect(_submit, findsOneWidget);
            // Aucun défilement horizontal (hors champs de texte).
            expect(
                find.byType(Scrollable).evaluate().where((e) =>
                    (e.widget as Scrollable).axis == Axis.horizontal),
                isEmpty);
            // Tout tient dans 360 px de large.
            for (final f in [_name, find.byKey(const ValueKey('recap-details'))]) {
              final r = tester.getRect(f);
              expect(r.left, greaterThanOrEqualTo(0));
              expect(r.right, lessThanOrEqualTo(360));
            }
            // Cibles tactiles d'au moins 48 dp.
            final targets = [
              find.ancestor(of: _submit, matching: find.byType(FilledButton)).first,
              find.byKey(const ValueKey('recap-zone')),
              find.byKey(const ValueKey('recap-edit-identity')),
              find.byKey(const ValueKey('recap-edit-details')),
            ];
            for (final f in targets) {
              await tester.ensureVisible(f);
              await tester.pumpAndSettle();
              final size = tester.getSize(f);
              expect(size.height, greaterThanOrEqualTo(48), reason: '$f');
              expect(size.width, greaterThanOrEqualTo(48), reason: '$f');
            }
          });
        }
      }
    }
  });

  group('lecteur d\'écran', () {
    testWidgets('lignes lues « Nom : valeur, modifier » et miniatures décrites', (tester) async {
      final handle = tester.ensureSemantics();
      await openRecap(tester, await completeDraft(BusinessAccountType.prestataireService));

      expect(find.bySemanticsLabel('Zone : Maroua, Hardé, modifier'), findsOneWidget);
      expect(find.bySemanticsLabel('Téléphone : +237 6•• •• •• 12 ✓'), findsOneWidget);
      expect(find.bySemanticsLabel('Modifier : CATÉGORIE DE SERVICE'), findsOneWidget);
      expect(find.bySemanticsLabel('Modifier : Boutique Mama Aïcha'), findsOneWidget);
      expect(find.bySemanticsLabel("Carte d'identité (CNI) : ✓ fournie"), findsOneWidget);
      expect(find.bySemanticsLabel('Photo de votre activité'), findsOneWidget);
      expect(find.bySemanticsLabel('Votre photo (vérification)'), findsOneWidget);
      handle.dispose();
    });
  });

  test('fichier de la CNI jamais lu par le récapitulatif (aucune API de fichier sur ce chemin)', () {
    // Le récapitulatif n'ouvre que les photos du commerce, du représentant et du diplôme.
    final source = File('lib/features/business/presentation/screens/recap_screen.dart')
        .readAsStringSync();
    expect(source, isNot(contains('cniPhotoPath!')));
    expect(RegExp(r'cniPhotoPath').allMatches(source), isEmpty);
  });
}
