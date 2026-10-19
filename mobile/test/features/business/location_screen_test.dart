import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/data/zones/zone.dart';
import 'package:netbuis/core/data/zones/zone_repository.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/auth/presentation/screens/login_screen.dart';

import '../auth/login_test_helpers.dart';
import 'business_test_helpers.dart';

// Zones de test. Maroua (16) et ses quartiers reprennent zones.csv (mêmes identifiants que
// le dépôt factice) ; Garoua et Ngaoundéré sont des données de test seulement.
const _maroua = Zone(id: 16, name: 'Maroua', level: ZoneLevel.villeVillage, parent: 12);
const _garoua = Zone(id: 30, name: 'Garoua', level: ZoneLevel.villeVillage, parent: 13);
const _ngaoundere = Zone(id: 31, name: 'Ngaoundéré', level: ZoneLevel.villeVillage, parent: 13);
const _harde = Zone(id: 17, name: 'Hardé', level: ZoneLevel.quartier, parent: 16);
const _dougoi = Zone(id: 18, name: 'Dougoï', level: ZoneLevel.quartier, parent: 16);
const _region = Zone(id: 11, name: 'Extrême-Nord', level: ZoneLevel.region, parent: 1);
const _network = ApiException(ApiErrorCode.network);

/// Dépôt de zones scénarisé : villes, quartiers par ville, erreurs une par une, appels notés.
class LocationZones implements ZoneRepository {
  LocationZones({
    this.cities = const [_maroua, _garoua, _ngaoundere],
    this.districts = const {
      16: [_harde, _dougoi],
    },
  });

  List<Zone> cities;
  Map<int, List<Zone>> districts;
  final List<ApiException> cityErrors = [];
  final List<ApiException> districtErrors = [];
  final List<({ZoneLevel? level, int? parent})> calls = [];
  int getZoneCalls = 0;

  /// Tant qu'il n'est pas terminé, la liste des villes n'arrive pas (état « chargement »).
  Completer<void>? cityGate;

  @override
  Future<List<Zone>> listZones({ZoneLevel? level, int? parent}) async {
    calls.add((level: level, parent: parent));
    if (level == ZoneLevel.quartier) {
      if (districtErrors.isNotEmpty) throw districtErrors.removeAt(0);
      return districts[parent] ?? const [];
    }
    if (cityGate != null) await cityGate!.future;
    if (cityErrors.isNotEmpty) throw cityErrors.removeAt(0);
    return cities;
  }

  @override
  Future<ZoneDetail> getZone(int id) async {
    getZoneCalls++;
    throw const ApiException(ApiErrorCode.unknown, statusCode: 404);
  }
}

Finder get _field => find.byKey(const ValueKey('business-location'));
Finder get _search => find.byKey(const ValueKey('location-search'));
Finder _city(int id) => find.byKey(ValueKey('city-$id'));
Finder _district(int id) => find.byKey(ValueKey('district-$id'));
Finder get _notFound => find.byKey(const ValueKey('district-not-found'));
Finder get _back => find.byKey(const ValueKey('location-back'));

Future<void> _openLocation(WidgetTester tester) async {
  await tester.ensureVisible(_field);
  await tester.pumpAndSettle();
  await tester.tap(_field);
  await tester.pumpAndSettle();
}

Future<void> _pumpLocation(
  WidgetTester tester,
  LocationZones zones, {
  bool city = true,
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.dark,
  bool settle = true,
}) async {
  await pumpBusinessApp(
    tester,
    textScale: textScale,
    mode: mode,
    settle: settle,
    prefs: city ? null : MemoryPrefs(seen: true, city: null),
    overrides: [zoneRepositoryProvider.overrideWithValue(zones)],
  );
  if (!settle) return;
  await _openLocation(tester);
}

