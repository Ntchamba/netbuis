import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/business_draft_controller.dart';

/// « Demande envoyée » (maquette CreationBusiness-Recap, état envoyé). Écran sans brouillon :
/// à son ouverture, le brouillon (photos locales et clés comprises) est vidé. Le retour
/// système mène au Profil, où l'état de la demande est visible.
class SentScreen extends ConsumerStatefulWidget {
  const SentScreen({super.key});

  @override
  ConsumerState<SentScreen> createState() => _SentScreenState();
}

class _SentScreenState extends ConsumerState<SentScreen> {
  @override
  void initState() {
    super.initState();
    // Après le premier affichage : les écrans du parcours sont déjà retirés de la pile.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(businessDraftProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.profile);
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accent,
                        ),
                        child: const ExcludeSemantics(
                          child: Icon(Icons.check, size: 40, color: AppColors.onAccent),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Semantics(
                        header: true,
                        liveRegion: true,
                        child: Text(
                          l10n.t('business.sent.title'),
                          key: const ValueKey('sent-title'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 18),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Text(
                          l10n.t('business.sent.body'),
                          key: const ValueKey('sent-body'),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, height: 1.5, color: c.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          key: const ValueKey('sent-home'),
                          onPressed: () => context.go(Routes.home),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 52),
                            textStyle:
                                const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          child: Text(l10n.t('business.sent.home')),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const ValueKey('sent-profile'),
                        onPressed: () => context.go(Routes.profile),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          foregroundColor: c.textSecondary,
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        child: Text(l10n.t('business.sent.profile')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
