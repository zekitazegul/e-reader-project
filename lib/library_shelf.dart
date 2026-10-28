import 'package:flutter/material.dart';

/// Paint once behind the grid so each row rests on one continuous shelf.
class LibraryShelfPainter extends CustomPainter {
  const LibraryShelfPainter({
    required this.columns,
    required this.bookCount,
    this.columnGap = 14,
    this.rowGap = 32,
    this.bookRatio = .70,
  });
  final int columns;
  final int bookCount;
  final double columnGap;
  final double rowGap;
  final double bookRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final bookWidth = (size.width - (columns - 1) * columnGap) / columns;
    final bookHeight = bookWidth / bookRatio;
    final rows = (bookCount / columns).ceil();
    for (var row = 0; row < rows; row++) {
      final y = bookHeight + row * (bookHeight + rowGap) - 1;
      final front = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, y + 3, size.width, 11),
        const Radius.circular(2),
      );
      canvas.drawRRect(
        front.shift(const Offset(0, 4)),
        Paint()
          ..color = const Color(0x28000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawPath(
        Path()
          ..moveTo(5, y - 2)
          ..lineTo(size.width - 5, y - 2)
          ..lineTo(size.width, y + 4)
          ..lineTo(0, y + 4)
          ..close(),
        Paint()..color = const Color(0xFFCFAB7D),
      );
      canvas.drawRRect(
        front,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFB18A5F), Color(0xFF8C6444)],
          ).createShader(front.outerRect),
      );
      canvas.drawLine(
        Offset(2, y + 4),
        Offset(size.width - 2, y + 4),
        Paint()
          ..color = const Color(0x88E8C899)
          ..strokeWidth = 1,
      );
      for (var grain = 0; grain < 2; grain++) {
        canvas.drawLine(
          Offset(12 + grain * 14, y + 8 + grain * 3),
          Offset(size.width - 16 - grain * 7, y + 8 + grain * 3),
          Paint()
            ..color = const Color(0x22815935)
            ..strokeWidth = .7,
        );
      }
    }
  }

  @override
  bool shouldRepaint(LibraryShelfPainter oldDelegate) =>
      columns != oldDelegate.columns ||
      bookCount != oldDelegate.bookCount ||
      columnGap != oldDelegate.columnGap ||
      rowGap != oldDelegate.rowGap ||
      bookRatio != oldDelegate.bookRatio;
}
