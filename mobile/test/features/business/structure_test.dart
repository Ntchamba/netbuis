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
import 'package:netbuis/features/business/application/business_creation_flow.dart';
import 'package:netbuis/features/business/application/business_draft_controller.dart';
import 'package:netbuis/features/business/application/business_services.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';

import 'business_test_helpers.dart';

/// Dépôt de référentiels dont les types de structure échouent (ou restent en attente).
class _ScriptedTypes extends ReferentialRepositoryFake {
  _ScriptedTypes({this.failures = 0, this.empty = false, this.gate, this.error});

  int failures;
  final bool empty;
  final Completer<void>? gate;
  final ApiException? error;
  int calls = 0;

  @override
  Future<List<ReferentialItem>> getStructureTypes() async {
    calls++;
    if (gate != null) await gate!.future;
    if (failures > 0) {
      failures--;
      throw error ?? const ApiException(ApiErrorCode.network);
    }
    if (empty) return const [];
    return super.getStructureTypes();
  }
}

const _codes = ['supermarche', 'restaurant', 'hotel', 'sante', 'autre'];
const _names = ['Supermarché', 'Restaurant', 'Hôtel', 'Centre de santé', 'Autre'];

Finder _type(String code) => find.byKey(ValueKey('business-structure-type-$code'));
Finder _opt(String group, String code) =>
    find.byKey(ValueKey('business-structure-opt-$group-$code'));
Finder _field(String name) => find.byKey(ValueKey('business-structure-$name'));
Finder get _upsell => find.byKey(const ValueKey('business-upsell'));
Finder get _soon => find.text('Cette étape arrive bientôt');
// Le récapitulatif (T035) ferme désormais le parcours.
Finder get _recap => find.text('Publier ma demande');
Finder get _counter => find.byKey(const ValueKey('business-subcategory-counter'));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Revient de l'écran suivant (récapitulatif) à l'étape testée.
Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('business-back')));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, Finder f, String text) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.enterText(f, text);
  await tester.pump();
}

Future<ReferentialItem> _item(String code) async {
  final all = await const ReferentialRepositoryFake().getStructureTypes();
  return all.firstWhere((t) => t.code == code);
}

Future<void> _go(WidgetTester tester, String path, {bool settle = true}) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(path);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Ouvre l'étape « Type d'établissement » avec le type de compte [type].
Future<void> _openType(
  WidgetTester tester, {
  BusinessAccountType type = BusinessAccountType.structure,
  List<Override> overrides = const [],
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.dark,
  bool settle = true,
}) async {
  await pumpBusinessApp(tester, overrides: overrides, textScale: textScale, mode: mode);
  _container(tester).read(businessDraftProvider.notifier).setType(type);
  await _go(tester, Routes.createBusinessStructureType, settle: settle);
}

/// Ouvre l'étape « Détails » du type d'établissement [code] (null = aucun choisi).
Future<void> _openDetails(
  WidgetTester tester,
  String? code, {
  BusinessAccountType type = BusinessAccountType.structure,
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.dark,
  List<Override> overrides = const [],
  bool viaType = false,
}) async {
  await pumpBusinessApp(tester, textScale: textScale, mode: mode, overrides: overrides);
  final notifier = _container(tester).read(businessDraftProvider.notifier)..setType(type);
  // Champs communs remplis : à la fin de l'étape, le récapitulatif peut s'ouvrir.
  fillCommonDraft(tester);
  if (code != null) notifier.setStructureType(await _item(code));
  // `viaType` : la pile contient l'étape Type sous les Détails (le retour y mène).
  if (viaType) await _go(tester, Routes.createBusinessStructureType);
  await _go(tester, Routes.createBusinessStructureDetails);
}

