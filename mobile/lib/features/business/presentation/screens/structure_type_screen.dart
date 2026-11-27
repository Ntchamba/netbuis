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
import '../../data/models/business_draft.dart';
import '../widgets/business_step_redirect.dart';
import '../widgets/business_step_scaffold.dart';
import '../widgets/step_status_message.dart';

/// Étape « Type d'établissement » (maquette CreationBusiness-Structure-Type), pour le
/// compte Structure : une grille de 5 types (icône + mot) lue sur le serveur, un encart
/// quand « Autre » est choisi, et la note sur la nuance commerciale / sociale. Un type est
/// obligatoire. Pour un autre type de compte, l'écran renvoie à l'étape Informations.
class StructureTypeScreen extends ConsumerStatefulWidget {
  const StructureTypeScreen({super.key});

  @override
  ConsumerState<StructureTypeScreen> createState() => _StructureTypeScreenState();
}

class _StructureTypeScreenState extends ConsumerState<StructureTypeScreen> {
  bool _submitted = false;

  void _continue() {
    final draft = ref.read(businessDraftProvider);
    setState(() => _submitted = true);
    if (!draft.structureTypeStepIsValid) return;
    final route = BusinessCreationFlow.nextRoute(draft.typeCompte, BusinessStep.structureType);
    if (route != null) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final draft = ref.watch(businessDraftProvider);
    if (draft.typeCompte != BusinessAccountType.structure) {
      return const BusinessStepRedirect(Routes.createBusiness);
    }
    final types = ref.watch(businessStructureTypesProvider);
    final selectedId = draft.structureTypeId;
    final error = Theme.of(context).colorScheme.error;

    Widget body;
    if (types.isLoading && !types.hasValue) {
      body = StepStatusMessage(
        key: const ValueKey('business-structure-types-loading'),
        icon: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        text: l10n.t('business.create.structure.type.loading'),
      );
    } else if (types.hasError) {
      final e = types.error;
      final network = e is ApiException && e.code == ApiErrorCode.network;
      body = StepStatusMessage(
        key: const ValueKey('business-structure-types-error'),
        icon: Icon(Icons.error_outline, color: error),
        text: l10n.t(network
            ? 'business.create.structure.type.error.network'
            : 'business.create.structure.type.error.unknown'),
        retryLabel: l10n.t('business.create.structure.type.retry'),
        retryKey: const ValueKey('business-structure-types-retry'),
        onRetry: () => ref.invalidate(businessStructureTypesProvider),
      );
    } else if (types.requireValue.isEmpty) {
      body = StepStatusMessage(
        key: const ValueKey('business-structure-types-empty'),
        icon: Icon(Icons.info_outline, color: c.textSecondary),
        text: l10n.t('business.create.structure.type.empty'),
        retryLabel: l10n.t('business.create.structure.type.retry'),
        retryKey: const ValueKey('business-structure-types-retry'),
        onRetry: () => ref.invalidate(businessStructureTypesProvider),
      );
    } else {
      final list = types.requireValue;
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
      step: BusinessCreationFlow.position(draft.typeCompte, BusinessStep.structureType),
      total: BusinessCreationFlow.total(draft.typeCompte),
      stepName: l10n.t('business.create.stepName.structureType'),
      onContinue: _continue,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.t('business.create.structure.type.title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.t('business.create.structure.type.intro'),
          style: TextStyle(fontSize: 12.5, height: 1.4, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        body,
        if (_submitted && draft.structureTypeMissing) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Row(
              key: const ValueKey('business-structure-type-error'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.t('business.create.structure.type.error.required'),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: error),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (draft.isOtherStructureType) ...[
          const SizedBox(height: 14),
          _Note(
            key: const ValueKey('business-structure-other-note'),
            emoji: '✨',
            emojiSize: 16,
            text: l10n.t('business.create.structure.type.otherNote'),
            fontSize: 12,
            height: 1.45,
          ),
        ],
        const SizedBox(height: 14),
        _Note(
          key: const ValueKey('business-structure-nuance'),
          emoji: 'ℹ️',
          emojiSize: 15,
          text: l10n.t('business.create.structure.type.nuance'),
          fontSize: 11.5,
          height: 1.4,
        ),
      ],
    );
  }

  Widget _tile(L10n l10n, ReferentialItem type, int? selectedId) {
    return _TypeTile(
      type: type,
      selected: type.id == selectedId,
      selectedText: l10n.t('business.create.structure.selected'),
      onTap: () => ref.read(businessDraftProvider.notifier).setStructureType(type),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.selectedText,
    required this.onTap,
  });

  final ReferentialItem type;
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
      label: selected ? selectedText.replaceAll('{label}', type.name) : type.name,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.accent : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? AppColors.accent : c.border, width: 1.5),
        ),
        child: InkWell(
          key: ValueKey('business-structure-type-${type.code}'),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (type.icon.isNotEmpty) ...[
                    Text(type.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    type.name,
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

/// Encart de la maquette : un pictogramme et un texte gris dans une carte arrondie.
class _Note extends StatelessWidget {
  const _Note({
    super.key,
    required this.emoji,
    required this.emojiSize,
    required this.text,
    required this.fontSize,
    required this.height,
  });

  final String emoji;
  final double emojiSize;
  final String text;
  final double fontSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DecoratedBox(
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
            ExcludeSemantics(child: Text(emoji, style: TextStyle(fontSize: emojiSize))),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: fontSize, height: height, color: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
