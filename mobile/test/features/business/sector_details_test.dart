import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
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

/// Dépôt de référentiels qui échoue (ou reste en attente) puis répond comme le faux dépôt.
class _ScriptedReferentials extends ReferentialRepositoryFake {
  _ScriptedReferentials({this.failures = 0, this.empty = false, this.gate});

  int failures;
  final bool empty;
  final Completer<void>? gate;
  int calls = 0;

  @override
  Future<List<Sector>> getSectors() async {
    calls++;
    if (gate != null) await gate!.future;
    if (failures > 0) {
      failures--;
      throw const ApiException(ApiErrorCode.network);
    }
    if (empty) return const [];
    return super.getSectors();
  }
}

Finder _sector(String code) => find.byKey(ValueKey('business-sector-$code'));
Finder _sub(int id) => find.byKey(ValueKey('business-sub-$id'));
Finder get _upsell => find.byKey(const ValueKey('business-upsell'));
Finder get _libre => find.byKey(const ValueKey('business-secteur-libre'));
Finder get _description => find.byKey(const ValueKey('business-description-activite'));

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _openSector(
  WidgetTester tester, {
  BusinessAccountType type = BusinessAccountType.boutique,
  List<Override> overrides = const [],
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.dark,
}) async {
  await pumpBusinessApp(
    tester,
    initialLocation: Routes.createBusinessSector,
    overrides: overrides,
    textScale: textScale,
    mode: mode,
  );
  if (type != BusinessAccountType.boutique) {
    _container(tester).read(businessDraftProvider.notifier).setType(type);
    await tester.pumpAndSettle();
  }
}

/// Choisit un secteur puis passe à l'écran Détails.
Future<void> _openDetails(
  WidgetTester tester,
  String code, {
  BusinessAccountType type = BusinessAccountType.boutique,
  List<Override> overrides = const [],
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.dark,
}) async {
  await _openSector(tester, type: type, overrides: overrides, textScale: textScale, mode: mode);
  await _tapVisible(tester, _sector(code));
  await tester.tap(continueButton);
  await tester.pumpAndSettle();
}

const _tenSectors = [
  ('alimentation', 'Alimentation'),
  ('boutique_superette', 'Boutique / Supérette'),
  ('pharmacie_sante', 'Pharmacie & Santé'),
  ('mode_beaute', 'Mode & Beauté'),
  ('electronique_informatique', 'Électronique & Informatique'),
  ('immobilier', 'Immobilier'),
  ('transport_livraison', 'Transport & Livraison'),
  ('agriculture_elevage', 'Agriculture & Élevage'),
  ('artisanat_services_domicile', 'Artisanat & Services à domicile'),
  ('autre', 'Autre'),
];

