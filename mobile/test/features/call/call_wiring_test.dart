// Le bouton Appeler de la fiche publique (T047) et de l'Accueil est branché sur la feuille d'appel.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/core/data/referentials/referential_repository_fake.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/features/account/data/repositories/account_repository_fake.dart';
import 'package:netbuis/features/business/application/public_business_controller.dart';
import 'package:netbuis/features/business/data/repositories/public_business_repository_fake.dart';
import 'package:netbuis/features/business/presentation/screens/business_detail_screen.dart';
import 'package:netbuis/features/call/data/models/call_session.dart';
import 'package:netbuis/features/home/presentation/screens/home_screen.dart';
import 'package:netbuis/features/search/application/search_controller.dart';
import 'package:netbuis/features/search/data/models/search_result.dart';
import 'package:netbuis/features/search/data/repositories/search_repository_fake.dart';

import '../auth/login_test_helpers.dart' show MemoryPrefs;
import 'call_test_helpers.dart';

void main() {
  testWidgets('fiche publique : Appeler ouvre la feuille avec le nom du commerce, sans numéro',
      (tester) async {
    final channel = FakeCallChannel();
    final repo = FakeCallRepository();
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        publicBusinessRepositoryProvider.overrideWithValue(PublicBusinessRepositoryFake()),
        ...callOverrides(channel, repo),
      ],
      child: testApp(const BusinessDetailScreen(businessId: 1)),
    ));
    await tester.pumpAndSettle();
    expectNoPhoneOnScreen(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('detail-call')), 300,
        scrollable: find.byType(Scrollable).first);
    final button = tester.widget<FilledButton>(
        find.descendant(of: find.byKey(const Key('detail-call')), matching: find.byType(FilledButton)));
    expect(button.onPressed, isNotNull);
    await tapAndSettle(tester, find.byKey(const Key('detail-call')));
    expect(find.byKey(const Key('call-choose')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('call-sheet')), matching: find.text('Boutique Aminatou')),
        findsOneWidget);
    expect(repo.requests, isEmpty);
    await tapAndSettle(tester, find.byKey(const Key('call-orange')));
    expect(repo.requests, [(businessId: 1, line: CallLine.orange)]);
    expect(channel.placed.single.accountId, 'tel|orange');
    expectNoPhoneOnScreen(tester);
    await closeSheet(tester);
    expect(find.byKey(const Key('call-sheet')), findsNothing);
  });

  testWidgets('Accueil : la carte de résultat appelle le bon commerce', (tester) async {
    final channel = FakeCallChannel();
    final repo = FakeCallRepository();
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appPrefsProvider.overrideWithValue(MemoryPrefs()),
        accountRepositoryProvider.overrideWithValue(AccountRepositoryFake()),
        searchRepositoryProvider.overrideWithValue(SearchRepositoryFake(data: const [
          SearchResult(
              id: 4, name: 'Pharmacie du Centre', kind: 'produit', zone: ResultZone(id: 19, name: 'Domayo')),
        ])),
        referentialRepositoryProvider.overrideWithValue(const ReferentialRepositoryFake()),
        ...callOverrides(channel, repo),
      ],
      child: testApp(const Scaffold(body: HomeScreen())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Pharmacie du Centre'), findsOneWidget);
    await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Appeler'));
    expect(find.byKey(const Key('call-choose')), findsOneWidget);
    await tapAndSettle(tester, find.byKey(const Key('call-mtn')));
    expect(repo.requests, [(businessId: 4, line: CallLine.mtn)]);
    expect(channel.placed.single.accountId, 'tel|mtn');
    expectNoPhoneOnScreen(tester);
    await closeSheet(tester);
  });
}
