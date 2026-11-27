import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../account/application/account_controller.dart';
import '../../application/business_creation_flow.dart';
import '../../application/business_draft_controller.dart';
import '../../application/business_request.dart';
import '../../application/business_submit_controller.dart';
import '../../data/models/business_draft.dart';
import '../../data/models/structure_options.dart';
import '../widgets/business_step_redirect.dart';
import '../widgets/business_step_scaffold.dart';
import '../widgets/recap_parts.dart';

/// Dernière étape de chaque parcours (maquette CreationBusiness-Recap) : ce que la personne
/// a rempli, le numéro MASQUÉ du compte avec ✓, la note « examinée sous 24 heures » et
/// « Publier ma demande », qui envoie les photos puis le profil. La photo de la CNI n'est
/// jamais montrée : seulement « ✓ fournie ». Si le brouillon est incomplet (écran ouvert à la
/// main, type changé), l'écran renvoie à la première étape à compléter.
class RecapScreen extends ConsumerWidget {
  const RecapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final draft = ref.watch(businessDraftProvider);
    final submit = ref.watch(businessSubmitProvider);
    ref.listen<SubmitState>(businessSubmitProvider, (previous, next) {
      if (next.phase == SubmitPhase.sent && previous?.phase != SubmitPhase.sent) {
        context.go(Routes.createBusinessSent);
      }
    });

    // Succès : l'écran « Demande envoyée » prend le relais (sans brouillon).
    if (submit.phase == SubmitPhase.sent) return const Scaffold(body: SizedBox.shrink());
    final incomplete = firstIncompleteStep(draft);
    if (incomplete != null) return BusinessStepRedirect(incomplete.path);

    final type = draft.typeCompte;
    final typeCode = type.value;
    final phone = ref.watch(accountControllerProvider).value?.phoneMasked;
    final owner = fill(l10n.t('business.recap.owner.$typeCode'), {'name': draft.representantNom.trim()});
    final location = draft.locationLabel ?? '';
    void edit(String route) => context.push(route);

    final failed = submit.phase == SubmitPhase.failed;
    final retryable = !failed ||
        const {
          SubmitProblem.network,
          SubmitProblem.server,
          SubmitProblem.throttled,
          SubmitProblem.session,
          SubmitProblem.support,
        }.contains(submit.problem);

