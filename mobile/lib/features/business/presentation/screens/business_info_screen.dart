import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../account/application/account_controller.dart';
import '../../../onboarding/application/city_controller.dart';
import '../../application/business_creation_flow.dart';
import '../../application/business_draft_controller.dart';
import '../../application/business_services.dart';
import '../../data/models/business_draft.dart';
import '../widgets/account_type_selector.dart';
import '../widgets/business_step_scaffold.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/listen_note.dart';
import '../widgets/photo_field.dart';

/// Message traduit d'une erreur de champ.
String businessFieldError(L10n l10n, FieldError error, {required String requiredKey, int? max}) {
  switch (error) {
    case FieldError.required:
      return l10n.t(requiredKey);
    case FieldError.tooLong:
      return l10n.t('business.create.error.tooLong').replaceAll('{max}', '$max');
  }
}

/// Étape 1 de la création du compte business (maquette CreationBusiness-Infos) :
/// type de compte, nom affiché, nom et photo de la personne, lieu, repère, numéro.
/// Les libellés suivent le type choisi. Les erreurs s'affichent à l'appui sur « Continuer ».
class BusinessInfoScreen extends ConsumerStatefulWidget {
  const BusinessInfoScreen({super.key});

  @override
  ConsumerState<BusinessInfoScreen> createState() => _BusinessInfoScreenState();
}

