import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/business_controller.dart';
import '../../data/models/business.dart';

/// Encart du Profil « Vous recevez beaucoup d'appels » (T111), sans maquette. Affiché seulement
/// pour un compte business ACTIF dont le serveur renvoie `suggest_subscription` vrai ; masqué
/// pendant le chargement, en cas d'erreur, en attente, rejeté ou sans compte business. Ton
/// bienveillant : aucune urgence, aucun prix. « Souscrire » ouvre [Routes.subscriptionSoon].
class SubscriptionSuggestionCard extends ConsumerWidget {
  const SubscriptionSuggestionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(myBusinessProvider).value;
    if (business == null ||
        business.status != BusinessStatus.active ||
        !business.suggestSubscription) {
      return const SizedBox.shrink();
    }
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        key: const ValueKey('profile-subscription-card'),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.10),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.t('subscription.card.title'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.t('subscription.card.body'),
                style: TextStyle(
                    fontSize: 12.5, height: 1.4, color: c.textSecondary),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: l10n.t('subscription.card.button.semantic'),
                button: true,
                excludeSemantics: true,
                onTap: () => context.push(Routes.subscriptionSoon),
                child: FilledButton(
                  key: const ValueKey('profile-subscription-button'),
                  onPressed: () => context.push(Routes.subscriptionSoon),
                  style:
                      FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(l10n.t('subscription.card.button'),
                      textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
