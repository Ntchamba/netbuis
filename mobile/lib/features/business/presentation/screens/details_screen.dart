import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/referentials/referential_models.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/business_creation_flow.dart';
import '../../application/business_draft_controller.dart';
import '../../application/business_services.dart';
import '../../data/models/business_draft.dart';
import '../widgets/business_step_redirect.dart';
import '../widgets/business_step_scaffold.dart';
import '../widgets/labeled_text_field.dart';
import 'business_info_screen.dart' show businessFieldError;

/// Secteurs dont la maquette donne une question et un exemple propres (codes du serveur).
const Set<String> _sectorsWithOwnTexts = {
  'alimentation',
  'boutique_superette',
  'transport_livraison',
};

/// Étape « Précisez votre activité » (maquette CreationBusiness-Details), pour Commerce,
/// Entreprise et Particulier vendeur : sous-catégories du secteur choisi (jusqu'à
/// [freeSubcategoryLimit] sans abonnement) et description ; pour le secteur « Autre », le
/// nom du secteur écrit par la personne (obligatoire) et la description (obligatoire).
class DetailsScreen extends ConsumerStatefulWidget {
  const DetailsScreen({super.key});

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  late final TextEditingController _libre;
  late final TextEditingController _description;
  final _libreKey = GlobalKey();
  final _descriptionKey = GlobalKey();
  bool _submitted = false;
  bool _upsellRequested = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(businessDraftProvider);
    _libre = TextEditingController(text: draft.secteurLibre);
    _description = TextEditingController(text: draft.descriptionActivite);
  }

  @override
  void dispose() {
    _libre.dispose();
    _description.dispose();
    super.dispose();
  }

  void _toggle(int id, int? limit) {
    final accepted = ref.read(businessDraftProvider.notifier).toggleSubcategory(id, limit: limit);
    // La 4e sélection n'est pas ajoutée : l'encart « Limite atteinte » s'affiche.
    setState(() => _upsellRequested = !accepted);
  }

  void _continue() {
    final notifier = ref.read(businessDraftProvider.notifier);
    notifier
      ..setSecteurLibre(_libre.text.trim())
      ..setDescriptionActivite(_description.text.trim());
    final draft = ref.read(businessDraftProvider);
    setState(() => _submitted = true);
    if (!draft.detailsIsValid) {
      final first = draft.secteurLibreError != null ? _libreKey : _descriptionKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = first.currentContext;
        if (target != null) Scrollable.ensureVisible(target, duration: Duration.zero);
      });
      return;
    }
    final route = BusinessCreationFlow.nextRoute(draft.typeCompte, BusinessStep.details);
    if (route == null) {
      // Le récapitulatif (T035) n'est pas encore construit.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(L10n.of(context).t('business.create.comingSoon'))));
      return;
    }
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final draft = ref.watch(businessDraftProvider);
    if (!draft.typeCompte.hasSector) {
      return const BusinessStepRedirect(Routes.createBusiness);
    }
    final sector = draft.secteur;
    if (sector == null) return const BusinessStepRedirect(Routes.createBusinessSector);

    final limit = ref.watch(subcategoryLimitProvider);
    final other = draft.isOtherSector;
    final subs = [...sector.subcategories]..sort((a, b) => a.order.compareTo(b.order));
    final chosen = draft.sousCategorieIds;
    final atCap = limit != null && chosen.length >= limit;
    final showChips = !other && subs.isNotEmpty;
    final code = sector.code;
    final ownTexts = _sectorsWithOwnTexts.contains(code);

    String? libreError;
    String? descriptionError;
    if (_submitted) {
      final l = draft.secteurLibreError;
      final d = draft.descriptionActiviteError;
      if (l != null) {
        libreError = businessFieldError(l10n, l,
            requiredKey: 'business.create.details.other.name.required',
            max: kBusinessSecteurLibreMax);
      }
      if (d != null) {
        descriptionError = businessFieldError(l10n, d,
            requiredKey: 'business.create.details.description.required',
            max: kBusinessDescriptionActiviteMax);
      }
    }
    final hintKey = other
        ? 'business.create.details.description.hint.autre'
        : 'business.create.details.description.hint.${ownTexts ? code : 'default'}';
    final notifier = ref.read(businessDraftProvider.notifier);

    return BusinessStepScaffold(
      step: BusinessCreationFlow.position(draft.typeCompte, BusinessStep.details),
      total: BusinessCreationFlow.total(draft.typeCompte),
      stepName: l10n.t('business.create.stepName.details'),
      onContinue: _continue,
      children: [
        if (showChips) ...[
          Semantics(
            header: true,
            child: Text(
              l10n.t('business.create.details.question.${ownTexts ? code : 'default'}'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l10n.t('business.create.details.selectAll'),
                  style: TextStyle(fontSize: 12, color: c.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: _Counter(count: chosen.length, limit: limit, atCap: atCap)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final sub in subs)
                _Chip(
                  item: sub,
                  selected: chosen.contains(sub.id),
                  locked: atCap && !chosen.contains(sub.id),
                  selectedText: l10n.t('business.create.sector.selected'),
                  lockedText: l10n.t('business.create.details.chipLocked'),
                  onTap: () => _toggle(sub.id, limit),
                ),
            ],
          ),
          if (_upsellRequested && atCap) ...[
            const SizedBox(height: 12),
            _Upsell(
              limit: limit,
              onLater: () => setState(() => _upsellRequested = false),
            ),
          ],
          const SizedBox(height: 14),
        ],
        if (other) ...[
          Semantics(
            header: true,
            child: Text(
              l10n.t('business.create.details.other.title'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.t('business.create.details.other.intro'),
            style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
          ),
          const SizedBox(height: 10),
          KeyedSubtree(
            key: _libreKey,
            child: LabeledTextField(
              fieldKey: const ValueKey('business-secteur-libre'),
              label: l10n.t('business.create.details.other.name.label'),
              hintText: l10n.t('business.create.details.other.name.hint'),
              controller: _libre,
              maxLength: kBusinessSecteurLibreMax,
              errorText: libreError,
              onChanged: notifier.setSecteurLibre,
            ),
          ),
          const SizedBox(height: 14),
        ],
        KeyedSubtree(
          key: _descriptionKey,
          child: LabeledTextField(
            fieldKey: const ValueKey('business-description-activite'),
            label: l10n.t('business.create.details.description.label'),
            hintText: l10n.t(hintKey),
            controller: _description,
            maxLength: kBusinessDescriptionActiviteMax,
            errorText: descriptionError,
            onChanged: notifier.setDescriptionActivite,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: 3,
            maxLines: 6,
          ),
        ),
        const SizedBox(height: 14),
        DecoratedBox(
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
                const ExcludeSemantics(child: Text('💡', style: TextStyle(fontSize: 16))),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.t(
                        other ? 'business.create.details.tipOther' : 'business.create.details.tip'),
                    key: const ValueKey('business-details-tip'),
                    style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// « X/3 inclus sans abonnement » (ou « Illimité · abonné ✓ » sans plafond).
class _Counter extends StatelessWidget {
  const _Counter({required this.count, required this.limit, required this.atCap});

  final int count;
  final int? limit;
  final bool atCap;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final max = '${limit ?? 0}';
    final label = limit == null
        ? l10n.t('business.create.details.counterUnlimited')
        : l10n
            .t('business.create.details.counter')
            .replaceAll('{n}', '$count')
            .replaceAll('{max}', max);
    final spoken = limit == null
        ? label
        : l10n
            .t('business.create.details.counterSemantics')
            .replaceAll('{n}', '$count')
            .replaceAll('{max}', max);
    return Semantics(
      liveRegion: true,
      label: spoken,
      excludeSemantics: true,
      child: Text(
        label,
        key: const ValueKey('business-subcategory-counter'),
        textAlign: TextAlign.end,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: limit == null || atCap ? c.accentText : c.textSecondary,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.item,
    required this.selected,
    required this.locked,
    required this.selectedText,
    required this.lockedText,
    required this.onTap,
  });

  final ReferentialItem item;
  final bool selected;
  final bool locked;
  final String selectedText;
  final String lockedText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final spoken = selected
        ? selectedText.replaceAll('{label}', item.name)
        : (locked ? lockedText.replaceAll('{label}', item.name) : item.name);
    return Semantics(
      button: true,
      selected: selected,
      label: spoken,
      onTap: onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: locked ? 0.5 : 1,
        child: InkWell(
          key: ValueKey('business-sub-${item.id}'),
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : c.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: selected ? AppColors.accent : c.border, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  child: Text(
                    locked ? '🔒 ${item.name}' : item.name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.onAccent : c.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Encart « Limite atteinte » : l'abonnement n'est pas encore possible, le bouton est
/// donc désactivé et porte la mention « bientôt » ; « Plus tard » ferme l'encart.
class _Upsell extends StatelessWidget {
  const _Upsell({required this.limit, required this.onLater});

  final int? limit;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final max = '${limit ?? 0}';
    final subscribe = l10n.t('business.create.details.upsell.subscribe');
    final soon = l10n.t('business.create.details.upsell.soon');
    return DecoratedBox(
      key: const ValueKey('business-upsell'),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF241D10) : const Color(0xFFFFF6E8),
        border: Border.all(color: AppColors.accent),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.t('business.create.details.upsell.title').replaceAll('{max}', max),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('business.create.details.upsell.body').replaceAll('{max}', max),
              style: TextStyle(fontSize: 12, height: 1.45, color: c.textSecondary),
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
                child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    enabled: false,
                    label: '$subscribe, $soon',
                    excludeSemantics: true,
                    child: FilledButton(
                      key: const ValueKey('business-upsell-subscribe'),
                      onPressed: null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            subscribe,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            soon,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const ValueKey('business-upsell-later'),
                  onPressed: onLater,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    foregroundColor: c.textSecondary,
                    side: BorderSide(color: c.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    l10n.t('business.create.details.upsell.later'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            )),
          ],
        ),
      ),
    );
  }
}
