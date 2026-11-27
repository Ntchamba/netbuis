import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/netbuis_logo.dart';
import '../../application/city_controller.dart';

/// Écran de lancement (maquette Splash) : logo, slogan, « Commencer », version.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    var seen = false;
    try {
      seen = await ref.read(appPrefsProvider).isOnboardingSeen();
    } on Object {
      // Préférence illisible : on montre la Découverte, c'est le choix le plus sûr.
    }
    final next = seen ? await routeAfterDiscovery(ref.read(appPrefsProvider)) : Routes.onboarding;
    if (!context.mounted) return;
    context.go(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                child: Column(
                  children: [
                    const SizedBox(height: 120),
                    ExcludeSemantics(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(Icons.search, size: 40, color: AppColors.onAccent),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const NetBuisLogo(fontSize: 28),
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        l10n.t('splash.slogan'),
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          fontSize: 13.5,
                          height: 1.5,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 56),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _start(context, ref),
                        child: Text(l10n.t('splash.start')),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l10n.t('splash.version'),
                      style: TextStyle(fontSize: 11, color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
