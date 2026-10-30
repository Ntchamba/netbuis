import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/business_creation_flow.dart';
import '../../application/business_draft_controller.dart';
import '../../application/business_services.dart';
import '../../data/models/business_draft.dart';
import '../../data/models/structure_options.dart';
import '../widgets/business_step_redirect.dart';
import '../widgets/business_step_scaffold.dart';
import '../widgets/capped_choice.dart';
import '../widgets/labeled_text_field.dart';
import 'business_info_screen.dart' show businessFieldError;

/// Étape « Détails de l'établissement » (maquette CreationBusiness-Structure-Details), pour
/// le compte Structure. Les champs suivent le type choisi à l'étape précédente :
/// - supermarché : rayons (jusqu'à [freeSubcategoryLimit] sans abonnement, au moins un) ;
/// - restaurant : cuisine (une seule), livraison, horaires (texte libre facultatif) ;
/// - hôtel : standing (un seul), nombre de chambres, équipements ;
/// - centre de santé : numéro d'agrément (facultatif), spécialités (jusqu'à 3, au moins une) ;
/// - autre : le type écrit par la personne (obligatoire) ;
/// puis, pour tous, la description libre avec un exemple propre au type. Sans type choisi,
/// l'écran renvoie à l'étape précédente ; pour un autre type de compte, à Informations.
class StructureDetailsScreen extends ConsumerStatefulWidget {
  const StructureDetailsScreen({super.key});

  @override
  ConsumerState<StructureDetailsScreen> createState() => _StructureDetailsScreenState();
}

