import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/referentials/referential_models.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/business_creation_flow.dart';
import '../../application/business_draft_controller.dart';
import '../../application/business_services.dart';
import '../widgets/business_step_redirect.dart';
import '../widgets/business_step_scaffold.dart';

/// Étape « Secteur d'activité » (maquette CreationBusiness-Secteur), pour Commerce,
/// Entreprise et Particulier vendeur : une grille de secteurs (icône + mot) lue sur le
/// serveur. Un secteur est obligatoire. Pour un autre type de compte, l'écran renvoie à
/// l'étape Informations.
class SectorScreen extends ConsumerStatefulWidget {
  const SectorScreen({super.key});

  @override
  ConsumerState<SectorScreen> createState() => _SectorScreenState();
}

class _SectorScreenState extends ConsumerState<SectorScreen> {
  bool _submitted = false;

  void _continue() {
    final draft = ref.read(businessDraftProvider);
    setState(() => _submitted = true);
    if (draft.sectorMissing) return;
    final route = BusinessCreationFlow.nextRoute(draft.typeCompte, BusinessStep.sector);
    if (route != null) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final draft = ref.watch(businessDraftProvider);
    if (!draft.typeCompte.hasSector) {
      return const BusinessStepRedirect(Routes.createBusiness);
    }
    final sectors = ref.watch(businessSectorsProvider);
    final selectedId = draft.secteurId;

    Widget body;
    if (sectors.isLoading && !sectors.hasValue) {
      body = _Message(
        key: const ValueKey('business-sectors-loading'),
        icon: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        text: l10n.t('business.create.sector.loading'),
      );
    } else if (sectors.hasError) {
      final error = sectors.error;
      final network = error is ApiException && error.code == ApiErrorCode.network;
      body = _Message(
        key: const ValueKey('business-sectors-error'),
        icon: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
        text: l10n.t(network
            ? 'business.create.sector.error.network'
            : 'business.create.sector.error.unknown'),
        retryLabel: l10n.t('business.create.sector.retry'),
        onRetry: () => ref.invalidate(businessSectorsProvider),
      );
    } else if (sectors.requireValue.isEmpty) {
      body = _Message(
        key: const ValueKey('business-sectors-empty'),
        icon: Icon(Icons.info_outline, color: c.textSecondary),
        text: l10n.t('business.create.sector.empty'),
        retryLabel: l10n.t('business.create.sector.retry'),
        onRetry: () => ref.invalidate(businessSectorsProvider),
      );
    } else {
      final list = sectors.requireValue;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < list.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _tile(l10n, list[i], selectedId)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: i + 1 < list.length
                        ? _tile(l10n, list[i + 1], selectedId)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    return BusinessStepScaffold(
      step: BusinessCreationFlow.position(draft.typeCompte, BusinessStep.sector),
      total: BusinessCreationFlow.total(draft.typeCompte),
      stepName: l10n.t('business.create.stepName.sector'),
      onContinue: _continue,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.t('business.create.sector.title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.t('business.create.sector.intro'),
          style: TextStyle(fontSize: 12.5, height: 1.4, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        body,
        if (_submitted && draft.sectorMissing) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Row(
              key: const ValueKey('business-sector-error'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.t('business.create.sector.error.required'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (draft.isOtherSector) ...[
          const SizedBox(height: 14),
          DecoratedBox(
            key: const ValueKey('business-sector-other-note'),
            decoration: BoxDecoration(
              color: c.card,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExcludeSemantics(child: Text('✨', style: TextStyle(fontSize: 16))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.t('business.create.sector.otherNote'),
                      style: TextStyle(fontSize: 12, height: 1.45, color: c.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _tile(L10n l10n, Sector sector, int? selectedId) {
    return _SectorTile(
      sector: sector,
      selected: sector.id == selectedId,
      selectedText: l10n.t('business.create.sector.selected'),
      onTap: () {
        ref.read(businessDraftProvider.notifier).setSector(sector);
      },
    );
  }
}

class _SectorTile extends StatelessWidget {
  const _SectorTile({
    required this.sector,
    required this.selected,
    required this.selectedText,
    required this.onTap,
  });

  final Sector sector;
  final bool selected;
  final String selectedText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = selected ? AppColors.onAccent : c.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: selected ? selectedText.replaceAll('{label}', sector.name) : sector.name,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.accent : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? AppColors.accent : c.border, width: 1.5),
        ),
        child: InkWell(
          key: ValueKey('business-sector-${sector.code}'),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (sector.icon.isNotEmpty) ...[
                    Text(sector.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    sector.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: fg,
                    ),
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

/// Chargement, erreur ou liste vide, avec « Réessayer » quand c'est utile.
class _Message extends StatelessWidget {
  const _Message(
      {super.key, required this.icon, required this.text, this.retryLabel, this.onRetry});

  final Widget icon;
  final String text;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Semantics(
        liveRegion: true,
        child: Column(
          children: [
            icon,
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: c.textSecondary),
            ),
            if (retryLabel != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const ValueKey('business-sectors-retry'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onRetry,
                child: Text(retryLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
