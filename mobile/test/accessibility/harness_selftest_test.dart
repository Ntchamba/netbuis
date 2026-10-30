// T120 : le harnais sait détecter les défauts (un contrôle qui ne peut pas échouer ne prouve rien).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y_harness.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  testWidgets('une cible de 20×20 dp est signalée', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      Align(
        alignment: Alignment.center,
        child: Semantics(
          button: true,
          label: 'Petit',
          child: GestureDetector(
              onTap: () {}, child: const SizedBox(width: 20, height: 20)),
        ),
      ),
    );
    final problems = await guidelineProblems(tester, contrast: false);
    expect(problems.join(), contains('cible tactile'));
    handle.dispose();
  });

  testWidgets('un bouton sans étiquette est signalé', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      Align(
        child: GestureDetector(
            onTap: () {}, child: const SizedBox(width: 60, height: 60)),
      ),
    );
    final problems = await guidelineProblems(tester, contrast: false);
    expect(problems.join(), contains('sans étiquette'));
    handle.dispose();
  });

  testWidgets('un bouton de 56 dp avec étiquette est accepté', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      Align(
        child: Semantics(
          button: true,
          label: 'Grand',
          child: GestureDetector(
              onTap: () {}, child: const SizedBox(width: 56, height: 56)),
        ),
      ),
    );
    expect(await guidelineProblems(tester, contrast: false), isEmpty);
    handle.dispose();
  });

  testWidgets('un débordement est signalé', (tester) async {
    await _pump(tester, Row(children: [Text('x' * 200)]));
    expect(
        () => expectNoRenderError(tester, 'test'), throwsA(isA<TestFailure>()));
    tester.takeException();
  });

  testWidgets('un défilement horizontal est signalé', (tester) async {
    await _pump(
      tester,
      ListView(
          scrollDirection: Axis.horizontal,
          children: const [SizedBox(width: 900)]),
    );
    expect(() => expectNoHorizontalScroll(tester, 'test'),
        throwsA(isA<TestFailure>()));
  });

  testWidgets('un défilement vertical est accepté', (tester) async {
    await _pump(tester, ListView(children: const [SizedBox(height: 2000)]));
    expectNoHorizontalScroll(tester, 'test');
  });
}
