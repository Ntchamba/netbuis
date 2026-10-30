// Bande « Très demandé près de chez vous » + rangée « Commerces très contactés »
// Widget prêt à poser sur l'Accueil : il se masque tout seul s'il n'y a rien à montrer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../search/application/search_controller.dart';
import '../../../onboarding/application/city_controller.dart';
import '../../application/trends_controller.dart';
import '../../data/models/trend.dart';

/// Produits montrés au plus.
const int kTrendingProductsMax = 6;

/// Commerces montrés au plus.
const int kTrendingBusinessesMax = 3;

class TrendingSection extends ConsumerWidget {
  const TrendingSection({super.key, this.onProductTap, this.onBusinessTap});

  /// Appelé avec le nom du produit touché. Par défaut : lance la recherche de ce terme
  /// dans la ville de la bande, sans secteur ni autre filtre, puis ouvre l'écran de recherche.
  final ValueChanged<String>? onProductTap;

  /// Appelé avec l'identifiant du commerce touché. Par défaut : ouvre sa fiche publique.
  final ValueChanged<int>? onBusinessTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trends = ref.watch(cityTrendsProvider).value;
    if (trends == null || trends.isEmpty) return const SizedBox.shrink();
    return TrendingContent(
      trends: trends,
      onProductTap: onProductTap ?? (name) => _searchProduct(context, ref, name),
      onBusinessTap: onBusinessTap ??
          (id) => context.push(Routes.businessDetailPath(id)),
    );
  }

  void _searchProduct(BuildContext context, WidgetRef ref, String name) {
    final zone = ref.read(selectedCityProvider).value?.id;
    ref.read(searchControllerProvider.notifier).searchFresh(name, zone: zone);
    context.push(Routes.search);
  }
}

/// Affichage pur des tendances (tronquées à 6 produits et 3 commerces).
class TrendingContent extends StatelessWidget {
  const TrendingContent({
    super.key,
    required this.trends,
    required this.onProductTap,
    required this.onBusinessTap,
  });

  final Trends trends;
  final ValueChanged<String> onProductTap;
  final ValueChanged<int> onBusinessTap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final products = trends.products.take(kTrendingProductsMax).toList();
    final businesses = trends.businesses.take(kTrendingBusinessesMax).toList();
    if (products.isEmpty && businesses.isEmpty) return const SizedBox.shrink();
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (products.isNotEmpty) ...[
          _Title(l10n.t('trends.products.title')),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, box) => Wrap(
              key: const Key('trending-products'),
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in products)
                  _ProductChip(
                    product: p,
                    maxWidth: box.maxWidth,
                    semantic: l10n.t('trends.product.semantic').replaceAll('{name}', p.name),
                    onTap: () => onProductTap(p.name),
                  ),
              ],
            ),
          ),
        ],
        if (products.isNotEmpty && businesses.isNotEmpty) const SizedBox(height: 16),
        if (businesses.isNotEmpty) ...[
          _Title(l10n.t('trends.businesses.title')),
          const SizedBox(height: 4),
          Column(
            key: const Key('trending-businesses'),
            children: [
              for (final b in businesses)
                Semantics(
                  button: true,
                  label: l10n
                      .t('trends.business.semantic')
                      .replaceAll('{name}', b.name)
                      .replaceAll('{zone}', b.zoneName),
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => onBusinessTap(b.id),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Row(
                        children: [
                          Icon(Icons.storefront_outlined, size: 22, color: c.accentText),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(b.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: c.textPrimary)),
                                Text(b.zoneName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, color: c.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(text,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.of(context).textPrimary)),
      );
}

class _ProductChip extends StatelessWidget {
  const _ProductChip({
    required this.product,
    required this.maxWidth,
    required this.semantic,
    required this.onTap,
  });

  final TrendProduct product;
  final double maxWidth;
  final String semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Semantics(
        button: true,
        label: semantic,
        excludeSemantics: true,
        child: Material(
          color: c.card,
          shape: StadiumBorder(side: BorderSide(color: c.border)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up, size: 18, color: c.accentText),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary)),
                    ),
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
