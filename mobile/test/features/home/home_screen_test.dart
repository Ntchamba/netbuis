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
import 'package:netbuis/core/widgets/netbuis_logo.dart';
import 'package:netbuis/features/account/data/repositories/account_repository_fake.dart';
import 'package:netbuis/features/home/application/invite_steps.dart';
import 'package:netbuis/features/home/data/share_service.dart';
import 'package:netbuis/features/home/presentation/screens/home_screen.dart';
import 'package:netbuis/features/home/presentation/widgets/category_chips.dart';
import 'package:netbuis/features/home/presentation/widgets/invite_dialog.dart';
import 'package:netbuis/features/search/application/search_controller.dart';
import 'package:netbuis/features/search/data/models/search_query.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';
import 'package:netbuis/features/search/data/repositories/search_repository_fake.dart';
import 'package:netbuis/core/data/referentials/referential_models.dart';

import '../auth/login_test_helpers.dart' show MemoryPrefs;

class _Share implements ShareService {
  final List<String> shared = [];
  bool fail = false;

  @override
  Future<void> shareText(String text) async {
    if (fail) throw StateError('partage impossible');
    shared.add(text);
  }
}

/// Recherche factice qui peut échouer une fois.
class _Search extends SearchRepositoryFake {
  _Search() : super(data: _data);

  bool fail = false;

  // Zones du faux référentiel : 17 Hardé, 18 Dougoï, 19 Domayo (quartiers de Maroua).
  static const _data = [
    SearchResult(
        id: 1, name: 'Boutique Aminatou', kind: 'produit', secteur: 'Alimentation',
        secteurCode: 'alimentation', zone: ResultZone(id: 17, name: 'Hardé'),
        repere: 'Près du marché', descriptionActivite: 'Riz, huile et condiments'),
    SearchResult(
        id: 2, name: 'Pharmacie du Centre', kind: 'produit', secteur: 'Pharmacie & Santé',
        secteurCode: 'pharmacie_sante', zone: ResultZone(id: 19, name: 'Domayo'),
        descriptionActivite: 'Médicaments et conseils'),
    SearchResult(
        id: 3, name: 'Couturier Ibrahim', kind: 'service', secteur: 'Artisanat',
        secteurCode: 'artisanat_services_domicile', zone: ResultZone(id: 18, name: 'Dougoï'),
        descriptionActivite: 'Confection sur mesure'),
  ];

