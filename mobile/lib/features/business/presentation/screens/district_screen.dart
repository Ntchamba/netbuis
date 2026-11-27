import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/data/zones/zone.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../onboarding/presentation/screens/choose_city_screen.dart'
    show CityMessage, cityErrorMessage;
import '../../application/business_draft_controller.dart';
import '../../application/location_controller.dart';
import '../widgets/business_step_redirect.dart';
import '../widgets/location_scaffold.dart';

/// Second temps du choix du lieu (aucune maquette) : le quartier de la ville choisie.
/// Liste simple ; le quartier est facultatif (« Je ne trouve pas mon quartier » garde la
/// ville seule, car les listes de quartiers sont construites par NetBuis et peuvent être
/// incomplètes). Une ville sans quartier passe directement : l'écran se referme tout seul.
/// Répond `true` à l'écran précédent quand le lieu est complet.
class DistrictScreen extends ConsumerStatefulWidget {
  const DistrictScreen({super.key});

  @override
  ConsumerState<DistrictScreen> createState() => _DistrictScreenState();
}

class _DistrictScreenState extends ConsumerState<DistrictScreen> {
  bool _closing = false;

  void _done() {
    if (_closing) return;
    _closing = true;
    context.pop(true);
  }

  void _choose(Zone? district) {
    ref.read(businessDraftProvider.notifier).setQuartier(district);
    _done();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final city = ref.watch(businessDraftProvider.select((d) => d.ville));
    final selectedId = ref.watch(businessDraftProvider.select((d) => d.quartier?.id));
    // Ouvert sans ville (adresse tapée à la main) : retour au premier temps.
    if (city == null) return const BusinessStepRedirect(Routes.createBusinessLocation);

    final districts = ref.watch(districtsProvider(city.id));
    final notFound = _NotFoundButton(
      label: l10n.t('business.create.location.district.notFound'),
      note: l10n.t('business.create.location.district.notFoundNote').replaceAll('{city}', city.name),
      onTap: () => _choose(null),
    );

    final List<Widget> body = districts.when(
      loading: () => [
        Semantics(
          label: l10n.t('business.create.location.district.loading'),
          liveRegion: true,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
      error: (error, _) => [
        CityMessage(
          text: cityErrorMessage(l10n, error),
          isError: true,
          onRetry: () => ref.invalidate(districtsProvider(city.id)),
        ),
        const SizedBox(height: 16),
        notFound,
      ],
      data: (list) {
        if (list.isEmpty) {
          // Aucun quartier connu pour cette ville : on garde la ville seule, sans message.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _done();
          });
          return const [SizedBox.shrink()];
        }
        return [
          for (final district in list) ...[
            _DistrictTile(
              district: district,
              selected: district.id == selectedId,
              selectedLabel: l10n.t('business.create.location.district.selected'),
              onTap: () => _choose(district),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          notFound,
        ];
      },
    );

    return LocationScaffold(
      title: l10n.t('business.create.location.district.title'),
      subtitle: l10n
          .t('business.create.location.district.subtitle')
          .replaceAll('{city}', city.name),
      children: [
        Row(
          children: [
            Icon(Icons.location_city_outlined, size: 18, color: c.accentText),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                city.name,
                key: const ValueKey('district-city'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...body,
      ],
    );
  }
}

class _DistrictTile extends StatelessWidget {
  const _DistrictTile({
    required this.district,
    required this.selected,
    required this.selectedLabel,
    required this.onTap,
  });

  final Zone district;
  final bool selected;
  final String selectedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: selected ? selectedLabel.replaceAll('{name}', district.name) : district.name,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.accent : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('district-${district.id}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(selected ? Icons.check_circle : Icons.place_outlined,
                      size: 22, color: c.accentText),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      district.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

/// « Je ne trouve pas mon quartier » : carte secondaire (contour seul) avec une note qui
/// dit ce qui sera gardé (la ville seule).
class _NotFoundButton extends StatelessWidget {
  const _NotFoundButton({required this.label, required this.note, required this.onTap});

  final String label;
  final String note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: label,
          onTap: onTap,
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('district-not-found'),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.help_outline, size: 22, color: c.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(note, style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary)),
      ],
    );
  }
}
