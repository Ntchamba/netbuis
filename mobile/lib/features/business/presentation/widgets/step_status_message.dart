import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Chargement, erreur ou liste vide d'une étape, avec « Réessayer » quand c'est utile.
class StepStatusMessage extends StatelessWidget {
  const StepStatusMessage({
    super.key,
    required this.icon,
    required this.text,
    this.retryLabel,
    this.onRetry,
    this.retryKey,
  });

  final Widget icon;
  final String text;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final Key? retryKey;

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
                key: retryKey,
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
