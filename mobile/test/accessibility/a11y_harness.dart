// Harnais d'accessibilité (T120) : monte un écran à 360 px avec des dépôts factices, dans un
// thème et à une taille de police donnés, et fournit les contrôles communs.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:netbuis/features/business/application/business_draft_controller.dart';
import 'package:netbuis/features/business/data/models/business_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/app.dart';
import 'package:netbuis/core/config/env.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/features/auth/presentation/widgets/otp_input.dart';
import 'package:netbuis/features/business/application/business_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/auth_test_helpers.dart';
import '../features/auth/login_test_helpers.dart';
import '../features/business/business_test_helpers.dart';

/// Les écrans lisent les dépôts factices de l'application : sans `USE_FAKE_API=true` ils
/// appelleraient le réseau. Les tests d'accessibilité sont alors ignorés (message explicite).
const bool a11yFakeApi = Env.useFakeApi;
const String a11ySkipReason = 'lancer avec --dart-define=USE_FAKE_API=true';

/// Un écran à auditer : où l'ouvrir, et comment le mettre dans l'état voulu.
class A11yScreen {
  const A11yScreen(
    this.id,
    this.route,
    this.shows, {
    this.prepare,
    this.draft,
    this.overrides = const [],
    this.mockup = true,
    this.critical = false,
    this.signedIn = true,
    this.spec = false,
    this.numericKeys = const [],
    this.text,
  });

  /// Nom court (grille d'audit).
  final String id;
  final String route;

  /// Type du widget qui doit être à l'écran (prouve qu'on n'audite pas une redirection).
  final Type shows;

  /// Étape facultative après l'ouverture (ouvrir une feuille, saisir un numéro…).
  final Future<void> Function(WidgetTester tester)? prepare;

  /// Brouillon de création à installer avant d'ouvrir [route] (écrans à étapes).
  final Future<BusinessDraft> Function()? draft;
  final List<Override> overrides;

  /// Faux : écran sans maquette.
  final bool mockup;

  /// Vrai : testé aussi à 200 % de police.
  final bool critical;
  final bool signedIn;

  /// Vrai : fait partie des 16 écrans de la liste de docs/spec/ACCESSIBILITE.md.
  final bool spec;

  /// Texte qui doit être à l'écran (prouve l'état voulu : erreur, liste vide…).
  final String? text;

  /// Clés des champs de saisie de nombres de l'écran (vérifiés au clavier numérique).
  final List<Key> numericKeys;
}

/// Monte l'application sur [screen], à 360×780 px ([height] plus grand : écran « tout déplié »,
/// pour les contrôles de la plateforme qui se trompent sur les éléments coupés par le bord).
Future<void> pumpA11y(
  WidgetTester tester,
  A11yScreen screen, {
  required double scale,
  required ThemeMode mode,
  double height = 780,
}) async {
  SharedPreferences.setMockInitialValues({});
  _renderErrors.clear();
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    // Décrit tout de suite l'erreur : plus tard, l'arbre de widgets peut avoir changé.
    _renderErrors.add(details
        .toString()
        .split('\n')
        .where((l) => l.contains('.dart:') || l.contains('creator:'))
        .take(3)
        .join(' | '));
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
  tester.view.physicalSize = Size(360, height);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FlowRepository()),
        tokenStorageProvider.overrideWithValue(
            MemoryTokenStorage(refresh: screen.signedIn ? 'ref-1' : null)),
        appPrefsProvider.overrideWithValue(MemoryPrefs(seen: true)),
        speechServiceProvider.overrideWithValue(FakeSpeechService()),
        photoPickerProvider.overrideWithValue(FakePhotoPicker()),
        smsCodeSourceProvider.overrideWithValue(FakeSmsSource()),
        ...screen.overrides,
      ],
      child: NetBuisApp(
        themeMode: mode,
        initialLocation: screen.draft == null ? screen.route : Routes.home,
      ),
    ),
  );
  await settle(tester);
  final makeDraft = screen.draft;
  final draft = makeDraft == null ? null : await makeDraft();
  if (draft != null) {
    final context = tester.element(find.byType(Scaffold).first);
    final container = ProviderScope.containerOf(context);
    // Le brouillon se vide quand plus rien ne l'écoute : on le garde le temps du test.
    final keep = container.listen(businessDraftProvider, (_, __) {});
    addTearDown(keep.close);
    container.read(businessDraftProvider.notifier).update((_) => draft);
    GoRouter.of(context).push(screen.route);
    await settle(tester);
  }
  final prepare = screen.prepare;
  if (prepare != null) {
    await prepare(tester);
    await settle(tester);
  }
}

