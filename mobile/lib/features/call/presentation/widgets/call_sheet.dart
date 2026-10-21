// Feuille d'appel (maquettes Main et Quartier) : choix de la ligne, puis « Appel en cours... ».
// Le numéro du commerçant n'apparaît JAMAIS ici, même dans le repli composeur.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/call_controller.dart';
import '../../data/call_channel.dart';
import '../../data/models/call_session.dart';

const Color _orange = Color(0xFFFF7900);
const Color _mtn = Color(0xFFFFCC00);
const Color _onLine = Color(0xFF1A1200);

Color _lineColor(CallLine? line) => switch (line) {
      CallLine.orange => _orange,
      CallLine.mtn => _mtn,
      null => AppColors.accent,
    };

class CallSheet extends ConsumerWidget {
  const CallSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(callFlowProvider);
    ref.listen<CallFlowState>(callFlowProvider, (_, next) {
      if (next.phase == CallPhase.done && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
    final c = AppColors.of(context);
    final locked = s.phase == CallPhase.preparing || s.phase == CallPhase.running;
    return PopScope(
      canPop: !locked,
      child: Container(
        key: const Key('call-sheet'),
        width: double.infinity,
        decoration: BoxDecoration(
          color: c.card,
          border: Border(top: BorderSide(color: c.border)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(child: _body(context, ref, s)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, CallFlowState s) {
    final l10n = L10n.of(context);
    final flow = ref.read(callFlowProvider.notifier);
    switch (s.phase) {
      case CallPhase.idle:
      case CallPhase.done:
        return const SizedBox(height: 1);
      case CallPhase.preparing:
        return Center(
          child: Semantics(
            label: l10n.t('call.preparing'),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          ),
        );
      case CallPhase.chooseLine:
        return Column(
          key: const Key('call-choose'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Target(name: s.businessName),
            const SizedBox(height: 14),
            Text(l10n.t('call.chooseLine'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _LineButton(
                key: const Key('call-orange'),
                line: CallLine.orange,
                label: l10n.t('call.line.orange'),
                onTap: () => flow.chooseLine(CallLine.orange)),
            const SizedBox(height: 14),
            _LineButton(
                key: const Key('call-mtn'),
                line: CallLine.mtn,
                label: l10n.t('call.line.mtn'),
                onTap: () => flow.chooseLine(CallLine.mtn)),
            _CancelButton(onTap: flow.cancel),
            _HonestNote(text: l10n.t('call.honest')),
          ],
        );
      case CallPhase.running:
        final line = s.line;
        final lineName = line != null ? l10n.t('call.line.${line.value}') : s.runningLabel;
        final c = AppColors.of(context);
        return Column(
          key: const Key('call-running'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _lineColor(line)),
              child: const Icon(Icons.call, size: 26, color: _onLine),
            ),
            const SizedBox(height: 12),
            Text(l10n.t('call.running'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(
              lineName.isEmpty
                  ? s.businessName
                  : l10n
                      .t('call.runningFor')
                      .replaceAll('{name}', s.businessName)
                      .replaceAll('{line}', lineName),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: c.textSecondary),
            ),
            const SizedBox(height: 10),
          ],
        );
      case CallPhase.rationale:
        return _Message(
          key: const Key('call-rationale'),
          title: l10n.t('call.rationale.title'),
          body: l10n.t('call.rationale.body'),
          primaryKey: const Key('call-rationale-ok'),
          primary: l10n.t('call.rationale.ok'),
          onPrimary: flow.confirmRationale,
          secondaryKey: const Key('call-rationale-cancel'),
          secondary: l10n.t('call.rationale.cancel'),
          onSecondary: flow.cancel,
        );
      case CallPhase.lineAbsent:
        final absent = s.absentLine ?? CallLine.orange;
        final other = absent.other;
        return _Message(
          key: const Key('call-absent'),
          title: l10n
              .t('call.absent.title')
              .replaceAll('{line}', l10n.t('call.line.${absent.value}')),
          primaryKey: const Key('call-other-line'),
          primary: l10n
              .t('call.absent.offer')
              .replaceAll('{line}', l10n.t('call.line.${other.value}')),
          onPrimary: flow.chooseOtherLine,
          secondaryKey: const Key('call-cancel'),
          secondary: l10n.t('call.cancel'),
          onSecondary: flow.cancel,
        );
      case CallPhase.pickSim:
        return Column(
          key: const Key('call-pick-sim'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Target(name: s.businessName),
            const SizedBox(height: 14),
            Text(l10n.t('call.pickSim.title'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l10n.t('call.pickSim.body'),
                style: TextStyle(fontSize: 13, color: AppColors.of(context).textSecondary)),
            const SizedBox(height: 14),
            for (var i = 0; i < s.sims.length; i++) ...[
              _SimButton(
                  key: Key('call-sim-$i'),
                  sim: s.sims[i],
                  onTap: () => flow.pickSim(s.sims[i])),
              const SizedBox(height: 10),
            ],
            _CancelButton(onTap: flow.cancel),
            _HonestNote(text: l10n.t('call.honest')),
          ],
        );
      case CallPhase.dialWarning:
        return _Message(
          key: const Key('call-dial-warning'),
          title: l10n.t('call.dial.title'),
          body: l10n.t('call.dial.body'),
          primaryKey: const Key('call-dial-ok'),
          primary: l10n.t('call.dial.ok'),
          onPrimary: flow.confirmDial,
          secondaryKey: const Key('call-cancel'),
          secondary: l10n.t('call.cancel'),
          onSecondary: flow.cancel,
        );
      case CallPhase.unsupported:
        return _Message(
          key: const Key('call-unsupported'),
          title: l10n.t('call.unsupported'),
          body: l10n.t('call.honest'),
          secondaryKey: const Key('call-close'),
          secondary: l10n.t('call.close'),
          onSecondary: flow.cancel,
        );
      case CallPhase.error:
        return _Message(
          key: const Key('call-error'),
          title: l10n.t('call.error.${(s.error ?? CallError.generic).name}'),
          secondaryKey: const Key('call-close'),
          secondary: l10n.t('call.close'),
          onSecondary: flow.cancel,
        );
    }
  }
}

class _Target extends StatelessWidget {
  const _Target({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.t('call.you'),
            style: TextStyle(fontSize: 12, color: AppColors.of(context).textSecondary)),
        const SizedBox(height: 2),
        Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _LineButton extends StatelessWidget {
  const _LineButton(
      {super.key, required this.line, required this.label, required this.onTap});

  final CallLine line;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = _lineColor(line);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: c.background,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color, width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                    child: const Icon(Icons.call, size: 20, color: _onLine),
                  ),
                  const SizedBox(width: 14),
                  Text(label,
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800, color: c.textPrimary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Repli : une SIM, avec le nom que le système lui donne.
class _SimButton extends StatelessWidget {
  const _SimButton({super.key, required this.sim, required this.onTap});

  final SimAccount sim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        alignment: Alignment.centerLeft,
        foregroundColor: c.textPrimary,
        side: BorderSide(color: c.border, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.sim_card_outlined),
      label: Text(sim.displayName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
        key: const Key('call-cancel'),
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: AppColors.of(context).textSecondary,
        ),
        child: Text(L10n.of(context).t('call.cancel'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      );
}

/// Texte honnête de la décision D-07 : le téléphone peut montrer le numéro.
class _HonestNote extends StatelessWidget {
  const _HonestNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text,
            key: const Key('call-honest'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.of(context).textSecondary)),
      );
}

class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.title,
    this.body,
    this.primary,
    this.primaryKey,
    this.onPrimary,
    this.secondary,
    this.secondaryKey,
    this.onSecondary,
  });

  final String title;
  final String? body;
  final String? primary;
  final Key? primaryKey;
  final VoidCallback? onPrimary;
  final String? secondary;
  final Key? secondaryKey;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(body!, style: TextStyle(fontSize: 13, color: c.textSecondary)),
        ],
        const SizedBox(height: 16),
        if (primary != null)
          SizedBox(
            height: 52,
            child: FilledButton(
              key: primaryKey,
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(primary!,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        if (secondary != null)
          TextButton(
            key: secondaryKey,
            onPressed: onSecondary,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: c.textSecondary,
            ),
            child: Text(secondary!,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}
