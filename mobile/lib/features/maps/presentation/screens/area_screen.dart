// Écran Quartier (maquette Quartier) : fil d'Ariane « Cameroun · Ville », nom du quartier,
// puis les commerces (mêmes cartes que la recherche). Aucun numéro affiché.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../call/presentation/widgets/call_button.dart';
import '../../../call/presentation/widgets/whatsapp_button.dart';
import '../../../search/application/offline_controller.dart';
import '../../../search/presentation/widgets/result_card.dart';
import '../../application/area_businesses_controller.dart';
import '../../application/map_controller.dart';

/// Ce que l'écran Carte transmet (`extra`) pour le fil d'Ariane. Absent (lien direct) :
/// le titre est générique et le fil ne montre que le pays.
class AreaArgs {
  const AreaArgs({required this.areaName, this.cityId, this.cityName});

  final String areaName;
  final int? cityId;
  final String? cityName;
}

class AreaScreen extends ConsumerStatefulWidget {
  const AreaScreen({super.key, required this.areaId, this.args});

  final int areaId;
  final AreaArgs? args;

  @override
  ConsumerState<AreaScreen> createState() => _AreaScreenState();
}

class _AreaScreenState extends ConsumerState<AreaScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.extentAfter < 300) {
        ref.read(areaBusinessesProvider(widget.areaId).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _backToArea() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.map);
    }
  }

  void _backToCities() {
    ref.read(mapControllerProvider.notifier).backToCities();
    context.go(Routes.map);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final state = ref.watch(areaBusinessesProvider(widget.areaId));
    final offline = ref.watch(offlineProvider);
    final notifier = ref.read(areaBusinessesProvider(widget.areaId).notifier);
    final args = widget.args;
    final cityName = args?.cityName;
    final title = (args?.areaName.isNotEmpty ?? false)
        ? args!.areaName
        : l10n.t('map.area.title');

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    key: const Key('area-back'),
                    onPressed: _backToArea,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.only(right: 12),
                      foregroundColor: c.textSecondary,
                    ),
                    icon: const Icon(Icons.chevron_left, size: 18),
                    label: Text(l10n.t('map.area.back'),
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Row(
                    key: const Key('area-breadcrumb'),
                    children: [
                      _Crumb(
                        key: const Key('area-crumb-country'),
                        label: l10n.t('map.area.country'),
                        hint: l10n.t('map.area.crumbCountry'),
                        onTap: _backToCities,
                      ),
                      if (cityName != null) ...[
                        Text(' · ',
                            style: TextStyle(
                                fontSize: 11, color: c.textSecondary)),
                        Flexible(
                          child: _Crumb(
                            key: const Key('area-crumb-city'),
                            label: cityName,
                            hint: l10n
                                .t('map.area.crumbCity')
                                .replaceAll('{name}', cityName),
                            onTap: _backToArea,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Semantics(
                    header: true,
                    child: Text(title,
                        key: const Key('area-title'),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            if (offline && state.status == AreaStatus.ready)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(l10n.t('offline.blocked'),
                    key: const Key('area-offline'),
                    style: TextStyle(fontSize: 13, color: c.textSecondary)),
              ),
            Expanded(
              child: switch (state.status) {
                AreaStatus.loading => Center(
                    child: Semantics(
                      label: l10n.t('map.area.loading'),
                      child: const CircularProgressIndicator(),
                    ),
                  ),
                AreaStatus.error => _Message(
                    key: const Key('area-error'),
                    title: l10n.t(offline ? 'map.offline' : 'map.area.error'),
                    retryKey: const Key('area-retry'),
                    retryLabel: l10n.t('map.retry'),
                    onRetry: notifier.retry,
                  ),
                AreaStatus.empty => _Message(
                    key: const Key('area-empty'),
                    title: l10n.t('map.area.empty'),
                  ),
                AreaStatus.ready => ListView.separated(
                    key: const Key('area-results'),
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: state.items.length +
                        (state.loadingMore || state.loadMoreFailed ? 1 : 0),
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      if (i < state.items.length) {
                        final item = state.items[i];
                        return ResultCard(
                          result: item,
                          offline: offline,
                          onCall: () => startCall(context,
                              businessId: item.id, businessName: item.name),
                          onWhatsapp: () => startWhatsapp(context,
                              businessId: item.id, businessName: item.name),
                          onOpen: () =>
                              context.push(Routes.businessDetailPath(item.id)),
                        );
                      }
                      if (state.loadMoreFailed) {
                        return _Message(
                          key: const Key('area-more-error'),
                          title: l10n.t('map.area.loadMoreError'),
                          retryKey: const Key('area-retry-more'),
                          retryLabel: l10n.t('map.retry'),
                          onRetry: notifier.loadMore,
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                            child:
                                CircularProgressIndicator(color: c.accentText)),
                      );
                    },
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb(
      {super.key,
      required this.label,
      required this.hint,
      required this.onTap});

  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: '$label. $hint',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            widthFactor: 1,
            alignment: Alignment.centerLeft,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: c.textSecondary)),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(
      {super.key,
      required this.title,
      this.retryKey,
      this.retryLabel,
      this.onRetry});

  final String title;
  final Key? retryKey;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: retryKey,
                onPressed: onRetry,
                style:
                    OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(retryLabel ?? ''),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
