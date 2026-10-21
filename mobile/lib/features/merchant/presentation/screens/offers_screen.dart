import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../business/application/business_controller.dart';
import '../../../business/data/models/business.dart';
import '../../application/offers_controller.dart';
import '../../data/repositories/merchant_repository.dart';
import 'edit_offer_screen.dart';

/// Ligne « Mes produits  12 → » du Profil (maquette Profil, bloc COMPTE BUSINESS). Le nombre
/// n'apparaît que si le compte business est actif et la liste chargée. Toucher la ligne ouvre
/// [OffersScreen], qui explique « en attente de validation » tant que le compte n'est pas actif.
class MyProductsEntry extends ConsumerWidget {
  const MyProductsEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final business = ref.watch(myBusinessProvider).value;
    if (business == null) return const SizedBox.shrink();
    final active = business.status == BusinessStatus.active;
    final count = active ? ref.watch(offersProvider).value?.length : null;
    final label = l10n.t('offers.title');
    final value = count == null ? '→' : '$count →';
    void open() => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(builder: (_) => const OffersScreen()),
        );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Semantics(
        button: true,
        label: count == null ? label : '$label : $count',
        onTap: open,
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey('profile-my-products'),
          borderRadius: BorderRadius.circular(16),
          onTap: open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14)),
                  Text(
                    value,
                    key: const ValueKey('profile-my-products-count'),
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « Mes produits » : liste, ajout, modification, suppression avec confirmation.
/// Réservé au compte business actif.
class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final status = ref.watch(myBusinessProvider);
    final active = status.value?.status == BusinessStatus.active;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('offers.title'))),
      floatingActionButton: active && ref.watch(offersProvider).hasValue
          ? FloatingActionButton.extended(
              key: const ValueKey('offers-add'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const EditOfferScreen()),
              ),
              icon: const Icon(Icons.add),
              label: Text(l10n.t('offers.add')),
            )
          : null,
      body: SafeArea(
        child: status.when(
          loading: () => _Loading(label: l10n.t('offers.loading')),
          error: (error, _) => _Problem(
            message: l10n.t(error is ApiException && error.code == ApiErrorCode.network
                ? 'business.status.error.network'
                : 'business.status.error.unknown'),
            onRetry: () => ref.invalidate(myBusinessProvider),
          ),
          data: (business) => business.status == BusinessStatus.active
              ? const _OffersList()
              : _NotActive(rejected: business.status == BusinessStatus.rejected),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        liveRegion: true,
        child: const Center(child: CircularProgressIndicator()),
      );
}

class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(liveRegion: true, child: Text(message, textAlign: TextAlign.center)),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('offers-retry'),
              onPressed: onRetry,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(l10n.t('profile.retry')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compte pas encore actif : on explique, sans rien charger.
class _NotActive extends StatelessWidget {
  const _NotActive({required this.rejected});

  final bool rejected;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Center(
      child: Padding(
        key: const ValueKey('offers-not-active'),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(rejected ? Icons.cancel_outlined : Icons.hourglass_top, size: 40, color: c.accentText),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(
                l10n.t(rejected ? 'offers.rejected.title' : 'offers.pending.title'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t(rejected ? 'offers.rejected.body' : 'offers.pending.body'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4, color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _OffersList extends ConsumerWidget {
  const _OffersList();

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, MerchantOffer offer) async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.t('offers.delete.title')),
        content: Text(l10n.t('offers.delete.body').replaceAll('{name}', offer.name)),
        actions: [
          TextButton(
            key: const ValueKey('offers-delete-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.t('offers.delete.cancel')),
          ),
          TextButton(
            key: const ValueKey('offers-delete-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.t('offers.delete.confirm')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(offersProvider.notifier).delete(offer.id);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.t(offerErrorKey(e)))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final offers = ref.watch(offersProvider);
    return offers.when(
      loading: () => _Loading(label: l10n.t('offers.loading')),
      error: (error, _) => isNotActiveError(error)
          ? const _NotActive(rejected: false)
          : _Problem(
              message: l10n.t(offerErrorKey(error)),
              onRetry: () => ref.read(offersProvider.notifier).reload(),
            ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.t('offers.empty'),
                key: const ValueKey('offers-empty'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.4, color: c.textSecondary),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final offer = list[i];
            return _OfferRow(
              offer: offer,
              onEdit: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => EditOfferScreen(existing: offer)),
              ),
              onDelete: () => _confirmDelete(context, ref, offer),
            );
          },
        );
      },
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer, required this.onEdit, required this.onDelete});

  final MerchantOffer offer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final price = offer.priceFcfa == null ? l10n.t('offers.price.onRequest') : formatFcfa(offer.priceFcfa!);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: ValueKey('offer-${offer.id}'),
              borderRadius: BorderRadius.circular(16),
              onTap: onEdit,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(offer.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(price, style: TextStyle(fontSize: 13, color: c.accentText)),
                      if (offer.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          offer.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            key: ValueKey('offer-delete-${offer.id}'),
            tooltip: l10n.t('offers.delete.action'),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
