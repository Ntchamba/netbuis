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
import '../../../merchant/presentation/screens/offers_screen.dart';
import '../../../onboarding/application/city_controller.dart';
import '../../../settings/application/help_providers.dart' show creditsEnabledProvider;
import '../../../settings/application/settings_controller.dart';
import '../../../settings/presentation/screens/settings_screen.dart' show SettingsCard, SettingsRow;
import '../../application/account_controller.dart';
import '../widgets/delete_account_flow.dart';
import '../widgets/profile_credits_card.dart';
import '../widgets/profile_identity.dart';

/// Onglet Profil (maquette Profil) : identité, appel gratuit et crédits (seulement si les
/// crédits sont activés), historique, compte business (ou invitation à l'activer), ville,
/// langue, thème, aide, déconnexion et suppression du compte.
///
/// « Modifier ma boutique » et « Corriger » (compte rejeté) sont masqués : leur écran arrive
/// avec T102b, qui ajoutera ces entrées ici.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  /// Double confirmation, puis DELETE /api/me/. Seul un succès efface jetons et état
  /// (même déconnexion que « Se déconnecter ») ; sur erreur, rien n'est effacé.
  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final deleted = await confirmAndDeleteAccount(
      context,
      onDelete: () => ref.read(accountControllerProvider.notifier).deleteAccount(),
    );
    if (deleted && ref.context.mounted) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final account = ref.watch(accountControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final creditsEnabled = ref.watch(creditsEnabledProvider);

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
              if (creditsEnabled &&
                  account.value != null &&
                  ProfileCreditsCard.hasContent(account.value!)) ...[
                ProfileCreditsCard(me: account.value!),
                const SizedBox(height: 16),
              ],
              _HistoryRow(
                label: l10n.t('profile.history'),
                onTap: () => context.push(Routes.callHistory),
              ),
              const SizedBox(height: 16),
              if (account.value?.hasBusiness == false) ...[
                _CreateBusinessCard(onTap: () => context.push(Routes.createBusiness)),
                const SizedBox(height: 16),
              ] else if (account.value?.hasBusiness == true) ...[
                // Compte business déjà demandé : son état remplace l'invitation à l'activer.
                const BusinessStatusCard(),
                const SizedBox(height: 10),
                const MyProductsEntry(),
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
              // Langue et thème ouvrent les Réglages, où se fait le choix (maquette Profil).
              SettingsCard(children: [
                SettingsRow(
                  key: const ValueKey('profile-settings'),
                  label: l10n.t('profile.language'),
                  value: l10n.t(settings.language == 'en'
                      ? 'settings.language.en'
                      : 'settings.language.fr'),
                  onTap: () => context.push(Routes.settings),
                ),
                SettingsRow(
                  key: const ValueKey('profile-theme'),
                  label: l10n.t('profile.theme'),
                  value: l10n.t(switch (settings.themeMode) {
                    ThemeMode.light => 'settings.theme.light',
                    ThemeMode.dark => 'settings.theme.dark',
                    ThemeMode.system => 'settings.theme.system',
                  }),
                  onTap: () => context.push(Routes.settings),
                ),
                SettingsRow(
                  key: const ValueKey('profile-help'),
                  label: l10n.t('profile.help'),
                  onTap: () => context.push(Routes.help),
                ),
                _DangerRow(
                  inkKey: const ValueKey('profile-logout'),
                  label: l10n.t('profile.logout'),
                  onTap: () => ref.read(authControllerProvider.notifier).logout(),
                ),
              ]),
              const SizedBox(height: 16),
              SettingsCard(children: [
                _DangerRow(
                  inkKey: const ValueKey('profile-delete'),
                  label: l10n.t('profile.delete'),
                  onTap: () => _deleteAccount(context, ref),
                ),
              ]),
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

/// Ligne d'action sensible (déconnexion, suppression), en couleur d'erreur.
class _DangerRow extends StatelessWidget {
  const _DangerRow({required this.inkKey, required this.label, required this.onTap});

  final Key inkKey;

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
        key: inkKey,
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

/// Entrée « Historique de mes appels » (maquette Profil).
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Semantics(
          button: true,
          label: label,
          onTap: onTap,
          excludeSemantics: true,
          child: InkWell(
            key: const ValueKey('profile-history'),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 20, color: c.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(label,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    Icon(Icons.chevron_right, size: 20, color: c.textSecondary),
                  ],
                ),
              ),
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
