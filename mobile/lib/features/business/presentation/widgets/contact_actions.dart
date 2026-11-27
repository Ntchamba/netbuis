// Appeler (T052), WhatsApp (T054) et Signaler (T093) branchés. Aucun numéro ici.
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';

class ContactActions extends StatelessWidget {
  const ContactActions({
    super.key,
    required this.businessName,
    required this.whatsappAvailable,
    this.onCall,
    this.onWhatsapp,
    this.onReport,
    this.offline = false,
    this.reported = false,
  });

  final String businessName;

  /// Faux : WhatsApp reste grisé avec « Non disponible ».
  final bool whatsappAvailable;

  /// Null = désactivé avec la mention « Bientôt ».
  final VoidCallback? onCall;
  final VoidCallback? onWhatsapp;
  final VoidCallback? onReport;

  /// Vrai : ce commerce a déjà été signalé pendant cette session (« Déjà signalé », désactivé).
  final bool reported;

  /// Hors connexion : Appeler et WhatsApp désactivés, avec « Hors connexion ».
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final soon = l10n.t('business.detail.soon');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (offline)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(l10n.t('offline.blocked'),
                key: const Key('detail-offline'),
                style: TextStyle(fontSize: 13, color: c.textSecondary)),
          ),
        _Action(
          key: const Key('detail-call'),
          icon: Icons.call,
          label: l10n.t('home.card.call'),
          semantics: l10n.t('home.card.callLabel').replaceFirst('{name}', businessName),
          note: offline ? l10n.t('offline.label') : (onCall == null ? soon : null),
          onPressed: offline ? null : onCall,
          filled: true,
        ),
        const SizedBox(height: 10),
        _Action(
          key: const Key('detail-whatsapp'),
          icon: Icons.chat_outlined,
          label: l10n.t('business.detail.whatsapp'),
          semantics: l10n.t('business.detail.whatsapp'),
          note: offline
              ? l10n.t('offline.label')
              : !whatsappAvailable
              ? l10n.t('business.detail.whatsappOff')
              : (onWhatsapp == null ? soon : null),
          onPressed: whatsappAvailable && !offline ? onWhatsapp : null,
        ),
        const SizedBox(height: 4),
        ReportBusinessButton(
          buttonKey: const Key('detail-report'),
          onReport: onReport,
          reported: reported,
          offline: offline,
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.icon,
    required this.label,
    required this.semantics,
    required this.onPressed,
    this.note,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final String semantics;
  final String? note;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final content = Text(note == null ? label : '$label · $note',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700));
    final child = Semantics(label: note == null ? semantics : '$semantics, $note',
        excludeSemantics: true, child: content);
    return SizedBox(
      height: 48,
      child: filled
          ? FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                shape: shape,
              ),
              icon: Icon(icon, size: 18),
              label: child,
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(shape: shape),
              icon: Icon(icon, size: 18),
              label: child,
            ),
    );
  }
}

/// « Signaler ce commerce » (fiche publique et Historique) : devient « Déjà signalé » (désactivé)
/// après un signalement, et reste désactivé avec « Hors connexion » sans réseau.
class ReportBusinessButton extends StatelessWidget {
  const ReportBusinessButton({
    super.key,
    required this.buttonKey,
    required this.onReport,
    this.reported = false,
    this.offline = false,
  });

  final Key buttonKey;
  final VoidCallback? onReport;
  final bool reported;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final enabled = !reported && !offline && onReport != null;
    final label = reported
        ? l10n.t('report.already')
        : offline
            ? '${l10n.t('business.detail.report')} · ${l10n.t('offline.label')}'
            : l10n.t('business.detail.report');
    return TextButton.icon(
      key: buttonKey,
      onPressed: enabled ? onReport : null,
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      icon: Icon(reported ? Icons.flag : Icons.flag_outlined, size: 18),
      label: Text(label,
          style: TextStyle(color: enabled ? c.accentText : c.textSecondary)),
    );
  }
}
