import 'package:flutter_test/flutter_test.dart';
import 'package:netbuis/features/call/application/call_plan.dart';
import 'package:netbuis/features/call/data/call_channel.dart';
import 'package:netbuis/features/call/data/models/call_session.dart';

SimAccount sim(String label, [String carrier = '']) =>
    SimAccount(id: 'id-$label', label: label, carrier: carrier);

void main() {
  group('classifySim', () {
    test('opérateur lu sur la SIM, même si la SIM est renommée', () {
      expect(classifySim(sim('Perso', 'Orange CM')), SimKind.orange);
      expect(classifySim(sim('Travail', 'MTN CAMEROON')), SimKind.mtn);
    });
    test('l\'opérateur de la SIM prime sur le nom', () {
      expect(classifySim(sim('MTN pro', 'Orange')), SimKind.orange);
    });
    test('nom reconnu quand l\'opérateur est illisible (eSIM)', () {
      expect(classifySim(sim('ORANGE eSIM')), SimKind.orange);
      expect(classifySim(sim('mtn')), SimKind.mtn);
    });
    test('opérateur lisible mais autre = other ; rien de lisible = unknown', () {
      expect(classifySim(sim('SIM 2', 'Camtel')), SimKind.other);
      expect(classifySim(sim('Perso')), SimKind.unknown);
    });
    test('les deux noms à la fois : ambigu', () {
      expect(classifySim(sim('Orange MTN')), SimKind.unknown);
    });
  });

  group('planFor', () {
    test('aucune SIM : repli composeur', () => expect(planFor(const []), isA<PlanNoSim>()));
    test('une SIM : feuille sautée', () {
      expect(planFor([sim('a', 'Orange')]), isA<PlanSingle>());
      expect(planFor([sim('Perso')]), isA<PlanSingle>());
    });
    test('Orange + MTN : feuille', () {
      final p = planFor([sim('a', 'Orange'), sim('b', 'MTN')]) as PlanSheet;
      expect(p.of(CallLine.orange)!.id, 'id-a');
      expect(p.of(CallLine.mtn)!.id, 'id-b');
    });
    test('Orange + autre : feuille, MTN absent', () {
      final p = planFor([sim('a', 'Orange'), sim('b', 'Camtel')]) as PlanSheet;
      expect(p.of(CallLine.mtn), isNull);
      expect(p.of(CallLine.orange), isNotNull);
    });
    test('SIM non reconnue, doublon, ou ni Orange ni MTN : noms du système', () {
      expect(planFor([sim('a', 'Orange'), sim('Perso')]), isA<PlanNames>());
      expect(planFor([sim('a', 'Orange'), sim('b', 'Orange')]), isA<PlanNames>());
      expect(planFor([sim('a', 'Camtel'), sim('b', 'Nexttel')]), isA<PlanNames>());
    });
  });

  test('displayName : nom du système, avec l\'opérateur si différent', () {
    expect(sim('Perso').displayName, 'Perso');
    expect(sim('Perso', 'Orange').displayName, 'Perso (Orange)');
    expect(sim('Orange', 'orange').displayName, 'Orange');
    expect(sim('', 'MTN').displayName, 'MTN');
  });
}
