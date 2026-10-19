import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:netbuis/core/data/referentials/referential_models.dart';
import 'package:netbuis/core/data/referentials/referential_repository_fake.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/business/application/business_draft_controller.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';
import 'package:netbuis/features/business/data/photo_service.dart';

import 'business_test_helpers.dart';

/// Dépôt de référentiels qui échoue (ou reste en attente) puis répond comme le faux dépôt.
class _ScriptedReferentials extends ReferentialRepositoryFake {
  _ScriptedReferentials({this.failures = 0, this.empty = false, this.gate, this.error});

  int failures;
  final bool empty;
  final Completer<void>? gate;
  final ApiException? error;
  int calls = 0;

  @override
  Future<List<ReferentialItem>> getServiceCategories() async {
    calls++;
    if (gate != null) await gate!.future;
    if (failures > 0) {
      failures--;
      throw error ?? const ApiException(ApiErrorCode.network);
    }
    if (empty) return const [];
    return super.getServiceCategories();
  }
}

class _OneCategory extends ReferentialRepositoryFake {
  const _OneCategory(this.item);

  final ReferentialItem item;

  @override
  Future<List<ReferentialItem>> getServiceCategories() async => [item];
}

const _names = [
  'Enseignement à domicile',
  'Technique & Réparation',
  'Services médicaux indépendants',
  'Beauté & Bien-être à domicile',
  'Juridique & Comptabilité',
  'Événementiel',
  'Autre',
];

const _cniHelp =
    "Vérifiée par l'équipe NetBuis avant publication. Elle n'est jamais affichée publiquement en entier — seul un badge « ✓ Identité vérifiée » apparaît sur votre profil.";

Finder _cat(String code) => find.byKey(ValueKey('business-service-$code'));
Finder get _libre => find.byKey(const ValueKey('business-service-libre'));
Finder get _cni => find.byKey(const ValueKey('business-cni'));
Finder get _diploma => find.byKey(const ValueKey('business-diploma'));
Finder get _soon => find.text('Cette étape arrive bientôt');

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

