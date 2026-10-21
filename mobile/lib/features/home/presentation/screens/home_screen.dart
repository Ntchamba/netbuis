// Accueil : en-tête, recherche + micro, puces de secteurs, commerces de la ville, encart « Aidez NetBuis »
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/data/referentials/referential_models.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/netbuis_logo.dart';
import '../../../account/application/account_controller.dart';
import '../../../search/application/search_controller.dart';
import '../../../search/voice_search/application/voice_search_controller.dart';
import '../../../search/voice_search/presentation/voice_button.dart';
import '../../../search/voice_search/presentation/voice_listening_sheet.dart';
import '../../../search/presentation/widgets/result_card.dart';
import '../../application/home_sectors.dart';
import '../../application/invite_steps.dart';
import '../../data/share_service.dart';
import '../widgets/category_chips.dart';
import '../widgets/invite_banner.dart';
import '../widgets/invite_dialog.dart';
import '../widgets/search_bar_entry.dart';
import '../widgets/sectors_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.onOpenSearch,
    this.onVoiceSearch,
    this.teamEnabled = FeatureFlags.teamEnabled,
  });

  /// Point d'entrée de la recherche écrite (T045). Sans lui : « Bientôt disponible ».
  final VoidCallback? onOpenSearch;

  /// Remplace la recherche vocale intégrée (tests). Sans lui : explication, micro, écoute.
  final VoidCallback? onVoiceSearch;

  /// Remplace `FeatureFlags.teamEnabled` (tests).
  final bool teamEnabled;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scroll = ScrollController();
  bool _promoClosed = false;

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
      ref.read(searchControllerProvider.notifier).loadMore();
    }
  }

  void _soon() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(L10n.of(context).t('home.soon'))));
  }

  /// Échec ou refus du micro : message simple, puis retour à la recherche écrite.
  void _onVoiceChange(VoiceState? previous, VoiceState next) {
    if (next.phase != VoicePhase.failed || previous?.phase == VoicePhase.failed) {
      return;
    }
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(l10n.t('voice.error.${next.error?.name ?? 'failed'}')),
      duration: const Duration(seconds: 5),
    ));
    ref.read(voiceSearchControllerProvider.notifier).acknowledge();
    widget.onOpenSearch?.call();
  }

  Future<void> _openSectors(List<Sector> sectors, String? selected) async {
    final code = await showSectorsSheet(context, sectors: sectors, selected: selected);
    if (code != null && mounted) {
      ref.read(searchControllerProvider.notifier).setSector(code);
    }
  }

  Future<void> _invite() async {
    var hasBusiness = false;
    try {
      hasBusiness = (await ref.read(accountControllerProvider.future)).hasBusiness;
    } on Object {
      // Profil illisible : on propose la création du compte business.
    }
    if (!mounted) return;
    await showInviteDialog(
      context,
      steps: inviteSteps(teamEnabled: widget.teamEnabled, hasBusiness: hasBusiness),
      onSponsor: _soon,
      onBusiness: () => context.go(Routes.profile),
      onShare: _share,
    );
  }

  Future<void> _share() async {
    final l10n = L10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(shareServiceProvider).shareText(l10n.t('home.invite.share.text'));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.t('home.invite.share.error'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(searchControllerProvider);
    ref.listen(voiceSearchControllerProvider, _onVoiceChange);
    final listening = ref.watch(
        voiceSearchControllerProvider.select((v) => v.phase == VoicePhase.listening));
    final sectors = ref.watch(homeSectorsProvider).value ?? const [];
    return SafeArea(
      child: Stack(
        children: [
          _buildContent(context, search, sectors),
          // Bandeau de la maquette, sous la barre de recherche (en-tête 20+48+12, décalage 58).
          if (listening)
            Positioned(
              left: 20,
              right: 20,
              top: 138,
              child: VoiceListeningBanner(
                onCancel: ref.read(voiceSearchControllerProvider.notifier).cancel,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, SearchState search, List<Sector> sectors) {
    final c = AppColors.of(context);
    final l10n = L10n.of(context);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const NetBuisLogo(),
                IconButton(
                  key: const Key('home-profile'),
                  tooltip: l10n.t('home.profile'),
                  onPressed: () => context.go(Routes.profile),
                  style: IconButton.styleFrom(
                    backgroundColor: c.card,
                    side: BorderSide(color: c.border),
                    minimumSize: const Size(48, 48),
                  ),
                  icon: Icon(Icons.person_outline, size: 20, color: c.textSecondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SearchBarEntry(
              onSearch: widget.onOpenSearch ?? _soon,
              onVoice: widget.onVoiceSearch ?? () => startVoiceSearch(context, ref),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: CategoryChips(
              sectors: sectors,
              selected: search.query.sector,
              onSelect: ref.read(searchControllerProvider.notifier).setSector,
              onMore: () => _openSectors(sectors, search.query.sector),
            ),
          ),
          Expanded(child: _Results(state: search, controller: _scroll)),
          if (!_promoClosed)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: InviteBanner(
                onInvite: _invite,
                onClose: () => setState(() => _promoClosed = true),
              ),
            ),
        ],
    );
  }
}

/// Zone des résultats : chargement, erreur, vide ou liste de cartes.
class _Results extends ConsumerWidget {
  const _Results({required this.state, required this.controller});

  final SearchState state;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final notifier = ref.read(searchControllerProvider.notifier);
    switch (state.status) {
      case SearchStatus.idle:
        // La ville n'est pas encore connue : rien à montrer, la recherche part dès qu'elle l'est.
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
          text: l10n.t('home.results.error'),
          action: l10n.t('home.results.retry'),
          onAction: notifier.retry,
        );
      case SearchStatus.empty:
        return _Message(text: l10n.t('home.results.empty'));
      case SearchStatus.results:
        final extra = state.loadingMore || state.loadMoreFailed ? 1 : 0;
        return ListView.separated(
          key: const Key('home-results'),
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          itemCount: state.items.length + extra,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) {
            if (i < state.items.length) {
              return ResultCard(
                result: state.items[i],
                onOpen: () => context.push(Routes.businessDetailPath(state.items[i].id)),
              );
            }
            if (state.loadMoreFailed) {
              return _Message(
                text: l10n.t('home.results.loadMoreError'),
                action: l10n.t('home.results.retry'),
                onAction: notifier.loadMore,
              );
            }
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator(color: c.accentText)),
            );
          },
        );
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            if (action != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('home-retry'),
                onPressed: onAction,
                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(action!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
