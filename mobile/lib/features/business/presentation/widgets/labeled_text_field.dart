import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// Champ de texte de la maquette : libellé en gras au-dessus (avec, si besoin, une
/// mention grise comme « (optionnel) »), la saisie, une aide facultative, puis l'erreur.
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.maxLength,
    this.fieldKey,
    this.labelSuffix,
    this.hintText,
    this.helper,
    this.errorText,
    this.onChanged,
    this.textCapitalization = TextCapitalization.words,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.minLines,
    this.maxLines = 1,
    this.extraFormatters = const [],
  });

  final String label;
  final String? labelSuffix;
  final TextEditingController controller;
  final int maxLength;
  final Key? fieldKey;
  final String? hintText;
  final String? helper;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextCapitalization textCapitalization;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;

  /// Zone de texte sur plusieurs lignes (description) : `minLines` à `maxLines`.
  final int? minLines;
  final int? maxLines;

  /// Filtres de saisie en plus de la longueur maximale (chiffres seulement, par exemple).
  final List<TextInputFormatter> extraFormatters;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final error = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (labelSuffix != null)
                TextSpan(
                  text: ' $labelSuffix',
                  style: TextStyle(fontWeight: FontWeight.w400, color: c.textSecondary),
                ),
            ],
          ),
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
          minLines: minLines,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          inputFormatters: [...extraFormatters, LengthLimitingTextInputFormatter(maxLength)],
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(fontSize: 13.5, fontStyle: FontStyle.italic, color: c.textSecondary),
            enabledBorder: errorText == null
                ? null
                : OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: error),
                  ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(helper!, style: TextStyle(fontSize: 11, height: 1.4, color: c.textSecondary)),
        ],
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 16, color: error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    errorText!,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
