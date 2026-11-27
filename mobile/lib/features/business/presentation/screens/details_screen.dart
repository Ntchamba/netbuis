import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/business_creation_flow.dart';
import '../../application/business_draft_controller.dart';
import '../../application/business_services.dart';
import '../../data/models/business_draft.dart';
import '../widgets/business_step_redirect.dart';
import '../widgets/business_step_scaffold.dart';
import '../widgets/capped_choice.dart';
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
              Flexible(child: CapCounter(count: chosen.length, limit: limit, atCap: atCap)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final sub in subs)
                ChoiceChipButton(
                  tapKey: ValueKey('business-sub-${sub.id}'),
                  label: sub.name,
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
            LimitUpsell(
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
