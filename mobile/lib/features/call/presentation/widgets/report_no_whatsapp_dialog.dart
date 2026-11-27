// Contenu de la feuille WhatsApp quand WhatsApp est absent du téléphone : message simple et
// bouton « Ce commerce n'a pas WhatsApp » (POST /calls/whatsapp-report/). Ce bouton n'existe
// qu'après une tentative d'ouverture, puisque le serveur exige d'avoir reçu le lien.
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/call_controller.dart';
import 'call_sheet.dart';

class ReportNoWhatsappPanel extends StatelessWidget {
  const ReportNoWhatsappPanel({
    super.key,
    required this.businessName,
    required this.phase,
    required this.reportFailed,
    required this.onReport,
    required this.onClose,
  });

  final String businessName;

  /// [WhatsappPhase.notInstalled], [WhatsappPhase.reporting] ou [WhatsappPhase.reported].
  final WhatsappPhase phase;
  final bool reportFailed;
  final VoidCallback onReport;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    if (phase == WhatsappPhase.reported) {
      return SheetMessage(
        key: const Key('whatsapp-reported'),
        title: l10n.t('whatsapp.reported.title'),
        body: l10n.t('whatsapp.reported.body'),
        secondaryKey: const Key('whatsapp-close'),
        secondary: l10n.t('call.close'),
        onSecondary: onClose,
      );
    }
    final sending = phase == WhatsappPhase.reporting;
    return Column(
      key: const Key('whatsapp-not-installed'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.t('whatsapp.notInstalled.title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
            l10n
                .t('whatsapp.notInstalled.body')
                .replaceAll('{name}', businessName),
            style: TextStyle(fontSize: 13, color: c.textSecondary)),
        if (reportFailed) ...[
          const SizedBox(height: 8),
          Text(l10n.t('whatsapp.report.failed'),
              key: const Key('whatsapp-report-failed'),
              style: TextStyle(
                  fontSize: 13, color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            key: const Key('whatsapp-report'),
            // Protection du double clic : désactivé pendant l'envoi.
            onPressed: sending ? null : onReport,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.flag_outlined, size: 18),
            label: Text(l10n.t('whatsapp.report'),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
        TextButton(
          key: const Key('whatsapp-close'),
          onPressed: sending ? null : onClose,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: c.textSecondary,
          ),
          child: Text(l10n.t('call.close'),
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
