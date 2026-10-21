import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:netbuis/core/l10n/l10n.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/network/dio_client.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/core/theme/app_theme.dart';
import 'package:netbuis/features/business/application/public_business_controller.dart';
import 'package:netbuis/features/business/data/models/public_business.dart';
import 'package:netbuis/features/business/data/repositories/public_business_repository.dart';
import 'package:netbuis/features/business/data/repositories/public_business_repository_api.dart';
import 'package:netbuis/features/business/data/repositories/public_business_repository_fake.dart';
import 'package:netbuis/features/business/presentation/screens/business_detail_screen.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';
import 'package:netbuis/features/search/presentation/widgets/result_card.dart';

import '../auth/auth_test_helpers.dart';
import 'business_submit_helpers.dart';

Map<String, Object?> _json({
  String type = 'boutique',
  Object? price = 18000,
  Map<String, Object?> details = const {},
  String forme = '',
  bool diplome = false,
  String structure = '',
  bool verifie = true,
  bool whatsapp = true,
}) =>
    {
      'id': 7,
      'name': 'Chez Aminatou',
      'type_compte': type,
      'kind': 'produit',
      'secteur': 'Alimentation',
      'secteur_code': 'alimentation',
      'zone': {'id': 17, 'name': 'Hardé'},
      'repere': 'À côté du Grand Manguier',
      'description': 'Boutique familiale.',
      'description_activite': 'Riz et huile',
      'photos': <String>[],
      'verifie': verifie,
      'whatsapp_available': whatsapp,
      'forme_juridique': forme,
      'diplome_fourni': diplome,
      'structure_type': structure,
      'details': details,
      'offers': [
        {'id': 1, 'name': 'Riz local', 'description': 'Sac de 50 kg', 'price_fcfa': price,
         'on_request': price == null, 'photos': <String>[]},
        {'id': 2, 'name': 'Huile', 'description': '', 'price_fcfa': null, 'on_request': true,
         'photos': <String>[]},
      ],
    };

class _Repo implements PublicBusinessRepository {
  _Repo(this.reply);
  Object? Function() reply;
  int calls = 0;

  @override
  Future<PublicBusiness> get(int id) async {
    calls++;
    final r = reply();
    if (r is ApiException) throw r;
    return PublicBusiness.fromJson(r);
  }
}

Future<void> _pump(WidgetTester tester, PublicBusinessRepository repo) async {
  tester.view.physicalSize = const Size(360, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [publicBusinessRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('fr'),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const BusinessDetailScreen(businessId: 7),
    ),
  ));
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, Key key) {
  final b = tester.widget<ButtonStyleButton>(find.descendant(
      of: find.byKey(key), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton)));
  return b.onPressed != null;
}

