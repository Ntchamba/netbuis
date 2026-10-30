// Écran d'appel à l'équipe NetBuis (D-25). Écran sans maquette : style de la feuille « Appel en
// cours... » de la maquette Main (pastille d'accent, titre 16 px / 800) étendu à tout l'écran.
// Ni numéro, ni salle, ni jeton ici.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/call_controller.dart';

/// « 00:07 » à partir d'un nombre de secondes.
String formatCallTimer(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class CallScreen extends ConsumerWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(callFlowProvider);
    ref.listen<CallFlowState>(callFlowProvider, (_, next) {
      if (next.phase == CallPhase.done && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
    return PopScope(
      canPop: !s.live,
      child: Scaffold(
        key: const Key('call-screen'),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: _body(context, ref, s),
          ),
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
        return const SizedBox.shrink();
      case CallPhase.preparing:
        return Center(
          key: const Key('call-preparing'),
          child: Semantics(
            label: l10n.t('call.preparing'),
            child: const CircularProgressIndicator(),
          ),
        );
      case CallPhase.ringing:
        return _Live(
          key: const Key('call-running'),
          title: l10n.t('call.running'),
          business: s.businessName,
          timer: formatCallTimer(s.seconds),
          icon: Icons.call,
          action: _Action(
              key: const Key('call-cancel'),
              label: l10n.t('call.cancel'),
              onTap: flow.cancel,
              danger: true),
        );
      case CallPhase.connected:
        return _Live(
          key: const Key('call-connected'),
          title: l10n.t('call.connected'),
          business: s.businessName,
          timer: formatCallTimer(s.seconds),
          icon: Icons.call,
          action: _Action(
              key: const Key('call-hangup'),
              label: l10n.t('call.hangup'),
              onTap: flow.hangUp,
              danger: true),
        );
      case CallPhase.ended:
        return _Result(
          key: const Key('call-ended'),
          icon: Icons.call_end,
          title: l10n.t('call.ended'),
          body: s.seconds > 0
              ? l10n.t('call.ended.duration').replaceAll('{time}', formatCallTimer(s.seconds))
              : null,
          onClose: flow.close,
        );
      case CallPhase.unavailable:
        return _Result(
          key: const Key('call-unavailable'),
          icon: Icons.person_off_outlined,
          title: l10n.t('call.unavailable'),
          onClose: flow.close,
        );
      case CallPhase.missed:
        return _Result(
          key: const Key('call-missed'),
          icon: Icons.phone_missed,
          title: l10n.t('call.missed'),
          body: l10n.t('call.missed.body'),
          onClose: flow.close,
        );
      case CallPhase.declined:
        return _Result(
          key: const Key('call-declined'),
          icon: Icons.phone_disabled,
          title: l10n.t('call.declined'),
          body: l10n.t('call.declined.body'),
          onClose: flow.close,
        );
      case CallPhase.micRationale:
        return _Result(
          key: const Key('call-mic-rationale'),
          icon: Icons.mic_none,
          title: l10n.t('call.mic.title'),
          body: l10n.t('call.mic.body'),
          primaryKey: const Key('call-mic-ok'),
          primary: l10n.t('call.mic.ok'),
          onPrimary: flow.requestMicrophone,
          closeLabel: l10n.t('call.mic.later'),
          onClose: flow.close,
        );
      case CallPhase.micDenied:
        return _Result(
          key: const Key('call-mic-denied'),
          icon: Icons.mic_off_outlined,
          title: l10n.t('call.mic.denied.title'),
          body: l10n.t('call.mic.denied.body'),
          primaryKey: const Key('call-mic-retry'),
          primary: l10n.t('call.mic.retry'),
          onPrimary: flow.requestMicrophone,
          onClose: flow.close,
        );
      case CallPhase.unsupported:
        return _Result(
          key: const Key('call-unsupported'),
          icon: Icons.phone_iphone,
          title: l10n.t('call.unsupported'),
          onClose: flow.close,
        );
      case CallPhase.webUnavailable:
        return _Result(
          key: const Key('call-web-unavailable'),
          icon: Icons.phone_android,
          title: l10n.t('call.web'),
          onClose: flow.close,
        );
      case CallPhase.error:
        return _Result(
          key: const Key('call-error'),
          icon: Icons.error_outline,
          title: l10n.t('call.error.${(s.error ?? CallError.generic).name}'),
          onClose: flow.close,
        );
    }
  }
}

/// Appel vivant : pastille, titre, commerce consulté, minuteur, mention « équipe NetBuis », bouton.
class _Live extends StatelessWidget {
  const _Live({
    super.key,
    required this.title,
    required this.business,
    required this.timer,
    required this.icon,
    required this.action,
  });

  final String title;
  final String business;
  final String timer;
  final IconData icon;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Column(
      children: [
        const Spacer(),
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
          child: Icon(icon, size: 32, color: AppColors.onAccent),
        ),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        Text(timer,
            key: const Key('call-timer'),
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()])),
        if (business.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(l10n.t('call.about').replaceAll('{name}', business),
              key: const Key('call-about'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.textSecondary)),
        ],
        const SizedBox(height: 12),
        Text(l10n.t('call.notice'),
            key: const Key('call-notice'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.textSecondary)),
        const Spacer(),
        action,
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(
      {super.key, required this.label, required this.onTap, this.danger = false});

  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: danger ? const Color(0xFFC62828) : AppColors.accent,
            foregroundColor: danger ? Colors.white : AppColors.onAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      );
}

/// Écran de résultat : icône, message, bouton principal facultatif et « Fermer ».
class _Result extends StatelessWidget {
  const _Result({
    super.key,
    required this.icon,
    required this.title,
    required this.onClose,
    this.body,
    this.primary,
    this.primaryKey,
    this.onPrimary,
    this.closeLabel,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? primary;
  final Key? primaryKey;
  final VoidCallback? onPrimary;
  final String? closeLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(icon, size: 48, color: c.accentText),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(body!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.textSecondary)),
        ],
        const Spacer(),
        if (primary != null) ...[
          _Action(key: primaryKey, label: primary!, onTap: onPrimary!),
          const SizedBox(height: 8),
        ],
        TextButton(
          key: const Key('call-close'),
          onPressed: onClose,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 52),
            foregroundColor: c.textSecondary,
          ),
          child: Text(closeLabel ?? l10n.t('call.close'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
