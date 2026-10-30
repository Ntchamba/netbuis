import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../business/application/business_controller.dart';
import '../../../business/data/models/business.dart';

/// Ne montre [builder] que si le compte business est actif ; sinon explique pourquoi
/// (« en attente de validation », comme « Mes produits »), sans rien charger d'autre.
class ActiveBusinessGate extends ConsumerWidget {
  const ActiveBusinessGate({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    return ref.watch(myBusinessProvider).when(
          loading: () => Semantics(
            label: l10n.t('posts.loading'),
            liveRegion: true,
            child: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l10n.t(error is ApiException && error.code == ApiErrorCode.network
                          ? 'posts.error.network'
                          : 'posts.error.unknown'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('posts-gate-retry'),
                    onPressed: () => ref.invalidate(myBusinessProvider),
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    child: Text(l10n.t('profile.retry')),
                  ),
                ],
              ),
            ),
          ),
          data: (business) => business.status == BusinessStatus.active
              ? builder(context)
              : PostsNotActive(rejected: business.status == BusinessStatus.rejected),
        );
  }
}

/// Compte business pas encore actif : on explique, sans rien charger.
class PostsNotActive extends StatelessWidget {
  const PostsNotActive({super.key, required this.rejected});

  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Center(
      child: Padding(
        key: const ValueKey('posts-not-active'),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(rejected ? Icons.cancel_outlined : Icons.hourglass_top,
                size: 40, color: c.accentText),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(
                l10n.t(rejected ? 'posts.rejected.title' : 'posts.pending.title'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t(rejected ? 'posts.rejected.body' : 'posts.pending.body'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4, color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
