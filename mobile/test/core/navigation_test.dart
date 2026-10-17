import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/app.dart';
import 'package:netbuis/core/router/routes.dart';
import 'package:netbuis/core/widgets/netbuis_logo.dart';

Future<void> _pumpApp(WidgetTester tester, {ThemeMode mode = ThemeMode.dark}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(child: NetBuisApp(themeMode: mode, initialLocation: Routes.home)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('la barre du bas a 4 onglets dans l\'ordre, sans Tendances (360 px)', (tester) async {
    await _pumpApp(tester);

    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    expect(labels, ['Accueil', 'Carte', 'Forum', 'Profil']);
    expect(find.text('Tendances'), findsNothing);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chaque onglet a une cible tactile d\'au moins 48 dp', (tester) async {
    await _pumpApp(tester);

    for (final d in find.byType(NavigationDestination).evaluate()) {
      final size = tester.getSize(find.byWidget(d.widget));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets("changer d'onglet change l'écran", (tester) async {
    await _pumpApp(tester);
    expect(find.byType(NetBuisLogo), findsOneWidget);
    expect(find.text('Explorer'), findsNothing);

    await tester.tap(find.text('Carte'));
    await tester.pumpAndSettle();
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.byType(NetBuisLogo), findsNothing);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Mon profil'), findsOneWidget);
    expect(find.text('Explorer'), findsNothing);

    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
    expect(find.byType(NetBuisLogo), findsOneWidget);
  });
}
