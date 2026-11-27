// Champ de saisie de la recherche écrite
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';

class TextSearchField extends StatelessWidget {
  const TextSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return TextField(
      key: const Key('search-field'),
      controller: controller,
      focusNode: focusNode,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(fontSize: 14, color: c.textPrimary),
      decoration: InputDecoration(
        hintText: l10n.t('search.field.hint'),
        hintStyle: TextStyle(fontSize: 14, color: c.textSecondary),
        filled: true,
        fillColor: c.card,
        prefixIcon: Icon(Icons.search, size: 20, color: c.textSecondary),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  key: const Key('search-clear'),
                  tooltip: l10n.t('search.field.clear'),
                  onPressed: onClear,
                  icon: Icon(Icons.close, size: 20, color: c.textSecondary),
                ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
      ),
    );
  }
}