/// Laisse l'écran se stabiliser ; un écran qui anime en continu (chargement) est avancé à la main.
Future<void> settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
  } on FlutterError {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Erreurs de rendu vues depuis l'ouverture de l'écran (pour nommer le widget fautif).
final List<String> _renderErrors = [];

String _culprits() => _renderErrors.join('\n');

/// Aucune exception de rendu (débordement RenderFlex, etc.) depuis l'ouverture de l'écran.
void expectNoRenderError(WidgetTester tester, String where) {
  final errors = <Object>[];
  Object? e;
  while ((e = tester.takeException()) != null) {
    errors.add(e!);
  }
  expect(errors, isEmpty,
      reason: '$where : ${errors.join('\n')}\n${_culprits()}');
}

/// Aucun défilement de l'écran n'est horizontal (le défilement interne d'un champ de texte sur
/// une seule ligne n'est pas un défilement d'écran).
void expectNoHorizontalScroll(WidgetTester tester, String where) {
  for (final e in find.byType(Scrollable).evaluate()) {
    final inField = find
        .ancestor(
            of: find.byElementPredicate((x) => x == e),
            matching: find.byType(EditableText))
        .evaluate()
        .isNotEmpty;
    if (inField) continue;
    final axis = (e.widget as Scrollable).axis;
    expect(axis, Axis.vertical,
        reason: '$where : défilement horizontal trouvé');
  }
}

/// Aucun élément dessiné ne dépasse la largeur de l'écran (360 px).
void expectInsideWidth(WidgetTester tester, String where) {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  for (final text in find.byType(RenderParagraph).evaluate()) {
    final box = text.renderObject! as RenderParagraph;
    if (!box.attached || !box.hasSize) continue;
    final right = box.localToGlobal(Offset(box.size.width, 0)).dx;
    final left = box.localToGlobal(Offset.zero).dx;
    // Un texte hors écran dans une liste verticale n'est pas un souci ; un texte coupé à droite l'est.
    if (left < width) {
      expect(right, lessThanOrEqualTo(width + 0.5),
          reason:
              '$where : un texte dépasse à droite (${box.text.toPlainText()})');
    }
  }
}

/// L'écran voulu est bien celui qui est affiché (et non une redirection ou une page d'erreur).
void expectShown(A11yScreen screen) {
  final found = find.byType(screen.shows, skipOffstage: false);
  expect(found, findsWidgets,
      reason: '${screen.id} : ${screen.shows} absent (redirection ?)');
  final text = screen.text;
  if (text != null) {
    expect(find.textContaining(text), findsWidgets,
        reason: '${screen.id} : « $text » absent');
  }
}

/// Contrôles de la plateforme sur l'écran affiché : cibles ≥ 48 dp, étiquettes, contraste.
/// Renvoie la liste des problèmes (vide = conforme) pour que le test les affiche tous.
Future<List<String>> guidelineProblems(WidgetTester tester,
    {bool contrast = true}) async {
  final problems = <String>[];
  Future<void> check(String name, Future<String?> Function() run) async {
    final result = await run();
    if (result != null) problems.add('$name : $result');
  }

  await check(
      'cible tactile < 48 dp',
      () async => await meetsGuideline(androidTapTargetGuideline)
          .matchAsync(tester) as String?);
  await check(
      'cible sans étiquette',
      () async => await meetsGuideline(labeledTapTargetGuideline)
          .matchAsync(tester) as String?);
  if (contrast) {
    await check(
        'contraste < 4,5:1',
        () async => await meetsGuideline(textContrastGuideline)
            .matchAsync(tester) as String?);
  }
  return problems;
}

/// La zone qui défile verticalement la plus grande de l'écran (null s'il n'y en a pas).
ScrollableState? _mainScrollable(WidgetTester tester) {
  ScrollableState? best;
  var bestArea = 0.0;
  for (final e in find.byType(Scrollable).evaluate()) {
    final inField = find
        .ancestor(
            of: find.byElementPredicate((x) => x == e),
            matching: find.byType(EditableText))
        .evaluate()
        .isNotEmpty;
    final state = (e as StatefulElement).state as ScrollableState;
    if (inField || state.widget.axis != Axis.vertical) continue;
    final size = tester.getSize(find.byWidget(e.widget));
    if (size.width * size.height > bestArea) {
      bestArea = size.width * size.height;
      best = state;
    }
  }
  return best;
}

/// Appelle [check] sur l'écran tel qu'ouvert, puis après chaque défilement d'un écran
/// (les éléments sous la ligne de flottaison ne sont construits qu'en défilant).
Future<void> checkEveryPage(
    WidgetTester tester, Future<void> Function() check) async {
  await check();
  final state = _mainScrollable(tester);
  if (state == null) return;
  for (var i = 0; i < 20; i++) {
    final position = state.position;
    if (position.pixels >= position.maxScrollExtent - 0.5) break;
    position.jumpTo((position.pixels + position.viewportDimension * 0.8)
        .clamp(0.0, position.maxScrollExtent));
    await settle(tester);
    await check();
  }
}
