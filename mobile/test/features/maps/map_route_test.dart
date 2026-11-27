import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/app.dart';
import 'package:netbuis/core/di/providers.dart';
import 'package:netbuis/core/router/routes.dart';

import '../auth/auth_test_helpers.dart';

void main() {
  testWidgets('l\'onglet Carte montre Explorer ; un quartier ouvre son détail', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [tokenStorageProvider.overrideWithValue(MemoryTokenStorage(refresh: 'ref-1'))],
      child: const NetBuisApp(themeMode: ThemeMode.dark, initialLocation: Routes.map),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('Maroua · 91'), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-pin-city-16')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-pin-area-301')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('area-title')), findsOneWidget);
    expect(find.text('Hardé'), findsWidgets);
    expect(find.text('Maroua'), findsOneWidget);
    expect(find.text('Cameroun'), findsOneWidget);
    expect(find.text('Commerce 1 de Hardé'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
