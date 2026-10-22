import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../call/data/call_channel.dart';
import '../../../settings/application/help_providers.dart';
import '../../../settings/presentation/widgets/settings_page.dart';

/// « Bientôt disponible — contactez le support » (T111, sans maquette) : la souscription n'est pas
/// encore ouverte. Même mécanisme que l'écran Aide pour WhatsApp : bouton grisé tant que le
/// numéro du support n'est pas renseigné (D-06), message pré-rempli sans numéro de personne.
class SubscriptionSoonScreen extends ConsumerWidget {
  const SubscriptionSoonScreen({super.key});

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _open(BuildContext context, WidgetRef ref, String link) async {
    final l10n = L10n.of(context);
    WhatsappOpenResult result;
    try {
      result = await ref.read(callChannelProvider).openWhatsapp(link);
    } on Object {
      result = WhatsappOpenResult.failed;
    }
    if (!context.mounted) return;
    switch (result) {
      case WhatsappOpenResult.opened:
        break;
      case WhatsappOpenResult.notInstalled:
        _snack(context, l10n.t('help.whatsapp.notInstalled'));
      case WhatsappOpenResult.failed:
        _snack(context, l10n.t('help.whatsapp.failed'));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final contact = ref.watch(supportContactProvider);
    final link =
        contact.whatsappLink(message: l10n.t('subscription.soon.message'));
    final enabled = link != null;
    final label = l10n.t('subscription.soon.whatsapp');
    return SettingsPage(
      title: l10n.t('subscription.soon.title'),
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.t('subscription.soon.heading'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.t('subscription.soon.body'),
          key: const ValueKey('subscription-soon-body'),
          style: TextStyle(fontSize: 14, height: 1.5, color: c.textSecondary),
        ),
        const SizedBox(height: 20),
        Semantics(
          button: true,
          enabled: enabled,
          excludeSemantics: true,
          label: enabled ? label : '$label. ${l10n.t('help.contact.soon')}',
          onTap: enabled ? () => _open(context, ref, link) : null,
          child: FilledButton.icon(
            key: const ValueKey('subscription-whatsapp'),
            onPressed: enabled ? () => _open(context, ref, link) : null,
            style: FilledButton.styleFrom(minimumSize: const Size(48, 52)),
            icon: const Text('💬', style: TextStyle(fontSize: 18)),
            label: Text(label, textAlign: TextAlign.center),
          ),
        ),
        if (!enabled) ...[
          const SizedBox(height: 8),
          Text(
            l10n.t('help.contact.soon'),
            key: const ValueKey('subscription-contact-soon'),
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey('subscription-back'),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
          child: Text(l10n.t('subscription.soon.back')),
        ),
      ],
    );
  }
}
