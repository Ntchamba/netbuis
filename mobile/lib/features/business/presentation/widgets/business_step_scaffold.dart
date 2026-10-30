import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/step_progress_bar.dart';

/// Gabarit commun à tous les écrans du parcours de création (maquettes CreationBusiness-*) :
/// bouton retour + « Créer mon compte business », barre « Étape X sur Y », contenu qui
/// défile verticalement, puis le bouton « Continuer » fixé en bas.
class BusinessStepScaffold extends StatelessWidget {
  const BusinessStepScaffold({
    super.key,
    required this.step,
    required this.total,
    required this.stepName,
    required this.onContinue,
    required this.children,
    this.scrollController,
    this.continueLabel,
    this.busy = false,
    this.bottomNote,
  });

  final int step;
  final int total;

  /// Nom court de l'étape, affiché à droite de la barre.
  final String stepName;
  final VoidCallback onContinue;
  final List<Widget> children;
  final ScrollController? scrollController;

  /// Texte du bouton du bas ; « Continuer » par défaut (« Publier ma demande » au récapitulatif).
  final String? continueLabel;

  /// Envoi en cours : le bouton est remplacé par un indicateur et le retour est bloqué
  /// (sur l'écran comme avec le geste système).
  final bool busy;

  /// Message (état d'envoi, erreur) affiché au-dessus du bouton du bas.
  final Widget? bottomNote;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final scaffold = Scaffold(
      // La barre du bas est celle du Scaffold : un message (SnackBar) s'affiche au-dessus
      // d'elle et ne cache jamais « Continuer ».
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (bottomNote != null) ...[bottomNote!, const SizedBox(height: 10)],
                PrimaryButton(
                  label: continueLabel ?? l10n.t('business.create.continue'),
                  onPressed: onContinue,
                  loading: busy,
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      _BackButton(label: l10n.t('business.create.back'), enabled: !busy),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            l10n.t('business.create.title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: StepProgressBar(step: step, total: total, stepName: stepName),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return PopScope(canPop: !busy, child: scaffold);
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.label, this.enabled = true});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    void back() {
      if (!enabled) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.profile);
      }
    }

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: back,
      child: InkResponse(
        key: const ValueKey('business-back'),
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
    );
  }
}
