import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:netbuis/core/data/referentials/referential_repository_fake.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/l10n/l10n.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/theme/app_theme.dart';
import 'package:netbuis/features/call/data/models/call_session.dart';
import 'package:netbuis/features/home/presentation/screens/home_screen.dart';
import 'package:netbuis/features/search/application/search_controller.dart';
import 'package:netbuis/features/search/data/models/search_query.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';
import 'package:netbuis/features/search/data/models/suggestion.dart';
import 'package:netbuis/features/search/data/repositories/search_repository_fake.dart';
import 'package:netbuis/features/search/presentation/screens/search_screen.dart';

import '../auth/login_test_helpers.dart' show MemoryPrefs;
import '../call/call_test_helpers.dart';

const _data = [
  SearchResult(
      id: 1, name: 'Boutique Aminatou', kind: 'produit', secteur: 'Alimentation',
      secteurCode: 'alimentation', zone: ResultZone(id: 17, name: 'Hardé'),
      repere: 'Près du marché', descriptionActivite: 'Riz, huile et condiments'),
  SearchResult(
      id: 2, name: 'Pharmacie du Centre', kind: 'produit', secteur: 'Santé',
      secteurCode: 'pharmacie_sante', zone: ResultZone(id: 19, name: 'Domayo'),
      descriptionActivite: 'Médicaments et conseils'),
  SearchResult(
      id: 3, name: 'Couturier Ibrahim', kind: 'service', secteur: 'Artisanat',
      secteurCode: 'artisanat_services_domicile', zone: ResultZone(id: 18, name: 'Dougoï'),
      descriptionActivite: 'Confection sur mesure', verifie: true),
];

class _Search extends SearchRepositoryFake {
  _Search() : super(data: _data);
  bool fail = false;
  final List<String> suggestionCalls = [];

  @override
  Future<SearchPage> search(SearchQuery query, {int page = 1}) async {
    if (fail) throw const ApiException(ApiErrorCode.network);
    return super.search(query, page: page);
  }

  @override
  Future<List<Suggestion>> suggestions(String q) {
    suggestionCalls.add(q);
    return super.suggestions(q);
  }
}

