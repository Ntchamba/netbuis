// Les feuilles « Inviter » : Devenir parrain (si l'équipe est active), Créer mon compte
// business, Partager NetBuis. Elles défilent toutes seules (3,4 s) jusqu'à la dernière,
// ou avec « Suivant ».
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/invite_steps.dart';

const Duration kInviteStepDuration = Duration(milliseconds: 3400);

Future<void> showInviteDialog(
  BuildContext context, {
  required List<InviteStep> steps,
  required VoidCallback onSponsor,
  required VoidCallback onBusiness,
  required VoidCallback onShare,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => InviteDialog(
      steps: steps,
      onSponsor: onSponsor,
      onBusiness: onBusiness,
      onShare: onShare,
    ),
  );
}

class InviteDialog extends StatefulWidget {
  const InviteDialog({
    super.key,
    required this.steps,
    required this.onSponsor,
    required this.onBusiness,
    required this.onShare,
  }) : assert(steps.length > 0);

  final List<InviteStep> steps;
  final VoidCallback onSponsor;
  final VoidCallback onBusiness;
  final VoidCallback onShare;

  @override
  State<InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<InviteDialog> {
  int _index = 0;
  Timer? _timer;

  bool get _isLast => _index >= widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    if (_isLast) return;
    _timer = Timer(kInviteStepDuration, _next);
  }

  void _next() {
    if (!mounted || _isLast) return;
    setState(() => _index++);
    _schedule();
  }

  void _act(VoidCallback action) {
    _timer?.cancel();
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final step = widget.steps[_index];
    final (icon, title, body, cta, action) = switch (step) {
      InviteStep.sponsor => (
          Icons.favorite_border,
          'home.invite.sponsor.title',
          'home.invite.sponsor.body',
          'home.invite.sponsor.cta',
          widget.onSponsor,
        ),
      InviteStep.business => (
          Icons.work_outline,
          'home.invite.business.title',
          'home.invite.business.body',
          'home.invite.business.cta',
          widget.onBusiness,
        ),
      InviteStep.share => (
          Icons.share_outlined,
          'home.invite.share.title',
          'home.invite.share.body',
          'home.invite.share.cta',
          widget.onShare,
        ),
    };
    return Dialog(
      backgroundColor: c.card,
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: c.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const Key('invite-close'),
                    tooltip: l10n.t('home.invite.close'),
                    onPressed: () {
                      _timer?.cancel();
                      Navigator.of(context).pop();
                    },
                    icon: Icon(Icons.close, size: 20, color: c.textSecondary),
                  ),
                ),
                Container(
                  width: 54,
                  height: 54,
                  decoration:
                      const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                  child: Icon(icon, size: 26, color: AppColors.onAccent),
                ),
                const SizedBox(height: 14),
                Text(l10n.t(title),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.3)),
                const SizedBox(height: 12),
                Text(l10n.t(body),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.45, color: c.textSecondary)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    key: const Key('invite-cta'),
                    onPressed: () => _act(action),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.onAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l10n.t(cta),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
                if (!_isLast)
                  TextButton(
                    key: const Key('invite-next'),
                    onPressed: _next,
                    child: Text(l10n.t('home.invite.next')),
                  ),
                const SizedBox(height: 10),
                Semantics(
                  label: l10n
                      .t('home.invite.step')
                      .replaceFirst('{n}', '${_index + 1}')
                      .replaceFirst('{total}', '${widget.steps.length}'),
                  excludeSemantics: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < widget.steps.length; i++)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _index ? AppColors.accent : c.border,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
