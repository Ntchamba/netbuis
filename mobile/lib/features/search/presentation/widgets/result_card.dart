// Carte d'un résultat : titre, sous-titre, badge Produit/Service, lieu, bouton « Appeler »
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/search_result.dart';

/// Aucun numéro ici : il ne sort que de POST /api/calls/initiate/ (T052).
/// Le bouton « Appeler » n'a pas de prix tant que `CREDITS_ENABLED=False` (D-19).
class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.result, this.onCall});

  final SearchResult result;

  /// Null : bouton visible mais inactif (l'appel est branché par T052).
  final VoidCallback? onCall;

  /// « Repère — Zone », ou l'un des deux, ou vide.
  static String location(SearchResult r) =>
      [r.repere.trim(), r.zone?.name ?? ''].where((s) => s.isNotEmpty).join(' — ');

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final place = location(result);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(result.name, style: text.titleMedium),
                    if (result.descriptionActivite.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(result.descriptionActivite, style: text.bodySmall),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.t(result.kind == 'service' ? 'home.card.service' : 'home.card.product'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary),
                ),
              ),
            ],
          ),
          if (place.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 16, color: c.accentText),
                const SizedBox(width: 6),
                Expanded(child: Text(place, style: TextStyle(fontSize: 13, color: c.accentText))),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onCall,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.call, size: 18),
              label: Semantics(
                label: l10n.t('home.card.callLabel').replaceFirst('{name}', result.name),
                excludeSemantics: true,
                child: Text(l10n.t('home.card.call'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