void main() {
  group('brouillon', () {
    final sectors = ReferentialRepositoryFake().getSectors();

    test('changer de secteur vide sous-catégories, nom libre et description', () async {
      final list = await sectors;
      var d = const BusinessDraft().withSector(list[0]);
      d = d.copyWith(
        sousCategorieIds: [1, 2],
        secteurLibre: 'x',
        descriptionActivite: 'des bananes',
      );
      expect(d.secteurId, list[0].id);
      expect(d.withSector(list[0]).sousCategorieIds, [1, 2],
          reason: 'même secteur : rien ne change');

      final other = d.withSector(list[1]);
      expect(other.secteurId, list[1].id);
      expect(other.secteur, list[1]);
      expect(other.sousCategorieIds, isEmpty);
      expect(other.secteurLibre, '');
      expect(other.descriptionActivite, '');
    });

    test('un type sans secteur efface le secteur choisi', () async {
      final list = await sectors;
      final d = const BusinessDraft().withSector(list[0]).withType(BusinessAccountType.structure);
      expect(d.secteurId, isNull);
      expect(d.secteur, isNull);
    });

    test('validation : secteur obligatoire, « Autre » exige nom et description', () async {
      final list = await sectors;
      expect(const BusinessDraft().sectorMissing, isTrue);
      expect(const BusinessDraft().detailsIsValid, isFalse);

      final alim = const BusinessDraft().withSector(list[0]);
      expect(alim.detailsIsValid, isTrue, reason: 'description facultative hors « Autre »');
      expect(alim.copyWith(descriptionActivite: 'a' * 501).descriptionActiviteError,
          FieldError.tooLong);
      expect(alim.copyWith(descriptionActivite: 'a' * 500).descriptionActiviteError, isNull);

      final autre = const BusinessDraft().withSector(list.last);
      expect(autre.isOtherSector, isTrue);
      expect(autre.secteurLibreError, FieldError.required);
      expect(autre.descriptionActiviteError, FieldError.required);
      final ok = autre.copyWith(secteurLibre: ' Mototaxi ', descriptionActivite: 'Trajets');
      expect(ok.detailsIsValid, isTrue);
      expect(ok.copyWith(secteurLibre: 'a' * 101).secteurLibreError, FieldError.tooLong);
    });

    test('toggleSubcategory : 3 acceptées, la 4e refusée, une place libérée', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(businessDraftProvider, (_, __) {});
      final n = container.read(businessDraftProvider.notifier);
      expect(n.toggleSubcategory(1, limit: 3), isTrue);
      expect(n.toggleSubcategory(2, limit: 3), isTrue);
      expect(n.toggleSubcategory(3, limit: 3), isTrue);
      expect(n.toggleSubcategory(4, limit: 3), isFalse);
      expect(container.read(businessDraftProvider).sousCategorieIds, [1, 2, 3]);
      expect(n.toggleSubcategory(2, limit: 3), isTrue);
      expect(n.toggleSubcategory(4, limit: 3), isTrue);
      expect(container.read(businessDraftProvider).sousCategorieIds, [1, 3, 4]);
      expect(n.toggleSubcategory(5, limit: null), isTrue, reason: 'null = illimité');
    });

    test('le plafond de l\'application vaut 3 (D-12)', () {
      expect(freeSubcategoryLimit, 3);
      expect(ProviderContainer().read(subcategoryLimitProvider), 3);
    });
  });

  group('écran Secteur', () {
    testWidgets('textes de la maquette et grille de 10 secteurs du faux dépôt', (tester) async {
      await _openSector(tester);

      expect(find.text('Étape 2 sur 4'), findsOneWidget);
      expect(find.text("Secteur d'activité"), findsOneWidget);
      expect(find.text("Quel est votre secteur d'activité ?"), findsOneWidget);
      expect(
        find.text(
          "Choisissez le secteur qui correspond le mieux à votre activité principale. Vous pourrez préciser davantage à l'étape suivante.",
        ),
        findsOneWidget,
      );
      for (final (code, name) in _tenSectors) {
        await tester.ensureVisible(_sector(code));
        expect(_sector(code), findsOneWidget, reason: code);
        expect(find.descendant(of: _sector(code), matching: find.text(name)), findsOneWidget,
            reason: name);
      }
      expect(
          find.descendant(of: _sector('alimentation'), matching: find.text('🍌')), findsOneWidget);
      expect(find.descendant(of: _sector('autre'), matching: find.text('✨')), findsOneWidget);
      expect(find.byKey(const ValueKey('business-sector-other-note')), findsNothing);
      expect(currentDraft(tester).secteurId, isNull, reason: 'aucun secteur préchoisi');
      expect(find.text('Cette étape arrive bientôt'), findsNothing);
    });

    testWidgets('choisir un secteur : enregistré dans le brouillon, un seul à la fois',
        (tester) async {
      await _openSector(tester);

      await _tapVisible(tester, _sector('alimentation'));
      expect(currentDraft(tester).secteurId, 1);
      expect(currentDraft(tester).secteur!.code, 'alimentation');
      expect(find.bySemanticsLabel('Alimentation, choisi'), findsOneWidget);

      await _tapVisible(tester, _sector('immobilier'));
      expect(currentDraft(tester).secteurId, 6);
      expect(find.bySemanticsLabel('Immobilier, choisi'), findsOneWidget);
      expect(find.bySemanticsLabel('Alimentation, choisi'), findsNothing);
      expect(find.bySemanticsLabel('Alimentation'), findsOneWidget);
    });

    testWidgets('Continuer sans secteur : message, on reste sur l\'écran', (tester) async {
      await _openSector(tester);

      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.text('Choisissez un secteur.'), findsOneWidget);
      expect(find.text('Étape 2 sur 4'), findsOneWidget);
      expect(find.text('Précisez votre activité'), findsNothing);

      await _tapVisible(tester, _sector('alimentation'));
      expect(find.text('Choisissez un secteur.'), findsNothing);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Étape 3 sur 4'), findsOneWidget);
      expect(find.text('Précisez votre activité'), findsOneWidget);
    });

    testWidgets('« Autre » montre l\'encart ✨ de la maquette, un autre secteur le retire',
        (tester) async {
      await _openSector(tester);

      await _tapVisible(tester, _sector('autre'));
      await tester.ensureVisible(find.byKey(const ValueKey('business-sector-other-note')));
      expect(
        find.text(
          "Votre activité n'est dans aucune des cases ci-dessus ? Pas de souci — à l'étape suivante, vous pourrez écrire vous-même le nom de votre secteur (ex. « Transport de personnes à moto ») et décrire ce que vous faites.",
        ),
        findsOneWidget,
      );

      await _tapVisible(tester, _sector('mode_beaute'));
      expect(find.byKey(const ValueKey('business-sector-other-note')), findsNothing);
    });

    testWidgets('chargement, erreur réseau avec « Réessayer », puis la grille', (tester) async {
      final repo = _ScriptedReferentials(failures: 1);
      await _openSector(tester, overrides: [referentialRepositoryProvider.overrideWithValue(repo)]);

      expect(find.byKey(const ValueKey('business-sectors-error')), findsOneWidget);
      expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsOneWidget);
      expect(_sector('alimentation'), findsNothing);

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(repo.calls, 2);
      expect(find.byKey(const ValueKey('business-sectors-error')), findsNothing);
      expect(_sector('alimentation'), findsOneWidget);
    });

    testWidgets('chargement en cours : message, puis la grille', (tester) async {
      final gate = Completer<void>();
      final repo = _ScriptedReferentials(gate: gate);
      await pumpBusinessApp(
        tester,
        initialLocation: Routes.createBusinessSector,
        settle: false,
        overrides: [referentialRepositoryProvider.overrideWithValue(repo)],
      );

      expect(find.byKey(const ValueKey('business-sectors-loading')), findsOneWidget);
      expect(find.text('Chargement des secteurs...'), findsOneWidget);
      expect(_sector('alimentation'), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('business-sectors-loading')), findsNothing);
      expect(_sector('alimentation'), findsOneWidget);
    });

    testWidgets('liste vide : message et « Réessayer »', (tester) async {
      await _openSector(tester, overrides: [
        referentialRepositoryProvider.overrideWithValue(_ScriptedReferentials(empty: true)),
      ]);
      expect(find.text('Aucun secteur disponible pour le moment.'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(_sector('alimentation'), findsNothing);
    });

    testWidgets('totaux : 3 sur 5 pour Entreprise, 2 sur 4 pour Particulier', (tester) async {
      await _openSector(tester, type: BusinessAccountType.entreprise);
      expect(find.text('Étape 3 sur 5'), findsOneWidget);

      await _openSector(tester, type: BusinessAccountType.particulierVendeur);
      expect(find.text('Étape 2 sur 4'), findsOneWidget);
    });

    testWidgets('inaccessible pour Prestataire et Structure : renvoie à Informations',
        (tester) async {
      for (final type in [BusinessAccountType.prestataireService, BusinessAccountType.structure]) {
        await _openSector(tester, type: type);

        expect(_sector('alimentation'), findsNothing, reason: type.value);
        expect(find.text('Informations de base'), findsOneWidget, reason: type.value);
        expect(find.text(type == BusinessAccountType.structure ? 'Étape 1 sur 4' : 'Étape 1 sur 3'),
            findsOneWidget,
            reason: type.value);
      }
    });
  });

  group('écran Détails', () {
    testWidgets('Alimentation : textes de la maquette, 12 sous-catégories, compteur 0/3',
        (tester) async {
      await _openDetails(tester, 'alimentation');

      expect(find.text('Étape 3 sur 4'), findsOneWidget);
      expect(find.text('Précisez votre activité'), findsOneWidget);
      expect(find.text('Quels produits alimentaires proposez-vous ?'), findsOneWidget);
      expect(find.text("Sélectionnez tout ce qui s'applique."), findsOneWidget);
      expect(find.text('0/3 inclus sans abonnement'), findsOneWidget);
      expect(find.bySemanticsLabel('0 sur 3 inclus sans abonnement'), findsOneWidget);
      final sector = currentDraft(tester).secteur!;
      expect(sector.subcategories.length, 12);
      for (final sub in sector.subcategories) {
        await tester.ensureVisible(_sub(sub.id));
        expect(find.descendant(of: _sub(sub.id), matching: find.text(sub.name)), findsOneWidget,
            reason: sub.name);
      }
      await tester.ensureVisible(_description);
      expect(find.text('Précisez / décrivez votre activité'), findsOneWidget);
      expect(find.text('Ex. Bananes plantain, macabo, tomates, oignons, gombo...'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('business-details-tip')));
      expect(
        find.text(
          'Ces informations alimentent la recherche intelligente : un client qui tape un mot proche de ce que vous vendez vous retrouve plus facilement.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cette étape arrive bientôt'), findsNothing);
      expect(_upsell, findsNothing);
    });

    testWidgets('questions et exemples de Boutique et de Transport', (tester) async {
      await _openDetails(tester, 'boutique_superette');
      expect(find.text('Quels produits de première nécessité vendez-vous ?'), findsOneWidget);
      expect(
        find.text('Ex. Boutique de quartier : biscuits, eau, spaghetti, macaroni, savon...'),
        findsOneWidget,
      );
      expect(currentDraft(tester).secteur!.subcategories.length, 9);

      await _openDetails(tester, 'transport_livraison');
      expect(find.text('Quels services de transport proposez-vous ?'), findsOneWidget);
      expect(
        find.text(
            'Ex. Mototaxi dans le quartier Hardé et ses environs, disponible tous les jours dès 6h...'),
        findsOneWidget,
      );
      expect(find.descendant(of: _sub(26), matching: find.text('Moto-taxi')), findsOneWidget);
    });

    testWidgets('plafond : 3 acceptées, la 4e refusée avec l\'encart, une place libérée',
        (tester) async {
      await _openDetails(tester, 'alimentation');

      for (final id in [1, 2, 3]) {
        await _tapVisible(tester, _sub(id));
      }
      expect(currentDraft(tester).sousCategorieIds, [1, 2, 3]);
      expect(find.text('3/3 inclus sans abonnement'), findsOneWidget);
      expect(find.bySemanticsLabel('3 sur 3 inclus sans abonnement'), findsOneWidget);
      expect(find.bySemanticsLabel('Fruits, choisi'), findsOneWidget);
      expect(_upsell, findsNothing, reason: 'l\'encart n\'apparaît qu\'à la 4e tentative');
      // Les cases non cochées montrent le cadenas.
      expect(find.descendant(of: _sub(4), matching: find.text('🔒 Céréales & Légumineuses')),
          findsOneWidget);

      await _tapVisible(tester, _sub(4));

      expect(currentDraft(tester).sousCategorieIds, [1, 2, 3], reason: 'la 4e n\'est pas ajoutée');
      expect(_upsell, findsOneWidget);
      await tester.ensureVisible(_upsell);
      expect(find.text('🔒 Limite atteinte — 3 éléments inclus sans abonnement'), findsOneWidget);
      expect(
        find.text(
          "Un compte business non abonné peut déclarer jusqu'à 3 produits/services. Passez à l'abonnement NetBuis pour en sélectionner autant que vous le souhaitez, en plus de la priorité d'affichage et des publications illimitées.",
        ),
        findsOneWidget,
      );
      expect(find.text('Souscrire à un abonnement'), findsOneWidget);
      expect(find.text('bientôt'), findsOneWidget);
      expect(find.text('Plus tard'), findsOneWidget);

      // Libérer une place : 2/3, l'encart disparaît, une autre case peut être cochée.
      await _tapVisible(tester, _sub(2));
      expect(currentDraft(tester).sousCategorieIds, [1, 3]);
      expect(find.text('2/3 inclus sans abonnement'), findsOneWidget);
      expect(find.bySemanticsLabel('2 sur 3 inclus sans abonnement'), findsOneWidget);
      expect(_upsell, findsNothing);
      await _tapVisible(tester, _sub(4));
      expect(currentDraft(tester).sousCategorieIds, [1, 3, 4]);
    });

    testWidgets('« Souscrire » est désactivé (« bientôt »), « Plus tard » ferme l\'encart',
        (tester) async {
      await _openDetails(tester, 'alimentation');
      for (final id in [1, 2, 3, 4]) {
        await _tapVisible(tester, _sub(id));
      }
      await tester.ensureVisible(_upsell);

      final subscribe =
          tester.widget<FilledButton>(find.byKey(const ValueKey('business-upsell-subscribe')));
      expect(subscribe.onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('business-upsell-subscribe')),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_upsell, findsOneWidget);
      expect(find.bySemanticsLabel('Souscrire à un abonnement, bientôt'), findsOneWidget);

      await tester.tap(find.text('Plus tard'));
      await tester.pumpAndSettle();
      expect(_upsell, findsNothing);
      expect(currentDraft(tester).sousCategorieIds, [1, 2, 3]);
      expect(find.text('3/3 inclus sans abonnement'), findsOneWidget);
    });

    testWidgets('sans plafond (compte abonné plus tard) : « Illimité », pas d\'encart',
        (tester) async {
      await _openDetails(tester, 'alimentation',
          overrides: [subcategoryLimitProvider.overrideWithValue(null)]);
      for (final id in [1, 2, 3, 4]) {
        await _tapVisible(tester, _sub(id));
      }
      expect(currentDraft(tester).sousCategorieIds, [1, 2, 3, 4]);
      expect(find.text('Illimité · abonné ✓'), findsOneWidget);
      expect(_upsell, findsNothing);
    });

    testWidgets('changer de secteur vide les sous-catégories ; revenir au même les garde',
        (tester) async {
      await _openDetails(tester, 'alimentation');
      await _tapVisible(tester, _sub(1));
      await _tapVisible(tester, _sub(2));
      await tester.enterText(_description, 'Bananes');
      await tester.pump();
      expect(currentDraft(tester).sousCategorieIds, [1, 2]);

      // Retour arrière : l'état est conservé, et Continuer le retrouve.
      await tester.tap(find.byKey(const ValueKey('business-back')));
      await tester.pumpAndSettle();
      expect(find.text('Étape 2 sur 4'), findsOneWidget);
      expect(find.bySemanticsLabel('Alimentation, choisi'), findsOneWidget);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('2/3 inclus sans abonnement'), findsOneWidget);
      expect(find.bySemanticsLabel('Fruits, choisi'), findsOneWidget);
      expect(tester.widget<TextField>(_description).controller!.text, 'Bananes');

      // Autre secteur : tout est vidé.
      await tester.tap(find.byKey(const ValueKey('business-back')));
      await tester.pumpAndSettle();
      await _tapVisible(tester, _sector('boutique_superette'));
      expect(currentDraft(tester).sousCategorieIds, isEmpty);
      expect(currentDraft(tester).descriptionActivite, '');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('0/3 inclus sans abonnement'), findsOneWidget);
      expect(tester.widget<TextField>(_description).controller!.text, '');
      expect(find.text('Biscuits & Confiseries'), findsOneWidget);
      expect(find.text('Fruits'), findsNothing);
    });

    testWidgets('secteur « Autre » : nom libre et description obligatoires, sans sous-catégories',
        (tester) async {
      await _openDetails(tester, 'autre');

      expect(find.text('Étape 3 sur 4'), findsOneWidget);
      expect(find.text("Votre secteur n'est pas dans la liste ?"), findsOneWidget);
      expect(
        find.text(
          "Pas de problème — écrivez-le vous-même. L'équipe NetBuis l'examinera et pourra l'ajouter officiellement à la liste si plusieurs commerçants le demandent.",
        ),
        findsOneWidget,
      );
      expect(find.text("Nom de votre secteur d'activité"), findsOneWidget);
      expect(find.text('Ex. Transport de personnes à moto (mototaxi)'), findsOneWidget);
      expect(
          find.text(
              'Ex. Transport de personnes à moto, trajets courts dans Maroua, disponible tous les jours.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('business-subcategory-counter')), findsNothing);
      expect(_sub(43), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('business-details-tip')));
      expect(
        find.text(
          'Ces informations alimentent la recherche intelligente, même pour un secteur non encore répertorié : un client qui tape un mot proche de votre activité vous retrouve quand même.',
        ),
        findsOneWidget,
      );

      // Rien rempli : deux erreurs, on reste.
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Écrivez le nom de votre secteur.'), findsOneWidget);
      expect(find.text('Décrivez votre activité.'), findsOneWidget);
      expect(find.text('Cette étape arrive bientôt'), findsNothing);

      // Le nom seul ne suffit pas.
      await tester.enterText(_libre, '  Mototaxi  ');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Écrivez le nom de votre secteur.'), findsNothing);
      expect(find.text('Décrivez votre activité.'), findsOneWidget);

      // Une description d'espaces seulement est refusée.
      await tester.enterText(_description, '   ');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Décrivez votre activité.'), findsOneWidget);

      await tester.enterText(_description, 'Trajets courts à Maroua');
      fillCommonDraft(tester);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Décrivez votre activité.'), findsNothing);
      // Le récapitulatif (T035) s'ouvre : il remplace l'ancien message « bientôt ».
      expectRecapShown();
      expect(find.text('Étape 4 sur 4'), findsOneWidget);
      final d = currentDraft(tester);
      expect(d.secteurLibre, 'Mototaxi');
      expect(d.descriptionActivite, 'Trajets courts à Maroua');
      expect(d.sousCategorieIds, isEmpty);
    });

    testWidgets('longueurs maximales : 100 caractères le nom libre, 500 la description',
        (tester) async {
      await _openDetails(tester, 'autre');

      await tester.enterText(_libre, 'a' * 130);
      await tester.enterText(_description, 'b' * 600);
      await tester.pump();

      expect(currentDraft(tester).secteurLibre.length, kBusinessSecteurLibreMax);
      expect(currentDraft(tester).descriptionActivite.length, kBusinessDescriptionActiviteMax);
      expect(kBusinessSecteurLibreMax, 100);
      expect(kBusinessDescriptionActiviteMax, 500);
    });

    testWidgets('hors « Autre » la description est facultative : Continuer passe', (tester) async {
      await _openDetails(tester, 'alimentation');
      fillCommonDraft(tester);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.text('Décrivez votre activité.'), findsNothing);
      expectRecapShown();
    });

    testWidgets('Entreprise : Détails est l\'étape 4 sur 5', (tester) async {
      await _openDetails(tester, 'immobilier', type: BusinessAccountType.entreprise);
      expect(find.text('Étape 4 sur 5'), findsOneWidget);
      // Secteur sans question propre : texte générique, une seule sous-catégorie « Autre ».
      expect(find.text('Quels produits ou services proposez-vous ?'), findsOneWidget);
      expect(find.descendant(of: _sub(25), matching: find.text('Autre')), findsOneWidget);
    });

    testWidgets('inaccessible sans secteur et pour Prestataire / Structure', (tester) async {
      await pumpBusinessApp(tester, initialLocation: Routes.createBusinessDetails);
      expect(find.text("Quel est votre secteur d'activité ?"), findsOneWidget,
          reason: 'sans secteur choisi : retour à l\'étape Secteur');

      for (final type in [BusinessAccountType.prestataireService, BusinessAccountType.structure]) {
        await _openDetails(tester, 'alimentation');
        _container(tester).read(businessDraftProvider.notifier).setType(type);
        await tester.pumpAndSettle();
        expect(find.text('Informations de base'), findsOneWidget, reason: type.value);
        expect(find.text('Précisez votre activité'), findsNothing, reason: type.value);
      }
    });
  });

  group('accessibilité et affichage', () {
    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      testWidgets('360 px, police 130 %, ${mode.name} : cibles 48 dp, sans débordement',
          (tester) async {
        await _openSector(tester, textScale: 1.3, mode: mode);
        for (final (code, _) in _tenSectors) {
          await tester.ensureVisible(_sector(code));
          expect(tester.getSize(_sector(code)).height, greaterThanOrEqualTo(48), reason: code);
          expect(tester.getSize(_sector(code)).width, lessThanOrEqualTo(360));
        }
        await tester.tap(_sector('autre'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('business-sector-other-note')));
        expect(find.byType(SingleChildScrollView), findsOneWidget);
        expect(
            tester
                .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
                .scrollDirection,
            Axis.vertical);
        expect(tester.takeException(), isNull);

        await _tapVisible(tester, _sector('artisanat_services_domicile'));
        await tester.tap(continueButton);
        await tester.pumpAndSettle();
        for (final id in [34, 35, 36, 37]) {
          await tester.ensureVisible(_sub(id));
          expect(tester.getSize(_sub(id)).height, greaterThanOrEqualTo(48), reason: '$id');
          expect(tester.getRect(_sub(id)).right, lessThanOrEqualTo(360), reason: '$id');
        }
        for (final id in [34, 35, 36, 37]) {
          await _tapVisible(tester, _sub(id));
        }
        await tester.ensureVisible(_upsell);
        for (final k in ['business-upsell-subscribe', 'business-upsell-later']) {
          expect(tester.getSize(find.byKey(ValueKey(k))).height, greaterThanOrEqualTo(48),
              reason: k);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  test('toutes les étapes sont construites, le récapitulatif ferme le parcours', () {
    expect(BusinessStep.sector.built, isTrue);
    expect(BusinessStep.details.built, isTrue);
    expect(BusinessStep.recap.built, isTrue);
    expect(BusinessStep.values.every((s) => s.built), isTrue);
    expect(BusinessCreationFlow.nextRoute(BusinessAccountType.boutique, BusinessStep.info),
        Routes.createBusinessSector);
    expect(BusinessCreationFlow.nextRoute(BusinessAccountType.boutique, BusinessStep.sector),
        Routes.createBusinessDetails);
    expect(BusinessCreationFlow.nextRoute(BusinessAccountType.boutique, BusinessStep.details),
        Routes.createBusinessRecap);
    expect(BusinessCreationFlow.nextRoute(BusinessAccountType.boutique, BusinessStep.recap),
        isNull);
  });
}
