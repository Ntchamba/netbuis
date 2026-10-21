// Résultats de la recherche écrite : chargement, erreur, « Aucun résultat » utile, liste de cartes
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../call/presentation/widgets/call_button.dart';
import '../../../call/presentation/widgets/whatsapp_button.dart';
import '../../application/offline_controller.dart';
import '../../application/search_controller.dart';
import '../widgets/offline_banner.dart';
import '../widgets/result_card.dart';

/// L'ordre des résultats vient du serveur (abonnés d'abord) : aucune étiquette « abonné »
/// n'est affichée, la carte ne montre que ce que la maquette montre.
class SearchResultsView extends ConsumerWidget {
  const SearchResultsView({
    super.key,
    required this.scroll,
    required this.onChangeCity,
  });

  final ScrollController scroll;
  final VoidCallback onChangeCity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchControllerProvider);
    final notifier = ref.read(searchControllerProvider.notifier);
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    switch (state.status) {
      case SearchStatus.idle:
        return const SizedBox.shrink();
      case SearchStatus.loading:
        return Center(
          child: Semantics(
            label: l10n.t('home.results.loading'),
            child: const CircularProgressIndicator(),
          ),
        );
      case SearchStatus.error:
        return _Message(
          title: l10n.t('home.results.error'),
          actions: [
            OutlinedButton(
              key: const Key('search-retry'),
              onPressed: notifier.retry,
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(l10n.t('home.results.retry')),
            ),
          ],
        );
      case SearchStatus.empty:
        final q = state.query.q.trim();
        return _Message(
          key: const Key('search-empty'),
          title: q.isEmpty
              ? l10n.t('search.empty.title')
              : l10n.t('search.empty.titleFor').replaceAll('{q}', q),
          lines: [l10n.t('search.empty.tipShorter'), l10n.t('search.empty.tipPlace')],
          actions: [
            OutlinedButton(
              key: const Key('search-change-city'),
              onPressed: onChangeCity,
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text(l10n.t('search.empty.changeCity')),
            ),
            if (state.query.sector != null)
              TextButton(
                key: const Key('search-clear-sector'),
                onPressed: () => notifier.setSector(null),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(l10n.t('search.empty.clearFilters')),
              ),
          ],
        );
      case SearchStatus.results:
        final extra = state.loadingMore || state.loadMoreFailed ? 1 : 0;
        final offline = ref.watch(offlineProvider);
        final list = ListView.separated(
          key: const Key('search-results'),
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          itemCount: state.items.length + extra,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) {
            if (i < state.items.length) {
              final item = state.items[i];
              return ResultCard(
                result: item,
                offline: offline,
                onCall: () => startCall(context, businessId: item.id, businessName: item.name),
                onWhatsapp: () =>
                    startWhatsapp(context, businessId: item.id, businessName: item.name),
                onOpen: () => context.push(Routes.businessDetailPath(item.id)),
              );
            }
            if (state.loadMoreFailed) {
              return _Message(
                title: l10n.t('home.results.loadMoreError'),
                actions: [
                  OutlinedButton(
                    key: const Key('search-retry-more'),
                    onPressed: notifier.loadMore,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                    child: Text(l10n.t('home.results.retry')),
                  ),
                ],
              );
            }
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator(color: c.accentText)),
            );
          },
        );
        if (!state.fromCache) return list;
        return Column(children: [
          OfflineBanner(onRetry: notifier.retry),
          Expanded(child: list),
        ]);
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.title, this.lines = const [], this.actions = const []});

  final String title;
  final List<String> lines;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: text.titleMedium),
            for (final l in lines) ...[
              const SizedBox(height: 8),
              Text(l, textAlign: TextAlign.center, style: text.bodyMedium),
            ],
            for (final a in actions) ...[const SizedBox(height: 12), a],
          ],
        ),
      ),
    );
  }
}
