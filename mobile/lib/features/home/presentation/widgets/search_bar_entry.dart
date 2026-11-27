// Barre de recherche (ouvre la recherche écrite) + bouton micro séparé
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';

class SearchBarEntry extends StatelessWidget {
  const SearchBarEntry({super.key, required this.onSearch, required this.onVoice});

  /// Point d'entrée de la recherche écrite (T045).
  final VoidCallback onSearch;

  /// Point d'entrée de la recherche vocale (T046).
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: l10n.t('home.search.label'),
            excludeSemantics: true,
            child: Material(
              color: c.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: c.border),
              ),
              child: InkWell(
                key: const Key('home-search'),
                borderRadius: BorderRadius.circular(14),
                onTap: onSearch,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 20, color: c.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.t('home.search.hint'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, color: c.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: l10n.t('home.voice.label'),
          excludeSemantics: true,
          child: Material(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              key: const Key('home-voice'),
              borderRadius: BorderRadius.circular(14),
              onTap: onVoice,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.mic, size: 22, color: AppColors.onAccent),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
