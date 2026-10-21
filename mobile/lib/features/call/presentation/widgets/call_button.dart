// Point d'entrée du bouton « Appeler » (fiche publique et cartes de résultat).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/call_controller.dart';
import 'call_sheet.dart';

/// Ouvre la feuille d'appel pour le commerce [businessId]. Un second appel pendant qu'un
/// premier est en cours est ignoré (double clic). La ligne est redemandée à chaque appel.
Future<void> startCall(
  BuildContext context, {
  required int businessId,
  required String businessName,
}) async {
  final container = ProviderScope.containerOf(context);
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
  flow.reset();
}
