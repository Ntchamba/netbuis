import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/app.dart';
import 'package:netbuis/core/data/zones/zone.dart';
import 'package:netbuis/core/data/zones/zone_repository.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/core/storage/prefs.dart';
import 'package:netbuis/features/auth/presentation/screens/login_screen.dart';
import 'package:netbuis/features/onboarding/presentation/screens/choose_city_screen.dart';

import '../account/account_test_helpers.dart';
import '../auth/auth_test_helpers.dart';
import '../auth/login_test_helpers.dart';

const _maroua = Zone(id: 16, name: 'Maroua', level: ZoneLevel.villeVillage, parent: 12);
const _garoua = Zone(id: 30, name: 'Garoua', level: ZoneLevel.villeVillage, parent: 13);
const _long = Zone(
    id: 31,
    name: 'Ngaoundéré-sur-la-Vina du Nord',
    level: ZoneLevel.villeVillage,
    parent: 13);

/// Dépôt de zones scénarisé : les erreurs de la file sont levées une par une.
class ScriptedZones implements ZoneRepository {
  ScriptedZones(this.cities);

  List<Zone> cities;
  final List<ApiException> errors = [];
  int calls = 0;
  ZoneLevel? lastLevel;

  @override
  Future<List<Zone>> listZones({ZoneLevel? level, int? parent}) async {
    calls++;
    lastLevel = level;
    if (errors.isNotEmpty) throw errors.removeAt(0);
    return cities;
  }

  @override
  Future<ZoneDetail> getZone(int id) async => throw const ApiException(ApiErrorCode.unknown, statusCode: 404);
}

class _FailingSavePrefs extends MemoryPrefs {
  _FailingSavePrefs({super.seen, super.city});

  @override
  Future<void> saveCity(SelectedCity value) async => throw StateError('écriture impossible');
}

Future<void> _pump(
  WidgetTester tester, {
  required MemoryPrefs prefs,
  required ScriptedZones zones,
  String initialLocation = Routes.splash,
  bool signedIn = true,
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.dark,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPrefsProvider.overrideWithValue(prefs),
        zoneRepositoryProvider.overrideWithValue(zones),
        accountRepositoryProvider.overrideWithValue(ScriptedAccountRepository()),
        authRepositoryProvider.overrideWithValue(FlowRepository()),
        tokenStorageProvider
            .overrideWithValue(MemoryTokenStorage(refresh: signedIn ? 'ref-1' : null)),
      ],
      child: NetBuisApp(themeMode: mode, initialLocation: initialLocation),
    ),
  );
  await tester.pumpAndSettle();
}

void _expectNoHorizontalScroll(WidgetTester tester) {
  for (final s in tester.widgetList<Scrollable>(find.byType(Scrollable))) {
    expect(s.axis, Axis.vertical);
  }
}

Finder _card(Zone z) => find.byKey(ValueKey('city-${z.id}'));

