import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/dashed_border.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../business/presentation/widgets/business_status_card.dart';
import '../../../onboarding/application/city_controller.dart';
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
          // Colonne qui défile (et non liste paresseuse) : tout est construit même quand
          // l'encart « compte business » et une grande police poussent la fin hors de l'écran.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
              if (account.value?.hasBusiness == false) ...[
                _CreateBusinessCard(onTap: () => context.push(Routes.createBusiness)),
                const SizedBox(height: 16),
              ] else if (account.value?.hasBusiness == true) ...[
                // Compte business déjà demandé : son état remplace l'invitation à l'activer.
                const BusinessStatusCard(),
                const SizedBox(height: 16),
              ],
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.card,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _CityRow(
                    label: l10n.t('city.profile.label'),
                    value: ref.watch(selectedCityProvider).value?.name ??
                        l10n.t('city.profile.none'),
                    onTap: () => context.push(Routes.chooseCity),
                  ),
                ),
              ),
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

/// Entrée « Ma ville » : rouvre le choix de la ville.
class _CityRow extends StatelessWidget {
  const _CityRow({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: '$label : $value',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('profile-city'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.location_city_outlined, size: 20, color: c.accentText),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: c.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Invitation à créer son compte business (maquette Profil, encart en tirets) : visible
/// seulement tant que le compte n'a pas de compte business.
class _CreateBusinessCard extends StatelessWidget {
  const _CreateBusinessCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DashedBorderBox(
      key: const ValueKey('profile-create-business'),
      color: dark ? const Color(0xFF3A3A2E) : const Color(0xFFE3C98A),
      background: c.card,
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.t('business.create.profile.title'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.t('business.create.profile.body'),
            style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
          ),
          const SizedBox(height: 10),
          FilledButton(
            key: const ValueKey('profile-create-business-button'),
            onPressed: onTap,
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(l10n.t('business.create.profile.button'), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}