void main() {
  group('premier temps : ville ou village', () {
    testWidgets('liste des villes (toutes les pages du dépôt), ville de T022 présélectionnée',
        (tester) async {
      final zones = LocationZones();
      await _pumpLocation(tester, zones);

      expect(find.text('Choisir le lieu de votre commerce'), findsOneWidget);
      expect(find.text('Choisissez votre ville ou votre village, puis votre quartier.'),
          findsOneWidget);
      for (final z in [_maroua, _garoua, _ngaoundere]) {
        expect(_city(z.id), findsOneWidget, reason: z.name);
      }
      // Maroua (mémorisée en T022) est cochée : icône « coche », les autres non.
      expect(find.descendant(of: _city(16), matching: find.byIcon(Icons.check)), findsOneWidget);
      expect(find.descendant(of: _city(30), matching: find.byIcon(Icons.check)), findsNothing);
      // Seul GET /api/zones/?level=ville_village a été appelé.
      expect(zones.calls.single, (level: ZoneLevel.villeVillage, parent: null));
    });

    testWidgets('sans ville mémorisée, rien n\'est présélectionné', (tester) async {
      await _pumpLocation(tester, LocationZones(), city: false);
      expect(find.byIcon(Icons.check), findsNothing);
      expect(currentDraft(tester).zoneId, isNull);
    });

    testWidgets('recherche : casse, accents, morceau de nom, effacer', (tester) async {
      await _pumpLocation(tester, LocationZones());

      await tester.enterText(_search, 'ngaoundere');
      await tester.pumpAndSettle();
      expect(_city(31), findsOneWidget);
      expect(_city(16), findsNothing);
      expect(_city(30), findsNothing);

      await tester.enterText(_search, 'MAROUA');
      await tester.pumpAndSettle();
      expect(_city(16), findsOneWidget);
      expect(_city(31), findsNothing);

      await tester.enterText(_search, 'oua');
      await tester.pumpAndSettle();
      expect(_city(16), findsOneWidget);
      expect(_city(30), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('location-search-clear')));
      await tester.pumpAndSettle();
      expect(_city(31), findsOneWidget);
      expect(find.byKey(const ValueKey('location-search-clear')), findsNothing);
    });

    testWidgets('recherche sans résultat : « Aucune ville ne correspond »', (tester) async {
      await _pumpLocation(tester, LocationZones());
      await tester.enterText(_search, 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('Aucune ville ne correspond'), findsOneWidget);
      for (final id in [16, 30, 31]) {
        expect(_city(id), findsNothing, reason: '$id');
      }
    });

    testWidgets('chargement visible quand les villes tardent', (tester) async {
      final zones = LocationZones();
      await _pumpLocation(tester, zones, settle: true);
      // Retour aux Informations, puis nouvelle ouverture avec les villes bloquées.
      await tester.tap(_back);
      await tester.pumpAndSettle();
      zones.cityGate = Completer<void>();
      await tester.ensureVisible(_field);
      await tester.tap(_field);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_city(16), findsNothing);
      zones.cityGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_city(16), findsOneWidget);
    });

    testWidgets('réseau coupé : message court (jamais celui du serveur) puis « Réessayer »',
        (tester) async {
      final zones = LocationZones()
        ..cityErrors.add(const ApiException(ApiErrorCode.network, message: 'ECONNRESET 10.0.0.1'));
      await _pumpLocation(tester, zones);

      expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsOneWidget);
      expect(find.textContaining('ECONNRESET'), findsNothing);
      expect(_city(16), findsNothing);

      await tester.tap(find.byKey(const ValueKey('city-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsNothing);
      expect(_city(16), findsOneWidget);
    });

    testWidgets('autre erreur : message générique, pas le texte du serveur', (tester) async {
      final zones = LocationZones()
        ..cityErrors.add(const ApiException(ApiErrorCode.unknown,
            message: 'Traceback interne', statusCode: 500));
      await _pumpLocation(tester, zones);

      expect(find.text('Une erreur est survenue. Réessayez.'), findsOneWidget);
      expect(find.textContaining('Traceback'), findsNothing);
    });

    testWidgets('aucune ville : « Aucune ville disponible pour l\'instant » et « Réessayer »',
        (tester) async {
      final zones = LocationZones(cities: const []);
      await _pumpLocation(tester, zones);

      expect(find.text('Aucune ville disponible pour l\'instant'), findsOneWidget);
      zones.cities = const [_maroua];
      await tester.tap(find.byKey(const ValueKey('city-retry')));
      await tester.pumpAndSettle();
      expect(_city(16), findsOneWidget);
    });

    testWidgets('une zone d\'un autre niveau reçue par erreur est refusée avec un message clair',
        (tester) async {
      // Serveur fautif : une région dans la liste des villes. L'écran ne la retient pas.
      final zones = LocationZones(cities: const [_maroua, _region]);
      await _pumpLocation(tester, zones);
      await tester.tap(find.byKey(const ValueKey('city-11')));
      await tester.pumpAndSettle();

      expect(
        find.text('Choisissez votre ville ou votre quartier, pas seulement une région ou un département.'),
        findsOneWidget,
      );
      expect(find.text('Choisir votre quartier'), findsNothing);
      expect(currentDraft(tester).ville?.id, 16);
      expect(currentDraft(tester).zoneId, 16);
    });
  });

  group('second temps : quartier', () {
    testWidgets('quartiers de la ville choisie ; choisir Hardé revient aux Informations',
        (tester) async {
      final zones = LocationZones();
      await _pumpLocation(tester, zones);
      await tester.tap(_city(16));
      await tester.pumpAndSettle();

      expect(find.text('Choisir votre quartier'), findsOneWidget);
      expect(find.text('Quartiers de Maroua. Le quartier est facultatif.'), findsOneWidget);
      expect(_district(17), findsOneWidget);
      expect(_district(18), findsOneWidget);
      expect(find.text('Je ne trouve pas mon quartier'), findsOneWidget);
      expect(find.text('Votre commerce sera rattaché à Maroua seulement.'), findsOneWidget);
      expect(zones.calls.last, (level: ZoneLevel.quartier, parent: 16));

      await tester.tap(_district(17));
      await tester.pumpAndSettle();

      expect(find.text('Étape 1 sur 4'), findsOneWidget);
      expect(find.descendant(of: _field, matching: find.text('Maroua, Hardé')), findsOneWidget);
      final d = currentDraft(tester);
      expect(d.zoneId, 17);
      expect(d.ville?.name, 'Maroua');
      expect(d.quartier?.name, 'Hardé');
      expect(d.locationLabel, 'Maroua, Hardé');
      // Aucun appel autre que GET /api/zones/ (villes puis quartiers).
      expect(zones.calls.map((c) => c.level).toSet(), {ZoneLevel.villeVillage, ZoneLevel.quartier});
      expect(zones.getZoneCalls, 0);
    });

    testWidgets('« Je ne trouve pas mon quartier » garde la ville seule', (tester) async {
      await _pumpLocation(tester, LocationZones());
      await tester.tap(_city(16));
      await tester.pumpAndSettle();
      await tester.tap(_district(18));
      await tester.pumpAndSettle();
      expect(currentDraft(tester).zoneId, 18);

      await _openLocation(tester);
      await tester.tap(_city(16));
      await tester.pumpAndSettle();
      await tester.ensureVisible(_notFound);
      await tester.tap(_notFound);
      await tester.pumpAndSettle();

      expect(find.text('Étape 1 sur 4'), findsOneWidget);
      expect(find.descendant(of: _field, matching: find.text('Maroua')), findsOneWidget);
      final d = currentDraft(tester);
      expect(d.zoneId, 16);
      expect(d.quartier, isNull);
      expect(d.locationLabel, 'Maroua');
    });

    testWidgets('ville sans quartier : le second temps est sauté, sans message d\'erreur',
        (tester) async {
      await _pumpLocation(tester, LocationZones());
      await tester.tap(_city(30));
      await tester.pumpAndSettle();

      expect(find.text('Étape 1 sur 4'), findsOneWidget);
      expect(find.text('Choisir votre quartier'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(find.descendant(of: _field, matching: find.text('Garoua')), findsOneWidget);
      expect(currentDraft(tester).zoneId, 30);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changer de ville vide le quartier choisi', (tester) async {
      await _pumpLocation(tester, LocationZones());
      await tester.tap(_city(16));
      await tester.pumpAndSettle();
      await tester.tap(_district(17));
      await tester.pumpAndSettle();
      expect(currentDraft(tester).locationLabel, 'Maroua, Hardé');

      await _openLocation(tester);
      await tester.tap(_city(30));
      await tester.pumpAndSettle();

      final d = currentDraft(tester);
      expect(d.quartier, isNull);
      expect(d.zoneId, 30);
      expect(d.locationLabel, 'Garoua');
    });

    testWidgets('même ville retapée : le quartier choisi reste marqué', (tester) async {
      await _pumpLocation(tester, LocationZones());
      await tester.tap(_city(16));
      await tester.pumpAndSettle();
      await tester.tap(_district(17));
      await tester.pumpAndSettle();

      await _openLocation(tester);
      await tester.tap(_city(16));
      await tester.pumpAndSettle();
      expect(find.descendant(of: _district(17), matching: find.byIcon(Icons.check_circle)),
          findsOneWidget);
      expect(find.descendant(of: _district(18), matching: find.byIcon(Icons.check_circle)),
          findsNothing);
      expect(currentDraft(tester).zoneId, 17);
    });

    testWidgets('erreur réseau sur les quartiers : « Réessayer » et la ville seule reste possible',
        (tester) async {
      final zones = LocationZones()..districtErrors.add(_network);
      await _pumpLocation(tester, zones);
      await tester.tap(_city(16));
      await tester.pumpAndSettle();

      expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsOneWidget);
      expect(_district(17), findsNothing);
      expect(_notFound, findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('city-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsNothing);
      expect(_district(17), findsOneWidget);
    });

    testWidgets('erreur persistante : « Je ne trouve pas mon quartier » permet de continuer',
        (tester) async {
      final zones = LocationZones()..districtErrors.add(_network);
      await _pumpLocation(tester, zones);
      await tester.tap(_city(16));
      await tester.pumpAndSettle();
      await tester.tap(_notFound);
      await tester.pumpAndSettle();

      expect(find.text('Étape 1 sur 4'), findsOneWidget);
      expect(currentDraft(tester).zoneId, 16);
    });

    testWidgets('chargement des quartiers : indicateur puis liste', (tester) async {
      await _pumpLocation(tester, LocationZones());
      await tester.tap(_city(16));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_district(17), findsOneWidget);
    });

    testWidgets('écran des quartiers ouvert sans ville : retour au choix de la ville',
        (tester) async {
      await pumpBusinessApp(
        tester,
        initialLocation: Routes.createBusinessDistrict,
        overrides: [zoneRepositoryProvider.overrideWithValue(LocationZones())],
      );
      expect(find.text('Choisir le lieu de votre commerce'), findsOneWidget);
      expect(find.text('Choisir votre quartier'), findsNothing);
    });
  });

  group('navigation et état conservé', () {
    testWidgets('retour depuis les quartiers : la recherche et la ville choisie sont conservées',
        (tester) async {
      await _pumpLocation(tester, LocationZones());
      await tester.enterText(_search, 'maroua');
      await tester.pumpAndSettle();
      await tester.tap(_city(16));
      await tester.pumpAndSettle();
      expect(find.text('Choisir votre quartier'), findsOneWidget);

      await tester.tap(_back);
      await tester.pumpAndSettle();

      expect(find.text('Choisir le lieu de votre commerce'), findsOneWidget);
      expect(tester.widget<TextField>(_search).controller!.text, 'maroua');
      expect(_city(16), findsOneWidget);
      expect(_city(30), findsNothing);
      expect(find.descendant(of: _city(16), matching: find.byIcon(Icons.check)), findsOneWidget);
      // La ville est gardée même sans quartier choisi.
      expect(currentDraft(tester).zoneId, 16);
    });

    testWidgets('bouton retour de l\'écran et retour système ramènent aux Informations',
        (tester) async {
      await _pumpLocation(tester, LocationZones());
      await tester.tap(_back);
      await tester.pumpAndSettle();
      expect(find.text('Étape 1 sur 4'), findsOneWidget);

      await _openLocation(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Étape 1 sur 4'), findsOneWidget);
      expect(find.text('Choisir le lieu de votre commerce'), findsNothing);
      // Rien n'a changé dans le brouillon.
      expect(currentDraft(tester).zoneId, 16);
    });

    testWidgets('route protégée : sans connexion, le choix du lieu mène à la connexion',
        (tester) async {
      await pumpBusinessApp(tester, signedIn: false, initialLocation: Routes.createBusinessLocation);
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('écran Informations : lieu obligatoire', () {
    Future<void> fillRest(WidgetTester tester) async {
      await tester.enterText(find.byKey(const ValueKey('business-name')), 'Chez Aïcha');
      await tester.enterText(find.byKey(const ValueKey('business-owner')), 'Aïcha B.');
      final photo = find.byKey(const ValueKey('business-owner-photo'));
      await tester.ensureVisible(photo);
      await tester.pumpAndSettle();
      await tester.tap(photo);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('photo-camera')));
      await tester.pumpAndSettle();
    }

    testWidgets('sans ville mémorisée : « Non choisi », erreur sous le champ, défilement jusqu\'à lui',
        (tester) async {
      await _pumpLocation(tester, LocationZones(), city: false, settle: false);
      await tester.pumpAndSettle();
      await fillRest(tester);
      await tester.ensureVisible(_field);
      await tester.pumpAndSettle();
      expect(find.descendant(of: _field, matching: find.text('Non choisi')), findsOneWidget);

      // On remonte en haut, puis « Continuer » doit ramener le champ à l'écran.
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 4000));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_field).dy, lessThan(0).or(greaterThan(780)));
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.text('Choisissez votre ville ou votre quartier.'), findsOneWidget);
      expect(find.byKey(const ValueKey('business-location-error')), findsOneWidget);
      expect(find.text('Étape 1 sur 4'), findsOneWidget);
      final top = tester.getTopLeft(_field).dy;
      expect(top, greaterThanOrEqualTo(0));
      expect(tester.getBottomLeft(_field).dy, lessThanOrEqualTo(780));
    });

    testWidgets('sans lieu, « Continuer » est refusé ; après le choix, il passe à l\'étape suivante',
        (tester) async {
      await _pumpLocation(tester, LocationZones(), city: false, settle: false);
      await tester.pumpAndSettle();
      await fillRest(tester);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Choisissez votre ville ou votre quartier.'), findsOneWidget);
      expect(find.text('Étape 2 sur 4'), findsNothing);

      await _openLocation(tester);
      await tester.tap(_city(16));
      await tester.pumpAndSettle();
      await tester.tap(_district(17));
      await tester.pumpAndSettle();
      expect(find.text('Choisissez votre ville ou votre quartier.'), findsNothing);
      expect(find.descendant(of: _field, matching: find.text('Maroua, Hardé')), findsOneWidget);

      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Étape 2 sur 4'), findsOneWidget);
      expect(currentDraft(tester).zoneId, 17);
    });

    testWidgets('la ville mémorisée préremplit le lieu, qui reste modifiable', (tester) async {
      await pumpBusinessApp(tester, overrides: [zoneRepositoryProvider.overrideWithValue(LocationZones())]);
      expect(currentDraft(tester).zoneId, 16);
      await fillRest(tester);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(find.text('Étape 2 sur 4'), findsOneWidget);
    });
  });

  group('accessibilité et mise en page', () {
    testWidgets('libellés lus : « Maroua, choisie » et « Hardé, quartier choisi »', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpLocation(tester, LocationZones());
      expect(find.bySemanticsLabel('Maroua, choisie'), findsOneWidget);
      expect(find.bySemanticsLabel('Garoua'), findsOneWidget);

      await tester.tap(_city(16));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Hardé'), findsOneWidget);
      await tester.tap(_district(17));
      await tester.pumpAndSettle();
      await _openLocation(tester);
      await tester.tap(_city(16));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Hardé, quartier choisi'), findsOneWidget);
      await tester.ensureVisible(_notFound);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('^Je ne trouve pas mon quartier')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('le champ lieu des Informations est un bouton lu avec son résumé', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBusinessApp(tester, overrides: [zoneRepositoryProvider.overrideWithValue(LocationZones())]);
      await tester.ensureVisible(_field);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Ville / Quartier : Maroua'), findsOneWidget);
      semantics.dispose();
    });

    for (final mode in [ThemeMode.dark, ThemeMode.light]) {
      testWidgets('360 px, police 130 %, $mode : pas de débordement, cibles d\'au moins 48 dp',
          (tester) async {
        await _pumpLocation(tester, LocationZones(), textScale: 1.3, mode: mode);
        expect(tester.takeException(), isNull);
        expectNoHorizontalScroll(tester);
        expect(tester.getSize(_city(16)).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(_back).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(_back).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(_search).height, greaterThanOrEqualTo(48));

        await tester.enterText(_search, 'zzz');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.enterText(_search, '');
        await tester.pumpAndSettle();

        await tester.tap(_city(16));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expectNoHorizontalScroll(tester);
        for (final id in [17, 18]) {
          expect(tester.getSize(_district(id)).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(_district(id)).width, lessThanOrEqualTo(360));
        }
        await tester.ensureVisible(_notFound);
        await tester.pumpAndSettle();
        expect(tester.getSize(_notFound).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      });
    }
  });
}

extension on Matcher {
  Matcher or(Matcher other) => anyOf(this, other);
}
