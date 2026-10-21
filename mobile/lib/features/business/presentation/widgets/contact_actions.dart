// Appeler (T052) et WhatsApp (T054) branchés ; Signaler présent mais désactivé (« Bientôt »).
// T093 branche Signaler. Aucun numéro ici.
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
  });

  final String businessName;

  /// Faux : WhatsApp reste grisé avec « Non disponible ».
  final bool whatsappAvailable;

  /// Null = désactivé avec la mention « Bientôt ».
  final VoidCallback? onCall;
  final VoidCallback? onWhatsapp;
  final VoidCallback? onReport;

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
        TextButton.icon(
          key: const Key('detail-report'),
          onPressed: onReport,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.flag_outlined, size: 18),
          label: Text(
            onReport == null
                ? '${l10n.t('business.detail.report')} · $soon'
                : l10n.t('business.detail.report'),
            style: TextStyle(color: onReport == null ? c.textSecondary : c.accentText),
          ),
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