    return BusinessStepScaffold(
      step: BusinessCreationFlow.position(type, BusinessStep.recap),
      total: BusinessCreationFlow.total(type),
      stepName: l10n.t('business.recap.stepName'),
      continueLabel: failed && retryable
          ? l10n.t('business.recap.retry')
          : l10n.t('business.recap.submit'),
      busy: submit.sending,
      onContinue: () => ref.read(businessSubmitProvider.notifier).submit(),
      bottomNote: submit.sending
          ? _Progress(state: submit)
          : (failed ? _Failure(state: submit, onFix: edit) : null),
      children: [
        RecapCard(
          cardKey: const ValueKey('recap-identity'),
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border),
                  ),
                  child: ExcludeSemantics(
                    child: Text(l10n.t('business.create.noteIcon.$typeCode'),
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        draft.name.trim(),
                        key: const ValueKey('recap-name'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        owner,
                        key: const ValueKey('recap-owner'),
                        style: TextStyle(fontSize: 12, color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 1, color: c.border),
            RecapEditableRow(
              key: const ValueKey('recap-zone'),
              label: l10n.t('business.recap.zone'),
              value: location,
              onEdit: () => edit(Routes.createBusinessLocation),
            ),
            if (draft.repere.trim().isNotEmpty)
              RecapRow(label: l10n.t('business.recap.repere'), value: draft.repere.trim()),
            RecapRow(
              rowKey: const ValueKey('recap-phone'),
              label: l10n.t('business.recap.phone'),
              value: '${phone ?? '—'} ✓',
            ),
            if (type == BusinessAccountType.entreprise) ...[
              RecapRow(
                label: l10n.t('business.recap.legalForm'),
                value: l10n.t('business.create.legal.${draft.formeJuridique!.value}'),
              ),
              if (draft.rccm.trim().isNotEmpty)
                RecapRow(label: l10n.t('business.recap.rccm'), value: draft.rccm.trim()),
            ],
            _Photos(draft: draft),
            RecapEditLink(
              key: const ValueKey('recap-edit-identity'),
              section: draft.name.trim(),
              onEdit: () => edit(Routes.createBusiness),
            ),
          ],
        ),
        _DetailsCard(draft: draft, onEdit: edit),
        DecoratedBox(
          key: const ValueKey('recap-pending-note'),
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
                const ExcludeSemantics(child: Text('⏳', style: TextStyle(fontSize: 16))),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.t('business.recap.pending'),
                    style: TextStyle(fontSize: 12, height: 1.45, color: c.textSecondary),
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

/// Miniatures des photos choisies (jamais la CNI).
class _Photos extends StatelessWidget {
  const _Photos({required this.draft});

  final BusinessDraft draft;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final code = draft.typeCompte.value;
    final thumbs = <Widget>[
      if (draft.photoPath != null)
        RecapThumb(path: draft.photoPath!, label: l10n.t('business.create.photo.label.$code')),
      if (draft.representantPhotoPath != null)
        RecapThumb(
            path: draft.representantPhotoPath!,
            label: l10n.t('business.create.ownerPhoto.label.$code')),
      if (draft.typeCompte == BusinessAccountType.prestataireService &&
          draft.diplomePhotoPath != null)
        RecapThumb(
            path: draft.diplomePhotoPath!, label: l10n.t('business.create.diploma.label')),
    ];
    if (thumbs.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('recap-photos'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.t('business.recap.photos'),
            style: TextStyle(fontSize: 13, color: c.textSecondary)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: thumbs),
      ],
    );
  }
}

/// Deuxième carte, propre au type : secteur, catégorie de service ou établissement.
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.draft, required this.onEdit});

  final BusinessDraft draft;
  final void Function(String route) onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final String title;
    final String heading;
    final String editRoute;
    final List<Widget> body;

    Widget quote(String text) => Text(
          fill(l10n.t('business.recap.quote'), {'text': text}),
          style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
        );
    Widget chips(List<String> labels) =>
        Wrap(spacing: 7, runSpacing: 7, children: [for (final t in labels) RecapChip(t)]);
    String opt(String group, String code) => l10n.t('business.create.structure.$group.$code');

    switch (draft.typeCompte) {
      case BusinessAccountType.prestataireService:
        title = l10n.t('business.recap.service.title');
        final category = draft.categorieService!;
        final libre = draft.categorieServiceLibre.trim();
        heading = '${category.icon} ${libre.isNotEmpty ? libre : category.name}'.trim();
        editRoute = Routes.createBusinessServiceCategory;
        body = [
          RecapRow(
            rowKey: const ValueKey('recap-cni'),
            label: l10n.t('business.recap.cni'),
            value: l10n.t('business.recap.cni.provided'),
          ),
          if (draft.diplomePhotoPath != null)
            RecapRow(
              rowKey: const ValueKey('recap-diploma'),
              label: l10n.t('business.recap.diploma'),
              value: l10n.t('business.recap.diploma.provided'),
            ),
        ];
      case BusinessAccountType.structure:
        title = l10n.t('business.recap.structure.title');
        final type = draft.structureType!;
        final libre = draft.structureTypeLibre.trim();
        heading = '${type.icon} ${libre.isNotEmpty ? libre : type.name}'.trim();
        editRoute = Routes.createBusinessStructureType;
        body = [
          switch (draft.structureCode) {
            kStructureSupermarche => chips([
                for (final o in kAisleOptions)
                  if (draft.rayons.contains(o.code)) l10n.t(o.labelKey)
              ]),
            kStructureRestaurant => Column(
                children: [
                  RecapRow(
                      label: l10n.t('business.recap.cuisine'),
                      value: opt('cuisine', draft.cuisine)),
                  const SizedBox(height: 8),
                  RecapRow(
                    label: l10n.t('business.recap.livraison'),
                    value: l10n.t(draft.livraison == true
                        ? 'business.create.structure.delivery.yes'
                        : 'business.create.structure.delivery.no'),
                  ),
                  if (draft.horaires.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    RecapRow(
                        label: l10n.t('business.recap.horaires'), value: draft.horaires.trim()),
                  ],
                ],
              ),
            kStructureHotel => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  RecapRow(
                      label: l10n.t('business.recap.standing'),
                      value: opt('standing', draft.standing)),
                  if (draft.nombreChambres != null) ...[
                    const SizedBox(height: 8),
                    RecapRow(
                        label: l10n.t('business.recap.chambres'),
                        value: '${draft.nombreChambres}'),
                  ],
                  if (draft.equipements.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    chips([
                      for (final o in kAmenityOptions)
                        if (draft.equipements.contains(o.code)) l10n.t(o.labelKey)
                    ]),
                  ],
                ],
              ),
            kStructureSante => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (draft.numeroAgrement.trim().isNotEmpty) ...[
                    RecapRow(
                        label: l10n.t('business.recap.agrement'),
                        value: draft.numeroAgrement.trim()),
                    const SizedBox(height: 10),
                  ],
                  chips([
                    for (final o in kSpecialityOptions)
                      if (draft.specialites.contains(o.code)) l10n.t(o.labelKey)
                  ]),
                ],
              ),
            _ => const SizedBox.shrink(),
          },
          if (draft.description.trim().isNotEmpty) quote(draft.description.trim()),
        ];
      case BusinessAccountType.boutique:
      case BusinessAccountType.entreprise:
      case BusinessAccountType.particulierVendeur:
        title = l10n.t('business.recap.sector.title');
        final sector = draft.secteur!;
        final libre = draft.secteurLibre.trim();
        heading = '${sector.icon} ${libre.isNotEmpty ? libre : sector.name}'.trim();
        editRoute = Routes.createBusinessSector;
        body = [
          if (draft.sousCategorieIds.isNotEmpty)
            chips([
              for (final s in sector.subcategories)
                if (draft.sousCategorieIds.contains(s.id)) s.name
            ]),
          if (draft.descriptionActivite.trim().isNotEmpty)
            quote(draft.descriptionActivite.trim()),
        ];
    }

    return RecapCard(
      cardKey: const ValueKey('recap-details'),
      children: [
        Semantics(
          header: true,
          child: Text(title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.accentText)),
        ),
        Text(heading, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ...body,
        RecapEditLink(
            key: const ValueKey('recap-edit-details'),
            section: title,
            onEdit: () => onEdit(editRoute)),
      ],
    );
  }
}

