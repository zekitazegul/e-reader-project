import 'package:flutter/material.dart';

class PageLayoutIcon extends StatelessWidget {
  const PageLayoutIcon({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(30, 24),
    painter: _PageLayoutPainter(
      count,
      IconTheme.of(context).color ?? Colors.black,
    ),
  );
}

class _PageLayoutPainter extends CustomPainter {
  const _PageLayoutPainter(this.count, this.color);
  final int count;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final width = (size.width - (count - 1) * 2) / count;
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < count; i++) {
      final left = i * (width + 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left + 0.6, 1, width - 1.2, 22),
          const Radius.circular(1),
        ),
        pen,
      );
      for (var line = 0; line < 3; line++) {
        canvas.drawLine(
          Offset(left + 2, 7.0 + line * 4),
          Offset(left + width - 2, 7.0 + line * 4),
          pen,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PageLayoutPainter old) =>
      old.count != count || old.color != color;
}
