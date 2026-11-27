import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/business_draft.dart';

/// Les 5 types de compte, icône + mot, sur deux rangées (3 puis 2), comme la maquette.
class AccountTypeSelector extends StatelessWidget {
  const AccountTypeSelector({super.key, required this.selected, required this.onSelected});

  final BusinessAccountType selected;
  final ValueChanged<BusinessAccountType> onSelected;

  static const _rows = [
    [BusinessAccountType.boutique, BusinessAccountType.entreprise, BusinessAccountType.structure],
    [BusinessAccountType.particulierVendeur, BusinessAccountType.prestataireService],
  ];

  /// Icône de chaque type (celles de la maquette).
  static String iconOf(BusinessAccountType type) {
    switch (type) {
      case BusinessAccountType.boutique:
        return '🏪';
      case BusinessAccountType.entreprise:
        return '🏢';
      case BusinessAccountType.structure:
        return '🏛️';
      case BusinessAccountType.particulierVendeur:
        return '🙋';
      case BusinessAccountType.prestataireService:
        return '🧰';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Semantics(
      container: true,
      label: l10n.t('business.create.types'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Column(
            children: [
              for (var r = 0; r < _rows.length; r++) ...[
                if (r > 0) const SizedBox(height: 4),
                Row(
                  children: [
                    for (var i = 0; i < _rows[r].length; i++) ...[
                      if (i > 0) const SizedBox(width: 3),
                      Expanded(
                        child: _TypeButton(
                          type: _rows[r][i],
                          label: l10n.t('business.create.type.${_rows[r][i].value}'),
                          selected: _rows[r][i] == selected,
                          onTap: () => onSelected(_rows[r][i]),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.type,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final BusinessAccountType type;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = selected ? AppColors.onAccent : c.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          key: ValueKey('business-type-${type.value}'),
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AccountTypeSelector.iconOf(type),
                    style: const TextStyle(fontSize: 20, height: 1.1),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
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
