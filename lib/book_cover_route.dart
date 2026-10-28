import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'library_book_cover.dart';

class BookCoverOpening {
  const BookCoverOpening({
    required this.rect,
    required this.title,
    required this.format,
    required this.color,
    this.imageBytes,
  });
  final Rect rect;
  final String title;
  final String format;
  final Color color;
  final Uint8List? imageBytes;
}

TransitionRoute<void> bookReaderRoute(
  Widget reader, {
  BookCoverOpening? cover,
  bool reduceMotion = false,
  bool animationsEnabled = true,
}) {
  if (!animationsEnabled) {
    return PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => reader,
    );
  }
  if (cover == null || reduceMotion) {
    return MaterialPageRoute<void>(builder: (_) => reader);
  }
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 1200),
    reverseTransitionDuration: const Duration(milliseconds: 1200),
    pageBuilder: (_, _, _) => reader,
    transitionsBuilder: (context, animation, secondary, child) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final height = math.min(size.height * .82, size.width * .84 / .70);
          final width = height * .70;
          final target = Rect.fromCenter(
            center: size.center(Offset.zero),
            width: width,
            height: height,
          );
          final jacket = RepaintBoundary(
            child: SizedBox(
              width: width,
              height: height,
              child: LibraryBookCover(
                title: cover.title,
                format: cover.format,
                color: cover.color,
                imageBytes: cover.imageBytes,
              ),
            ),
          );
          return AnimatedBuilder(
            animation: animation,
            child: jacket,
            builder: (context, jacket) {
              final t = animation.value;
              if (t >= 1) return child;
              final grow = Curves.easeOutCubic.transform((t / .38).clamp(0, 1));
              final rect = Rect.lerp(cover.rect, target, grow)!;
              final open = Curves.easeInOutCubic.transform(
                ((t - .28) / .48).clamp(0, 1),
              );
              final expand = Curves.easeInOutCubic.transform(
                ((t - .72) / .28).clamp(0, 1),
              );
              final pageRect = Rect.lerp(rect, Offset.zero & size, expand)!;
              final coverFade =
                  1 - Curves.easeIn.transform(((t - .72) / .14).clamp(0, 1));
              return AbsorbPointer(
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Keep the live reader at its final layout size so that
                    // growing the page never repaginates the saved position.
                    Positioned.fill(
                      child: Transform(
                        alignment: Alignment.topLeft,
                        transform: Matrix4.identity()
                          ..translateByDouble(pageRect.left, pageRect.top, 0, 1)
                          ..scaleByDouble(
                            pageRect.width / size.width,
                            pageRect.height / size.height,
                            1,
                            1,
                          ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5 * (1 - expand)),
                          child: child,
                        ),
                      ),
                    ),
                    if (coverFade > 0)
                      Positioned.fromRect(
                        rect: rect,
                        child: Opacity(
                          opacity: coverFade,
                          child: Transform(
                            key: const ValueKey('book-opening-hinge'),
                            alignment: Alignment.centerLeft,
                            // Positive Y brings the right edge toward the
                            // reader before it swings left around the spine.
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, .0015)
                              ..rotateY(math.pi * open),
                            child: open < .5
                                ? FittedBox(child: jacket)
                                : DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF3E7CF),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: cover.color,
                                        width: 3,
                                      ),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFE1D0AE),
                                          Color(0xFFFFF4DE),
                                        ],
                                      ),
                                    ),
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
    },
  );
}
