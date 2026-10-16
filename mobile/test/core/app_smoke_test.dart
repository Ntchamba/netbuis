import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/app.dart';

void main() {
  testWidgets("l'application démarre sans erreur", (tester) async {
    await tester.pumpWidget(const ProviderScope(child: NetBuisApp()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'NetBuis');
  });
}
