// Point d'entrée du bouton « Appeler » (fiche publique, cartes de résultat, historique) :
// appelle l'équipe NetBuis (D-25) ; le commerce consulté n'est qu'un contexte.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/call_controller.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../search/application/offline_controller.dart';
import 'call_screen.dart';

/// Ouvre l'écran d'appel pour le commerce [businessId]. Un second appel pendant qu'un
/// premier est en cours est ignoré (double clic).
Future<void> startCall(
  BuildContext context, {
  required int businessId,
  required String businessName,
}) async {
  final container = ProviderScope.containerOf(context);
  if (blockIfOffline(context, container)) return;
  final navigator = Navigator.of(context);
  final flow = container.read(callFlowProvider.notifier);
  if (!flow.begin(businessId, businessName)) return;
  await navigator.push<void>(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => const CallScreen(),
  ));
  flow.reset();
}

/// Réchauffe la connexion réseau quand la fiche d'un commerce s'ouvre : la poignée de main TLS
/// est déjà faite au moment du clic sur « Appeler ».
class CallWarmUp extends ConsumerStatefulWidget {
  const CallWarmUp({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<CallWarmUp> createState() => _CallWarmUpState();
}

class _CallWarmUpState extends ConsumerState<CallWarmUp> {
  @override
  void initState() {
    super.initState();
    ref.read(callRepositoryProvider).warmUp();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Hors connexion : ni appel ni WhatsApp. Affiche le message et renvoie vrai (rien n'est ouvert).
bool blockIfOffline(BuildContext context, ProviderContainer container) {
  if (!container.read(offlineProvider)) return false;
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(content: Text(L10n.of(context).t('offline.blocked'))));
  return true;
}