void main() {
  group('flux après la Découverte', () {
    testWidgets('sans ville mémorisée : Passer mène à « Choisir ma ville », puis à l\'Accueil',
        (tester) async {
      final prefs = MemoryPrefs(city: null);
      final zones = ScriptedZones([_maroua]);
      await _pump(tester, prefs: prefs, zones: zones);
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();

      expect(prefs.seen, isTrue);
      expect(find.byType(ChooseCityScreen), findsOneWidget);
      expect(find.text('Choisir ma ville'), findsOneWidget);
      expect(zones.lastLevel, ZoneLevel.villeVillage);
      expect(find.byType(NavigationDestination), findsNothing);
      // Une seule ville : une seule carte, rien d'autre à faire défiler.
      expect(find.text('Maroua'), findsOneWidget);
      expect(find.byKey(const ValueKey('city-back')), findsNothing);

      await tester.tap(_card(_maroua));
      await tester.pumpAndSettle();

      expect(prefs.city, const SelectedCity(id: 16, name: 'Maroua'));
      expect(find.byType(ChooseCityScreen), findsNothing);
      expect(onHome(), isTrue);
    });

    testWidgets('« Commencer » de la Découverte (5e diapositive) mène aussi au choix',
        (tester) async {
      final prefs = MemoryPrefs(city: null);
      await _pump(tester, prefs: prefs, zones: ScriptedZones([_maroua]));
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Suivant'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      expect(find.byType(ChooseCityScreen), findsOneWidget);
    });

    testWidgets('non connecté : après le choix, la garde mène à la connexion', (tester) async {
      final prefs = MemoryPrefs(city: null);
      await _pump(tester, prefs: prefs, zones: ScriptedZones([_maroua]), signedIn: false);
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();
      expect(find.byType(ChooseCityScreen), findsOneWidget);

      await tester.tap(_card(_maroua));
      await tester.pumpAndSettle();

      expect(prefs.city?.name, 'Maroua');
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('ville déjà mémorisée : l\'écran n\'est pas réaffiché', (tester) async {
      final zones = ScriptedZones([_maroua]);
      await _pump(
          tester, prefs: MemoryPrefs(seen: true, city: _prefsMaroua), zones: zones);
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      expect(find.byType(ChooseCityScreen), findsNothing);
      expect(zones.calls, 0);
      expect(onHome(), isTrue);
    });

    testWidgets('Découverte déjà vue mais aucune ville : le choix est demandé', (tester) async {
      await _pump(tester,
          prefs: MemoryPrefs(seen: true, city: null), zones: ScriptedZones([_maroua]));
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      expect(find.byType(ChooseCityScreen), findsOneWidget);
    });

    testWidgets('mémorisation impossible : on arrive quand même à l\'Accueil', (tester) async {
      final prefs = _FailingSavePrefs(seen: true, city: null);
      await _pump(tester, prefs: prefs, zones: ScriptedZones([_maroua]));
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();
      await tester.tap(_card(_maroua));
      await tester.pumpAndSettle();

      expect(prefs.city, isNull);
      expect(onHome(), isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('écran « Choisir ma ville »', () {
    testWidgets('réseau coupé : message, puis « Réessayer » affiche les villes', (tester) async {
      final zones = ScriptedZones([_maroua])
        ..errors.add(const ApiException(ApiErrorCode.network));
      await _pump(tester,
          prefs: MemoryPrefs(city: null), zones: zones, initialLocation: Routes.chooseCity);

      expect(find.text('Pas de connexion. Vérifiez votre réseau et réessayez.'), findsOneWidget);
      expect(find.text('Maroua'), findsNothing);
      final retry = find.byKey(const ValueKey('city-retry'));
      expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));

      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(zones.calls, 2);
      expect(find.text('Maroua'), findsOneWidget);
      expect(find.byKey(const ValueKey('city-retry')), findsNothing);
    });

    testWidgets('erreur du serveur : message générique, jamais le texte du serveur',
        (tester) async {
      final zones = ScriptedZones([])
        ..errors.add(const ApiException(ApiErrorCode.unknown, message: 'secret interne'));
      await _pump(tester,
          prefs: MemoryPrefs(city: null), zones: zones, initialLocation: Routes.chooseCity);

      expect(find.text('Une erreur est survenue. Réessayez.'), findsOneWidget);
      expect(find.textContaining('secret'), findsNothing);
    });

    testWidgets('aucune ville : message simple et « Réessayer » (pas de blocage définitif)',
        (tester) async {
      final zones = ScriptedZones([]);
      await _pump(tester,
          prefs: MemoryPrefs(city: null), zones: zones, initialLocation: Routes.chooseCity);

      expect(find.text("Aucune ville disponible pour l'instant"), findsOneWidget);
      zones.cities = [_maroua];
      await tester.tap(find.byKey(const ValueKey('city-retry')));
      await tester.pumpAndSettle();

      expect(find.text("Aucune ville disponible pour l'instant"), findsNothing);
      expect(find.text('Maroua'), findsOneWidget);
    });

    testWidgets('chargement : indicateur annoncé', (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final gate = _Gate();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPrefsProvider.overrideWithValue(MemoryPrefs(city: null)),
            zoneRepositoryProvider.overrideWithValue(_SlowZones(gate)),
            tokenStorageProvider.overrideWithValue(MemoryTokenStorage()),
          ],
          child: const NetBuisApp(initialLocation: Routes.chooseCity),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Chargement des villes'), findsOneWidget);

      gate.open([_maroua]);
      await tester.pumpAndSettle();
      expect(find.text('Maroua'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('plusieurs villes, police 130 %, 360 px : grille sans défilement horizontal',
        (tester) async {
      await _pump(
        tester,
        prefs: MemoryPrefs(city: null),
        zones: ScriptedZones([_maroua, _garoua, _long]),
        initialLocation: Routes.chooseCity,
        textScale: 1.3,
      );

      expect(find.byType(InkWell), findsNWidgets(3));
      for (final z in [_maroua, _garoua, _long]) {
        final size = tester.getSize(_card(z));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(tester.getRect(_card(z)).right, lessThanOrEqualTo(360));
      }
      // Deux colonnes : Maroua et Garoua côte à côte.
      expect(tester.getTopLeft(_card(_garoua)).dy, tester.getTopLeft(_card(_maroua)).dy);
      expect(tester.getTopLeft(_card(_garoua)).dx, greaterThan(tester.getTopLeft(_card(_maroua)).dx));
      _expectNoHorizontalScroll(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('thème clair : aucune erreur d\'affichage', (tester) async {
      await _pump(tester,
          prefs: MemoryPrefs(city: null),
          zones: ScriptedZones([_maroua]),
          initialLocation: Routes.chooseCity,
          mode: ThemeMode.light);
      expect(find.text('Maroua'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Profil → Ma ville', () {
    testWidgets('l\'entrée affiche la ville mémorisée (48 dp au moins)', (tester) async {
      await _pump(tester,
          prefs: MemoryPrefs(seen: true, city: _prefsMaroua),
          zones: ScriptedZones([_maroua]),
          initialLocation: Routes.profile);

      expect(find.text('Ma ville'), findsOneWidget);
      expect(find.text('Maroua'), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('profile-city'))).height,
          greaterThanOrEqualTo(48));
    });

    testWidgets('aucune ville : « Non choisie »', (tester) async {
      await _pump(tester,
          prefs: MemoryPrefs(seen: true, city: null),
          zones: ScriptedZones([_maroua]),
          initialLocation: Routes.profile);
      expect(find.text('Non choisie'), findsOneWidget);
    });

    testWidgets('changer de ville : l\'écran se rouvre, le choix est mémorisé et affiché',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final prefs = MemoryPrefs(seen: true, city: _prefsMaroua);
      await _pump(tester,
          prefs: prefs, zones: ScriptedZones([_maroua, _garoua]), initialLocation: Routes.profile);

      await tester.tap(find.byKey(const ValueKey('profile-city')));
      await tester.pumpAndSettle();

      expect(find.byType(ChooseCityScreen), findsOneWidget);
      expect(find.bySemanticsLabel('Maroua, sélectionnée'), findsOneWidget);
      expect(find.bySemanticsLabel('Garoua'), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('city-back'))).shortestSide,
          greaterThanOrEqualTo(48));

      await tester.tap(_card(_garoua));
      await tester.pumpAndSettle();

      expect(prefs.city, const SelectedCity(id: 30, name: 'Garoua'));
      expect(find.byType(ChooseCityScreen), findsNothing);
      expect(find.text('Mon profil'), findsOneWidget);
      expect(find.text('Garoua'), findsOneWidget);
      expect(find.text('Maroua'), findsNothing);
      semantics.dispose();
    });

    testWidgets('retour sans choisir : la ville ne change pas', (tester) async {
      final prefs = MemoryPrefs(seen: true, city: _prefsMaroua);
      await _pump(tester,
          prefs: prefs, zones: ScriptedZones([_maroua, _garoua]), initialLocation: Routes.profile);
      await tester.tap(find.byKey(const ValueKey('profile-city')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('city-back')));
      await tester.pumpAndSettle();

      expect(find.text('Mon profil'), findsOneWidget);
      expect(prefs.city, _prefsMaroua);
      expect(find.text('Maroua'), findsOneWidget);
    });
  });
}

const _prefsMaroua = SelectedCity(id: 16, name: 'Maroua');

/// Retient la réponse du dépôt tant qu'on ne l'ouvre pas (état « chargement »).
class _Gate {
  final List<Zone> _result = [];
  bool isOpen = false;
  void open(List<Zone> zones) {
    _result.addAll(zones);
    isOpen = true;
  }
}

class _SlowZones implements ZoneRepository {
  _SlowZones(this.gate);

  final _Gate gate;

  @override
  Future<List<Zone>> listZones({ZoneLevel? level, int? parent}) async {
    while (!gate.isOpen) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return gate._result;
  }

  @override
  Future<ZoneDetail> getZone(int id) async => throw const ApiException(ApiErrorCode.unknown, statusCode: 404);
}
