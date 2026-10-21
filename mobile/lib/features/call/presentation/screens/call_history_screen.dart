// Historique de mes appels (maquette Historique) : nom, zone, date, badge de type, « Rappeler ».
// Aucun numéro ici : l'API n'en renvoie pas, et « Rappeler » repasse par la feuille Orange / MTN.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/call_history_controller.dart';
import '../../data/models/call_history_entry.dart';
import '../widgets/call_button.dart';

class CallHistoryScreen extends ConsumerStatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  ConsumerState<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends ConsumerState<CallHistoryScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) {
      ref.read(callHistoryControllerProvider.notifier).loadMore();
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final state = ref.watch(callHistoryControllerProvider);
    final notifier = ref.read(callHistoryControllerProvider.notifier);

    final Widget body;
    switch (state.status) {
      case HistoryStatus.loading:
        body = Center(
          child: Semantics(
            label: l10n.t('history.loading'),
            liveRegion: true,
            child: const CircularProgressIndicator(),
          ),
        );
      case HistoryStatus.error:
        body = _Message(
          key: const Key('history-error'),
          icon: Icons.error_outline,
          title: l10n.t('history.error'),
          action: OutlinedButton(
            key: const Key('history-retry'),
            onPressed: notifier.retry,
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(l10n.t('history.retry')),
          ),
        );
      case HistoryStatus.empty:
        body = _Message(
          key: const Key('history-empty'),
          icon: Icons.history,
          title: l10n.t('history.empty.title'),
          body: l10n.t('history.empty.body'),
          action: FilledButton(
            key: const Key('history-empty-action'),
            onPressed: () => context.go(Routes.home),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(l10n.t('history.empty.action')),
          ),
        );
      case HistoryStatus.results:
        final extra = state.loadingMore || state.loadMoreFailed ? 1 : 0;
        body = ListView.separated(
          key: const Key('history-list'),
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          itemCount: state.items.length + extra,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i < state.items.length) {
              return _HistoryCard(entry: state.items[i]);
            }
            if (state.loadMoreFailed) {
              return _Message(
                key: const Key('history-more-error'),
                title: l10n.t('history.loadMoreError'),
                action: OutlinedButton(
                  key: const Key('history-retry-more'),
                  onPressed: notifier.loadMore,
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(l10n.t('history.retry')),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(12),
              child:
                  Center(child: CircularProgressIndicator(color: c.accentText)),
            );
          },
        );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    key: const Key('history-back'),
                    onPressed: _back,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: c.textSecondary,
                    ),
                    icon: const Icon(Icons.chevron_left, size: 20),
                    label: Text(l10n.t('history.back'),
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            l10n.t('history.title'),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.t('history.subtitle'),
                          style:
                              TextStyle(fontSize: 13, color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// « Aujourd'hui, 09:14 » / « Hier, 17:40 » / « 28 sept., 11:02 » (selon la langue).
String formatHistoryDate(BuildContext context, DateTime date, DateTime now) {
  final l10n = L10n.of(context);
  final m = MaterialLocalizations.of(context);
  final time = m.formatTimeOfDay(TimeOfDay.fromDateTime(date),
      alwaysUse24HourFormat: true);
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return '${l10n.t('history.today')}, $time';
  if (diff == 1) return '${l10n.t('history.yesterday')}, $time';
  return '${m.formatShortMonthDay(date)}, $time';
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.entry});

  final CallHistoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isWhatsapp = entry.type == HistoryType.whatsapp;
    final date =
        formatHistoryDate(context, entry.date, ref.watch(historyNowProvider)());
    final typeLabel =
        l10n.t(isWhatsapp ? 'history.badge.whatsapp' : 'history.badge.call');
    // Couleurs de badge de la maquette : vert (réussite) pour WhatsApp, accent pour l'appel.
    final badgeBg = isWhatsapp
        ? (dark ? const Color(0xFF1E2E22) : const Color(0xFFE3F5E7))
        : (dark ? const Color(0xFF262620) : const Color(0xFFFBE7C8));
    final badgeFg = isWhatsapp
        ? (dark ? const Color(0xFF5FBE7A) : const Color(0xFF1E8A3C))
        : c.accentText;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark ? const Color(0xFF262620) : const Color(0xFFFBE7C8),
              ),
              child: Icon(
                isWhatsapp ? Icons.chat_bubble_outline : Icons.phone_outlined,
                size: 17,
                color: c.accentText,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                container: true,
                excludeSemantics: true,
                label: l10n
                    .t('history.entry')
                    .replaceAll('{name}', entry.businessName)
                    .replaceAll('{zone}', entry.zone)
                    .replaceAll('{date}', date)
                    .replaceAll('{type}', typeLabel),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.businessName,
                      key: ValueKey('history-name-${entry.id}'),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${entry.zone} · $date',
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        key: ValueKey('history-badge-${entry.id}'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: badgeFg),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              key: ValueKey('history-recall-${entry.id}'),
              tooltip: l10n
                  .t('history.callAgain')
                  .replaceAll('{name}', entry.businessName),
              onPressed: () => startCall(
                context,
                businessId: entry.businessId,
                businessName: entry.businessName,
              ),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: Icon(Icons.phone, color: c.accentText),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(
      {super.key, required this.title, this.body, this.icon, this.action});

  final String title;
  final String? body;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 40, color: c.textSecondary),
              const SizedBox(height: 12),
            ],
            Text(title, textAlign: TextAlign.center, style: text.titleMedium),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body!,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: c.textSecondary)),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
