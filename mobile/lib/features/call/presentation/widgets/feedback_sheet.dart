// Petite feuille facultative après un appel : « Votre appel a-t-il abouti ? ».
// Trois gros boutons avec icône ; fermable sans répondre ; jamais bloquante. Aucun numéro ici.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/call_controller.dart';
import '../../data/models/call_feedback.dart';
import 'call_sheet.dart';

/// Affiche la feuille pour l'appel [callId]. Rend vrai si une réponse a été envoyée.
/// Utilise le navigateur de [navigator] : la feuille s'affiche même si l'écran qui a lancé
/// l'appel n'est plus visible (retour du composeur).
Future<void> showCallFeedback(
  NavigatorState navigator, {
  required int callId,
  required String businessName,
}) async {
  final context = navigator.context;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final thanks = L10n.of(context).t('feedback.thanks');
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        CallFeedbackSheet(callId: callId, businessName: businessName),
  );
  if (sent == true) {
    messenger?.showSnackBar(SnackBar(content: Text(thanks)));
  }
}

class CallFeedbackSheet extends ConsumerStatefulWidget {
  const CallFeedbackSheet(
      {super.key, required this.callId, required this.businessName});

  final int callId;
  final String businessName;

  @override
  ConsumerState<CallFeedbackSheet> createState() => _CallFeedbackSheetState();
}

class _CallFeedbackSheetState extends ConsumerState<CallFeedbackSheet> {
  bool _sending = false;
  bool _failed = false;

  Future<void> _send(CallOutcome outcome) async {
    if (_sending) return; // double clic
    setState(() {
      _sending = true;
      _failed = false;
    });
    try {
      await ref
          .read(callRepositoryProvider)
          .sendFeedback(callId: widget.callId, outcome: outcome);
    } on Object {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _failed = true;
      });
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return SheetFrame(
      key: const Key('feedback-sheet'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
              l10n
                  .t('feedback.title')
                  .replaceAll('{name}', widget.businessName),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(l10n.t('feedback.hint'),
              style: TextStyle(fontSize: 12, color: c.textSecondary)),
          if (_failed) ...[
            const SizedBox(height: 8),
            Text(l10n.t('feedback.error'),
                key: const Key('feedback-error'),
                style: TextStyle(
                    fontSize: 13, color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 14),
          _OutcomeButton(
              key: const Key('feedback-answered'),
              icon: Icons.check_circle_outline,
              label: l10n.t('feedback.answered'),
              onTap: _sending ? null : () => _send(CallOutcome.answered)),
          const SizedBox(height: 10),
          _OutcomeButton(
              key: const Key('feedback-no-answer'),
              icon: Icons.phone_missed,
              label: l10n.t('feedback.noAnswer'),
              onTap: _sending ? null : () => _send(CallOutcome.noAnswer)),
          const SizedBox(height: 10),
          _OutcomeButton(
              key: const Key('feedback-wrong-number'),
              icon: Icons.phone_disabled,
              label: l10n.t('feedback.wrongNumber'),
              onTap: _sending ? null : () => _send(CallOutcome.wrongNumber)),
          TextButton(
            key: const Key('feedback-later'),
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: c.textSecondary,
            ),
            child: Text(l10n.t('feedback.later'),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _OutcomeButton extends StatelessWidget {
  const _OutcomeButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: 64,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: Icon(icon, size: 26, color: c.accentText),
        label: Text(label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