void main() {
  group('grille des types', () {
    testWidgets('5 types venus du dépôt, textes et icônes de la maquette, Étape 2 sur 4',
        (tester) async {
      await _openType(tester);

      expect(find.text('Étape 2 sur 4'), findsOneWidget);
      expect(find.text("Type d'établissement"), findsOneWidget);
      expect(find.text("Quel type d'établissement gérez-vous ?"), findsOneWidget);
      expect(
          find.text(
              "Un supermarché, un restaurant, un hôtel ou un centre de santé n'ont pas les mêmes informations à préciser qu'un commerce classique — chacun a sa propre suite d'écrans."),
          findsOneWidget);
      for (final n in _names) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      for (final e in ['🛒', '🍲', '🏨', '🏥', '✨']) {
        expect(find.text(e), findsWidgets, reason: e);
      }
      // Deux colonnes, comme la maquette.
      expect(tester.getTopLeft(_type('supermarche')).dy, tester.getTopLeft(_type('restaurant')).dy);
      expect(tester.getTopLeft(_type('hotel')).dy, tester.getTopLeft(_type('sante')).dy);
      expect(tester.getTopLeft(_type('hotel')).dy, greaterThan(tester.getTopLeft(_type('supermarche')).dy));
      for (final code in _codes) {
        expect(tester.getSize(_type(code)).height, greaterThanOrEqualTo(48), reason: code);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('encart commercial / social toujours présent, encart « Autre » seulement si choisi',
        (tester) async {
      await _openType(tester);
      const nuance =
          'Un restaurant ou un hôtel reste une structure à vocation commerciale ; un centre de santé a une vocation davantage sociale. NetBuis adapte les informations demandées en conséquence, plutôt que de tout réduire à un simple "secteur".';
      const autre =
          "Votre établissement n'est pas un supermarché, un restaurant, un hôtel ou un centre de santé ? À l'étape suivante, décrivez-le librement.";
      await tester.ensureVisible(find.byKey(const ValueKey('business-structure-nuance')));
      expect(find.text(nuance), findsOneWidget);
      expect(find.text('ℹ️'), findsOneWidget);
      expect(find.text(autre), findsNothing);

      await _tap(tester, _type('restaurant'));
      expect(find.text(autre), findsNothing);
      expect(find.text(nuance), findsOneWidget);

      await _tap(tester, _type('autre'));
      expect(find.text(autre), findsOneWidget);
      expect(find.text('✨'), findsWidgets);
      expect(find.text(nuance), findsOneWidget);

      await _tap(tester, _type('hotel'));
      expect(find.text(autre), findsNothing);
    });

    testWidgets('chargement, erreur réseau avec « Réessayer », erreur inconnue, liste vide',
        (tester) async {
      final gate = Completer<void>();
      final slow = _ScriptedTypes(gate: gate);
      await _openType(tester,
          overrides: [referentialRepositoryProvider.overrideWithValue(slow)], settle: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('business-structure-types-loading')), findsOneWidget);
      expect(find.text("Chargement des types d'établissement..."), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('business-structure-types-loading')), findsNothing);
      expect(_type('autre'), findsOneWidget);

      final repo = _ScriptedTypes(failures: 1);
      await _openType(tester, overrides: [referentialRepositoryProvider.overrideWithValue(repo)]);
      expect(find.byKey(const ValueKey('business-structure-types-error')), findsOneWidget);
      expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsOneWidget);
      expect(_type('hotel'), findsNothing);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('business-structure-types-error')), findsNothing);
      expect(_type('hotel'), findsOneWidget);
      expect(repo.calls, 2);

      await _openType(tester, overrides: [
        referentialRepositoryProvider.overrideWithValue(
            _ScriptedTypes(failures: 1, error: const ApiException(ApiErrorCode.unknown))),
      ]);
      expect(find.text('Une erreur est survenue. Réessayez.'), findsOneWidget);

      await _openType(tester, overrides: [
        referentialRepositoryProvider.overrideWithValue(_ScriptedTypes(empty: true)),
      ]);
      expect(find.byKey(const ValueKey('business-structure-types-empty')), findsOneWidget);
      expect(find.text("Aucun type d'établissement disponible pour le moment."), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('le choix est dans le brouillon, lu à voix haute « choisi », exclusif',
        (tester) async {
      await _openType(tester);
      expect(currentDraft(tester).structureTypeId, isNull);

      await _tap(tester, _type('restaurant'));
      expect(currentDraft(tester).structureTypeId, 2);
      expect(currentDraft(tester).structureCode, 'restaurant');
      expect(find.bySemanticsLabel('Restaurant, choisi'), findsOneWidget);
      expect(find.bySemanticsLabel('Hôtel'), findsOneWidget);

      await _tap(tester, _type('hotel'));
      expect(currentDraft(tester).structureTypeId, 3);
      expect(find.bySemanticsLabel('Restaurant, choisi'), findsNothing);
      expect(find.bySemanticsLabel('Hôtel, choisi'), findsOneWidget);
    });

    testWidgets('sans choix : « Continuer » reste sur l\'écran avec un message', (tester) async {
      await _openType(tester);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('business-structure-type-error')), findsOneWidget);
      expect(find.text("Choisissez un type d'établissement."), findsOneWidget);
      expect(find.text('Étape 2 sur 4'), findsOneWidget);

      await _tap(tester, _type('sante'));
      expect(find.byKey(const ValueKey('business-structure-type-error')), findsNothing);
    });

    testWidgets('Informations -> Type -> Détails ; retour arrière garde le choix', (tester) async {
      await pumpBusinessApp(tester);
      await _tap(tester, typeButton('structure'));
      await tester.enterText(find.byKey(const ValueKey('business-name')), 'Chez Moussa');
      await tester.enterText(find.byKey(const ValueKey('business-owner')), 'Moussa B.');
      await _tap(tester, find.byKey(const ValueKey('business-owner-photo')));
      await tester.tap(find.byKey(const ValueKey('photo-camera')));
      await tester.pumpAndSettle();
      await _tap(tester, continueButton);
      expect(find.text("Quel type d'établissement gérez-vous ?"), findsOneWidget);
      expect(find.text('Étape 2 sur 4'), findsOneWidget);
      expect(_soon, findsNothing);
      expect(_recap, findsNothing);

      await _tap(tester, _type('sante'));
      await _tap(tester, continueButton);
      expect(find.text('Étape 3 sur 4'), findsOneWidget);
      expect(find.text("Détails de l'établissement"), findsOneWidget);
      expect(find.text('Quelles spécialités médicales proposez-vous ?'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('business-back')));
      await tester.pumpAndSettle();
      expect(find.text('Étape 2 sur 4'), findsOneWidget);
      expect(find.bySemanticsLabel('Centre de santé, choisi'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('business-back')));
      await tester.pumpAndSettle();
      expect(find.text('Étape 1 sur 4'), findsOneWidget);
      expect(currentDraft(tester).structureCode, 'sante');
    });
  });

  group('accès', () {
    testWidgets('Type et Détails sont inaccessibles aux 4 autres types : renvoi à Informations',
        (tester) async {
      for (final type in [
        BusinessAccountType.boutique,
        BusinessAccountType.entreprise,
        BusinessAccountType.particulierVendeur,
        BusinessAccountType.prestataireService,
      ]) {
        await _openType(tester, type: type);
        expect(_type('autre'), findsNothing, reason: type.value);
        expect(find.text('Informations de base'), findsOneWidget, reason: type.value);

        await _openDetails(tester, 'restaurant', type: type);
        expect(find.text("Détails de l'établissement"), findsNothing, reason: type.value);
        expect(find.text('Informations de base'), findsOneWidget, reason: type.value);
      }
    });

    testWidgets('Détails sans type choisi : renvoi à l\'étape Type', (tester) async {
      await _openDetails(tester, null);
      expect(find.text("Type d'établissement"), findsOneWidget);
      expect(find.text("Quel type d'établissement gérez-vous ?"), findsOneWidget);
      expect(find.text("Détails de l'établissement"), findsNothing);
    });

    test('les étapes sont construites ; le total vaut 4 pour la Structure', () {
      expect(BusinessStep.structureType.built, isTrue);
      expect(BusinessStep.structureDetails.built, isTrue);
      expect(BusinessCreationFlow.total(BusinessAccountType.structure), 4);
      expect(BusinessCreationFlow.position(BusinessAccountType.structure, BusinessStep.structureType),
          2);
      expect(
          BusinessCreationFlow.position(BusinessAccountType.structure, BusinessStep.structureDetails),
          3);
      expect(BusinessCreationFlow.nextRoute(BusinessAccountType.structure, BusinessStep.info),
          Routes.createBusinessStructureType);
      expect(
          BusinessCreationFlow.nextRoute(BusinessAccountType.structure, BusinessStep.structureType),
          Routes.createBusinessStructureDetails);
      // Le récapitulatif (T035) ferme le parcours Structure.
      expect(
          BusinessCreationFlow.nextRoute(
              BusinessAccountType.structure, BusinessStep.structureDetails),
          Routes.createBusinessRecap);
      expect(
          BusinessCreationFlow.nextRoute(BusinessAccountType.structure, BusinessStep.recap),
          isNull);
    });
  });

  group('supermarché', () {
    testWidgets('rayons de la maquette, compteur, exemple de description, codes enregistrés',
        (tester) async {
      await _openDetails(tester, 'supermarche');

      expect(find.text('Étape 3 sur 4'), findsOneWidget);
      expect(find.text('Quels rayons proposez-vous ?'), findsOneWidget);
      expect(find.text("Sélectionnez ce qui s'applique — vous pourrez préciser davantage plus tard."),
          findsOneWidget);
      for (final n in [
        'Alimentation générale',
        'Produits frais',
        'Boissons',
        'Hygiène & Beauté',
        'Entretien & Maison',
        'Bazar & Électroménager',
        'Produits pour bébés',
        'Autre',
      ]) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      expect(find.text('0/3 inclus sans abonnement'), findsOneWidget);
      expect(find.text('Description libre de l\'établissement'), findsOneWidget);
      expect(tester.widget<TextField>(_field('description')).decoration!.hintText,
          'Ex. Grande surface au centre-ville, parking disponible, ouvert 7j/7.');
      // Aucun champ des autres types.
      expect(_field('horaires'), findsNothing);
      expect(_field('chambres'), findsNothing);
      expect(_field('agrement'), findsNothing);
      expect(_field('libre'), findsNothing);

      await _tap(tester, _opt('aisle', 'produits_frais'));
      await _tap(tester, _opt('aisle', 'boissons'));
      expect(currentDraft(tester).rayons, ['produits_frais', 'boissons']);
      expect(find.text('2/3 inclus sans abonnement'), findsOneWidget);
      expect(find.bySemanticsLabel('2 sur 3 inclus sans abonnement'), findsOneWidget);
      expect(find.bySemanticsLabel('Boissons, choisi'), findsOneWidget);

      await _enter(tester, _field('description'), 'Grande surface');
      expect(currentDraft(tester).description, 'Grande surface');

      await _tap(tester, continueButton);
      expect(_recap, findsOneWidget);
      expect(_soon, findsNothing);
    });

    testWidgets('au moins un rayon est obligatoire', (tester) async {
      await _openDetails(tester, 'supermarche');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('business-structure-error-aisle')), findsOneWidget);
      expect(find.text('Choisissez au moins un rayon.'), findsOneWidget);
      expect(_soon, findsNothing);
      expect(_recap, findsNothing);

      await _tap(tester, _opt('aisle', 'autre'));
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('business-structure-error-aisle')), findsNothing);
      expect(_recap, findsOneWidget);
      expect(_soon, findsNothing);
    });

    testWidgets('plafond de 3 comme les sous-catégories : 4e refusé, encart, « Plus tard »',
        (tester) async {
      await _openDetails(tester, 'supermarche');
      for (final c in ['boissons', 'produits_frais', 'autre']) {
        await _tap(tester, _opt('aisle', c));
      }
      expect(currentDraft(tester).rayons, ['boissons', 'produits_frais', 'autre']);
      expect(_upsell, findsNothing);
      expect(find.text('3/3 inclus sans abonnement'), findsOneWidget);
      expect(find.descendant(of: _opt('aisle', 'hygiene_beaute'), matching: find.text('🔒 Hygiène & Beauté')),
          findsOneWidget);

      await _tap(tester, _opt('aisle', 'hygiene_beaute'));
      expect(currentDraft(tester).rayons, ['boissons', 'produits_frais', 'autre'],
          reason: 'le 4e n\'est pas ajouté');
      expect(_upsell, findsOneWidget);
      await tester.ensureVisible(_upsell);
      expect(find.text('🔒 Limite atteinte — 3 éléments inclus sans abonnement'), findsOneWidget);
      expect(
          find.text(
              "Souscrivez à un abonnement NetBuis pour déclarer autant d'éléments que vous le souhaitez, et bénéficier d'une priorité d'affichage."),
          findsOneWidget);
      expect(find.text('Souscrire à un abonnement'), findsOneWidget);
      expect(find.text('bientôt'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('business-upsell-subscribe'))).onPressed,
          isNull);

      await _tap(tester, find.text('Plus tard'));
      expect(_upsell, findsNothing);
      expect(currentDraft(tester).rayons.length, 3);

      // Libérer une place permet d'en cocher une autre.
      await _tap(tester, _opt('aisle', 'boissons'));
      expect(find.text('2/3 inclus sans abonnement'), findsOneWidget);
      await _tap(tester, _opt('aisle', 'hygiene_beaute'));
      expect(currentDraft(tester).rayons, ['produits_frais', 'autre', 'hygiene_beaute']);
    });

    testWidgets('sans plafond : « Illimité · abonné ✓ », pas d\'encart', (tester) async {
      await _openDetails(tester, 'supermarche',
          overrides: [subcategoryLimitProvider.overrideWithValue(null)]);
      for (final c in ['boissons', 'produits_frais', 'autre', 'produits_bebes']) {
        await _tap(tester, _opt('aisle', c));
      }
      expect(currentDraft(tester).rayons.length, 4);
      expect(find.text('Illimité · abonné ✓'), findsOneWidget);
      expect(_upsell, findsNothing);
    });
  });

  group('restaurant', () {
    testWidgets('cuisine, livraison, horaires, exemple de description ; codes enregistrés',
        (tester) async {
      await _openDetails(tester, 'restaurant');

      expect(find.text('Type de cuisine'), findsOneWidget);
      for (final n in [
        'Camerounaise',
        'Africaine (autre pays)',
        'Fast-food',
        'Pizzeria / Occidentale',
        'Autre',
      ]) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      expect(find.text('Service de livraison disponible'), findsOneWidget);
      expect(find.text("Horaires d'ouverture"), findsOneWidget);
      expect(tester.widget<TextField>(_field('horaires')).decoration!.hintText,
          'Ex. Tous les jours, 11h–22h');
      expect(tester.widget<TextField>(_field('description')).decoration!.hintText,
          'Ex. Restaurant familial, cadre climatisé, salle pour événements.');
      expect(_counter, findsNothing, reason: 'pas de plafond pour la cuisine');
      expect(_field('chambres'), findsNothing);
      expect(_field('agrement'), findsNothing);

      await _tap(tester, _opt('cuisine', 'africaine_autre_pays'));
      expect(currentDraft(tester).cuisine, 'africaine_autre_pays');
      expect(find.bySemanticsLabel('Africaine (autre pays), choisi'), findsOneWidget);
      await _tap(tester, _opt('cuisine', 'fast_food'));
      expect(currentDraft(tester).cuisine, 'fast_food', reason: 'une seule cuisine');
      expect(find.bySemanticsLabel('Africaine (autre pays), choisi'), findsNothing);

      // L'interrupteur est sur « oui » comme la maquette ; un appui le passe sur « non ».
      expect(find.bySemanticsLabel('Service de livraison disponible, Oui'), findsOneWidget);
      await _tap(tester, _field('livraison'));
      expect(currentDraft(tester).livraison, isFalse);
      expect(find.bySemanticsLabel('Service de livraison disponible, Non'), findsOneWidget);
      await _tap(tester, _field('livraison'));
      expect(currentDraft(tester).livraison, isTrue);

      await _enter(tester, _field('horaires'), 'Tous les jours, 11h–22h');
      await _enter(tester, _field('description'), 'Restaurant familial');
      final d = currentDraft(tester);
      expect(d.horaires, 'Tous les jours, 11h–22h');
      expect(d.description, 'Restaurant familial');

      await _tap(tester, continueButton);
      expect(_recap, findsOneWidget);
      expect(_soon, findsNothing);
    });

    testWidgets('la cuisine est obligatoire ; la livraison laissée sur « oui » est enregistrée',
        (tester) async {
      await _openDetails(tester, 'restaurant');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('business-structure-error-cuisine')), findsOneWidget);
      expect(find.text('Choisissez un type de cuisine.'), findsOneWidget);
      expect(_soon, findsNothing);
      expect(_recap, findsNothing);
      expect(currentDraft(tester).livraison, isTrue);

      await _tap(tester, _opt('cuisine', 'camerounaise'));
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(_recap, findsOneWidget);
      expect(_soon, findsNothing);
      expect(currentDraft(tester).cuisine, 'camerounaise');
    });

    testWidgets('les horaires sont facultatifs et limités à 200 caractères', (tester) async {
      await _openDetails(tester, 'restaurant');
      await _tap(tester, _opt('cuisine', 'autre'));
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(_recap, findsOneWidget);
      expect(_soon, findsNothing);
      expect(currentDraft(tester).horaires, '');
      await _back(tester);

      await _enter(tester, _field('horaires'), 'x' * 250);
      expect(currentDraft(tester).horaires.length, 200);
    });
  });

  group('hôtel', () {
    testWidgets('standing, chambres (clavier numérique), équipements ; codes enregistrés',
        (tester) async {
      await _openDetails(tester, 'hotel');

      expect(find.text('Catégorie / standing'), findsOneWidget);
      for (final n in ['Économique', 'Standard', 'Confort', 'Haut standing']) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      expect(find.text('Nombre de chambres'), findsOneWidget);
      expect(tester.widget<TextField>(_field('chambres')).decoration!.hintText, 'Ex. 18');
      expect(tester.widget<TextField>(_field('chambres')).keyboardType, TextInputType.number);
      expect(find.text('Services inclus'), findsOneWidget);
      for (final n in ['Petit-déjeuner', 'Wifi', 'Parking', 'Climatisation']) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      expect(tester.widget<TextField>(_field('description')).decoration!.hintText,
          "Ex. Hôtel calme à 5 min du centre, idéal pour les voyageurs d'affaires.");
      expect(_counter, findsNothing);

      await _tap(tester, _opt('standing', 'haut_standing'));
      expect(currentDraft(tester).standing, 'haut_standing');
      await _tap(tester, _opt('standing', 'confort'));
      expect(currentDraft(tester).standing, 'confort', reason: 'un seul standing');

      await _enter(tester, _field('chambres'), '12abc');
      expect(tester.widget<TextField>(_field('chambres')).controller!.text, '12');
      expect(currentDraft(tester).nombreChambres, 12);

      await _tap(tester, _opt('amenity', 'wifi'));
      await _tap(tester, _opt('amenity', 'petit_dejeuner'));
      await _tap(tester, _opt('amenity', 'parking'));
      await _tap(tester, _opt('amenity', 'wifi'));
      expect(currentDraft(tester).equipements, ['petit_dejeuner', 'parking']);
      expect(find.bySemanticsLabel('Parking, choisi'), findsOneWidget);

      await _tap(tester, continueButton);
      expect(_recap, findsOneWidget);
      expect(_soon, findsNothing);
    });

    testWidgets('le standing est obligatoire ; 0 chambre est refusé ; vide est accepté',
        (tester) async {
      await _openDetails(tester, 'hotel');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('business-structure-error-standing')), findsOneWidget);
      expect(find.text('Choisissez une catégorie.'), findsOneWidget);
      expect(_soon, findsNothing);
      expect(_recap, findsNothing);

      await _tap(tester, _opt('standing', 'standard'));
      await _enter(tester, _field('chambres'), '0');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Entrez un nombre de chambres entre 1 et 9999.'), findsOneWidget);
      expect(_soon, findsNothing);
      expect(_recap, findsNothing);

      await _enter(tester, _field('chambres'), '');
      expect(currentDraft(tester).nombreChambres, isNull);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(_recap, findsOneWidget);
      expect(_soon, findsNothing);
    });

    testWidgets('au plus 4 chiffres dans le nombre de chambres', (tester) async {
      await _openDetails(tester, 'hotel');
      await _enter(tester, _field('chambres'), '123456');
      expect(currentDraft(tester).nombreChambres, 1234);
    });
  });

  group('centre de santé', () {
    testWidgets('agrément facultatif, spécialités, exemple de description ; codes enregistrés',
        (tester) async {
      await _openDetails(tester, 'sante');

      expect(find.text("Numéro d'agrément sanitaire (optionnel)", findRichText: true),
          findsOneWidget);
      expect(tester.widget<TextField>(_field('agrement')).decoration!.hintText,
          'Ex. MINSANTE/2024/0456');
      expect(find.text('Quelles spécialités médicales proposez-vous ?'), findsOneWidget);
      for (final n in [
        'Médecine générale',
        'Pédiatrie',
        'Gynécologie',
        'Dentisterie',
        "Laboratoire d'analyses",
        'Pharmacie interne',
        'Autre',
      ]) {
        expect(find.text(n), findsOneWidget, reason: n);
      }
      expect(find.text('0/3 inclus sans abonnement'), findsOneWidget);
      expect(tester.widget<TextField>(_field('description')).decoration!.hintText,
          'Ex. Centre de santé de quartier, consultations sans rendez-vous.');

      await _tap(tester, _opt('speciality', 'pediatrie'));
      await _tap(tester, _opt('speciality', 'laboratoire'));
      expect(currentDraft(tester).specialites, ['pediatrie', 'laboratoire']);
      await _enter(tester, _field('agrement'), 'MINSANTE/2024/0456');
      expect(currentDraft(tester).numeroAgrement, 'MINSANTE/2024/0456');

      await _tap(tester, continueButton);
      expect(_recap, findsOneWidget);
      expect(_soon, findsNothing);
    });

    testWidgets('au moins une spécialité obligatoire ; l\'agrément reste facultatif',
        (tester) async {
      await _openDetails(tester, 'sante');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('business-structure-error-speciality')), findsOneWidget);
      expect(find.text('Choisissez au moins une spécialité.'), findsOneWidget);
      expect(_soon, findsNothing);
      expect(_recap, findsNothing);

      await _tap(tester, _opt('speciality', 'dentisterie'));
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(_recap, findsOneWidget);
      expect(_soon, findsNothing);
      expect(currentDraft(tester).numeroAgrement, '');
    });

    testWidgets('plafond de 3 comme les sous-catégories ; l\'agrément est limité à 50 caractères',
        (tester) async {
      await _openDetails(tester, 'sante');
      for (final c in ['pediatrie', 'gynecologie', 'dentisterie', 'laboratoire']) {
        await _tap(tester, _opt('speciality', c));
      }
      expect(currentDraft(tester).specialites, ['pediatrie', 'gynecologie', 'dentisterie']);
      expect(_upsell, findsOneWidget);
      expect(find.text('3/3 inclus sans abonnement'), findsOneWidget);
      expect(find.bySemanticsLabel('3 sur 3 inclus sans abonnement'), findsOneWidget);

      await _tap(tester, find.text('Plus tard'));
      expect(_upsell, findsNothing);

      await _enter(tester, _field('agrement'), 'A' * 80);
      expect(currentDraft(tester).numeroAgrement.length, 50);
    });
  });

  group('autre', () {
    testWidgets('texte libre obligatoire, aucun détail propre, exemple de description',
        (tester) async {
      await _openDetails(tester, 'autre');

      expect(find.text('Type de votre établissement'), findsOneWidget);
      expect(_field('horaires'), findsNothing);
      expect(_field('chambres'), findsNothing);
      expect(_field('agrement'), findsNothing);
      expect(_counter, findsNothing);
      expect(tester.widget<TextField>(_field('description')).decoration!.hintText,
          'Ex. Salle de sport de quartier, cours collectifs le soir et le week-end.');

      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Précisez le type de votre établissement.'), findsOneWidget);
      expect(_soon, findsNothing);
      expect(_recap, findsNothing);

      await _enter(tester, _field('libre'), '   ');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Précisez le type de votre établissement.'), findsOneWidget);

      await _enter(tester, _field('libre'), 'Salle de sport');
      expect(currentDraft(tester).structureTypeLibre, 'Salle de sport');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(_recap, findsOneWidget);
      expect(_soon, findsNothing);
    });

    testWidgets('le texte libre est limité à 100 caractères', (tester) async {
      await _openDetails(tester, 'autre');
      await _enter(tester, _field('libre'), 'x' * 130);
      expect(currentDraft(tester).structureTypeLibre.length, 100);
    });
  });

  group('description libre', () {
    testWidgets('facultative (aucun détail requis pour « Autre » avec libre), 1000 au plus',
        (tester) async {
      await _openDetails(tester, 'autre');
      await _enter(tester, _field('libre'), 'Pressing');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(_recap, findsOneWidget);
      expect(_soon, findsNothing);
      expect(currentDraft(tester).description, '');
      await _back(tester);

      await _enter(tester, _field('description'), 'y' * 1100);
      expect(currentDraft(tester).description.length, 1000);
    });
  });

  group('changement de type', () {
    testWidgets('vide les détails de l\'ancien type, garde la description', (tester) async {
      await _openDetails(tester, 'restaurant', viaType: true);
      await _tap(tester, _opt('cuisine', 'fast_food'));
      await _tap(tester, _field('livraison'));
      await _enter(tester, _field('horaires'), '8h-20h');
      await _enter(tester, _field('description'), 'Mon établissement');
      var d = currentDraft(tester);
      expect([d.cuisine, d.livraison, d.horaires], ['fast_food', false, '8h-20h']);

      // Retour au choix du type : le même type ne vide rien.
      await tester.tap(find.byKey(const ValueKey('business-back')));
      await tester.pumpAndSettle();
      await _tap(tester, _type('restaurant'));
      d = currentDraft(tester);
      expect([d.cuisine, d.livraison, d.horaires], ['fast_food', false, '8h-20h']);

      await _tap(tester, _type('hotel'));
      d = currentDraft(tester);
      expect(d.cuisine, '');
      expect(d.livraison, isNull);
      expect(d.horaires, '');
      expect(d.structureCode, 'hotel');
      expect(d.description, 'Mon établissement');

      await _tap(tester, continueButton);
      expect(find.text('Catégorie / standing'), findsOneWidget);
      expect(find.text('Type de cuisine'), findsNothing);
      expect(tester.widget<TextField>(_field('description')).controller!.text, 'Mon établissement');
    });

    testWidgets('quitter « Autre » vide le texte libre ; sante -> supermarché vide les spécialités',
        (tester) async {
      await _openDetails(tester, 'autre', viaType: true);
      await _enter(tester, _field('libre'), 'Pressing');
      await tester.tap(find.byKey(const ValueKey('business-back')));
      await tester.pumpAndSettle();
      await _tap(tester, _type('sante'));
      expect(currentDraft(tester).structureTypeLibre, '');

      await _tap(tester, continueButton);
      await _tap(tester, _opt('speciality', 'pediatrie'));
      await tester.tap(find.byKey(const ValueKey('business-back')));
      await tester.pumpAndSettle();
      await _tap(tester, _type('supermarche'));
      expect(currentDraft(tester).specialites, isEmpty);
      expect(currentDraft(tester).rayons, isEmpty);
    });

    testWidgets('retour arrière depuis les détails : tout est conservé', (tester) async {
      await _openDetails(tester, 'hotel', viaType: true);
      await _tap(tester, _opt('standing', 'confort'));
      await _enter(tester, _field('chambres'), '18');
      await _tap(tester, _opt('amenity', 'wifi'));
      await tester.tap(find.byKey(const ValueKey('business-back')));
      await tester.pumpAndSettle();
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Confort, choisi'), findsOneWidget);
      expect(tester.widget<TextField>(_field('chambres')).controller!.text, '18');
      expect(find.bySemanticsLabel('Wifi, choisi'), findsOneWidget);
    });
  });

  group('brouillon', () {
    test('withStructureType vide les détails ; withType les vide aussi', () async {
      final resto = await _item('restaurant');
      final hotel = await _item('hotel');
      var d = const BusinessDraft(typeCompte: BusinessAccountType.structure)
          .withStructureType(resto)
          .copyWith(cuisine: 'fast_food', livraison: true, horaires: 'x', description: 'd');
      expect(d.structureDetailsIsValid, isTrue);
      expect(d.withStructureType(resto).cuisine, 'fast_food');

      d = d.withStructureType(hotel);
      expect(d.cuisine, '');
      expect(d.livraison, isNull);
      expect(d.horaires, '');
      expect(d.description, 'd');
      expect(d.standingMissing, isTrue);
      expect(d.structureDetailsIsValid, isFalse);

      final other = d.withType(BusinessAccountType.boutique);
      expect(other.structureType, isNull);
      expect(other.structureTypeId, isNull);
    });

    test('obligations par type', () async {
      BusinessDraft base(String code, ReferentialItem t) =>
          const BusinessDraft(typeCompte: BusinessAccountType.structure).withStructureType(t);
      final s = base('supermarche', await _item('supermarche'));
      expect(s.rayonsMissing, isTrue);
      expect(s.copyWith(rayons: ['boissons']).structureDetailsIsValid, isTrue);

      final r = base('restaurant', await _item('restaurant')).copyWith(cuisine: 'autre');
      expect(r.livraisonMissing, isTrue);
      expect(r.structureDetailsIsValid, isFalse);
      expect(r.copyWith(livraison: false).structureDetailsIsValid, isTrue);

      final h = base('hotel', await _item('hotel'));
      expect(h.structureDetailsIsValid, isFalse);
      expect(h.copyWith(standing: 'standard').structureDetailsIsValid, isTrue);
      expect(h.copyWith(standing: 'standard', nombreChambres: 0).structureDetailsIsValid, isFalse);
      expect(h.copyWith(standing: 'standard', nombreChambres: 10000).structureDetailsIsValid,
          isFalse);
      expect(h.copyWith(standing: 'standard', nombreChambres: 9999).structureDetailsIsValid,
          isTrue);

      final sa = base('sante', await _item('sante'));
      expect(sa.specialitesMissing, isTrue);
      expect(sa.copyWith(specialites: ['autre']).structureDetailsIsValid, isTrue);

      final a = base('autre', await _item('autre'));
      expect(a.structureTypeLibreError, FieldError.required);
      expect(a.copyWith(structureTypeLibre: 'Pressing').structureDetailsIsValid, isTrue);
      expect(a.copyWith(structureTypeLibre: 'x' * 101).structureTypeLibreError, FieldError.tooLong);

      expect(const BusinessDraft(typeCompte: BusinessAccountType.structure).structureDetailsIsValid,
          isFalse);
    });
  });

  group('accessibilité et affichage', () {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      testWidgets('360 px, police 130 %, ${mode.name} : cibles 48 dp, sans défilement horizontal',
          (tester) async {
        await _openType(tester, textScale: 1.3, mode: mode);
        for (final code in _codes) {
          await tester.ensureVisible(_type(code));
          expect(tester.getSize(_type(code)).height, greaterThanOrEqualTo(48), reason: code);
          expect(tester.getRect(_type(code)).right, lessThanOrEqualTo(360), reason: code);
        }
        await _tap(tester, _type('autre'));
        await tester.ensureVisible(find.byKey(const ValueKey('business-structure-other-note')));
        _expectOnlyVerticalScroll(tester);
        expect(tester.takeException(), isNull);

        for (final code in _codes) {
          await _openDetails(tester, code, textScale: 1.3, mode: mode);
          _expectOnlyVerticalScroll(tester);
          final chips = find.byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('business-structure-opt-'));
          for (final e in chips.evaluate()) {
            final f = find.byElementPredicate((x) => x == e);
            await tester.ensureVisible(f);
            expect(tester.getSize(f).height, greaterThanOrEqualTo(48), reason: code);
            expect(tester.getRect(f).right, lessThanOrEqualTo(360), reason: code);
            expect(tester.getRect(f).left, greaterThanOrEqualTo(0), reason: code);
          }
          if (code == 'restaurant') {
            await tester.ensureVisible(_field('livraison'));
            expect(tester.getSize(_field('livraison')).height, greaterThanOrEqualTo(48));
          }
          if (code == 'supermarche' || code == 'sante') {
            final group = code == 'sante' ? 'speciality' : 'aisle';
            final opts = code == 'sante'
                ? ['pediatrie', 'gynecologie', 'dentisterie', 'laboratoire']
                : ['boissons', 'produits_frais', 'autre', 'produits_bebes'];
            for (final o in opts) {
              await _tap(tester, _opt(group, o));
            }
            await tester.ensureVisible(_upsell);
            for (final k in ['business-upsell-subscribe', 'business-upsell-later']) {
              expect(tester.getSize(find.byKey(ValueKey(k))).height, greaterThanOrEqualTo(48));
            }
          }
          expect(tester.takeException(), isNull, reason: code);
        }
      });
    }
  });
}

void _expectOnlyVerticalScroll(WidgetTester tester) {
  for (final s in tester.widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))) {
    expect(s.scrollDirection, Axis.vertical);
  }
  expect(find.byType(ListView), findsNothing);
}
