// T122 : mesures de performance faisables sans téléphone. La liste de résultats est paresseuse
// (500 éléments en mémoire, seuls les visibles sont construits), le défilement ne reconstruit
// pas l'en-tête, et l'écran de 200 résultats se construit sous un seuil généreux.
import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/l10n/l10n.dart';
import 'package:netbuis/core/theme/app_theme.dart';
import 'package:netbuis/features/search/application/search_controller.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';
import 'package:netbuis/features/search/presentation/screens/results_screen.dart';
import 'package:netbuis/features/search/presentation/widgets/offline_banner.dart';
import 'package:netbuis/features/search/presentation/widgets/result_card.dart';

class _Fixed extends SearchController {
  _Fixed(this._state);
  final SearchState _state;

  @override
  SearchState build() => _state;
}

SearchState _state(int n, {bool fromCache = false, bool hasMore = false}) => SearchState(
      status: SearchStatus.results,
      fromCache: fromCache,
      hasMore: hasMore,
      count: n,
      items: [
        for (var i = 0; i < n; i++)
          SearchResult(
            id: i + 1,
            name: 'Commerce $i',
            kind: i.isEven ? 'produit' : 'service',
            secteur: 'Alimentation',
            zone: ResultZone(id: 1, name: 'Hardé'),
            repere: 'Près du marché',
            descriptionActivite: 'Riz, huile et condiments',
          ),
      ],
    );

Future<ScrollController> _pump(WidgetTester tester, SearchState s) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final scroll = ScrollController();
  addTearDown(scroll.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [searchControllerProvider.overrideWith(() => _Fixed(s))],
    child: MaterialApp(
      theme: AppTheme.light,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: SearchResultsView(scroll: scroll, onChangeCity: () {}),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return scroll;
}

void main() {
  testWidgets('500 résultats : seuls les éléments visibles sont construits', (tester) async {
    await _pump(tester, _state(500));
    final built = find.byType(ResultCard).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(15), reason: 'écran de 780 px : une dizaine de cartes au plus');
    expect(find.text('Commerce 499'), findsNothing);
  });

  testWidgets('le défilement garde un nombre borné d\'éléments construits', (tester) async {
    final scroll = await _pump(tester, _state(500));
    for (var i = 0; i < 20; i++) {
      await tester.drag(find.byKey(const Key('search-results')), const Offset(0, -600));
      await tester.pump();
      expect(find.byType(ResultCard).evaluate().length, lessThan(15));
    }
    expect(scroll.offset, greaterThan(1000));
  });

  testWidgets('le défilement ne reconstruit pas l\'en-tête (bandeau hors connexion)', (tester) async {
    await _pump(tester, _state(500, fromCache: true));
    expect(find.byType(OfflineBanner), findsOneWidget);
    var bannerRebuilds = 0;
    var cardRebuilds = 0;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      if (element.widget is OfflineBanner) bannerRebuilds++;
      if (element.widget is ResultCard) cardRebuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    for (var i = 0; i < 10; i++) {
      await tester.drag(find.byKey(const Key('search-results')), const Offset(0, -300));
      await tester.pump();
    }
    expect(bannerRebuilds, 0);
    // Les cartes déjà visibles ne sont pas reconstruites non plus : seules les nouvelles le sont
    // (dix glissements de 300 px font entrer au plus une trentaine de cartes).
    expect(cardRebuilds, lessThan(40));
  });

  testWidgets('écran de 200 résultats : temps de construction sous 3 s', (tester) async {
    // Seuil volontairement généreux (machine de test, pas un téléphone) : il ne détecte que
    // les régressions grossières (liste construite en entier : ~200 cartes au lieu d'une dizaine).
    final sw = Stopwatch()..start();
    await _pump(tester, _state(200));
    sw.stop();
    // ignore: avoid_print
    print('T122 construction de 200 résultats : ${sw.elapsedMilliseconds} ms');
    expect(sw.elapsedMilliseconds, lessThan(3000));
  });

  testWidgets('test d\'échec : une liste non paresseuse serait détectée', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            for (var i = 0; i < 200; i++) SizedBox(height: 100, child: Text('x$i')),
          ]),
        ),
      ),
    ));
    expect(find.byType(SizedBox).evaluate().length, greaterThan(15));
  });
}