  @override
  Future<SearchPage> search(SearchQuery query, {int page = 1}) async {
    if (fail) throw const ApiException(ApiErrorCode.network);
    return super.search(query, page: page);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  ThemeMode mode = ThemeMode.dark,
  _Share? share,
  _Search? search,
  AccountRepositoryFake? account,
  bool teamEnabled = false,
  VoidCallback? onOpenSearch,
  VoidCallback? onVoiceSearch,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, __) => Scaffold(
          body: HomeScreen(
            teamEnabled: teamEnabled,
            onOpenSearch: onOpenSearch,
            onVoiceSearch: onVoiceSearch,
          ),
        ),
      ),
      GoRoute(path: '/profile', builder: (_, __) => const Scaffold(body: Text('PAGE-PROFIL'))),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appPrefsProvider.overrideWithValue(MemoryPrefs()),
      searchRepositoryProvider.overrideWithValue(search ?? _Search()),
      referentialRepositoryProvider.overrideWithValue(const ReferentialRepositoryFake()),
      accountRepositoryProvider.overrideWithValue(account ?? AccountRepositoryFake()),
      shareServiceProvider.overrideWithValue(share ?? _Share()),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      locale: const Locale('fr'),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('structure de l\'Accueil', () {
    testWidgets('logo, recherche, micro séparé, puces, résultats de la ville, encart', (tester) async {
      await _pump(tester);
      expect(find.byType(NetBuisLogo), findsOneWidget);
      expect(find.text('Rechercher un produit, un service...'), findsOneWidget);
      expect(find.byKey(const Key('home-voice')), findsOneWidget);
      expect(find.byKey(const Key('home-search')), findsOneWidget);
      // Puces : Tous + 2 secteurs + plus, chacune avec son icône.
      expect(find.text('Tous'), findsOneWidget);
      expect(find.text('Alimentation'), findsOneWidget);
      expect(find.text('Boutique / Supérette'), findsOneWidget);
      expect(find.byKey(const Key('chip-more')), findsOneWidget);
      expect(find.text('📋'), findsOneWidget);
      expect(find.text('🍌'), findsOneWidget);
      expect(find.text('➕'), findsOneWidget);
      // D-19 : avant toute recherche, les commerces de la ville choisie (Maroua, zone 16).
      expect(find.text('Boutique Aminatou'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Couturier Ibrahim'), 200,
          scrollable: find.descendant(
              of: find.byKey(const Key('home-results')), matching: find.byType(Scrollable)));
      expect(find.text('Couturier Ibrahim'), findsOneWidget);
      // Bouton d'appel sans prix (CREDITS_ENABLED=False).
      expect(find.text('Appeler'), findsWidgets);
      expect(find.textContaining('FCFA'), findsNothing);
      expect(find.text('Aidez NetBuis à grandir'), findsOneWidget);
      expect(find.text('Inviter →'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('les puces passent à la ligne : aucun défilement horizontal', (tester) async {
      await _pump(tester, textScale: 1.5);
      expect(find.byType(Wrap), findsWidgets);
      final horizontal = tester.widgetList<Scrollable>(find.byType(Scrollable)).where(
          (s) => s.axisDirection == AxisDirection.left || s.axisDirection == AxisDirection.right);
      expect(horizontal, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('carte de résultat : badge, lieu « repère — zone », aucun numéro', (tester) async {
      await _pump(tester);
      expect(find.text('Produit'), findsWidgets);
      await tester.scrollUntilVisible(find.text('Service'), 200,
          scrollable: find.descendant(
              of: find.byKey(const Key('home-results')), matching: find.byType(Scrollable)));
      expect(find.text('Service'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Près du marché — Hardé'), -200,
          scrollable: find.descendant(
              of: find.byKey(const Key('home-results')), matching: find.byType(Scrollable)));
      expect(find.text('Près du marché — Hardé'), findsOneWidget);
      expect(find.textContaining('+237'), findsNothing);
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('thème $mode : écran complet sans erreur', (tester) async {
        await _pump(tester, mode: mode);
        expect(find.text('Boutique Aminatou'), findsOneWidget);
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor ?? Theme.of(tester.element(find.byType(HomeScreen))).scaffoldBackgroundColor,
            mode == ThemeMode.dark ? const Color(0xFF0D0D0F) : const Color(0xFFF7F7F8));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('recherche et puces', () {
    testWidgets('une puce de secteur filtre, « Tous » revient', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Alimentation'));
      await tester.pumpAndSettle();
      expect(find.text('Boutique Aminatou'), findsOneWidget);
      expect(find.text('Pharmacie du Centre'), findsNothing);
      await tester.tap(find.text('Tous'));
      await tester.pumpAndSettle();
      expect(find.text('Pharmacie du Centre'), findsOneWidget);
    });

    testWidgets('« plus » ouvre la grille des 10 secteurs ; le choix filtre', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('chip-more')));
      await tester.pumpAndSettle();
      expect(find.text('Tous les secteurs'), findsOneWidget);
      final grid = find.byKey(const Key('sectors-grid'));
      expect(grid, findsOneWidget);
      final sectors = await const ReferentialRepositoryFake().getSectors();
      expect(sectors.length, 10);
      final santeName = sectors.firstWhere((s) => s.code == 'pharmacie_sante').name;
      expect(find.text(santeName), findsOneWidget);
      await tester.tap(find.text(santeName));
      await tester.pumpAndSettle();
      expect(find.text('Tous les secteurs'), findsNothing);
      expect(find.text('Pharmacie du Centre'), findsOneWidget);
      expect(find.text('Boutique Aminatou'), findsNothing);
      // Le secteur choisi, plus loin que les puces visibles, reste visible.
      expect(find.text(santeName), findsOneWidget);
    });

    test('visibleSectors : le secteur choisi prend la place de la dernière puce', () {
      final sectors = [
        for (var i = 0; i < 5; i++)
          Sector(item: ReferentialItem(id: i, code: 'c$i', name: 'S$i', order: i), subcategories: const []),
      ];
      expect(visibleSectors(sectors, null).map((s) => s.code), ['c0', 'c1']);
      expect(visibleSectors(sectors, 'c0').map((s) => s.code), ['c0', 'c1']);
      expect(visibleSectors(sectors, 'c4').map((s) => s.code), ['c0', 'c4']);
      expect(visibleSectors(sectors, 'inconnu').map((s) => s.code), ['c0', 'c1']);
    });

    testWidgets('erreur réseau : message et « Réessayer » relance', (tester) async {
      final search = _Search()..fail = true;
      await _pump(tester, search: search);
      expect(find.text('Les commerces ne se chargent pas. Vérifiez votre connexion.'), findsOneWidget);
      expect(find.text('Boutique Aminatou'), findsNothing);
      search.fail = false;
      await tester.tap(find.byKey(const Key('home-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Boutique Aminatou'), findsOneWidget);
    });

    testWidgets('aucun commerce : message simple', (tester) async {
      await _pump(tester);
      final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
      container.read(searchControllerProvider.notifier).submit('zzzzzz');
      await tester.pumpAndSettle();
      expect(find.text('Aucun commerce pour le moment.'), findsOneWidget);
    });
  });

  group('points d\'entrée', () {
    testWidgets('barre de recherche et micro appellent les points d\'entrée', (tester) async {
      var search = 0, voice = 0;
      await _pump(tester, onOpenSearch: () => search++, onVoiceSearch: () => voice++);
      await tester.tap(find.byKey(const Key('home-search')));
      await tester.tap(find.byKey(const Key('home-voice')));
      expect(search, 1);
      expect(voice, 1);
    });

    testWidgets('sans écran de recherche branché : « Bientôt disponible »', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('home-search')));
      await tester.pump();
      expect(find.text('Bientôt disponible'), findsOneWidget);
    });

    testWidgets('l\'icône de profil ouvre Profil', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('home-profile')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE-PROFIL'), findsOneWidget);
    });
  });

  group('Aidez NetBuis à grandir', () {
    test('inviteSteps : parrain seulement si TEAM_ENABLED, business seulement sans compte', () {
      expect(inviteSteps(teamEnabled: false, hasBusiness: false),
          [InviteStep.business, InviteStep.share]);
      expect(inviteSteps(teamEnabled: true, hasBusiness: false),
          [InviteStep.sponsor, InviteStep.business, InviteStep.share]);
      expect(inviteSteps(teamEnabled: false, hasBusiness: true), [InviteStep.share]);
      expect(inviteSteps(teamEnabled: true, hasBusiness: true),
          [InviteStep.sponsor, InviteStep.share]);
    });

    testWidgets('Inviter : Parrain masqué (TEAM_ENABLED=False), puis Business, puis Partager', (tester) async {
      final share = _Share();
      await _pump(tester, share: share);
      await tester.tap(find.byKey(const Key('home-invite')));
      await tester.pumpAndSettle();
      expect(find.text('Devenir parrain'), findsNothing);
      expect(find.text('Créez votre compte business'), findsOneWidget);
      expect(find.text('Créer mon compte business'), findsOneWidget);
      await tester.tap(find.byKey(const Key('invite-next')));
      await tester.pumpAndSettle();
      expect(find.text('Partagez NetBuis'), findsOneWidget);
      expect(find.byKey(const Key('invite-next')), findsNothing);
      await tester.tap(find.text('Partager NetBuis'));
      await tester.pumpAndSettle();
      expect(share.shared, hasLength(1));
      expect(share.shared.single, contains('NetBuis'));
      expect(find.byType(InviteDialog), findsNothing);
    });

    testWidgets('TEAM_ENABLED=True : la feuille Devenir parrain vient en premier', (tester) async {
      await _pump(tester, teamEnabled: true);
      await tester.tap(find.byKey(const Key('home-invite')));
      await tester.pumpAndSettle();
      expect(find.text('Devenir parrain'), findsOneWidget);
    });

    testWidgets('les feuilles défilent toutes seules, la dernière reste', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('home-invite')));
      await tester.pumpAndSettle();
      expect(find.text('Créez votre compte business'), findsOneWidget);
      await tester.pump(kInviteStepDuration + const Duration(milliseconds: 50));
      expect(find.text('Partagez NetBuis'), findsOneWidget);
      await tester.pump(kInviteStepDuration * 2);
      expect(find.text('Partagez NetBuis'), findsOneWidget);
    });

    testWidgets('Créer mon compte business mène à Profil', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('home-invite')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite-cta')));
      await tester.pumpAndSettle();
      expect(find.text('PAGE-PROFIL'), findsOneWidget);
    });

    testWidgets('compte déjà business : seulement Partager', (tester) async {
      final account = AccountRepositoryFake()..markHasBusiness();
      await _pump(tester, account: account);
      await tester.tap(find.byKey(const Key('home-invite')));
      await tester.pumpAndSettle();
      expect(find.text('Créez votre compte business'), findsNothing);
      expect(find.text('Partagez NetBuis'), findsOneWidget);
    });

    testWidgets('partage impossible : message, pas de plantage', (tester) async {
      final share = _Share()..fail = true;
      await _pump(tester, share: share, account: AccountRepositoryFake()..markHasBusiness());
      await tester.tap(find.byKey(const Key('home-invite')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite-cta')));
      await tester.pumpAndSettle();
      expect(find.text("Le partage n'a pas pu s'ouvrir. Réessayez."), findsOneWidget);
    });

    testWidgets('fermer la feuille ou l\'encart', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(const Key('home-invite')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite-close')));
      await tester.pumpAndSettle();
      expect(find.byType(InviteDialog), findsNothing);
      await tester.tap(find.byKey(const Key('home-promo-close')));
      await tester.pumpAndSettle();
      expect(find.text('Aidez NetBuis à grandir'), findsNothing);
      expect(find.text('Boutique Aminatou'), findsOneWidget);
    });
  });
}
