import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Shared by report preview and its full category breakdown. Values are never
/// encoded only by color: callers provide a text legend and center total.
class SpendingDonut extends StatelessWidget {
  const SpendingDonut(
      {super.key,
      required this.amounts,
      required this.colors,
      required this.center});
  final List<int> amounts;
  final List<Color> colors;
  final Widget center;
  @override
  Widget build(BuildContext context) => AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
          painter: _Donut(amounts, colors),
          child: Center(
              child:
                  Padding(padding: const EdgeInsets.all(38), child: center))));
}

class _Donut extends CustomPainter {
  _Donut(this.amounts, this.colors);
  final List<int> amounts;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 26.0;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final total = amounts.fold<int>(0, (a, b) => a + b);
    if (total <= 0) {
      canvas.drawArc(
          rect,
          0,
          math.pi * 2,
          false,
          Paint()
            ..color = const Color(0xFFE4ECE8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke);
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < amounts.length; i++) {
      final sweep = math.pi * 2 * amounts[i] / total;
      canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..color = colors[i]
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _Donut old) =>
      old.amounts != amounts || old.colors != colors;
}
