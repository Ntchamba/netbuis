import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/city_controller.dart';
import '../../application/onboarding_controller.dart';

const _slideIcons = [
  Icons.search,
  Icons.call_outlined,
  Icons.place_outlined,
  Icons.chat_bubble_outline,
  Icons.storefront_outlined,
];

/// Découverte en 5 diapositives (maquette Onboarding). Affichée à la première ouverture seulement.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key, this.teamEnabled});

  /// Remplace le drapeau `FeatureFlags.teamEnabled` (tests).
  final bool? teamEnabled;

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(onboardingIndexProvider.notifier).markSeen();
    } on Object {
      // Mémorisation impossible : on continue, la Découverte sera simplement revue.
    }
    final next = await routeAfterDiscovery(ref.read(appPrefsProvider));
    if (!context.mounted) return;
    context.go(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final index = ref.watch(onboardingIndexProvider);
    final slides =
        teamEnabled == null ? onboardingSlides() : onboardingSlides(teamEnabled: teamEnabled!);
    final slide = slides[index];
    final isLast = index == onboardingSlideCount - 1;
    final page = l10n
        .t('onboarding.page')
        .replaceAll('{n}', '${index + 1}')
        .replaceAll('{total}', '$onboardingSlideCount');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _finish(context, ref),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: c.textSecondary,
                    textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  child: Text(l10n.t('onboarding.skip')),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Semantics(
                        container: true,
                        label: page,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ExcludeSemantics(
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(color: c.card, shape: BoxShape.circle),
                                  child: Center(
                                    child: Container(
                                      width: 72,
                                      height: 72,
                                      decoration: const BoxDecoration(
                                        color: AppColors.accent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _slideIcons[index],
                                        size: 30,
                                        color: AppColors.onAccent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                l10n.t(slide.titleKey),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                      height: 1.3,
                                    ),
                              ),
                              const SizedBox(height: 20),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 300),
                                child: Text(
                                  l10n.t(slide.bodyKey),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.55,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                children: [
                  ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < onboardingSlideCount; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3.5),
                            child: Container(
                              key: ValueKey('dot-$i'),
                              width: i == index ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: i == index ? AppColors.accent : c.border,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isLast
                          ? () => _finish(context, ref)
                          : ref.read(onboardingIndexProvider.notifier).next,
                      child: Text(l10n.t(isLast ? 'onboarding.start' : 'onboarding.next')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
