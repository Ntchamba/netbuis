import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Logo-texte : « NET » en couleur de texte + « BUIS » en accent, graisse 800.
class NetBuisLogo extends StatelessWidget {
  const NetBuisLogo({super.key, this.fontSize = 22});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final style = TextStyle(
        fontSize: fontSize, fontWeight: FontWeight.w800, letterSpacing: 0.5);
    return Semantics(
      label: 'NetBuis',
      excludeSemantics: true,
      // Réduit le logo (au lieu de déborder) quand la police du téléphone est très agrandie.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text.rich(
          TextSpan(
            style: style,
            children: [
              TextSpan(text: 'NET', style: TextStyle(color: c.textPrimary)),
              TextSpan(text: 'BUIS', style: TextStyle(color: c.accentText)),
            ],
          ),
        ),
      ),
    );
  }
}
