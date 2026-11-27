import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';

/// Ligne « Modifier ma boutique → » du Profil (maquette Profil, bloc COMPTE BUSINESS), sous
/// « Mes publications ». Affichée quand le compte a un compte business ; ouvre
/// [Routes.editBusiness].
class EditBusinessEntry extends StatelessWidget {
  const EditBusinessEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final label = l10n.t('business.edit.entry');
    void open() => context.push(Routes.editBusiness);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Semantics(
        button: true,
        label: label,
        onTap: open,
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey('profile-edit-business'),
          borderRadius: BorderRadius.circular(16),
          onTap: open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
                  const SizedBox(width: 8),
                  Text('→', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