Future<_Search> _pump(WidgetTester tester, {_Search? repo, FakeCallRepository? call}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final search = repo ?? _Search();
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, _) => Scaffold(
          body: HomeScreen(onOpenSearch: () => context.push('/search')),
        ),
      ),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/choose-city', builder: (_, __) => const Scaffold(body: Text('PAGE-VILLE'))),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appPrefsProvider.overrideWithValue(MemoryPrefs()),
      searchRepositoryProvider.overrideWithValue(search),
      referentialRepositoryProvider.overrideWithValue(const ReferentialRepositoryFake()),
      ...callOverrides(FakeCallChannel(), call ?? FakeCallRepository()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      locale: const Locale('fr'),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('home-search')));
  await tester.pumpAndSettle();
  return search;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('search-field')), text);
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("l'Accueil ouvre la recherche : champ, filtres, commerces de la ville", (tester) async {
    await _pump(tester);
    expect(find.byKey(const Key('search-field')), findsOneWidget);
    expect(find.byKey(const Key('search-filters')), findsOneWidget);
    expect(find.text('Boutique Aminatou'), findsOneWidget);
    expect(find.text('Appeler'), findsWidgets);
  });

  testWidgets('suggestions pendant la frappe, le choix lance la recherche', (tester) async {
    final repo = await _pump(tester);
    await _type(tester, 'ri');
    expect(repo.suggestionCalls, ['ri']);
    expect(find.byKey(const Key('suggestions-list')), findsOneWidget);
    expect(find.text('riz local'), findsOneWidget);
    await tester.tap(find.text('riz local'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('suggestions-list')), findsNothing);
    expect(tester.widget<TextField>(find.byKey(const Key('search-field'))).controller!.text,
        'riz local');
  });

  testWidgets('un seul caractère : aucune suggestion demandée', (tester) async {
    final repo = await _pump(tester);
    await _type(tester, 'r');
    expect(repo.suggestionCalls, isEmpty);
    expect(find.byKey(const Key('suggestions-list')), findsNothing);
  });

  testWidgets('résultats : carte complète, aucune étiquette « abonné », aucun numéro', (tester) async {
    await _pump(tester);
    await _type(tester, 'riz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Boutique Aminatou'), findsOneWidget);
    expect(find.text('Riz, huile et condiments'), findsOneWidget);
    expect(find.text('Produit'), findsOneWidget);
    expect(find.text('Près du marché — Hardé'), findsOneWidget);
    expect(find.text('Appeler'), findsOneWidget);
    expect(find.textContaining(RegExp('abonn|premium|sponsor', caseSensitive: false)), findsNothing);
    expect(find.textContaining('+237'), findsNothing);
  });

  testWidgets('le bouton Appeler est activé (T052) : ouvre la feuille Orange / MTN du commerce',
      (tester) async {
    final call = FakeCallRepository();
    await _pump(tester, call: call);
    final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(button.onPressed, isNotNull);
    await tester.tap(find.byType(FilledButton).first);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('call-choose')), findsOneWidget);
    expect(find.text('Boutique Aminatou'), findsWidgets);
    expect(find.text('Orange'), findsOneWidget);
    expect(find.text('MTN'), findsOneWidget);
    expect(call.requests, isEmpty, reason: 'rien n\'est demandé avant le choix de la ligne');
    await tester.tap(find.byKey(const Key('call-mtn')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(call.requests, [(businessId: 1, line: CallLine.mtn)]);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('le bouton WhatsApp (T054) de la carte ouvre WhatsApp pour ce commerce', (tester) async {
    final call = FakeCallRepository();
    await _pump(tester, call: call);
    expect(find.text('WhatsApp'), findsNWidgets(3));
    await tester.tap(find.byKey(const Key('card-whatsapp')).first);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(call.whatsappRequests, [1]);
    expect(call.requests, isEmpty);
    expect(find.byKey(const Key('whatsapp-sheet')), findsNothing);
    expectNoPhoneOnScreen(tester);
  });

  testWidgets('filtre par secteur dans la feuille', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('search-filters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('filters-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sector-alimentation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filters-apply')));
    await tester.pumpAndSettle();
    expect(find.text('Boutique Aminatou'), findsOneWidget);
    expect(find.text('Pharmacie du Centre'), findsNothing);
  });

  testWidgets('filtre par zone (quartier) dans la feuille', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('search-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Toute la ville : Maroua'), findsOneWidget);
    await tester.tap(find.byKey(const Key('zone-19')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filters-apply')));
    await tester.pumpAndSettle();
    expect(find.text('Pharmacie du Centre'), findsOneWidget);
    expect(find.text('Boutique Aminatou'), findsNothing);
  });

  testWidgets('« Aucun résultat » : conseils et changement de ville', (tester) async {
    await _pump(tester);
    await _type(tester, 'zzzzzz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-empty')), findsOneWidget);
    expect(find.text('Aucun résultat pour « zzzzzz »'), findsOneWidget);
    expect(find.text('Essayez un mot plus court ou un autre mot.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('search-change-city')));
    await tester.pumpAndSettle();
    expect(find.text('PAGE-VILLE'), findsOneWidget);
  });

  testWidgets('erreur réseau : message et « Réessayer »', (tester) async {
    final repo = await _pump(tester);
    repo.fail = true;
    await _type(tester, 'riz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Les commerces ne se chargent pas. Vérifiez votre connexion.'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.byKey(const Key('search-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Boutique Aminatou'), findsOneWidget);
  });

  testWidgets('retour : revient à l\'Accueil', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('search-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-search')), findsOneWidget);
  });
}
