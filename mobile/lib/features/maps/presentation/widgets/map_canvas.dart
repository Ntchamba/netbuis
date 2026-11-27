// Cadre « carte » schématique : fond quadrillé et repères cliquables placés par positions relatives.
// Aucune carte tierce, aucune tuile : rien n'est téléchargé.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../application/map_layout.dart';

/// Un repère à afficher : étiquette « Nom · n », texte pour lecteur d'écran, action.
class MapPinData {
  const MapPinData({
    required this.keyId,
    required this.label,
    required this.semanticLabel,
    required this.spot,
    required this.onTap,
  });

  final String keyId;
  final String label;
  final String semanticLabel;
  final MapSpot spot;
  final VoidCallback onTap;
}

class MapCanvas extends StatelessWidget {
  const MapCanvas({super.key, required this.pins, this.legend, this.overlay});

  final List<MapPinData> pins;

  /// Légende en bas du cadre.
  final String? legend;

  /// Contenu centré (encart « Pas encore de détail par quartier »).
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mapBg = dark ? const Color(0xFF15151A) : const Color(0xFFEFEFF2);
    final gridLine = dark ? const Color(0xFF22222A) : const Color(0xFFE2E2E6);
    final chipText = dark ? const Color(0xFFC8C8CC) : const Color(0xFF4A4A50);

    return Container(
      key: const Key('map-canvas'),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: mapBg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.5,
                child: CustomPaint(painter: _GridPainter(gridLine)),
              ),
            ),
            for (final pin in pins)
              Positioned(
                left: pin.spot.x * box.maxWidth,
                top: pin.spot.y * box.maxHeight,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -1),
                  child: _Pin(data: pin),
                ),
              ),
            if (overlay != null) Positioned.fill(child: Center(child: overlay)),
            if (legend != null)
              Positioned(
                left: 14,
                bottom: 14,
                right: 14,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: DecoratedBox(
                    key: const Key('map-legend'),
                    decoration: BoxDecoration(
                      color: c.background.withValues(alpha: 0.9),
                      border: Border.all(color: c.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: Text(legend!, style: TextStyle(fontSize: 11, color: chipText)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.color);

  final Color color;
  static const double step = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

class _Pin extends StatelessWidget {
  const _Pin({required this.data});

  final MapPinData data;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: data.semanticLabel,
      excludeSemantics: true,
      onTap: data.onTap,
      child: GestureDetector(
        key: ValueKey('map-pin-${data.keyId}'),
        behavior: HitTestBehavior.opaque,
        onTap: data.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: c.background,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Text(
                    data.label,
                    softWrap: false,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Transform.rotate(
                angle: -0.7853981633974483,
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(13),
                      topRight: Radius.circular(13),
                      bottomRight: Radius.circular(13),
                    ),
                  ),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.onAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
