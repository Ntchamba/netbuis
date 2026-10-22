import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/l10n/l10n.dart';
import 'package:netbuis/core/network/api_exception.dart';
import 'package:netbuis/core/theme/app_theme.dart';
import 'package:netbuis/features/business/application/public_business_controller.dart';
import 'package:netbuis/features/business/data/models/public_business.dart';
import 'package:netbuis/features/business/data/repositories/public_business_repository.dart';
import 'package:netbuis/features/business/presentation/screens/business_detail_screen.dart';
import 'package:netbuis/features/forum/application/forum_services.dart';
import 'package:netbuis/features/forum/data/models/report.dart';
import 'package:netbuis/features/forum/data/repositories/report_repository.dart';
import 'package:netbuis/features/search/application/offline_controller.dart';

class _Repo implements PublicBusinessRepository {
  @override
  Future<PublicBusiness> get(int id) async => PublicBusiness.fromJson({
        'id': id,
        'name': 'Chez Aminatou',
        'type_compte': 'boutique',
        'kind': 'produit',
        'secteur': 'Alimentation',
        'secteur_code': 'alimentation',
        'zone': {'id': 17, 'name': 'Hardé'},
        'repere': '',
        'description': '',
        'description_activite': '',
        'photos': <String>[],
        'verifie': false,
        'whatsapp_available': true,
        'forme_juridique': '',
        'diplome_fourni': false,
        'structure_type': '',
        'details': <String, Object?>{},
        'offers': <Object?>[],
      });
}

class _Reports implements ReportRepository {
  ApiException? error;
  Completer<void>? gate;
  final List<({ReportTarget target, int id, ReportReason reason})> calls = [];

  @override
  Future<void> report(ReportTarget target, int id, ReportReason reason) async {
    calls.add((target: target, id: id, reason: reason));
    await gate?.future;
    final e = error;
    if (e != null) throw e;
  }
}

Future<ProviderContainer> _pump(WidgetTester tester, _Reports reports,
    {bool offline = false}) async {
  tester.view.physicalSize = const Size(360, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      publicBusinessRepositoryProvider.overrideWithValue(_Repo()),
      reportRepositoryProvider.overrideWithValue(reports),
    ],
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
  final container =
      ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
  if (offline) {
    container.read(offlineProvider.notifier).set(true);
    await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(find.byKey(const Key('detail-report')), 300,
      scrollable: find.byType(Scrollable).first);
  return container;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

bool _reportEnabled(WidgetTester tester) =>
    tester
        .widget<TextButton>(find.byKey(const Key('detail-report')))
        .onPressed !=
    null;

void main() {
  testWidgets(
      'fiche : Signaler ouvre la feuille ; un motif envoie target_type=business ; merci puis « Déjà signalé » désactivé',
      (tester) async {
    final reports = _Reports();
    await _pump(tester, reports);
    await _tap(tester, 'detail-report');
    expect(find.text('Signaler ce commerce'), findsWidgets);
    for (final label in ['Spam', 'Arnaque', 'Contenu inapproprié', 'Autre']) {
      expect(find.text(label), findsOneWidget);
    }
    await _tap(tester, 'report-reason-arnaque');

    expect(reports.calls.single,
        (target: ReportTarget.business, id: 7, reason: ReportReason.arnaque));
    expect(find.byKey(const Key('report-sheet')), findsNothing);
    expect(find.text('Merci, votre signalement a été envoyé.'), findsOneWidget);
    expect(find.text('Déjà signalé'), findsOneWidget);
    expect(find.text('Signaler ce commerce'), findsNothing);
    expect(_reportEnabled(tester), isFalse);
    // La fiche reste affichée.
    expect(find.text('Chez Aminatou'), findsOneWidget);
  });

  testWidgets('annuler : rien n\'est envoyé, le bouton reste actif',
      (tester) async {
    final reports = _Reports();
    await _pump(tester, reports);
    await _tap(tester, 'detail-report');
    await _tap(tester, 'report-cancel');
    expect(reports.calls, isEmpty);
    expect(_reportEnabled(tester), isTrue);
  });

  testWidgets('409 already_reported : « Déjà signalé », sans erreur',
      (tester) async {
    final reports = _Reports()
      ..error = const ApiException(ApiErrorCode.unknown,
          statusCode: 409, serverCode: 'already_reported');
    await _pump(tester, reports);
    await _tap(tester, 'detail-report');
    await _tap(tester, 'report-reason-spam');
    expect(find.text('Vous avez déjà signalé ce contenu.'), findsOneWidget);
    expect(find.text('Déjà signalé'), findsOneWidget);
    expect(_reportEnabled(tester), isFalse);
    expect(find.byKey(const Key('report-error')), findsNothing);
  });

  testWidgets('400 own_content : message clair, le bouton reste actif',
      (tester) async {
    final reports = _Reports()
      ..error = const ApiException(ApiErrorCode.unknown,
          statusCode: 400, serverCode: 'own_content');
    await _pump(tester, reports);
    await _tap(tester, 'detail-report');
    await _tap(tester, 'report-reason-autre');
    expect(find.text('Vous ne pouvez pas signaler votre propre contenu.'),
        findsOneWidget);
    await _tap(tester, 'report-close');
    expect(find.text('Signaler ce commerce'), findsOneWidget);
    expect(_reportEnabled(tester), isTrue);
  });

  testWidgets('404 : message « plus disponible », pas de « Déjà signalé »',
      (tester) async {
    final reports = _Reports()
      ..error = const ApiException(ApiErrorCode.unknown,
          statusCode: 404, serverCode: 'not_found');
    await _pump(tester, reports);
    await _tap(tester, 'detail-report');
    await _tap(tester, 'report-reason-spam');
    expect(find.text('Ce commerce n\'est plus disponible.'), findsOneWidget);
    expect(find.text('Déjà signalé'), findsNothing);
  });

  testWidgets('réseau : message + Réessayer, puis succès', (tester) async {
    final reports = _Reports()
      ..error = const ApiException(ApiErrorCode.network);
    final container = await _pump(tester, reports);
    await _tap(tester, 'detail-report');
    await _tap(tester, 'report-reason-spam');
    expect(
        find.text('Pas de connexion. Votre signalement n\'a pas été envoyé.'),
        findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Déjà signalé'), findsNothing);

    reports.error = null;
    container.read(offlineProvider.notifier).set(false);
    await _tap(tester, 'report-retry');
    expect(reports.calls.length, 2);
    expect(find.text('Déjà signalé'), findsOneWidget);
  });

  testWidgets('double envoi impossible', (tester) async {
    final reports = _Reports()..gate = Completer<void>();
    await _pump(tester, reports);
    await _tap(tester, 'detail-report');
    await tester.tap(find.byKey(const Key('report-reason-spam')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('report-reason-spam')),
        warnIfMissed: false);
    await tester.tap(find.byKey(const Key('report-reason-autre')),
        warnIfMissed: false);
    await tester.pump();
    expect(reports.calls.length, 1);
    reports.gate!.complete();
    await tester.pumpAndSettle();
    expect(reports.calls.length, 1);
    expect(find.text('Déjà signalé'), findsOneWidget);
  });

  testWidgets('hors connexion : bouton désactivé avec « Hors connexion »',
      (tester) async {
    final reports = _Reports();
    await _pump(tester, reports, offline: true);
    expect(_reportEnabled(tester), isFalse);
    expect(find.text('Signaler ce commerce · Hors connexion'), findsOneWidget);
    expect(find.byKey(const Key('detail-offline')), findsOneWidget);
    expect(reports.calls, isEmpty);
  });
}
