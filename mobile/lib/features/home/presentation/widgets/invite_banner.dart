// Encart « Aidez NetBuis à grandir » (fermable) avec le bouton « Inviter »
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';

class InviteBanner extends StatelessWidget {
  const InviteBanner({super.key, required this.onInvite, required this.onClose});

  final VoidCallback onInvite;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 4, 10),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
            child: const Icon(Icons.favorite_border, size: 20, color: AppColors.onAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.t('home.promo.title'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(l10n.t('home.promo.body'),
                    style: TextStyle(fontSize: 12, height: 1.35, color: c.textSecondary)),
                TextButton(
                  key: const Key('home-invite'),
                  onPressed: onInvite,
                  style: TextButton.styleFrom(
                    foregroundColor: c.accentText,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 44),
                    alignment: Alignment.centerLeft,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.t('home.promo.invite'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('home-promo-close'),
            tooltip: l10n.t('home.promo.close'),
            onPressed: onClose,
            icon: Icon(Icons.close, size: 18, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
