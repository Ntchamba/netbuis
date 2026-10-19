import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/business_controller.dart';
import '../../data/models/business.dart';

/// Carte « COMPTE BUSINESS » du Profil (maquette Profil, bloc COMPTE BUSINESS) quand le compte
/// a déjà un compte business : son état lu via GET /api/business/me/ — en attente de
/// validation, actif, ou rejeté avec le motif. Une erreur de lecture reste discrète
/// (message + « Réessayer ») et ne bloque pas le reste du Profil.
class BusinessStatusCard extends ConsumerWidget {
  const BusinessStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final status = ref.watch(myBusinessProvider);

    final Widget content = status.when(
      loading: () => Semantics(
        label: l10n.t('business.status.loading'),
        liveRegion: true,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => _StatusError(
        message: l10n.t(error is ApiException && error.code == ApiErrorCode.network
            ? 'business.status.error.network'
            : 'business.status.error.unknown'),
        onRetry: () => ref.invalidate(myBusinessProvider),
      ),
      data: (business) => _StatusBody(business: business),
    );

    return DecoratedBox(
      key: const ValueKey('profile-business-status'),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
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
                l10n.t('business.status.title'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.accentText),
              ),
            ),
            const SizedBox(height: 10),
            content,
          ],
        ),
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  const _StatusBody({required this.business});

  final MyBusiness business;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (IconData icon, Color color, String title, String body) = switch (business.status) {
      BusinessStatus.pending => (
          Icons.hourglass_top,
          c.accentText,
          l10n.t('business.status.pending'),
          l10n.t('business.status.pending.body'),
        ),
      BusinessStatus.active => (
          Icons.check_circle,
          dark ? const Color(0xFF4CC38A) : const Color(0xFF1E7B4F),
          l10n.t('business.status.active'),
          l10n.t('business.status.active.body'),
        ),
      BusinessStatus.rejected => (
          Icons.cancel,
          scheme.error,
          l10n.t('business.status.rejected'),
          l10n.t('business.status.rejected.body'),
        ),
    };
    final motif = business.motifRejet;
    return Column(
      key: ValueKey('profile-business-status-${business.status.value}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (business.name.isNotEmpty) ...[
          Text(business.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
        ],
        Semantics(
          container: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
        ),
        if (business.status == BusinessStatus.rejected && motif.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            l10n.t('business.status.rejected.motif').replaceAll('{motif}', motif),
            key: const ValueKey('profile-business-motif'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4),
          ),
        ],
        const SizedBox(height: 6),
        Text(body, style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary)),
      ],
    );
  }
}

class _StatusError extends StatelessWidget {
  const _StatusError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Column(
      key: const ValueKey('profile-business-status-error'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(message, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
        ),
        const SizedBox(height: 4),
        TextButton(
          key: const ValueKey('profile-business-status-retry'),
          onPressed: onRetry,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n.t('profile.retry')),
        ),
      ],
    );
  }
}
