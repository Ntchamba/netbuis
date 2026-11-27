// Suggestions affichées sous le champ pendant la frappe
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/suggestion.dart';

class SuggestionsList extends StatelessWidget {
  const SuggestionsList({super.key, required this.suggestions, required this.onSelect});

  final List<Suggestion> suggestions;
  final ValueChanged<Suggestion> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Semantics(
      label: l10n.t('search.suggestions.label'),
      container: true,
      child: ListView.separated(
        key: const Key('suggestions-list'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: c.border),
        itemBuilder: (context, i) {
          final s = suggestions[i];
          final isProduct = s.type == SuggestionType.produit;
          return InkWell(
            key: Key('suggestion-$i'),
            onTap: () => onSelect(s),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  Icon(isProduct ? Icons.shopping_basket_outlined : Icons.history,
                      size: 18, color: c.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(s.text,
                        style: TextStyle(fontSize: 15, color: c.textPrimary)),
                  ),
                  Text(
                    l10n.t(isProduct ? 'search.suggestion.product' : 'search.suggestion.search'),
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
