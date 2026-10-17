import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/app.dart';
import 'package:netbuis/core/config/feature_flags.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/storage/prefs.dart';
import 'package:netbuis/features/auth/presentation/screens/login_screen.dart';
import 'package:netbuis/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:netbuis/core/l10n/l10n.dart';
import 'package:netbuis/core/theme/app_theme.dart';
import 'package:netbuis/core/widgets/netbuis_logo.dart';

import '../auth/auth_test_helpers.dart';

class MemoryPrefs implements AppPrefs {
  MemoryPrefs({
    this.seen = false,
    this.throwOnRead = false,
    this.city,
    this.throwOnSaveCity = false,
  });

  bool seen;
  bool throwOnRead;

  /// Ville mémorisée (null : aucune).
  SelectedCity? city;
  bool throwOnSaveCity;

  @override
  Future<bool> isOnboardingSeen() async {
    if (throwOnRead) throw StateError('préférences illisibles');
    return seen;
  }

  @override
  Future<void> markOnboardingSeen() async => seen = true;

  @override
  Future<SelectedCity?> getCity() async {
    if (throwOnRead) throw StateError('préférences illisibles');
    return city;
  }

  @override
  Future<void> saveCity(SelectedCity value) async {
    if (throwOnSaveCity) throw StateError('écriture impossible');
    city = value;
  }
}

Future<void> _pumpApp(
  WidgetTester tester,
  MemoryPrefs prefs, {
  double textScale = 1.0,
  bool signedIn = true,
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
        // Session ouverte par défaut : ces tests vérifient le parcours vers l'Accueil.
        tokenStorageProvider.overrideWithValue(
          MemoryTokenStorage(refresh: signedIn ? 'ref-1' : null),
        ),
      ],
      child: const NetBuisApp(themeMode: ThemeMode.dark),
    ),
  );
  await tester.pumpAndSettle();
}

/// Ville déjà mémorisée : les tests de la Découverte qui vérifient l'arrivée à
/// l'Accueil ou à la connexion ne passent alors pas par « Choisir ma ville »
/// (ce passage est testé dans choose_city_test.dart).
const _maroua = SelectedCity(id: 16, name: 'Maroua');

const _titles = [
  'Trouvez ce que vous cherchez',
  'Appelez en un geste',
  'Explorez par quartier',
  'Suivez le forum',
  'Créez votre compte business',
];

const _bodies = [
  'Recherchez un produit ou un service et découvrez les commerçants qui le proposent près de chez vous.',
  "NetBuis n'affiche jamais le numéro. Votre téléphone peut cependant l'afficher pendant l'appel et le garder dans son journal d'appels. Sur iPhone, le système demande une confirmation qui montre le numéro.",
  "Parcourez les commerces quartier par quartier, dans votre ville — et bientôt dans d'autres villes.",
  'Découvrez les nouveautés publiées par les commerçants et commentez leurs publications.',
  'Publiez vos produits ou services pour être trouvé près de chez vous.',
];

void _expectNoHorizontalScroll(WidgetTester tester) {
  for (final s in tester.widgetList<Scrollable>(find.byType(Scrollable))) {
    expect(s.axis, Axis.vertical);
  }
}

