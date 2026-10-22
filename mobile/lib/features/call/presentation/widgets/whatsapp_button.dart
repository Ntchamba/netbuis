// Bouton « WhatsApp » des cartes et feuille qui ouvre WhatsApp (T054).
// Le lien wa.me contient le numéro du commerçant : il n'apparaît ici nulle part.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/call_controller.dart';
import 'call_button.dart';
import 'call_sheet.dart';
import 'report_no_whatsapp_dialog.dart';

/// Bouton « WhatsApp » d'une carte. Grisé avec « Non disponible » si [available] est faux.
class WhatsappButton extends StatelessWidget {
  const WhatsappButton({
    super.key,
    required this.businessName,
    required this.onPressed,
    this.available = true,
    this.offline = false,
  });

  final String businessName;
  final bool available;

  /// Hors connexion : désactivé avec « Hors connexion ».
  final bool offline;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final off = l10n.t(offline ? 'offline.label' : 'home.card.whatsappOff');
    final label = l10n.t('home.card.whatsapp');
    final enabled = available && !offline;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Semantics(
          label: enabled
              ? l10n
                  .t('home.card.whatsappLabel')
                  .replaceFirst('{name}', businessName)
              : '$label, $off',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat_outlined, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    if (!enabled)
                      Text(off,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 11, color: c.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Écrit à [businessName] sur WhatsApp : demande le lien au serveur, puis l'ouvre dans WhatsApp.
/// Un second clic pendant qu'une ouverture est en cours est ignoré (double clic).
Future<void> startWhatsapp(
  BuildContext context, {
  required int businessId,
  required String businessName,
}) async {
  final container = ProviderScope.containerOf(context);
  if (blockIfOffline(context, container)) return;
  final flow = container.read(whatsappFlowProvider.notifier);
  if (!flow.begin(businessId, businessName)) return;
  await showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const WhatsappSheet(),
  );
  flow.reset();
}

class WhatsappSheet extends ConsumerStatefulWidget {
  const WhatsappSheet({super.key});

  @override
  ConsumerState<WhatsappSheet> createState() => _WhatsappSheetState();
}

class _WhatsappSheetState extends ConsumerState<WhatsappSheet> {
  bool _closed = false;

  /// Ferme la feuille une seule fois, dès que l'ouverture est terminée. L'état peut déjà être
  /// « terminé » quand la feuille s'affiche (réponse très rapide) : d'où le contrôle à chaque
  /// construction et pas seulement à chaque changement.
  void _closeIfDone(WhatsappPhase phase) {
    if (phase != WhatsappPhase.done || _closed) return;
    _closed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(whatsappFlowProvider);
    _closeIfDone(s.phase);
    final locked =
        s.phase == WhatsappPhase.opening || s.phase == WhatsappPhase.reporting;
    return PopScope(
      canPop: !locked,
      child: SheetFrame(
        key: const Key('whatsapp-sheet'),
        child: _body(context, ref, s),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, WhatsappFlowState s) {
    final l10n = L10n.of(context);
    final flow = ref.read(whatsappFlowProvider.notifier);
    switch (s.phase) {
      case WhatsappPhase.idle:
      case WhatsappPhase.done:
        return const SizedBox(height: 1);
      case WhatsappPhase.opening:
        return Center(
          key: const Key('whatsapp-opening'),
          child: Semantics(
            label: l10n.t('whatsapp.opening'),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          ),
        );
      case WhatsappPhase.notInstalled:
      case WhatsappPhase.reporting:
      case WhatsappPhase.reported:
        return ReportNoWhatsappPanel(
          businessName: s.businessName,
          phase: s.phase,
          reportFailed: s.reportFailed,
          onReport: flow.report,
          onClose: flow.cancel,
        );
      case WhatsappPhase.unsupported:
        return SheetMessage(
          key: const Key('whatsapp-unsupported'),
          title: l10n.t('whatsapp.unsupported'),
          secondaryKey: const Key('whatsapp-close'),
          secondary: l10n.t('call.close'),
          onSecondary: flow.cancel,
        );
      case WhatsappPhase.error:
        return SheetMessage(
          key: const Key('whatsapp-error'),
          title:
              l10n.t('whatsapp.error.${(s.error ?? CallError.generic).name}'),
          secondaryKey: const Key('whatsapp-close'),
          secondary: l10n.t('call.close'),
          onSecondary: flow.cancel,
        );
    }
  }
}
