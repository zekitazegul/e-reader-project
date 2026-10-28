import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'text_direction.dart';
import 'app_language.dart';

/// A cloth-bound volume with a spine groove and a visible page block.
class LibraryBookCover extends StatelessWidget {
  const LibraryBookCover({
    super.key,
    required this.title,
    required this.format,
    required this.color,
    this.requiresConversion = false,
    this.imageBytes,
  });
  final String title;
  final String format;
  final Color color;
  final bool requiresConversion;
  final Uint8List? imageBytes;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        left: 7,
        top: 5,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE9E1CF),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFC5BAA1)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 7,
                offset: Offset(3, 4),
              ),
            ],
          ),
        ),
      ),
      for (var edge = 1; edge <= 3; edge++)
        Positioned(
          right: edge.toDouble(),
          top: 9,
          bottom: 5,
          child: const SizedBox(
            width: 1,
            child: ColoredBox(color: Color(0xFFCEC4AE)),
          ),
        ),
      Positioned.fill(
        right: 5,
        bottom: 5,
        child: imageBytes == null
            ? paintedCover(context)
            : ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.memory(
                  imageBytes!,
                  cacheWidth: 512,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => paintedCover(context),
                ),
              ),
      ),
    ],
  );

  Widget paintedCover(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(3),
        bottomLeft: Radius.circular(3),
        topRight: Radius.circular(6),
        bottomRight: Radius.circular(6),
      ),
      gradient: LinearGradient(
        colors: [
          Color.lerp(color, Colors.black, .28)!,
          color,
          Color.lerp(color, Colors.white, .14)!,
          Color.lerp(color, Colors.black, .16)!,
          color,
        ],
        stops: const [0, .035, .065, .085, .13],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x24000000),
          blurRadius: 2,
          offset: Offset(1, 1),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(15, 14, 7, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0x55E7D7B6)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 22,
              color: Color(0xFFE7D7B6),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final style = DefaultTextStyle.of(context).style.merge(
                    const TextStyle(
                      fontFamily: 'Lora',
                      color: Color(0xFFFFF6DF),
                      fontSize: 16,
                      height: 1.3,
                    ),
                  );
                  final scaler = MediaQuery.textScalerOf(context);
                  final direction = directionForText(title);
                  var layoutWidth = constraints.maxWidth;
                  final measure = TextPainter(
                    textDirection: direction,
                    textScaler: scaler,
                  );
                  for (final word in title.split(RegExp(r'\s+'))) {
                    measure.text = TextSpan(text: word, style: style);
                    measure.layout();
                    layoutWidth = math.max(layoutWidth, measure.width + 2);
                  }
                  measure.dispose();
                  // Lay out wide enough for every complete word first.
                  // Fit the complete title to the cover afterwards.
                  return FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: layoutWidth,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        textDirection: direction,
                        softWrap: true,
                        style: style,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 24,
              height: 1,
              child: ColoredBox(color: Color(0x88E7D7B6)),
            ),
            if (requiresConversion)
              const AppText(
                'Dönüşüm gerekli',
                style: TextStyle(color: Color(0xFFE7D7B6), fontSize: 9),
              ),
          ],
        ),
      ),
    ),
  );
}