Future<void> _show(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await _show(tester, f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _openService(
  WidgetTester tester, {
  BusinessAccountType type = BusinessAccountType.prestataireService,
  FakePhotoPicker? photos,
  List<Override> overrides = const [],
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.dark,
  bool settle = true,
}) async {
  // On part de l'écran Informations (le brouillon y vit), on fixe le type de compte, puis on
  // ouvre l'étape : sans le bon type, l'écran renvoie aussitôt à Informations.
  await pumpBusinessApp(
    tester,
    photos: photos,
    overrides: overrides,
    textScale: textScale,
    mode: mode,
    settle: settle,
  );
  _container(tester).read(businessDraftProvider.notifier).setType(type);
  GoRouter.of(tester.element(find.byType(Scaffold).first))
      .push(Routes.createBusinessServiceCategory);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Prend la photo (appareil photo) dans la zone [field].
Future<void> _addPhoto(WidgetTester tester, Finder field, FakePhotoPicker photos, String path,
    {String source = 'photo-camera'}) async {
  photos.result = path;
  await _tap(tester, field);
  await tester.tap(find.byKey(ValueKey(source)));
  await tester.pumpAndSettle();
}

void main() {
  group('grille des catégories', () {
    testWidgets('7 catégories venues du dépôt, avec les icônes et textes de la maquette',
        (tester) async {
      await _openService(tester);

      expect(find.text('Étape 2 sur 3'), findsOneWidget);
      expect(find.text('Catégorie & vérification'), findsOneWidget);
      expect(find.text('Quel type de service proposez-vous ?'), findsOneWidget);
      expect(
          find.text(
              "Contrairement à une boutique, un prestataire choisit une catégorie de service plutôt qu'un secteur de produits."),
          findsOneWidget);
      for (final name in _names) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      for (final emoji in ['🎓', '🔧', '🩺', '💅', '⚖️', '🎉', '✨']) {
        expect(find.text(emoji), findsWidgets, reason: emoji);
      }
      // Deux colonnes, comme la maquette.
      final y1 = tester.getTopLeft(_cat('enseignement_domicile')).dy;
      final y2 = tester.getTopLeft(_cat('technique_reparation')).dy;
      expect(y1, y2);
      for (final name in _names) {
        final size =
            tester.getSize(find.ancestor(of: find.text(name), matching: find.byType(InkWell)));
        expect(size.height, greaterThanOrEqualTo(48), reason: name);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('chargement puis erreur réseau avec « Réessayer »', (tester) async {
      final repo = _ScriptedReferentials(failures: 1);
      await _openService(tester,
          overrides: [referentialRepositoryProvider.overrideWithValue(repo)]);

      expect(find.byKey(const ValueKey('business-service-error')), findsOneWidget);
      expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsOneWidget);
      expect(_cat('evenementiel'), findsNothing);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('business-service-error')), findsNothing);
      expect(find.text('Événementiel'), findsOneWidget);
      expect(repo.calls, 2);
    });

    testWidgets('état de chargement visible tant que le dépôt n\'a pas répondu', (tester) async {
      final gate = Completer<void>();
      final repo = _ScriptedReferentials(gate: gate);
      await _openService(tester,
          overrides: [referentialRepositoryProvider.overrideWithValue(repo)], settle: false);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('business-service-loading')), findsOneWidget);
      expect(find.text('Chargement des catégories...'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('business-service-loading')), findsNothing);
      expect(find.text('Autre'), findsOneWidget);
    });

    testWidgets('erreur inconnue : message simple ; liste vide : message et « Réessayer »',
        (tester) async {
      await _openService(tester, overrides: [
        referentialRepositoryProvider.overrideWithValue(
            _ScriptedReferentials(failures: 1, error: const ApiException(ApiErrorCode.unknown))),
      ]);
      expect(find.text('Une erreur est survenue. Réessayez.'), findsOneWidget);

      await _openService(tester, overrides: [
        referentialRepositoryProvider.overrideWithValue(_ScriptedReferentials(empty: true)),
      ]);
      expect(find.byKey(const ValueKey('business-service-empty')), findsOneWidget);
      expect(find.text('Aucune catégorie de service disponible pour le moment.'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('une seule catégorie choisie à la fois, gardée dans le brouillon', (tester) async {
      await _openService(tester);
      await _tap(tester, _cat('enseignement_domicile'));
      expect(currentDraft(tester).categorieServiceId, 1);
      expect(currentDraft(tester).categorieService?.name, 'Enseignement à domicile');
      expect(find.bySemanticsLabel('Enseignement à domicile, choisi'), findsOneWidget);

      await _tap(tester, _cat('evenementiel'));
      expect(currentDraft(tester).categorieServiceId, 6);
      expect(find.bySemanticsLabel('Événementiel, choisi'), findsOneWidget);
      expect(find.bySemanticsLabel('Enseignement à domicile, choisi'), findsNothing);
      expect(find.bySemanticsLabel('Enseignement à domicile'), findsOneWidget);
    });

    testWidgets('code inconnu : icône par défaut, sans erreur', (tester) async {
      const odd =
          ReferentialItem(id: 99, code: 'inconnu', name: 'Nouveau métier', icon: '', order: 99);
      await _openService(tester, overrides: [
        referentialRepositoryProvider.overrideWithValue(_OneCategory(odd)),
      ]);
      expect(find.text('Nouveau métier'), findsOneWidget);
      expect(find.byIcon(Icons.handyman_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('catégorie « Autre »', () {
    testWidgets('note de la maquette et champ libre, seulement pour « Autre »', (tester) async {
      await _openService(tester);
      expect(_libre, findsNothing);
      expect(find.byKey(const ValueKey('business-service-other-note')), findsNothing);

      await _tap(tester, _cat('autre'));
      expect(_libre, findsOneWidget);
      expect(
          find.textContaining(
              'Votre service n\'est dans aucune des cases ci-dessus ? Décrivez-le librement :',
              findRichText: true),
          findsOneWidget);
      expect(
          find.textContaining('« Mototaxi », « Couture à domicile », « Traduction »...',
              findRichText: true),
          findsOneWidget);
      expect(find.text('Ex. Transport de personnes à moto (mototaxi)'), findsOneWidget);
    });

    testWidgets('texte libre obligatoire : sans texte, « Continuer » est refusé', (tester) async {
      final photos = FakePhotoPicker();
      await _openService(tester, photos: photos);
      await _tap(tester, _cat('autre'));
      await _addPhoto(tester, _cni, photos, '/fictif/cni.jpg');

      await _tap(tester, continueButton);
      expect(find.text('Précisez votre service.'), findsOneWidget);
      expect(_soon, findsNothing);

      await tester.enterText(_libre, '   ');
      await _tap(tester, continueButton);
      expect(find.text('Précisez votre service.'), findsOneWidget);
      expect(_soon, findsNothing);

      await tester.enterText(_libre, 'Mototaxi');
      await _tap(tester, continueButton);
      expect(find.text('Précisez votre service.'), findsNothing);
      expect(_soon, findsOneWidget);
      expect(currentDraft(tester).categorieServiceLibre, 'Mototaxi');
    });

    testWidgets('longueur maximale du serveur : 100 caractères', (tester) async {
      await _openService(tester);
      await _tap(tester, _cat('autre'));
      await tester.enterText(_libre, 'a' * 130);
      await tester.pump();
      expect(currentDraft(tester).categorieServiceLibre.length, kBusinessCategorieServiceLibreMax);
      expect(kBusinessCategorieServiceLibreMax, 100);
      expect(
          FieldError.tooLong,
          BusinessDraft(
            categorieService:
                const ReferentialItem(id: 7, code: 'autre', name: 'Autre', icon: '', order: 7),
            categorieServiceId: 7,
            categorieServiceLibre: 'a' * 101,
          ).categorieServiceLibreError);
    });

    testWidgets('changer de catégorie vide le texte libre devenu sans objet', (tester) async {
      await _openService(tester);
      await _tap(tester, _cat('autre'));
      await tester.enterText(_libre, 'Couture à domicile');
      await tester.pump();
      expect(currentDraft(tester).categorieServiceLibre, 'Couture à domicile');

      await _tap(tester, _cat('evenementiel'));
      expect(_libre, findsNothing);
      expect(currentDraft(tester).categorieServiceLibre, '');

      await _tap(tester, _cat('autre'));
      expect(tester.widget<TextField>(_libre).controller!.text, '');
    });
  });

  group('CNI et diplôme', () {
    testWidgets('textes de la maquette et mention de confidentialité', (tester) async {
      await _openService(tester);
      await _show(tester, _diploma);

      expect(find.text("Vérification d'identité"), findsOneWidget);
      expect(
          find.text(
              "Ces éléments mettent les utilisateurs en confiance avant qu'ils ne vous appellent."),
          findsOneWidget);
      expect(find.textContaining("Carte Nationale d'Identité (CNI)", findRichText: true),
          findsOneWidget);
      expect(find.textContaining('· obligatoire', findRichText: true), findsOneWidget);
      expect(find.text('Ajouter une photo de ma CNI'), findsOneWidget);
      expect(find.text(_cniHelp), findsOneWidget);
      expect(find.textContaining('Diplôme / Certificat', findRichText: true), findsOneWidget);
      expect(find.textContaining('(optionnel)', findRichText: true), findsOneWidget);
      expect(find.text('Ajouter un diplôme ou une attestation'), findsOneWidget);
      expect(
          find.text(
              "Facultatif — s'il est ajouté, il peut être affiché sur votre profil public pour renforcer la confiance."),
          findsOneWidget);
      // Pas de numéro de CNI demandé : seulement le champ de texte libre « Autre ».
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('CNI obligatoire : erreur simple sans photo, jamais d\'envoi', (tester) async {
      await _openService(tester);
      await _tap(tester, _cat('evenementiel'));

      await _tap(tester, continueButton);
      expect(find.text('Ajoutez la photo de votre CNI.'), findsOneWidget);
      expect(_soon, findsNothing);
      expect(find.text('Étape 2 sur 3'), findsOneWidget);
    });

    testWidgets('CNI prise ou choisie : acceptée, chemin gardé en mémoire dans le brouillon',
        (tester) async {
      final photos = FakePhotoPicker();
      await _openService(tester, photos: photos);
      await _tap(tester, _cat('evenementiel'));
      await _addPhoto(tester, _cni, photos, '/fictif/cni.jpg');

      expect(photos.asked, [PhotoSource.camera]);
      expect(currentDraft(tester).cniPhotoPath, '/fictif/cni.jpg');
      expect(find.bySemanticsLabel(RegExp('Photo de la CNI ajoutée')), findsOneWidget);
      expect(find.text('Photo ajoutée'), findsOneWidget);

      // Choisie dans la galerie : remplace.
      await _addPhoto(tester, _cni, photos, '/fictif/cni2.jpg', source: 'photo-gallery');
      expect(photos.asked.last, PhotoSource.gallery);
      expect(currentDraft(tester).cniPhotoPath, '/fictif/cni2.jpg');

      await _tap(tester, continueButton);
      expect(find.text('Ajoutez la photo de votre CNI.'), findsNothing);
      expect(_soon, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('appareil photo inaccessible : message, pas de CNI', (tester) async {
      final photos = FakePhotoPicker()..fail = true;
      await _openService(tester, photos: photos);
      await _tap(tester, _cni);
      await tester.tap(find.byKey(const ValueKey('photo-camera')));
      await tester.pumpAndSettle();

      expect(find.text('Photo impossible. Réessayez.'), findsOneWidget);
      expect(currentDraft(tester).cniPhotoPath, isNull);
    });

    testWidgets('catégorie manquante : message, rien n\'avance', (tester) async {
      final photos = FakePhotoPicker();
      await _openService(tester, photos: photos);
      await _addPhoto(tester, _cni, photos, '/fictif/cni.jpg');

      await _tap(tester, continueButton);
      expect(find.text('Choisissez une catégorie de service.'), findsOneWidget);
      expect(_soon, findsNothing);
    });

    testWidgets('diplôme facultatif : sans, avec, puis retrait', (tester) async {
      final photos = FakePhotoPicker();
      await _openService(tester, photos: photos);
      await _tap(tester, _cat('technique_reparation'));
      await _addPhoto(tester, _cni, photos, '/fictif/cni.jpg');

      // Sans diplôme : accepté.
      await _tap(tester, continueButton);
      expect(_soon, findsOneWidget);
      expect(currentDraft(tester).diplomePhotoPath, isNull);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Avec diplôme.
      await _addPhoto(tester, _diploma, photos, '/fictif/diplome.jpg');
      expect(currentDraft(tester).diplomePhotoPath, '/fictif/diplome.jpg');
      expect(find.bySemanticsLabel(RegExp('Photo du diplôme ajoutée')), findsOneWidget);
      expect(find.byKey(const ValueKey('business-diploma-remove')), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('business-diploma-remove'))).height,
          greaterThanOrEqualTo(48));

      // Retrait : la CNI reste.
      await _tap(tester, find.byKey(const ValueKey('business-diploma-remove')));
      expect(currentDraft(tester).diplomePhotoPath, isNull);
      expect(currentDraft(tester).cniPhotoPath, '/fictif/cni.jpg');
      expect(find.byKey(const ValueKey('business-diploma-remove')), findsNothing);
      expect(find.text('Ajouter un diplôme ou une attestation'), findsOneWidget);
    });

    testWidgets('aucune clé, aucun chemin dans les journaux', (tester) async {
      final logs = <String>[];
      final old = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => logs.add(m ?? '');
      final photos = FakePhotoPicker();
      try {
        await runZoned(() async {
          await _openService(tester, photos: photos);
          await _tap(tester, _cat('evenementiel'));
          await _addPhoto(tester, _cni, photos, '/fictif/secret-cni.jpg');
          await _addPhoto(tester, _diploma, photos, '/fictif/secret-diplome.jpg');
          await _tap(tester, continueButton);
        },
            zoneSpecification:
                ZoneSpecification(print: (self, parent, zone, line) => logs.add(line)));
      } finally {
        debugPrint = old;
      }

      expect(logs.where((l) => l.contains('secret-') || l.contains('/fictif/')), isEmpty);
    });
  });

  group('parcours', () {
    testWidgets('inaccessible pour les 4 autres types : renvoie à Informations', (tester) async {
      for (final type in [
        BusinessAccountType.boutique,
        BusinessAccountType.entreprise,
        BusinessAccountType.particulierVendeur,
        BusinessAccountType.structure,
      ]) {
        await _openService(tester, type: type);
        expect(_cat('autre'), findsNothing, reason: type.value);
        expect(find.text('Informations de base'), findsOneWidget, reason: type.value);
      }
    });

    testWidgets('Informations -> Catégorie : Étape 2 sur 3 ; retour arrière garde tout',
        (tester) async {
      final photos = FakePhotoPicker();
      await pumpBusinessApp(tester, photos: photos);
      await _tap(tester, typeButton('prestataire_service'));
      await tester.enterText(find.byKey(const ValueKey('business-name')), 'Chez Moussa');
      await tester.enterText(find.byKey(const ValueKey('business-owner')), 'Moussa B.');
      await _addPhoto(
          tester, find.byKey(const ValueKey('business-owner-photo')), photos, '/fictif/moi.jpg');
      await _tap(tester, continueButton);
      expect(find.text('Étape 2 sur 3'), findsOneWidget);
      expect(find.text('Quel type de service proposez-vous ?'), findsOneWidget);
      expect(_soon, findsNothing);

      await _tap(tester, _cat('autre'));
      await tester.enterText(_libre, 'Traduction');
      await _addPhoto(tester, _cni, photos, '/fictif/cni.jpg');
      await _addPhoto(tester, _diploma, photos, '/fictif/diplome.jpg');

      await tester.tap(find.byKey(const ValueKey('business-back')));
      await tester.pumpAndSettle();
      expect(find.text('Étape 1 sur 3'), findsOneWidget);
      expect(currentDraft(tester).name, 'Chez Moussa');

      await _tap(tester, continueButton);
      expect(find.text('Étape 2 sur 3'), findsOneWidget);
      expect(tester.widget<TextField>(_libre).controller!.text, 'Traduction');
      expect(find.bySemanticsLabel('Autre, choisi'), findsOneWidget);
      final d = currentDraft(tester);
      expect(d.cniPhotoPath, '/fictif/cni.jpg');
      expect(d.diplomePhotoPath, '/fictif/diplome.jpg');
      expect(d.categorieServiceId, 7);

      // Tout est valide : le lieu et le récapitulatif n'existent pas encore (T034, T035).
      await _tap(tester, continueButton);
      expect(_soon, findsOneWidget);
    });

    testWidgets('changer de type de compte efface catégorie, CNI et diplôme', (tester) async {
      final photos = FakePhotoPicker();
      await _openService(tester, photos: photos);
      await _tap(tester, _cat('autre'));
      await _addPhoto(tester, _cni, photos, '/fictif/cni.jpg');
      _container(tester).read(businessDraftProvider.notifier).setType(BusinessAccountType.boutique);
      final d = currentDraft(tester);
      expect(d.categorieServiceId, isNull);
      expect(d.categorieService, isNull);
      expect(d.cniPhotoPath, isNull);
    });
  });

  group('affichage', () {
    for (final mode in ThemeMode.values.where((m) => m != ThemeMode.system)) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('360 px, police ${(scale * 100).round()} %, $mode : sans défilement horizontal',
            (tester) async {
          final photos = FakePhotoPicker();
          await _openService(tester, photos: photos, textScale: scale, mode: mode);
          await _tap(tester, _cat('autre'));
          await _addPhoto(tester, _cni, photos, '/fictif/cni.jpg');
          await _addPhoto(tester, _diploma, photos, '/fictif/diplome.jpg');
          await tester.enterText(_libre, 'a' * 100);
          await _tap(tester, continueButton);

          expect(tester.takeException(), isNull);
          expect(
              // Le champ de texte a son propre défilement interne : on compte ceux de la page.
              find.byType(Scrollable).evaluate().where((e) {
                final inField = find
                    .ancestor(of: find.byWidget(e.widget), matching: find.byType(EditableText))
                    .evaluate()
                    .isNotEmpty;
                return !inField && (e.widget as Scrollable).axis == Axis.horizontal;
              }),
              isEmpty);
          for (final name in _names) {
            final f = find.text(name);
            expect(tester.getTopRight(f).dx, lessThanOrEqualTo(360), reason: name);
          }
        });
      }
    }
  });
}
