import 'package:flutter/material.dart';

/// Cadre à bordure en tirets (zones « Ajouter une photo », encart du Profil…).
/// Flutter n'en propose pas : on trace le contour arrondi tronçon par tronçon.
class DashedBorderBox extends StatelessWidget {
  const DashedBorderBox({
    super.key,
    required this.child,
    required this.color,
    this.background,
    this.radius = 12,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Color color;
  final Color? background;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(color: color, background: background, radius: radius),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter({required this.color, required this.background, required this.radius});

  final Color color;
  final Color? background;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(0.5),
      Radius.circular(radius),
    );
    final bg = background;
    if (bg != null) canvas.drawRRect(rrect, Paint()..color = bg);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
        distance += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.color != color || old.background != background || old.radius != radius;
}
