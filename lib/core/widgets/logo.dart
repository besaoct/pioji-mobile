import 'package:flutter/material.dart';

import '../design/context_ext.dart';

/// The tea-leaf mark, drawn from two arcs. It stands on its own in the
/// accent colour; never on a coloured tile.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pioji',
      image: true,
      child: CustomPaint(size: Size.square(size), painter: _LeafPainter(context.colors.accent)),
    );
  }
}

class _LeafPainter extends CustomPainter {
  _LeafPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 56;
    canvas.scale(s);
    final main = Path()
      ..moveTo(28, 6)
      ..cubicTo(14, 14, 10, 30, 18, 44)
      ..cubicTo(24, 42, 29, 38, 32, 32)
      ..cubicTo(36, 22, 34, 12, 28, 6)
      ..close();
    final side = Path()
      ..moveTo(30, 50)
      ..cubicTo(40, 46, 48, 36, 46, 22)
      ..cubicTo(40, 24, 35, 29, 32, 36)
      ..cubicTo(30, 41, 30, 45, 30, 50)
      ..close();
    canvas.drawPath(main, Paint()..color = color);
    canvas.drawPath(side, Paint()..color = color.withValues(alpha: 0.55));
  }

  @override
  bool shouldRepaint(_LeafPainter old) => old.color != color;
}
