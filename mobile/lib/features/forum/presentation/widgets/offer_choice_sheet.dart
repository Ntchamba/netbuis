import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../merchant/application/offers_controller.dart';
import '../../../merchant/data/repositories/merchant_repository.dart';

/// Résultat du choix : [offer] vaut `null` pour « Aucun produit ».
class OfferChoice {
  const OfferChoice(this.offer);

  final MerchantOffer? offer;
}

/// Feuille « Associer un produit » : la liste de MES produits (jamais ceux des autres),
/// plus « Aucun produit ».
class OfferChoiceSheet extends ConsumerWidget {
  const OfferChoiceSheet({super.key, this.selectedId});

  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final offers = ref.watch(offersProvider);
    Widget message(String key, {Widget? action}) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.t(key),
                  key: const ValueKey('post-offers-message'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.4, color: c.textSecondary)),
              if (action != null) action,
            ],
          ),
        );
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                header: true,
                child: Text(l10n.t('posts.offer.sheet.title'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          ListTile(
            key: const ValueKey('post-offer-none'),
            minTileHeight: 56,
            title: Text(l10n.t('posts.offer.none')),
            trailing: selectedId == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop(const OfferChoice(null)),
          ),
          Flexible(
            child: offers.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => message(
                'posts.offer.error',
                action: TextButton(
                  key: const ValueKey('post-offers-retry'),
                  onPressed: () => ref.read(offersProvider.notifier).reload(),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(l10n.t('profile.retry')),
                ),
              ),
              data: (list) {
                final active = [for (final o in list) if (o.isActive) o];
                if (active.isEmpty) return message('posts.offer.empty');
                return ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in active)
                      ListTile(
                        key: ValueKey('post-offer-${o.id}'),
                        minTileHeight: 56,
                        title: Text(o.name),
                        subtitle: o.priceFcfa == null
                            ? Text(l10n.t('offers.price.onRequest'))
                            : Text(formatFcfa(o.priceFcfa!)),
                        trailing: o.id == selectedId ? const Icon(Icons.check) : null,
                        onTap: () => Navigator.of(context).pop(OfferChoice(o)),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
