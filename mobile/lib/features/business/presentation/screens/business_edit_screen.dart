import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../account/application/account_controller.dart';
import '../../application/business_controller.dart';
import '../../application/business_edit.dart';
import '../../application/business_edit_controller.dart';
import '../../data/models/business.dart';
import '../../data/models/business_draft.dart';
import '../widgets/edit_location_sheet.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/photo_field.dart';
import 'business_info_screen.dart' show businessFieldError;

/// « Modifier ma boutique » (aucune maquette ; ouvert depuis Profil) : les champs du compte
/// business qui se modifient après la création. Règle D-08 : le nom et le lieu demandent une
/// nouvelle validation (avertissement avant d'enregistrer, sur un compte actif) ; le reste
/// est publié tout de suite. Un compte rejeté affiche le motif et se corrige puis se renvoie.
/// Le type de compte et le numéro ne se modifient pas ici.
class BusinessEditScreen extends ConsumerWidget {
  const BusinessEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final async = ref.watch(myBusinessProvider);
    // Après un enregistrement le compte est relu : le formulaire reste affiché.
    final loaded = async.value;
    if (loaded != null) {
      return _EditForm(key: const ValueKey('business-edit-form'), original: loaded);
    }
    final Widget body = async.when(
      loading: () => Semantics(
        label: l10n.t('business.edit.loading'),
        liveRegion: true,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) {
        final key = error is ApiException && error.code == ApiErrorCode.network
            ? 'business.edit.error.network'
            : (error is ApiException && error.serverCode == ServerCodes.noBusiness
                ? 'business.edit.error.noBusiness'
                : 'business.edit.error.unknown');
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(l10n.t(key),
                    key: const ValueKey('business-edit-load-error'),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.error)),
              ),
              TextButton(
                key: const ValueKey('business-edit-retry'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => ref.invalidate(myBusinessProvider),
                child: Text(l10n.t('profile.retry')),
              ),
            ],
          ),
        );
      },
      data: (_) => const SizedBox.shrink(),
    );
    return _EditScaffold(title: l10n.t('business.edit.title'), body: body);
  }
}

/// Barre du haut (retour + titre) commune au chargement, à l'erreur et au formulaire.
class _EditScaffold extends StatelessWidget {
  const _EditScaffold({
    required this.title,
    required this.body,
    this.bottom,
  });