class _StructureDetailsScreenState extends ConsumerState<StructureDetailsScreen> {
  late final TextEditingController _libre;
  late final TextEditingController _horaires;
  late final TextEditingController _chambres;
  late final TextEditingController _agrement;
  late final TextEditingController _description;
  final _libreKey = GlobalKey();
  final _choiceKey = GlobalKey();
  final _chambresKey = GlobalKey();
  final _descriptionKey = GlobalKey();
  bool _submitted = false;
  bool _upsellRequested = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(businessDraftProvider);
    _libre = TextEditingController(text: draft.structureTypeLibre);
    _horaires = TextEditingController(text: draft.horaires);
    _chambres = TextEditingController(text: draft.nombreChambres?.toString() ?? '');
    _agrement = TextEditingController(text: draft.numeroAgrement);
    _description = TextEditingController(text: draft.description);
  }

  @override
  void dispose() {
    _libre.dispose();
    _horaires.dispose();
    _chambres.dispose();
    _agrement.dispose();
    _description.dispose();
    super.dispose();
  }

  void _toggleCapped(String code, int? limit, {required bool rayon}) {
    final notifier = ref.read(businessDraftProvider.notifier);
    final accepted = rayon
        ? notifier.toggleRayon(code, limit: limit)
        : notifier.toggleSpecialite(code, limit: limit);
    // Le 4e choix n'est pas ajouté : l'encart « Limite atteinte » s'affiche.
    setState(() => _upsellRequested = !accepted);
  }

  void _continue() {
    final notifier = ref.read(businessDraftProvider.notifier);
    final before = ref.read(businessDraftProvider);
    final isOther = before.isOtherStructureType;
    final code = before.structureCode;
    notifier.setDescription(_description.text.trim());
    if (isOther) notifier.setStructureTypeLibre(_libre.text.trim());
    if (code == kStructureRestaurant) {
      notifier
        ..setHoraires(_horaires.text.trim())
        // L'interrupteur de la maquette est affiché sur « oui » tant qu'on n'y a pas touché.
        ..setLivraison(before.livraison ?? true);
    }
    if (code == kStructureSante) notifier.setNumeroAgrement(_agrement.text.trim());
    final draft = ref.read(businessDraftProvider);
    setState(() => _submitted = true);
    if (!draft.structureDetailsIsValid) {
      final GlobalKey first;
      if (draft.structureTypeLibreError != null) {
        first = _libreKey;
      } else if (draft.rayonsMissing ||
          draft.cuisineMissing ||
          draft.standingMissing ||
          draft.specialitesMissing) {
        first = _choiceKey;
      } else if (draft.nombreChambresInvalid) {
        first = _chambresKey;
      } else {
        first = _descriptionKey;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = first.currentContext;
        if (target != null) Scrollable.ensureVisible(target, duration: Duration.zero);
      });
      return;
    }
    final route = BusinessCreationFlow.nextRoute(draft.typeCompte, BusinessStep.structureDetails);
    if (route == null) {
      // Le lieu et le récapitulatif (T034, T035) ne sont pas encore construits.
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
    if (draft.typeCompte != BusinessAccountType.structure) {
      return const BusinessStepRedirect(Routes.createBusiness);
    }
    if (draft.structureType == null) {
      return const BusinessStepRedirect(Routes.createBusinessStructureType);
    }
    final notifier = ref.read(businessDraftProvider.notifier);
    final limit = ref.watch(subcategoryLimitProvider);
    final code = draft.structureCode!;
    const knownTypes = {
      kStructureSupermarche,
      kStructureRestaurant,
      kStructureHotel,
      kStructureSante,
    };
    final descKey = knownTypes.contains(code) ? code : 'autre';
    final selectedText = l10n.t('business.create.structure.selected');
    final error = Theme.of(context).colorScheme.error;

    String? libreError;
    if (_submitted && draft.structureTypeLibreError != null) {
      libreError = businessFieldError(l10n, draft.structureTypeLibreError!,
          requiredKey: 'business.create.structure.other.required',
          max: kBusinessStructureTypeLibreMax);
    }
    String? descriptionError;
    if (_submitted && draft.descriptionError != null) {
      descriptionError = businessFieldError(l10n, draft.descriptionError!,
          requiredKey: 'business.create.structure.description.label', max: kBusinessDescriptionMax);
    }
    String? chambresError;
    if (_submitted && draft.nombreChambresInvalid) {
      chambresError = l10n
          .t('business.create.structure.chambres.error')
          .replaceAll('{min}', '$kBusinessChambresMin')
          .replaceAll('{max}', '$kBusinessChambresMax');
    }

    Widget cappedGroup({
      required String group,
      required String questionKey,
      required List<StructureOption> options,
      required List<String> chosen,
      required bool rayon,
      required bool missing,
      required String requiredKey,
    }) {
      final atCap = limit != null && chosen.length >= limit;
      return KeyedSubtree(
        key: _choiceKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Title(l10n.t(questionKey))),
                const SizedBox(width: 8),
                Flexible(child: CapCounter(count: chosen.length, limit: limit, atCap: atCap)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.t('business.create.structure.selectAll'),
              style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
            ),
            const SizedBox(height: 10),
            _Grid([
              for (final o in options)
                ChoiceChipButton(
                  tapKey: ValueKey('business-structure-opt-$group-${o.code}'),
                  tile: true,
                  label: l10n.t(o.labelKey),
                  selected: chosen.contains(o.code),
                  locked: atCap && !chosen.contains(o.code),
                  selectedText: selectedText,
                  lockedText: l10n.t('business.create.details.chipLocked'),
                  onTap: () => _toggleCapped(o.code, limit, rayon: rayon),
                ),
            ]),
            if (_upsellRequested && atCap) ...[
              const SizedBox(height: 12),
              LimitUpsell(
                limit: limit,
                titleKey: 'business.create.structure.upsell.title',
                bodyKey: 'business.create.structure.upsell.body',
                onLater: () => setState(() => _upsellRequested = false),
              ),
            ],
            if (_submitted && missing) _ErrorLine(group, l10n.t(requiredKey), error),
          ],
        ),
      );
    }

    Widget singleGroup({
      required String group,
      required String titleKey,
      required List<StructureOption> options,
      required String chosen,
      required void Function(String) onChoose,
      required bool missing,
      required String requiredKey,
    }) {
      return KeyedSubtree(
        key: _choiceKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Title(l10n.t(titleKey)),
            const SizedBox(height: 10),
            _Grid([
              for (final o in options)
                ChoiceChipButton(
                  tapKey: ValueKey('business-structure-opt-$group-${o.code}'),
                  tile: true,
                  exclusive: true,
                  label: l10n.t(o.labelKey),
                  selected: chosen == o.code,
                  selectedText: selectedText,
                  onTap: () => onChoose(o.code),
                ),
            ]),
            if (_submitted && missing) _ErrorLine(group, l10n.t(requiredKey), error),
          ],
        ),
      );
    }

    final children = <Widget>[];
    switch (code) {
      case kStructureSupermarche:
        children.add(cappedGroup(
          group: 'aisle',
          questionKey: 'business.create.structure.aisle.question',
          options: kAisleOptions,
          chosen: draft.rayons,
          rayon: true,
          missing: draft.rayonsMissing,
          requiredKey: 'business.create.structure.aisle.required',
        ));
      case kStructureRestaurant:
        children
          ..add(singleGroup(
            group: 'cuisine',
            titleKey: 'business.create.structure.cuisine.title',
            options: kCuisineOptions,
            chosen: draft.cuisine,
            onChoose: notifier.setCuisine,
            missing: draft.cuisineMissing,
            requiredKey: 'business.create.structure.cuisine.required',
          ))
          ..add(_DeliveryCard(
            value: draft.livraison ?? true,
            onChanged: notifier.setLivraison,
          ))
          ..add(LabeledTextField(
            fieldKey: const ValueKey('business-structure-horaires'),
            label: l10n.t('business.create.structure.horaires.label'),
            hintText: l10n.t('business.create.structure.horaires.hint'),
            controller: _horaires,
            maxLength: kBusinessHorairesMax,
            onChanged: notifier.setHoraires,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
          ));
      case kStructureHotel:
        children
          ..add(singleGroup(
            group: 'standing',
            titleKey: 'business.create.structure.standing.title',
            options: kStandingOptions,
            chosen: draft.standing,
            onChoose: notifier.setStanding,
            missing: draft.standingMissing,
            requiredKey: 'business.create.structure.standing.required',
          ))
          ..add(KeyedSubtree(
            key: _chambresKey,
            child: LabeledTextField(
              fieldKey: const ValueKey('business-structure-chambres'),
              label: l10n.t('business.create.structure.chambres.label'),
              hintText: l10n.t('business.create.structure.chambres.hint'),
              controller: _chambres,
              maxLength: '$kBusinessChambresMax'.length,
              errorText: chambresError,
              keyboardType: TextInputType.number,
              textCapitalization: TextCapitalization.none,
              extraFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) => notifier.setNombreChambres(int.tryParse(v)),
            ),
          ))
          ..add(Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Title(l10n.t('business.create.structure.amenity.title'), small: true),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                children: [
                  for (final o in kAmenityOptions)
                    ChoiceChipButton(
                      tapKey: ValueKey('business-structure-opt-amenity-${o.code}'),
                      label: l10n.t(o.labelKey),
                      selected: draft.equipements.contains(o.code),
                      selectedText: selectedText,
                      onTap: () => notifier.toggleEquipement(o.code),
                    ),
                ],
              ),
            ],
          ));
      case kStructureSante:
        children
          ..add(LabeledTextField(
            fieldKey: const ValueKey('business-structure-agrement'),
            label: l10n.t('business.create.structure.agrement.label'),
            labelSuffix: l10n.t('business.create.optional'),
            hintText: l10n.t('business.create.structure.agrement.hint'),
            controller: _agrement,
            maxLength: kBusinessNumeroAgrementMax,
            textCapitalization: TextCapitalization.characters,
            onChanged: notifier.setNumeroAgrement,
          ))
          ..add(cappedGroup(
            group: 'speciality',
            questionKey: 'business.create.structure.speciality.question',
            options: kSpecialityOptions,
            chosen: draft.specialites,
            rayon: false,
            missing: draft.specialitesMissing,
            requiredKey: 'business.create.structure.speciality.required',
          ));
      default:
        children.add(KeyedSubtree(
          key: _libreKey,
          child: LabeledTextField(
            fieldKey: const ValueKey('business-structure-libre'),
            label: l10n.t('business.create.structure.other.label'),
            hintText: l10n.t('business.create.structure.other.hint'),
            controller: _libre,
            maxLength: kBusinessStructureTypeLibreMax,
            errorText: libreError,
            onChanged: notifier.setStructureTypeLibre,
            textCapitalization: TextCapitalization.sentences,
          ),
        ));
    }
    children.add(KeyedSubtree(
      key: _descriptionKey,
      child: LabeledTextField(
        fieldKey: const ValueKey('business-structure-description'),
        label: l10n.t('business.create.structure.description.label'),
        hintText: l10n.t('business.create.structure.description.hint.$descKey'),
        controller: _description,
        maxLength: kBusinessDescriptionMax,
        errorText: descriptionError,
        onChanged: notifier.setDescription,
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        minLines: 3,
        maxLines: 6,
      ),
    ));

    return BusinessStepScaffold(
      step: BusinessCreationFlow.position(draft.typeCompte, BusinessStep.structureDetails),
      total: BusinessCreationFlow.total(draft.typeCompte),
      stepName: l10n.t('business.create.stepName.structureDetails'),
      onContinue: _continue,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          children[i],
        ],
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, {this.small = false});

  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: !small,
      child: Text(
        text,
        style: TextStyle(fontSize: small ? 12.5 : 15, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Deux colonnes de cases de même hauteur (grille de la maquette), sans défilement
/// horizontal : le texte passe à la ligne.
class _Grid extends StatelessWidget {
  const _Grid(this.items);

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 9),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: items[i]),
                const SizedBox(width: 9),
                Expanded(child: i + 1 < items.length ? items[i + 1] : const SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.name, this.text, this.color);

  final String name;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        liveRegion: true,
        child: Row(
          key: ValueKey('business-structure-error-$name'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Service de livraison disponible » avec son interrupteur (maquette).
class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final label = l10n.t('business.create.structure.delivery.label');
    final state = l10n.t(value
        ? 'business.create.structure.delivery.yes'
        : 'business.create.structure.delivery.no');
    return Semantics(
      container: true,
      toggled: value,
      label: '$label, $state',
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          key: const ValueKey('business-structure-livraison'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChanged(!value),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IgnorePointer(
                    child: Switch(
                      value: value,
                      onChanged: onChanged,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.accent,
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
