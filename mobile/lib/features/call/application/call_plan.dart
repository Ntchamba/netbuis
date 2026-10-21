// Quelle ligne proposer ? Décision pure (sans Flutter) à partir des noms donnés par le système.
import '../data/call_channel.dart';
import '../data/models/call_session.dart';

/// Ce qu'on sait d'une SIM.
enum SimKind { orange, mtn, other, unknown }

/// Reconnaît l'opérateur. L'opérateur lu sur la SIM prime sur le nom (renommable) ;
/// opérateur lisible mais ni Orange ni MTN = `other` ; rien de lisible = `unknown`.
SimKind classifySim(SimAccount sim) {
  SimKind byText(String text) {
    final t = text.toLowerCase();
    final orange = t.contains('orange');
    final mtn = t.contains('mtn');
    if (orange && !mtn) return SimKind.orange;
    if (mtn && !orange) return SimKind.mtn;
    return SimKind.unknown;
  }

  final fromCarrier = byText(sim.carrier);
  if (fromCarrier != SimKind.unknown) return fromCarrier;
  final fromLabel = byText(sim.label);
  if (fromLabel != SimKind.unknown) return fromLabel;
  return sim.carrier.trim().isEmpty ? SimKind.unknown : SimKind.other;
}

/// La ligne Orange ou MTN d'une SIM reconnue, sinon null.
CallLine? lineOf(SimAccount sim) {
  switch (classifySim(sim)) {
    case SimKind.orange:
      return CallLine.orange;
    case SimKind.mtn:
      return CallLine.mtn;
    case SimKind.other:
    case SimKind.unknown:
      return null;
  }
}

sealed class CallPlan {
  const CallPlan();
}

/// Aucune ligne lisible : repli sur le composeur du téléphone.
class PlanNoSim extends CallPlan {
  const PlanNoSim();
}

/// Une seule SIM : la feuille est sautée.
class PlanSingle extends CallPlan {
  const PlanSingle(this.sim);
  final SimAccount sim;
}

/// Feuille Orange / MTN : chaque SIM est reconnue sans ambiguïté. Une ligne peut manquer.
class PlanSheet extends CallPlan {
  const PlanSheet({this.orange, this.mtn});
  final SimAccount? orange;
  final SimAccount? mtn;

  SimAccount? of(CallLine line) => line == CallLine.orange ? orange : mtn;
}

/// SIM renommée, eSIM, doublon : on montre les noms donnés par le système.
class PlanNames extends CallPlan {
  const PlanNames(this.sims);
  final List<SimAccount> sims;
}

CallPlan planFor(List<SimAccount> sims) {
  if (sims.isEmpty) return const PlanNoSim();
  if (sims.length == 1) return PlanSingle(sims.first);
  SimAccount? orange;
  SimAccount? mtn;
  for (final s in sims) {
    switch (classifySim(s)) {
      case SimKind.unknown:
        return PlanNames(sims);
      case SimKind.orange:
        if (orange != null) return PlanNames(sims);
        orange = s;
      case SimKind.mtn:
        if (mtn != null) return PlanNames(sims);
        mtn = s;
      case SimKind.other:
        break;
    }
  }
  if (orange == null && mtn == null) return PlanNames(sims);
  return PlanSheet(orange: orange, mtn: mtn);
}