void main() {
  group('lancement', () {
    testWidgets('affiche logo, slogan, Commencer et la version (360 px)', (tester) async {
      await _pumpApp(tester, MemoryPrefs());

      expect(find.byType(NetBuisLogo), findsOneWidget);
      expect(
        find.text('Trouvez un produit ou un service.\nAppelez directement. Près de chez vous.'),
        findsOneWidget,
      );
      expect(find.text('Commencer'), findsOneWidget);
      expect(find.text('v1.0 — Maroua, Cameroun'), findsOneWidget);
      expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
      _expectNoHorizontalScroll(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('première ouverture : Commencer mène à la Découverte', (tester) async {
      await _pumpApp(tester, MemoryPrefs());
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text(_titles[0]), findsOneWidget);
    });

    testWidgets('déjà vue : Commencer saute la Découverte et va à l\'accueil', (tester) async {
      await _pumpApp(tester, MemoryPrefs(seen: true, city: _maroua));
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
    });

    testWidgets('déjà vue mais non connecté : Commencer mène à la connexion', (tester) async {
      await _pumpApp(tester, MemoryPrefs(seen: true, city: _maroua), signedIn: false);
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNothing);
    });

    testWidgets('préférence illisible : la Découverte est montrée', (tester) async {
      await _pumpApp(tester, MemoryPrefs(throwOnRead: true));
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });
  });

  group('Découverte', () {
    Future<void> openOnboarding(WidgetTester tester, MemoryPrefs prefs,
        {double textScale = 1.0}) async {
      await _pumpApp(tester, prefs, textScale: textScale);
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();
    }

    testWidgets('5 diapositives avec les textes exacts, Suivant puis Commencer', (tester) async {
      final semantics = tester.ensureSemantics();
      final prefs = MemoryPrefs(city: _maroua);
      await openOnboarding(tester, prefs);

      for (var i = 0; i < 5; i++) {
        expect(find.text(_titles[i]), findsOneWidget, reason: 'titre $i');
        expect(find.text(_bodies[i]), findsOneWidget, reason: 'texte $i');
        expect(find.bySemanticsLabel(RegExp('Diapositive ${i + 1} sur 5')), findsOneWidget);
        expect(find.byKey(ValueKey('dot-$i')), findsOneWidget);
        if (i < 4) {
          expect(find.text('Suivant'), findsOneWidget);
          await tester.tap(find.text('Suivant'));
          await tester.pumpAndSettle();
        }
      }
      expect(find.text('Suivant'), findsNothing);
      expect(find.text('Passer'), findsOneWidget);
      expect(prefs.seen, isFalse);

      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();
      expect(prefs.seen, isTrue);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      semantics.dispose();
    });

    testWidgets('non connecté : Passer mène à la connexion', (tester) async {
      final prefs = MemoryPrefs(city: _maroua);
      await _pumpApp(tester, prefs, signedIn: false);
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();

      expect(prefs.seen, isTrue);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNothing);
    });

    testWidgets('Passer saute la Découverte et la mémorise', (tester) async {
      final prefs = MemoryPrefs(city: _maroua);
      await openOnboarding(tester, prefs);
      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();

      expect(prefs.seen, isTrue);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
    });

    testWidgets('1re ouverture seulement : après Passer, plus de Découverte', (tester) async {
      final prefs = MemoryPrefs(city: _maroua);
      await openOnboarding(tester, prefs);
      await tester.tap(find.text('Passer'));
      await tester.pumpAndSettle();

      // Nouveau lancement avec les mêmes préférences.
      await tester.pumpWidget(const SizedBox());
      await _pumpApp(tester, prefs);
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
    });

    testWidgets('boutons >= 48 dp, police 130 %, pas de défilement horizontal', (tester) async {
      await openOnboarding(tester, MemoryPrefs(), textScale: 1.3);

      for (var i = 0; i < 5; i++) {
        for (final finder in [find.byType(FilledButton), find.byType(TextButton)]) {
          final size = tester.getSize(finder);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        _expectNoHorizontalScroll(tester);
        expect(tester.takeException(), isNull, reason: 'diapositive $i');
        if (i < 4) {
          await tester.tap(find.text('Suivant'));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('si l\'équipe est activée, la 5e diapositive est celle de la maquette',
        (tester) async {
      expect(FeatureFlags.teamEnabled, isFalse);
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.dark,
            locale: const Locale('fr'),
            localizationsDelegates: const [
              L10n.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: L10n.supportedLocales,
            home: const OnboardingScreen(teamEnabled: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Suivant'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Faites grandir NetBuis'), findsOneWidget);
      expect(
        find.text(
          "Créez votre compte business ou rejoignez l'équipe NetBuis pour parrainer de nouveaux commerçants.",
        ),
        findsOneWidget,
      );
      expect(find.text('Créez votre compte business'), findsNothing);
    });
  });
}
