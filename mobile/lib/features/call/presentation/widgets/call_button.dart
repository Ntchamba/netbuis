// Point d'entrée du bouton « Appeler » (fiche publique et cartes de résultat).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/call_controller.dart';
import 'call_sheet.dart';
import 'feedback_sheet.dart';

/// Ouvre la feuille d'appel pour le commerce [businessId]. Un second appel pendant qu'un
/// premier est en cours est ignoré (double clic). La ligne est redemandée à chaque appel.
/// Une fois l'appel parti, une feuille facultative demande s'il a abouti.
Future<void> startCall(
  BuildContext context, {
  required int businessId,
  required String businessName,
}) async {
  final container = ProviderScope.containerOf(context);
  final navigator = Navigator.of(context);
  final flow = container.read(callFlowProvider.notifier);
  if (!flow.begin(businessId, businessName)) return;
  await showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CallSheet(),
  );
  // Le retour « ça a abouti ? » est facultatif : il n'est proposé que si l'appel est parti.
  final placedCallId = container.read(callFlowProvider).placedCallId;
  flow.reset();
  if (placedCallId != null && navigator.mounted) {
    await showCallFeedback(navigator,
        callId: placedCallId, businessName: businessName);
  }
}