/// Progression de l'envoi : barre + texte, annoncés au lecteur d'écran.
class _Progress extends StatelessWidget {
  const _Progress({required this.state});

  final SubmitState state;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final photoCount = state.total - 1;
    final text = state.sendingProfile
        ? l10n.t('business.recap.sending.profile')
        : fill(l10n.t('business.recap.sending.photos'), {
            'n': '${(state.done + 1).clamp(1, photoCount)}',
            'total': '$photoCount',
          });
    return Semantics(
      key: const ValueKey('recap-progress'),
      liveRegion: true,
      label: fill(l10n.t('business.recap.sending.semantics'), {
        'n': '${(state.done + 1).clamp(1, state.total)}',
        'total': '${state.total}',
      }),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: state.total == 0 ? null : state.done / state.total,
              backgroundColor: c.border,
            ),
          ),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
        ],
      ),
    );
  }
}

/// Message d'échec court et traduit (jamais le texte du serveur) ; « Corriger » ouvre
/// l'écran concerné quand il y en a un.
class _Failure extends StatelessWidget {
  const _Failure({required this.state, required this.onFix});

  final SubmitState state;
  final void Function(String route) onFix;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final error = Theme.of(context).colorScheme.error;
    final problem = state.problem ?? SubmitProblem.server;
    final key = switch (problem) {
      SubmitProblem.network => 'network',
      SubmitProblem.session => 'session',
      SubmitProblem.throttled => 'throttled',
      SubmitProblem.support => 'support',
      SubmitProblem.photoMissing => 'photoMissing',
      SubmitProblem.photo => 'photo',
      SubmitProblem.subscription => 'subscription',
      SubmitProblem.fields => 'fields',
      SubmitProblem.server => 'server',
    };
    final message =
        fill(l10n.t('business.recap.error.$key'), {'max': '$freeSubcategoryLimit'});
    final fixRoute = state.fixRoute;
    return Column(
      key: const ValueKey('recap-error'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 18, color: error),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: error),
                ),
              ),
            ],
          ),
        ),
        if (fixRoute != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const ValueKey('recap-fix'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => onFix(fixRoute),
              child: Text(l10n.t('business.recap.fix')),
            ),
          ),
      ],
    );
  }
}
