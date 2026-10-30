import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// Barre « Étape X sur Y » des parcours en plusieurs écrans (maquettes CreationBusiness-*) :
/// le numéro de l'étape à gauche, le nom de l'étape en accent à droite, puis une
/// barre de 5 px remplie à [step] / [total].
///
/// Lecture d'écran : « Étape 2 sur 6 » (le nom de l'étape est lu à part).
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({
    super.key,
    required this.step,
    required this.total,
    required this.stepName,
  }) : assert(step >= 1 && total >= step);

  /// Numéro de l'étape, à partir de 1.
  final int step;
  final int total;

  /// Nom court de l'étape (déjà traduit).
  final String stepName;

  /// Texte « Étape X sur Y » dans la langue de l'application.
  static String labelFor(L10n l10n, int step, int total) =>
      l10n.t('business.create.step').replaceAll('{n}', '$step').replaceAll('{total}', '$total');

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final label = labelFor(l10n, step, total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Semantics(
              label: label,
              excludeSemantics: true,
              child: Text(
                label,
                key: const ValueKey('step-label'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textSecondary),
              ),
            ),
            Text(
              stepName,
              key: const ValueKey('step-name'),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.accentText),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 5,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: c.border)),
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: step / total,
                      child: const ColoredBox(
                        key: ValueKey('step-fill'),
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