void main() {
  group('modèle', () {
    test('fromJson : prix null = sur demande, détails lus', () {
      final b = PublicBusiness.fromJson(_json(
        type: 'structure',
        structure: 'Restaurant',
        details: {'cuisine': 'fast_food', 'livraison': true, 'horaires': '8h-20h'},
      ));
      expect(b.offers[1].onRequest, isTrue);
      expect(b.offers[0].priceFcfa, 18000);
      expect(b.details.cuisine, 'fast_food');
      expect(b.details.livraison, isTrue);
      expect(b.zone?.name, 'Hardé');
    });

    test('fromJson : réponse mal formée -> FormatException', () {
      expect(() => PublicBusiness.fromJson({'id': 'x'}), throwsFormatException);
      expect(() => PublicBusiness.fromJson(_json()..['offers'] = [1]), throwsFormatException);
    });

    test('le modèle ne porte ni numéro, ni CNI, ni motif de rejet', () {
      final json = _json()
        ..['phone'] = '+237690000000'
        ..['cni_photo'] = 'k'
        ..['motif_rejet'] = 'x';
      final b = PublicBusiness.fromJson(json);
      expect(b.toString(), isNot(contains('237')));
    });
  });

  group('dépôt api', () {
    PublicBusinessRepositoryApi api(FakeAdapter a) => PublicBusinessRepositoryApi(
        buildDio(baseUrl: kApiUrl, readAccessToken: () async => 'acc-test')
          ..httpClientAdapter = a);

    test('GET /business/<id>/ lit la fiche', () async {
      final a = FakeAdapter((r) => FakeAdapter.reply(200, _json()));
      final b = await api(a).get(7);
      expect(b.name, 'Chez Aminatou');
      expect(a.seen.single.method, 'GET');
      expect(a.seen.single.path, '/business/7/');
    });

    test('404 not_found -> ApiException 404 ; corps illisible -> unknown', () async {
      final a = FakeAdapter((r) => FakeAdapter.reply(404, {'code': 'not_found', 'message': 'x'}));
      await expectLater(
          api(a).get(7), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
      final b = FakeAdapter((r) => FakeAdapter.reply(200, {'id': 'x'}));
      await expectLater(api(b).get(7),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.unknown)));
    });
  });

  testWidgets('fiche complète : nom, type, badge, zone, repère, offres, Sur demande',
      (tester) async {
    await _pump(tester, _Repo(_json));
    expect(find.text('Chez Aminatou'), findsOneWidget);
    expect(find.text('Commerce'), findsOneWidget);
    expect(find.text('Alimentation'), findsOneWidget);
    expect(find.byKey(const Key('detail-verified')), findsOneWidget);
    expect(find.text('✓ Identité vérifiée'), findsOneWidget);
    expect(find.text('À côté du Grand Manguier — Hardé'), findsOneWidget);
    expect(find.text('Riz et huile'), findsOneWidget);
    expect(find.text('Boutique familiale.'), findsOneWidget);
    expect(find.text('Riz local'), findsOneWidget);
    expect(find.text('18 000 FCFA'), findsOneWidget);
    expect(find.text('Sur demande'), findsOneWidget);
    // Aucune suite de 8 chiffres ou plus affichée (pas de numéro).
    final all = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').join(' ');
    expect(RegExp(r'\d{8,}').hasMatch(all), isFalse);
  });

  testWidgets("sans identité vérifiée : pas de badge", (tester) async {
    await _pump(tester, _Repo(() => _json(verifie: false)));
    expect(find.byKey(const Key('detail-verified')), findsNothing);
  });

  testWidgets('Appeler (T052) et WhatsApp (T054) sont activés ; Signaler reste désactivé « Bientôt »',
      (tester) async {
    await _pump(tester, _Repo(_json));
    await tester.scrollUntilVisible(find.byKey(const Key('detail-report')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Appeler'), findsOneWidget);
    expect(find.text('Appeler · Bientôt'), findsNothing);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('WhatsApp · Bientôt'), findsNothing);
    expect(find.textContaining('Signaler ce commerce'), findsOneWidget);
    expect(_enabled(tester, const Key('detail-call')), isTrue);
    expect(_enabled(tester, const Key('detail-whatsapp')), isTrue);
    expect(tester.widget<TextButton>(find.byKey(const Key('detail-report'))).onPressed, isNull);
  });

  testWidgets('WhatsApp indisponible : grisé avec « Non disponible »', (tester) async {
    await _pump(tester, _Repo(() => _json(whatsapp: false)));
    await tester.scrollUntilVisible(find.byKey(const Key('detail-report')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('WhatsApp · Non disponible'), findsOneWidget);
    expect(_enabled(tester, const Key('detail-whatsapp')), isFalse);
  });

  testWidgets('entreprise : forme juridique traduite', (tester) async {
    await _pump(tester, _Repo(() => _json(type: 'entreprise', forme: 'sarl')));
    expect(find.text('Entreprise'), findsOneWidget);
    expect(find.text('Forme juridique'), findsOneWidget);
    expect(find.text('SARL'), findsOneWidget);
  });

  testWidgets('prestataire : diplôme fourni ; sans diplôme, la ligne est absente', (tester) async {
    await _pump(tester, _Repo(() => _json(type: 'prestataire_service', diplome: true)));
    expect(find.text('Diplôme'), findsOneWidget);
    expect(find.text('Fourni'), findsOneWidget);
    await _pump(tester, _Repo(() => _json(type: 'prestataire_service')));
    expect(find.text('Diplôme'), findsNothing);
  });

  testWidgets('restaurant : cuisine, livraison, horaires', (tester) async {
    await _pump(
        tester,
        _Repo(() => _json(type: 'structure', structure: 'Restaurant', details: {
              'cuisine': 'camerounaise', 'livraison': false, 'horaires': 'Tous les jours, 11h-22h'
            })));
    expect(find.text('Restaurant'), findsOneWidget);
    expect(find.text('Camerounaise'), findsOneWidget);
    expect(find.text('Livraison'), findsOneWidget);
    expect(find.text('Non'), findsOneWidget);
    expect(find.text('Tous les jours, 11h-22h'), findsOneWidget);
  });

  testWidgets('hôtel, supermarché, santé : standing, chambres, équipements, rayons, spécialités',
      (tester) async {
    await _pump(
        tester,
        _Repo(() => _json(type: 'structure', structure: 'Hôtel', details: {
              'standing': 'confort', 'nombre_chambres': 18, 'equipements': ['wifi', 'parking']
            })));
    expect(find.text('Confort'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('Wifi, Parking'), findsOneWidget);
    await _pump(
        tester,
        _Repo(() => _json(type: 'structure', structure: 'Supermarché', details: {
              'rayons': ['boissons', 'produits_frais']
            })));
    expect(find.text('Boissons, Produits frais'), findsOneWidget);
    await _pump(
        tester,
        _Repo(() => _json(type: 'structure', structure: 'Centre de santé', details: {
              'specialites': ['pediatrie']
            })));
    expect(find.text('Pédiatrie'), findsOneWidget);
  });

  testWidgets('numéro d\'agrément jamais affiché même s\'il arrivait', (tester) async {
    await _pump(
        tester,
        _Repo(() => _json(type: 'structure', structure: 'Centre de santé', details: {
              'numero_agrement': 'MINSANTE/2024/0456', 'specialites': ['pediatrie']
            })));
    expect(find.textContaining('MINSANTE'), findsNothing);
  });

  testWidgets('404 : « Fiche introuvable » ; autre erreur : réessayer recharge', (tester) async {
    await _pump(tester, _Repo(() => const ApiException(ApiErrorCode.unknown, statusCode: 404)));
    expect(find.byKey(const Key('detail-not-found')), findsOneWidget);
    expect(find.text('Fiche introuvable'), findsOneWidget);

    final repo = _Repo(() => const ApiException(ApiErrorCode.network));
    await _pump(tester, repo);
    expect(find.byKey(const Key('detail-error')), findsOneWidget);
    expect(find.text('Fiche introuvable'), findsNothing);
    repo.reply = _json;
    await tester.tap(find.byKey(const Key('detail-action')));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(find.text('Chez Aminatou'), findsOneWidget);
  });

  testWidgets('chargement : indicateur affiché avant la réponse', (tester) async {
    final repo = PublicBusinessRepositoryFake();
    await tester.pumpWidget(ProviderScope(
      overrides: [publicBusinessRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('fr'),
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: const [
          L10n.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const BusinessDetailScreen(businessId: 1),
      ),
    ));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Boutique Aminatou'), findsOneWidget);
  });

  testWidgets('tap sur une carte de résultat : ouvre la fiche', (tester) async {
    final router = GoRouter(initialLocation: '/list', routes: [
      GoRoute(
        path: '/list',
        builder: (context, _) => Scaffold(
          body: ResultCard(
            result: const SearchResult(id: 1, name: 'Boutique Aminatou', kind: 'produit'),
            onOpen: () => context.push(Routes.businessDetailPath(1)),
          ),
        ),
      ),
      GoRoute(
          path: Routes.businessDetail,
          builder: (_, s) => BusinessDetailScreen(businessId: int.parse(s.pathParameters['id']!))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        publicBusinessRepositoryProvider.overrideWithValue(PublicBusinessRepositoryFake())
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
    await tester.tap(find.text('Boutique Aminatou'));
    await tester.pumpAndSettle();
    expect(find.text('Fiche du commerce'), findsOneWidget);
    expect(find.text('Riz local (sac)'), findsOneWidget);
  });
}