class _BusinessInfoScreenState extends ConsumerState<BusinessInfoScreen> {
  late final TextEditingController _name;
  late final TextEditingController _owner;
  late final TextEditingController _repere;
  final _nameKey = GlobalKey();
  final _ownerKey = GlobalKey();
  final _ownerPhotoKey = GlobalKey();
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Le brouillon est la source de vérité : au retour arrière on retrouve tout.
    final draft = ref.read(businessDraftProvider);
    _name = TextEditingController(text: draft.name);
    _owner = TextEditingController(text: draft.representantNom);
    _repere = TextEditingController(text: draft.repere);
  }

  @override
  void dispose() {
    _name.dispose();
    _owner.dispose();
    _repere.dispose();
    super.dispose();
  }

  void _continue() {
    final l10n = L10n.of(context);
    final notifier = ref.read(businessDraftProvider.notifier);
    // Espaces des bouts retirés, une seule fois, avant de valider et d'envoyer plus loin.
    notifier
      ..setName(_name.text.trim())
      ..setRepresentantNom(_owner.text.trim())
      ..setRepere(_repere.text.trim());
    final draft = ref.read(businessDraftProvider);
    setState(() => _submitted = true);
    if (!draft.infoIsValid) {
      final first = draft.nameError != null
          ? _nameKey
          : (draft.representantNomError != null ? _ownerKey : _ownerPhotoKey);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = first.currentContext;
        if (target != null) Scrollable.ensureVisible(target, duration: Duration.zero);
      });
      return;
    }
    ref.read(speechServiceProvider).stop();
    final route = BusinessCreationFlow.nextRoute(draft.typeCompte, BusinessStep.info);
    if (route == null) {
      // L'étape suivante n'est pas encore construite (T031 à T035).
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.t('business.create.comingSoon'))));
      return;
    }
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final draft = ref.watch(businessDraftProvider);
    final notifier = ref.read(businessDraftProvider.notifier);
    final type = draft.typeCompte.value;
    final cityName = ref.watch(selectedCityProvider).value?.name;
    final phone = ref.watch(accountControllerProvider).value?.phoneMasked;

    String? nameError;
    String? ownerError;
    String? photoError;
    if (_submitted) {
      final n = draft.nameError;
      final o = draft.representantNomError;
      if (n != null) {
        nameError = businessFieldError(l10n, n,
            requiredKey: 'business.create.error.nameRequired', max: kBusinessNameMax);
      }
      if (o != null) {
        ownerError = businessFieldError(l10n, o,
            requiredKey: 'business.create.error.ownerRequired', max: kBusinessRepresentantMax);
      }
      if (draft.representantPhotoMissing) {
        photoError = l10n.t('business.create.error.photoRequired');
      }
    }
    final ownerHintKey = 'business.create.owner.hint.$type';
    final hasOwnerHint = draft.typeCompte != BusinessAccountType.boutique;

    return BusinessStepScaffold(
      step: BusinessCreationFlow.position(draft.typeCompte, BusinessStep.info),
      total: BusinessCreationFlow.total(draft.typeCompte),
      stepName: l10n.t('business.create.stepName.info'),
      onContinue: _continue,
      children: [
        AccountTypeSelector(selected: draft.typeCompte, onSelected: notifier.setType),
        const SizedBox(height: 16),
        ListenNote(
          icon: l10n.t('business.create.noteIcon.$type'),
          text: l10n.t('business.create.note.$type'),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _nameKey,
          child: LabeledTextField(
            fieldKey: const ValueKey('business-name'),
            label: l10n.t('business.create.name.label.$type'),
            hintText: l10n.t('business.create.name.hint.$type'),
            controller: _name,
            maxLength: kBusinessNameMax,
            errorText: nameError,
            onChanged: notifier.setName,
          ),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _ownerKey,
          child: LabeledTextField(
            fieldKey: const ValueKey('business-owner'),
            label: l10n.t('business.create.owner.label.$type'),
            hintText: l10n.t('business.create.owner.placeholder'),
            helper: hasOwnerHint ? l10n.t(ownerHintKey) : null,
            controller: _owner,
            maxLength: kBusinessRepresentantMax,
            errorText: ownerError,
            onChanged: notifier.setRepresentantNom,
          ),
        ),
        const SizedBox(height: 16),
        PhotoField(
          tapKey: const ValueKey('business-photo'),
          label: l10n.t('business.create.photo.label.$type'),
          placeholder: l10n.t('business.create.photo.add'),
          icon: Icons.photo_camera_outlined,
          path: draft.photoPath,
          onChanged: notifier.setPhotoPath,
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _ownerPhotoKey,
          child: PhotoField(
            tapKey: const ValueKey('business-owner-photo'),
            compact: true,
            label: l10n.t('business.create.ownerPhoto.label.$type'),
            labelSuffix: l10n.t('business.create.ownerPhoto.required'),
            placeholder: l10n.t('business.create.ownerPhoto.add'),
            icon: Icons.person_outline,
            path: draft.representantPhotoPath,
            errorText: photoError,
            onChanged: notifier.setRepresentantPhotoPath,
          ),
        ),
        const SizedBox(height: 16),
        _ReadOnlyField(
          fieldKey: const ValueKey('business-location'),
          label: l10n.t('business.create.location.label'),
          value: cityName ?? l10n.t('business.create.location.none'),
          valueColor: cityName == null ? c.textSecondary : null,
        ),
        const SizedBox(height: 16),
        LabeledTextField(
          fieldKey: const ValueKey('business-repere'),
          label: l10n.t('business.create.repere.label'),
          labelSuffix: l10n.t('business.create.optional'),
          hintText: l10n.t('business.create.repere.hint'),
          controller: _repere,
          maxLength: kBusinessRepereMax,
          textInputAction: TextInputAction.done,
          onChanged: notifier.setRepere,
        ),
        if (phone != null) ...[
          const SizedBox(height: 16),
          _ReadOnlyField(
            fieldKey: const ValueKey('business-phone'),
            label: l10n.t('business.create.phone.label'),
            value: phone,
            trailing: l10n.t('business.create.phone.verified'),
            dimmed: true,
          ),
        ],
      ],
    );
  }
}

/// Champ en lecture seule de la maquette (lieu, numéro vérifié) : jamais modifiable ici.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.fieldKey,
    required this.label,
    required this.value,
    this.trailing,
    this.valueColor,
    this.dimmed = false,
  });

  final Key fieldKey;
  final String label;
  final String value;
  final String? trailing;
  final Color? valueColor;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Semantics(
          container: true,
          label: trailing == null ? '$label : $value' : '$label : $value, $trailing',
          excludeSemantics: true,
          child: Opacity(
            opacity: dimmed ? 0.75 : 1,
            child: DecoratedBox(
              key: fieldKey,
              decoration: BoxDecoration(
                color: c.card,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(value, style: TextStyle(fontSize: 14, color: valueColor)),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          trailing!,
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700, color: c.accentText),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
