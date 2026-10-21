// Une offre active : nom, description, prix ou « Sur demande »
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/public_business.dart';

class OfferTile extends StatelessWidget {
  const OfferTile({super.key, required this.offer});

  final PublicOffer offer;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final c = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final price = offer.onRequest
        ? l10n.t('business.detail.onRequest')
        : l10n.t('business.detail.price').replaceAll('{amount}', _amount(offer.priceFcfa!));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(offer.name, style: text.titleSmall),
                if (offer.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(offer.description, style: text.bodySmall),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(price,
              key: const Key('offer-price'),
              style: TextStyle(fontWeight: FontWeight.w700, color: c.accentText)),
        ],
      ),
    );
  }

  /// 18000 -> « 18 000 » (espace insécable fine non utilisée : simple espace).
  static String _amount(int v) {
    final s = v.toString();
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) out.write(' ');
      out.write(s[i]);
    }
    return out.toString();
  }
}
