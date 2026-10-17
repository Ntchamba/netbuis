import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/phone_formatter.dart';

/// Champ du numéro (maquette Connexion) : préfixe fixe « 🇨🇲 +237 » puis 9 chiffres
/// au clavier numérique, affichés « 6 12 34 56 78 ».
class PhoneInput extends StatelessWidget {
  const PhoneInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    this.hasError = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final bool hasError;

  /// Préfixe affiché (indicatif du Cameroun, fixe).
  static const prefix = '🇨🇲 +237';

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final error = Theme.of(context).colorScheme.error;
    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: l10n.t('auth.phone.prefixLabel'),
          excludeSemantics: true,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: c.card,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              prefix,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.textPrimary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            label: l10n.t('auth.phone.label'),
            child: TextField(
            key: const ValueKey('phone-field'),
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: const [PhoneNumberFormatter()],
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: l10n.t('auth.phone.hint'),
              contentPadding: const EdgeInsets.all(14),
              enabledBorder: hasError
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: error),
                    )
                  : null,
            ),
            onChanged: onChanged,
            onSubmitted: (_) => onSubmitted(),
          ),
          ),
        ),
      ],
    ),
    );
  }
}