  final String title;
  final Widget body;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    void back() => Navigator.of(context).maybePop();
    return Scaffold(
      bottomNavigationBar: bottom == null
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 14), child: bottom),
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: l10n.t('business.create.back'),
                    excludeSemantics: true,
                    onTap: back,
                    child: InkResponse(
                      key: const ValueKey('business-edit-back'),
                      onTap: back,
                      radius: 24,
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.card,
                              border: Border.all(color: c.border),
                            ),
                            child: Icon(Icons.chevron_left, size: 22, color: c.textPrimary),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
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

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({super.key, required this.original});

  final MyBusiness original;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  /// Le compte tel qu'il était à l'ouverture : base de toutes les comparaisons.
  late final MyBusiness _original = widget.original;
  late final TextEditingController _name;
  late final TextEditingController _owner;
  late final TextEditingController _repere;
  late final TextEditingController _description;

  int? _zoneId;
  String? _pickedLabel;
  String? _photoPath;
  String? _ownerPhotoPath;
  String? _cniPath;
  String? _diplomaPath;

  bool _submitted = false;
  bool _allowPop = false;

  /// Champs refusés par le serveur au dernier essai (effacés dès qu'on les modifie).
  Set<String> _serverFields = {};

  @override
  void initState() {
    super.initState();
    final start = BusinessEditForm.from(_original);
    _name = TextEditingController(text: start.name);
    _owner = TextEditingController(text: start.representantNom);
    _repere = TextEditingController(text: start.repere);
    _description = TextEditingController(text: start.description);
    _zoneId = start.zoneId;
  }

  @override
  void dispose() {
    _name.dispose();
    _owner.dispose();
    _repere.dispose();
    _description.dispose();
    super.dispose();
  }

  BusinessEditForm get _form => BusinessEditForm(
        name: _name.text,
        representantNom: _owner.text,
        repere: _repere.text,
        description: _description.text,
        zoneId: _zoneId,
        photoPath: _photoPath,
        representantPhotoPath: _ownerPhotoPath,
        cniPhotoPath: _cniPath,
        diplomePhotoPath: _diplomaPath,
      );

  bool get _dirty => hasEditChanges(_original, _form);
  bool get _rejected => _original.status == BusinessStatus.rejected;

  /// Une modification d'un champ efface son éventuelle erreur du serveur.
  void _touched(Set<String> fields) {
    setState(() {
      _serverFields = _serverFields.difference(fields);
    });
  }

  Future<void> _pickLocation() async {
    final picked = await showEditLocationSheet(context);
    if (picked == null || !mounted) return;
    setState(() {
      _zoneId = picked.zoneId;
      _pickedLabel = picked.label;
      _serverFields = _serverFields.difference({'zone'});
    });
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialog) {
        final l10n = L10n.of(dialog);
        return AlertDialog(
          key: const ValueKey('business-edit-leave'),
          title: Text(l10n.t('business.edit.leave.title')),
          content: Text(l10n.t('business.edit.leave.body')),
          actions: [
            TextButton(
              key: const ValueKey('business-edit-leave-stay'),
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(l10n.t('business.edit.leave.stay')),
            ),
            TextButton(
              key: const ValueKey('business-edit-leave-confirm'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(l10n.t('business.edit.leave.confirm')),
            ),
          ],
        );
      },
    );
    return leave == true;
  }

  /// Retour avec des modifications non enregistrées : on demande avant de les perdre.
  Future<void> _leave() async {
    final leave = await _confirmLeave();
    if (!leave || !mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  Future<bool> _confirmRevalidation() async {
    final nameChanged = _name.text.trim() != _original.name;
    final zoneChanged = _zoneId != null && _zoneId != _original.zoneId;
    final fieldsKey = nameChanged && zoneChanged
        ? 'business.edit.warn.field.both'
        : (nameChanged ? 'business.edit.warn.field.name' : 'business.edit.warn.field.zone');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) {
        final l10n = L10n.of(dialog);
        return AlertDialog(
          key: const ValueKey('business-edit-warning'),
          title: Text(l10n.t('business.edit.warn.title')),
          content: Text(
              l10n.t('business.edit.warn.body').replaceAll('{fields}', l10n.t(fieldsKey))),
          actions: [
            TextButton(
              key: const ValueKey('business-edit-warning-cancel'),
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(l10n.t('business.edit.warn.cancel')),
            ),
            TextButton(
              key: const ValueKey('business-edit-warning-confirm'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(l10n.t('business.edit.warn.confirm')),
            ),
          ],
        );
      },
    );
    return ok == true;
  }

  Future<void> _save() async {
    final notifier = ref.read(businessEditProvider.notifier);
    if (ref.read(businessEditProvider).saving) return;
    setState(() => _submitted = true);
    final form = _form;
    if (editErrors(_original, form).any) return;
    if (!hasEditChanges(_original, form)) return;
    if (_original.status == BusinessStatus.active && isSensitiveChange(_original, form)) {
      if (!await _confirmRevalidation() || !mounted) return;
    }
    await notifier.save(_original, form);
    if (!mounted) return;
    final state = ref.read(businessEditProvider);
    if (state.phase == EditPhase.saved) {
      final l10n = L10n.of(context);
      final result = state.saved?.status;
      final messageKey = _rejected
          ? 'business.edit.saved.resent'
          : (result == BusinessStatus.pending
              ? 'business.edit.saved.pending'
              : 'business.edit.saved');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.t(messageKey))));
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    } else if (state.phase == EditPhase.failed) {
      setState(() {
        _serverFields = state.fieldNames.toSet();
      });
    }
  }

  String? _fieldMessage(L10n l10n, String field) {
    if (!_serverFields.contains(field)) return null;
    final kinds = {kPhotoKind, kRepresentantPhotoKind, kCniPhotoKind, kDiplomePhotoKind};
    return l10n.t(kinds.contains(field) ? 'business.edit.error.photo' : 'business.edit.error.field');
  }

  static const _known = {
    'name', 'zone', 'repere', 'representant_nom', 'description', 'description_activite',
    kPhotoKind, kRepresentantPhotoKind, kCniPhotoKind, kDiplomePhotoKind, //
  };

  String? _problemMessage(L10n l10n, EditState state) {
    if (state.phase != EditPhase.failed) return null;
    return switch (state.problem) {
      EditProblem.network => l10n.t('business.edit.error.network.save'),
      EditProblem.session => l10n.t('business.edit.error.session'),
      EditProblem.throttled => l10n.t('business.edit.error.throttled'),
      EditProblem.support => l10n.t('business.edit.error.support'),
      EditProblem.photo => l10n.t('business.edit.error.photo'),
      EditProblem.subscription => l10n.t('business.edit.error.subscription'),
      EditProblem.noBusiness => l10n.t('business.edit.error.noBusiness'),
      EditProblem.fields => l10n.t('business.edit.error.fields'),
      _ => l10n.t('business.edit.error.server'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final type = _original.typeCompte;
    final typeCode = type?.value ?? 'boutique';
    final form = _form;
    final dirty = _dirty;
    final errors = _submitted ? editErrors(_original, form) : const EditErrors();
    final edit = ref.watch(businessEditProvider);
    final saving = edit.saving;
    final phone = ref.watch(accountControllerProvider).value?.phoneMasked;
    final descField = descriptionFieldOf(type);
    final isProvider = type == BusinessAccountType.prestataireService;

    String? nameError = _fieldMessage(l10n, 'name');
    if (errors.name != null) {
      nameError = businessFieldError(l10n, errors.name!,
          requiredKey: 'business.create.error.nameRequired', max: kBusinessNameMax);
    }
    String? ownerError = _fieldMessage(l10n, 'representant_nom');
    if (errors.owner != null) {
      ownerError = businessFieldError(l10n, errors.owner!,
          requiredKey: 'business.create.error.ownerRequired', max: kBusinessRepresentantMax);
    }
    String? repereError = _fieldMessage(l10n, 'repere');
    if (errors.repere != null) {
      repereError = businessFieldError(l10n, errors.repere!,
          requiredKey: 'business.create.error.nameRequired', max: kBusinessRepereMax);
    }
    String? descError = _fieldMessage(l10n, descField ?? 'description');
    if (errors.description != null) {
      descError = businessFieldError(l10n, errors.description!,
          requiredKey: 'business.create.details.description.required',
          max: descriptionMaxOf(type));
    }

    final zoneLabel = _pickedLabel ??
        (_zoneId == null
            ? null
            : ref.watch(businessZoneLabelProvider(_zoneId!)).value);

    final unknownServerFields = _serverFields.difference(_known);
    final problem = _problemMessage(l10n, edit);
    final noteText = problem ??
        (unknownServerFields.isNotEmpty ? l10n.t('business.edit.error.fields') : null);

    final Widget banner = switch (_original.status) {
      BusinessStatus.rejected => _Banner(
          key: const ValueKey('business-edit-rejected'),
          icon: Icons.cancel,
          color: scheme.error,
          title: l10n.t('business.edit.rejected.title'),
          lines: [
            if (_original.motifRejet.isNotEmpty)
              l10n.t('business.status.rejected.motif').replaceAll('{motif}', _original.motifRejet),
            l10n.t('business.edit.rejected.help'),
          ],
          motifKey: const ValueKey('business-edit-motif'),
        ),
      BusinessStatus.active => _Banner(
          key: const ValueKey('business-edit-active-note'),
          icon: Icons.info_outline,
          color: c.accentText,
          lines: [l10n.t('business.edit.active.note')],
        ),
      BusinessStatus.pending => _Banner(
          key: const ValueKey('business-edit-pending-note'),
          icon: Icons.hourglass_top,
          color: c.accentText,
          lines: [l10n.t('business.edit.pending.note')],
        ),
    };

    return PopScope(
      canPop: _allowPop || (!dirty && !saving),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || saving) return;
        _leave();
      },
      child: _EditScaffold(
        title: l10n.t(_rejected ? 'business.edit.title.rejected' : 'business.edit.title'),
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (noteText != null) ...[
              Semantics(
                liveRegion: true,
                child: Row(
                  key: const ValueKey('business-edit-problem'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline, size: 16, color: scheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(noteText,
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.error)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ] else if (!dirty && !saving) ...[
              Text(l10n.t('business.edit.nochange'),
                  key: const ValueKey('business-edit-nochange'),
                  style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
              const SizedBox(height: 10),
            ],
            PrimaryButton(
              key: const ValueKey('business-edit-save'),
              label: l10n.t(saving
                  ? 'business.edit.saving'
                  : (_rejected ? 'business.edit.save.rejected' : 'business.edit.save')),
              loading: saving,
              onPressed: dirty ? _save : null,
            ),
          ],
        ),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              banner,
              const SizedBox(height: 16),
              LabeledTextField(
                fieldKey: const ValueKey('business-edit-name'),
                label: l10n.t('business.create.name.label.$typeCode'),
                controller: _name,
                maxLength: kBusinessNameMax,
                errorText: nameError,
                onChanged: (_) => _touched({'name'}),
              ),
              const SizedBox(height: 16),
              LabeledTextField(
                fieldKey: const ValueKey('business-edit-owner'),
                label: l10n.t('business.create.owner.label.$typeCode'),
                controller: _owner,
                maxLength: kBusinessRepresentantMax,
                errorText: ownerError,
                onChanged: (_) => _touched({'representant_nom'}),
              ),
              const SizedBox(height: 16),
              PhotoField(
                tapKey: const ValueKey('business-edit-photo'),
                label: l10n.t('business.create.photo.label.$typeCode'),
                placeholder: l10n.t('business.create.photo.add'),
                icon: Icons.photo_camera_outlined,
                path: _photoPath,
                helper: _original.hasPhoto && _photoPath == null
                    ? l10n.t('business.edit.photo.current')
                    : null,
                errorText: _fieldMessage(l10n, kPhotoKind),
                onChanged: (p) {
                  _photoPath = p;
                  _touched({kPhotoKind});
                },
              ),
              const SizedBox(height: 16),
              PhotoField(
                tapKey: const ValueKey('business-edit-owner-photo'),
                compact: true,
                label: l10n.t('business.create.ownerPhoto.label.$typeCode'),
                placeholder: l10n.t('business.create.ownerPhoto.add'),
                icon: Icons.person_outline,
                path: _ownerPhotoPath,
                helper: _original.hasRepresentantPhoto && _ownerPhotoPath == null
                    ? l10n.t('business.edit.photo.current')
                    : null,
                errorText: _fieldMessage(l10n, kRepresentantPhotoKind),
                onChanged: (p) {
                  _ownerPhotoPath = p;
                  _touched({kRepresentantPhotoKind});
                },
              ),
              const SizedBox(height: 16),
              _ValueField(
                fieldKey: const ValueKey('business-edit-location'),
                label: l10n.t('business.create.location.label'),
                value: zoneLabel ?? l10n.t('business.create.location.none'),
                muted: zoneLabel == null,
                hint: l10n.t('business.create.location.hint'),
                errorText: _fieldMessage(l10n, 'zone'),
                onTap: saving ? null : _pickLocation,
              ),
              const SizedBox(height: 16),
              LabeledTextField(
                fieldKey: const ValueKey('business-edit-repere'),
                label: l10n.t('business.create.repere.label'),
                labelSuffix: l10n.t('business.create.optional'),
                hintText: l10n.t('business.create.repere.hint'),
                controller: _repere,
                maxLength: kBusinessRepereMax,
                errorText: repereError,
                onChanged: (_) => _touched({'repere'}),
              ),
              if (descField != null) ...[
                const SizedBox(height: 16),
                LabeledTextField(
                  fieldKey: const ValueKey('business-edit-description'),
                  label: l10n.t(type == BusinessAccountType.structure
                      ? 'business.create.structure.description.label'
                      : 'business.create.details.description.label'),
                  labelSuffix: l10n.t('business.create.optional'),
                  controller: _description,
                  maxLength: descriptionMaxOf(type),
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  errorText: descError,
                  onChanged: (_) => _touched({descField}),
                ),
              ],
              if (isProvider) ...[
                const SizedBox(height: 16),
                PhotoField(
                  tapKey: const ValueKey('business-edit-cni'),
                  label: l10n.t('business.create.cni.label'),
                  placeholder: l10n.t('business.create.cni.add'),
                  icon: Icons.badge_outlined,
                  path: _cniPath,
                  addedSemantics: l10n.t('business.create.cni.added'),
                  helper: _original.hasCni && _cniPath == null
                      ? l10n.t('business.edit.photo.current')
                      : l10n.t('business.create.cni.help'),
                  errorText: _fieldMessage(l10n, kCniPhotoKind),
                  onChanged: (p) {
                    _cniPath = p;
                    _touched({kCniPhotoKind});
                  },
                ),
                const SizedBox(height: 16),
                PhotoField(
                  tapKey: const ValueKey('business-edit-diploma'),
                  label: l10n.t('business.create.diploma.label'),
                  labelSuffix: l10n.t('business.create.optional'),
                  placeholder: l10n.t('business.create.diploma.add'),
                  icon: Icons.school_outlined,
                  path: _diplomaPath,
                  addedSemantics: l10n.t('business.create.diploma.added'),
                  helper: _original.hasDiplome && _diplomaPath == null
                      ? l10n.t('business.edit.photo.current')
                      : l10n.t('business.create.diploma.help'),
                  errorText: _fieldMessage(l10n, kDiplomePhotoKind),
                  onChanged: (p) {
                    _diplomaPath = p;
                    _touched({kDiplomePhotoKind});
                  },
                ),
              ],
              if (phone != null) ...[
                const SizedBox(height: 16),
                _ValueField(
                  fieldKey: const ValueKey('business-edit-phone'),
                  label: l10n.t('business.create.phone.label'),
                  value: phone,
                  trailing: l10n.t('business.create.phone.verified'),
                  hint: l10n.t('business.edit.phone.note'),
                  dimmed: true,
                ),
                const SizedBox(height: 6),
                Text(l10n.t('business.edit.phone.note'),
                    style: TextStyle(fontSize: 11, height: 1.4, color: c.textSecondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bandeau d'information ou d'alerte en haut du formulaire (état du compte).
class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.icon,
    required this.color,
    required this.lines,
    this.title,
    this.motifKey,
  });

  final IconData icon;
  final Color color;
  final String? title;
  final List<String> lines;
  final Key? motifKey;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(title!,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                  for (var i = 0; i < lines.length; i++) ...[
                    if (i > 0 || title != null) const SizedBox(height: 6),
                    Text(
                      lines[i],
                      key: i == 0 && title != null ? motifKey : null,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        fontWeight: i == 0 && title != null ? FontWeight.w600 : FontWeight.w400,
                        color: i == 0 && title != null ? null : c.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Champ qui n'est pas une saisie : le lieu (un appui ouvre le choix) et le numéro (jamais
/// modifiable ici).
class _ValueField extends StatelessWidget {
  const _ValueField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.hint,
    this.trailing,
    this.muted = false,
    this.dimmed = false,
    this.onTap,
    this.errorText,
  });

  final Key fieldKey;
  final String label;
  final String value;
  final String hint;
  final String? trailing;
  final bool muted;
  final bool dimmed;
  final VoidCallback? onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final error = Theme.of(context).colorScheme.error;
    final interactive = onTap != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Semantics(
          container: true,
          button: interactive,
          onTap: onTap,
          label: trailing == null ? '$label : $value' : '$label : $value, $trailing',
          hint: hint,
          excludeSemantics: true,
          child: Opacity(
            opacity: dimmed ? 0.75 : 1,
            child: DecoratedBox(
              key: fieldKey,
              decoration: BoxDecoration(
                color: c.card,
                border: Border.all(color: errorText == null ? c.border : error),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(value,
                                style: TextStyle(
                                    fontSize: 14, color: muted ? c.textSecondary : null)),
                          ),
                          if (trailing != null) ...[
                            const SizedBox(width: 8),
                            Text(trailing!,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: c.accentText)),
                          ],
                          if (interactive) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.chevron_right, size: 22, color: c.textSecondary),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(errorText!,
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600, color: error)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
