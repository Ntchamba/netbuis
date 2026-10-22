// Éléments communs des feuilles du bas : cadre ([SheetFrame]) et message à deux boutons
// ([SheetMessage]), utilisés par WhatsApp, le retour d'appel et le signalement.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Cadre commun des feuilles d'appel, de WhatsApp et de retour d'appel.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      child: SafeArea(top: false, child: SingleChildScrollView(child: child)),
    );
  }
}

/// Message avec un bouton principal et un bouton secondaire facultatifs.
class SheetMessage extends StatelessWidget {
  const SheetMessage({
    super.key,
    required this.title,
    this.body,
    this.primary,
    this.primaryKey,
    this.onPrimary,
    this.secondary,
    this.secondaryKey,
    this.onSecondary,
  });

  final String title;
  final String? body;
  final String? primary;
  final Key? primaryKey;
  final VoidCallback? onPrimary;
  final String? secondary;
  final Key? secondaryKey;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(body!, style: TextStyle(fontSize: 13, color: c.textSecondary)),
        ],
        const SizedBox(height: 16),
        if (primary != null)
          SizedBox(
            height: 52,
            child: FilledButton(
              key: primaryKey,
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(primary!,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        if (secondary != null)
          TextButton(
            key: secondaryKey,
            onPressed: onSecondary,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: c.textSecondary,
            ),
            child: Text(secondary!,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}
