import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../widgets/photo_field.dart';
import 'business_info_screen.dart' show businessFieldError;

/// Icône de la maquette pour chaque catégorie de service, associée par `code` (le serveur
/// n'envoie pas d'icône pour ces catégories).
const Map<String, String> kServiceCategoryEmojis = {
  'enseignement_domicile': '🎓',
  'technique_reparation': '🔧',
  'services_medicaux_independants': '🩺',
  'beaute_bien_etre_domicile': '💅',
  'juridique_comptabilite': '⚖️',
  'evenementiel': '🎉',
  'autre': '✨',
};

/// Étape « Catégorie & vérification » (maquette CreationBusiness-Prestataire-Categorie),
/// pour le Prestataire de service : une seule catégorie de service (texte libre si
/// « Autre »), la photo de la CNI (obligatoire, jamais affichée en entier au public) et le
/// diplôme (facultatif). Pour un autre type de compte, l'écran renvoie à Informations.
class ServiceCategoryScreen extends ConsumerStatefulWidget {
  const ServiceCategoryScreen({super.key});

  @override
  ConsumerState<ServiceCategoryScreen> createState() => _ServiceCategoryScreenState();
}

class _ServiceCategoryScreenState extends ConsumerState<ServiceCategoryScreen> {
  late final TextEditingController _libre;
  final _categoryKey = GlobalKey();
  final _libreKey = GlobalKey();
  final _cniKey = GlobalKey();
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _libre = TextEditingController(text: ref.read(businessDraftProvider).categorieServiceLibre);
  }

  @override
  void dispose() {
    _libre.dispose();
    super.dispose();
  }

  void _continue() {
    final notifier = ref.read(businessDraftProvider.notifier);
    notifier.setCategorieServiceLibre(_libre.text.trim());
    final draft = ref.read(businessDraftProvider);
    setState(() => _submitted = true);
    if (!draft.serviceStepIsValid) {
      final first = draft.serviceCategoryMissing
          ? _categoryKey
          : (draft.categorieServiceLibreError != null ? _libreKey : _cniKey);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = first.currentContext;
        if (target != null) Scrollable.ensureVisible(target, duration: Duration.zero);
      });
      return;
    }
    final route = BusinessCreationFlow.nextRoute(draft.typeCompte, BusinessStep.serviceCategory);
    if (route == null) {
      // Le lieu et le récapitulatif (T034, T035) ne sont pas encore construits.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(L10n.of(context).t('business.create.comingSoon'))));
      return;
    }
    context.push(route);
  }

  void _choose(ReferentialItem item) {
    final before = ref.read(businessDraftProvider).categorieServiceId;
    ref.read(businessDraftProvider.notifier).setServiceCategory(item);
    // Le texte libre n'a de sens que pour « Autre » : un autre choix le vide.
    if (before != item.id) _libre.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final error = Theme.of(context).colorScheme.error;
    final draft = ref.watch(businessDraftProvider);
    if (draft.typeCompte != BusinessAccountType.prestataireService) {
      return const BusinessStepRedirect(Routes.createBusiness);
    }
    final notifier = ref.read(businessDraftProvider.notifier);
    final categories = ref.watch(businessServiceCategoriesProvider);
    final selectedId = draft.categorieServiceId;

    Widget grid;
    if (categories.isLoading && !categories.hasValue) {
      grid = _Message(
        key: const ValueKey('business-service-loading'),
        icon: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        text: l10n.t('business.create.service.loading'),
      );
    } else if (categories.hasError) {
      final e = categories.error;
      final network = e is ApiException && e.code == ApiErrorCode.network;
      grid = _Message(
        key: const ValueKey('business-service-error'),
        icon: Icon(Icons.error_outline, color: error),
        text: l10n.t(network
            ? 'business.create.service.error.network'
            : 'business.create.service.error.unknown'),
        retryLabel: l10n.t('business.create.service.retry'),
        onRetry: () => ref.invalidate(businessServiceCategoriesProvider),
      );
    } else if (categories.requireValue.isEmpty) {
      grid = _Message(
        key: const ValueKey('business-service-empty'),
        icon: Icon(Icons.info_outline, color: c.textSecondary),
        text: l10n.t('business.create.service.empty'),
        retryLabel: l10n.t('business.create.service.retry'),
        onRetry: () => ref.invalidate(businessServiceCategoriesProvider),
      );
    } else {
      final list = categories.requireValue;
      grid = Column(
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

    String? libreError;
    if (_submitted) {
      final l = draft.categorieServiceLibreError;
      if (l != null) {
        libreError = businessFieldError(l10n, l,
            requiredKey: 'business.create.service.other.required',
            max: kBusinessCategorieServiceLibreMax);
      }
    }

    return BusinessStepScaffold(
      step: BusinessCreationFlow.position(draft.typeCompte, BusinessStep.serviceCategory),
      total: BusinessCreationFlow.total(draft.typeCompte),
      stepName: l10n.t('business.create.stepName.service'),
      onContinue: _continue,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.t('business.create.service.title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.t('business.create.service.intro'),
          style: TextStyle(fontSize: 12.5, height: 1.4, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(key: _categoryKey, child: grid),
        if (_submitted && draft.serviceCategoryMissing) ...[
          const SizedBox(height: 10),
          _ErrorLine(
            key: const ValueKey('business-service-required'),
            text: l10n.t('business.create.service.error.required'),
          ),
        ],
        if (draft.isOtherServiceCategory) ...[
          const SizedBox(height: 16),
          DecoratedBox(
            key: const ValueKey('business-service-other-note'),
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
                    child: Text.rich(
                      TextSpan(
                        text: '${l10n.t('business.create.service.otherNote.lead')} ',
                        children: [
                          TextSpan(
                            text: l10n.t('business.create.service.otherNote.examples'),
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                      style: TextStyle(fontSize: 12, height: 1.45, color: c.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          KeyedSubtree(
            key: _libreKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: l10n.t('business.create.service.other.label'),
                  textField: true,
                  child: TextField(
                    key: const ValueKey('business-service-libre'),
                    controller: _libre,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(kBusinessCategorieServiceLibreMax),
                    ],
                    onChanged: notifier.setCategorieServiceLibre,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: l10n.t('business.create.service.other.hint'),
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        fontStyle: FontStyle.italic,
                        color: c.textSecondary,
                      ),
                      enabledBorder: libreError == null
                          ? null
                          : OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: error),
                            ),
                    ),
                  ),
                ),
                if (libreError != null) ...[
                  const SizedBox(height: 6),
                  _ErrorLine(key: const ValueKey('business-service-libre-error'), text: libreError),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Divider(height: 1, color: c.border),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            l10n.t('business.create.verify.title'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.t('business.create.verify.intro'),
          style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        KeyedSubtree(
          key: _cniKey,
          child: PhotoField(
            tapKey: const ValueKey('business-cni'),
            label: l10n.t('business.create.cni.label'),
            labelSuffix: l10n.t('business.create.cni.required'),
            labelSuffixColor: c.accentText,
            placeholder: l10n.t('business.create.cni.add'),
            icon: Icons.badge_outlined,
            path: draft.cniPhotoPath,
            addedSemantics: l10n.t('business.create.cni.added'),
            helper: l10n.t('business.create.cni.help'),
            errorText: _submitted && draft.cniPhotoMissing
                ? l10n.t('business.create.cni.error.required')
                : null,
            onChanged: notifier.setCniPhotoPath,
          ),
        ),
        const SizedBox(height: 16),
        PhotoField(
          tapKey: const ValueKey('business-diploma'),
          label: l10n.t('business.create.diploma.label'),
          labelSuffix: l10n.t('business.create.optional'),
          placeholder: l10n.t('business.create.diploma.add'),
          icon: Icons.school_outlined,
          path: draft.diplomePhotoPath,
          addedSemantics: l10n.t('business.create.diploma.added'),
          helper: l10n.t('business.create.diploma.help'),
          onChanged: notifier.setDiplomePhotoPath,
          onRemove: () => notifier.setDiplomePhotoPath(null),
          removeLabel: l10n.t('business.create.diploma.remove'),
          removeKey: const ValueKey('business-diploma-remove'),
        ),
      ],
    );
  }

  Widget _tile(L10n l10n, ReferentialItem item, int? selectedId) {
    return _CategoryTile(
      item: item,
      selected: item.id == selectedId,
      selectedText: l10n.t('business.create.service.selected'),
      onTap: () => _choose(item),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.item,
    required this.selected,
    required this.selectedText,
    required this.onTap,
  });

  final ReferentialItem item;
  final bool selected;
  final String selectedText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fg = selected ? AppColors.onAccent : c.textPrimary;
    final emoji = kServiceCategoryEmojis[item.code] ?? (item.icon.isNotEmpty ? item.icon : null);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: selected ? selectedText.replaceAll('{label}', item.name) : item.name,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.accent : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? AppColors.accent : c.border, width: 1.5),
        ),
        child: InkWell(
          key: ValueKey('business-service-${item.code}'),
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Code inconnu sans icône du serveur : icône neutre.
                  if (emoji != null)
                    Text(emoji, style: const TextStyle(fontSize: 24))
                  else
                    Icon(Icons.handyman_outlined, size: 24, color: fg),
                  const SizedBox(height: 8),
                  Text(
                    item.name,
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

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: error),
            ),
          ),
        ],
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
                key: const ValueKey('business-service-retry'),
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
