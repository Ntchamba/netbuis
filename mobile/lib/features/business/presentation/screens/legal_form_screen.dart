import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/business_creation_flow.dart';
import '../../application/business_draft_controller.dart';
import '../../data/models/business_draft.dart';
import '../widgets/business_step_scaffold.dart';
import '../widgets/labeled_text_field.dart';

/// Étape « Forme juridique » (maquette CreationBusiness-Entreprise-Forme), **réservée aux
/// Entreprises** : 8 formes à choisir (« Entreprise individuelle » est préchoisie, comme dans la
/// maquette) et le numéro RCCM, facultatif. Ouvert pour un autre type de compte, l'écran
/// renvoie à l'étape Informations.
class LegalFormScreen extends ConsumerStatefulWidget {
  const LegalFormScreen({super.key});

  @override
  ConsumerState<LegalFormScreen> createState() => _LegalFormScreenState();
}

class _LegalFormScreenState extends ConsumerState<LegalFormScreen> {
  late final TextEditingController _rccm;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    _rccm = TextEditingController(text: ref.read(businessDraftProvider).rccm);
  }

  @override
  void dispose() {
    _rccm.dispose();
    super.dispose();
  }

  void _continue() {
    final l10n = L10n.of(context);
    final notifier = ref.read(businessDraftProvider.notifier);
    final draft = ref.read(businessDraftProvider);
    notifier
      ..setFormeJuridique(draft.formeJuridique ?? LegalForm.individuelle)
      ..setRccm(_rccm.text.trim());
    final route = BusinessCreationFlow.nextRoute(draft.typeCompte, BusinessStep.legalForm);
    if (route == null) {
      // L'étape suivante (Secteur, T031) n'est pas encore construite.
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
    final draft = ref.watch(businessDraftProvider);
    if (draft.typeCompte != BusinessAccountType.entreprise) {
      if (!_redirecting) {
        _redirecting = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go(Routes.createBusiness);
        });
      }
      return const Scaffold(body: SizedBox.shrink());
    }
    final current = draft.formeJuridique ?? LegalForm.individuelle;
    final notifier = ref.read(businessDraftProvider.notifier);

    return BusinessStepScaffold(
      step: BusinessCreationFlow.position(draft.typeCompte, BusinessStep.legalForm),
      total: BusinessCreationFlow.total(draft.typeCompte),
      stepName: l10n.t('business.create.stepName.legal'),
      onContinue: _continue,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.t('business.create.legal.title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.t('business.create.legal.intro'),
          style: TextStyle(
              fontSize: 12.5, height: 1.4, color: AppColors.of(context).textSecondary),
        ),
        const SizedBox(height: 14),
        for (final form in LegalForm.values) ...[
          _FormChoice(
            form: form,
            label: l10n.t('business.create.legal.${form.value}'),
            selectedText: l10n.t('business.create.legal.selected'),
            selected: form == current,
            onTap: () => notifier.setFormeJuridique(form),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 6),
        LabeledTextField(
          fieldKey: const ValueKey('business-rccm'),
          label: l10n.t('business.create.rccm.label'),
          labelSuffix: l10n.t('business.create.optional'),
          hintText: l10n.t('business.create.rccm.hint'),
          controller: _rccm,
          maxLength: kBusinessRccmMax,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onChanged: notifier.setRccm,
        ),
      ],
    );
  }
}

class _FormChoice extends StatelessWidget {
  const _FormChoice({
    required this.form,
    required this.label,
    required this.selectedText,
    required this.selected,
    required this.onTap,
  });

  final LegalForm form;
  final String label;
  final String selectedText;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = selected ? AppColors.onAccent : c.textPrimary;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: selected ? selectedText.replaceAll('{label}', label) : label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.accent : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? AppColors.accent : c.border, width: 1.5),
        ),
        child: InkWell(
          key: ValueKey('business-legal-${form.value}'),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.onAccent : Colors.transparent,
                      border: Border.all(
                        color: selected ? AppColors.onAccent : c.textSecondary,
                        width: 1.5,
                      ),
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
