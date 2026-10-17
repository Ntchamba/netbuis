import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/account_controller.dart';
import '../widgets/profile_identity.dart';

/// Onglet Profil (maquette Profil, partie haute) : identité puis « Se déconnecter ».
/// Les autres blocs de la maquette (appel gratuit, solde, historique, compte business,
/// langue, aide) arrivent avec leurs propres tâches, chacune ajoutant son entrée ici.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final account = ref.watch(accountControllerProvider);

    final Widget identity = account.when(
      data: (me) => ProfileIdentity(me: me),
      loading: () => Semantics(
        label: l10n.t('profile.loading'),
        liveRegion: true,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, _) => _ProfileError(
        message: _errorMessage(l10n, error),
        onRetry: () => ref.read(accountControllerProvider.notifier).reload(),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Semantics(
          label: l10n.t('profile.title'),
          container: true,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.t('profile.title'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 16),
              identity,
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.card,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _LogoutRow(
                    label: l10n.t('profile.logout'),
                    onTap: () =>
                        ref.read(authControllerProvider.notifier).logout(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Message court et traduit ; jamais le texte du serveur ni de données personnelles.
String _errorMessage(L10n l10n, Object error) {
  if (error is ApiException) {
    if (error.statusCode == 401 || error.code == ApiErrorCode.tokenInvalid) {
      return l10n.t('profile.error.session');
    }
    switch (error.code) {
      case ApiErrorCode.network:
        return l10n.t('profile.error.network');
      case ApiErrorCode.accountBlocked:
      case ApiErrorCode.accountDeleted:
        return l10n.t('profile.error.support');
      default:
        break;
    }
  }
  return l10n.t('profile.error.unknown');
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final error = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 18, color: error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: error),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('profile-retry'),
          onPressed: onRetry,
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(l10n.t('profile.retry')),
        ),
      ],
    );
  }
}

class _LogoutRow extends StatelessWidget {
  const _LogoutRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('profile-logout'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(label, style: TextStyle(fontSize: 14, color: color)),
            ),
          ),
        ),
      ),
    );
  }
}
