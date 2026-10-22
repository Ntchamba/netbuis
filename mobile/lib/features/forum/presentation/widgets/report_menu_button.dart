// Bouton discret ⋯ « Signaler » d'une publication ou d'un commentaire (T093).
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ReportMenuButton extends StatelessWidget {
  const ReportMenuButton(
      {super.key, required this.tooltip, required this.onPressed});

  final String tooltip;

  /// Null = désactivé (hors connexion).
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        icon: Icon(Icons.more_horiz,
            size: 20, color: AppColors.of(context).textSecondary),
      );
}
