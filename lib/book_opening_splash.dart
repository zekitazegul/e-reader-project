import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// A single live home page grows out of the opening book; no screenshot or
/// duplicate Navigator is needed, so library loading continues behind the scene.
class BookOpeningSplash extends StatefulWidget {
  const BookOpeningSplash({super.key, required this.child});
  final Widget child;
  @override
  State<BookOpeningSplash> createState() => _BookOpeningSplashState();
}

class _BookOpeningSplashState extends State<BookOpeningSplash>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = 1;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.forward();
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      return AnimatedBuilder(
        animation: controller,
        child: widget.child,
        builder: (context, child) {
          final t = controller.value;
          final reveal = _phase(t, .67, 1);
          final width = math.min(size.width * .37, size.height * .28);
          final page = Rect.fromCenter(
            center: Offset(size.width / 2 + width / 2, size.height * .46),
            width: width,
            height: width * 1.45,
          );
          final rect = Rect.lerp(page, Offset.zero & size, reveal)!;
          return AbsorbPointer(
            absorbing: t < 1,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (t < 1)
                  const Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _BookScene(0, backgroundOnly: true),
                      ),
                    ),
                  ),
                if (t < 1)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 1 - _phase(t, .75, .98),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          key: const ValueKey('opening-red-book'),
                          painter: _BookScene(t),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  key: const ValueKey('opening-home'),
                  child: Opacity(
                    opacity: _phase(t, .64, .76),
                    child: Transform(
                      alignment: Alignment.topLeft,
                      transform: Matrix4.identity()
                        ..translateByDouble(rect.left, rect.top, 0, 1)
                        ..scaleByDouble(
                          rect.width / size.width,
                          rect.height / size.height,
                          1,
                          1,
                        ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8 * (1 - reveal)),
                        child: RepaintBoundary(child: child),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

double _phase(double t, double start, double end) =>
    Curves.easeInOutCubic.transform(((t - start) / (end - start)).clamp(0, 1));

class _BookScene extends CustomPainter {
  const _BookScene(this.t, {this.backgroundOnly = false});
  final double t;
  final bool backgroundOnly;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final pull = _phase(t, .08, .43);
    final open = _phase(t, .40, .73);
    final w = math.min(size.width * .37, size.height * .28);
    final h = w * 1.45;
    final shelfY = size.height * .46 + h * .52;
    if (backgroundOnly) {
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0, -.15),
            radius: 1.1,
            colors: [Color(0xFF534039), Color(0xFF191719)],
          ).createShader(bounds),
      );
      // Books behind the hero, with shaded spines and gilded bands.
      for (var i = -6; i <= 6; i++) {
        if (i == 0) continue;
        final bw = w * .24;
        final bh = h * (.81 + (i.abs() % 3) * .07);
        final x = size.width / 2 + i * bw - bw / 2;
        final r = Rect.fromLTWH(x, shelfY - bh, bw - 3, bh);
        final color = [
          const Color(0xFF304E47),
          const Color(0xFF73522F),
          const Color(0xFF343F59),
        ][i.abs() % 3];
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(3)),
          Paint()
            ..shader = LinearGradient(
              colors: [
                Color.lerp(color, Colors.black, .5)!,
                color,
                Color.lerp(color, Colors.black, .35)!,
              ],
            ).createShader(r),
        );
        for (final fraction in [.1, .15, .82, .87]) {
          canvas.drawLine(
            Offset(x + 4, r.top + bh * fraction),
            Offset(r.right - 4, r.top + bh * fraction),
            Paint()
              ..color = const Color(0xFFB79861).withValues(alpha: .55)
              ..strokeWidth = 1.5,
          );
        }
      }
      final shelf = Rect.fromLTWH(0, shelfY, size.width, 19);
      canvas.drawShadow(Path()..addRect(shelf), Colors.black, 14, false);
      canvas.drawRect(
        shelf,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFA4764F), Color(0xFF493021)],
          ).createShader(shelf),
      );
      return;
    }
    // The shadow separates from the shelf as the book moves toward the viewer.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width / 2, shelfY + 6),
        width: w * (1 + pull),
        height: 12 + pull * 15,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: .4 * (1 - pull * .55))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    final scale = lerpDouble(.72, 1, pull)!;
    final origin = Offset(
      size.width / 2 - w * .5 * (1 - open),
      lerpDouble(shelfY - h * .36, size.height * .46, pull)!,
    );
    final yaw = lerpDouble(-1.28, -.035, pull)!;
    final tilt = .1 * math.sin(pull * math.pi);
    Offset project(double x, double y, double z) {
      final rx = x * math.cos(yaw) + z * math.sin(yaw);
      final rz = -x * math.sin(yaw) + z * math.cos(yaw);
      final ry = y * math.cos(tilt) - rz * math.sin(tilt);
      final depth = y * math.sin(tilt) + rz * math.cos(tilt);
      final perspective = 800 / (800 - depth);
      return origin + Offset(rx, ry) * (scale * perspective);
    }

    Path quad(List<Offset> points) => Path()..addPolygon(points, true);
    void panel(double left, double right, double z, Color color) {
      canvas.drawPath(
        quad([
          project(left, -h / 2, z),
          project(right, -h / 2, z),
          project(right, h / 2, z),
          project(left, h / 2, z),
        ]),
        Paint()..color = color,
      );
    }

    // Back cover, visible page-block thickness, and fanned left leaves.
    final back = quad([
      project(-3, -h / 2 - 3, -10),
      project(w + 4, -h / 2 - 3, -10),
      project(w + 4, h / 2 + 3, -10),
      project(-3, h / 2 + 3, -10),
    ]);
    canvas.drawShadow(back, Colors.black, 18 + pull * 8, false);
    canvas.drawPath(back, Paint()..color = const Color(0xFF8F1324));
    for (var layer = 8; layer >= 0; layer--) {
      panel(
        0,
        w - 2,
        -layer.toDouble(),
        layer.isEven ? const Color(0xFFF6E9CF) : const Color(0xFFD7C7AC),
      );
    }
    if (open > 0) {
      panel(-w * open, 0, -1, const Color(0xFFFFF4DD));
      for (var line = 0; line < 11; line++) {
        final y = -h * .34 + line * h * .06;
        canvas.drawLine(
          project(-w * open * .86, y, 0),
          project(-w * open * .12, y, 0),
          Paint()
            ..color = const Color(0xFFD7C8AC)
            ..strokeWidth = 1,
        );
      }
    }
    // A real hinged front cover: its four corners move in perspective.
    final angle = math.pi * open;
    Offset cover(double x, double y) =>
        project(x * math.cos(angle), y, 6 + x * math.sin(angle));
    final coverPath = quad([
      cover(0, -h / 2),
      cover(w, -h / 2),
      cover(w, h / 2),
      cover(0, h / 2),
    ]);
    final coverBounds = coverPath.getBounds();
    canvas.drawPath(
      coverPath,
      Paint()
        ..shader = LinearGradient(
          colors: open < .5
              ? [
                  const Color(0xFF650C18),
                  const Color(0xFFD12B40),
                  const Color(0xFF9A1427),
                ]
              : [
                  const Color(0xFFB39466),
                  const Color(0xFFFFF1D4),
                  const Color(0xFFE1CDA6),
                ],
        ).createShader(coverBounds),
    );
    canvas.drawPath(
      coverPath,
      Paint()
        ..color = const Color(0xFF6A101B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    if (open < .49) {
      final border = quad([
        cover(w * .09, -h * .43),
        cover(w * .91, -h * .43),
        cover(w * .91, h * .43),
        cover(w * .09, h * .43),
      ]);
      canvas.drawPath(
        border,
        Paint()
          ..color = const Color(0xFFEBC571)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      // Gilded book emblem, also projected onto the cover plane.
      for (final side in [-1.0, 1.0]) {
        final emblem = quad([
          cover(w * .5, -h * .08),
          cover(w * (.5 + side * .21), -h * .12),
          cover(w * (.5 + side * .21), h * .09),
          cover(w * .5, h * .13),
        ]);
        canvas.drawPath(emblem, Paint()..color = const Color(0xFFF4D798));
      }
    }
    canvas.drawLine(
      project(0, -h / 2, 7),
      project(0, h / 2, 7),
      Paint()
        ..color = const Color(0xFF6C1321)
        ..strokeWidth = 4,
    );
  }

  @override
  bool shouldRepaint(_BookScene oldDelegate) =>
      oldDelegate.t != t || oldDelegate.backgroundOnly != backgroundOnly;
}
