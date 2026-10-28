import 'dart:math' as math;

import 'package:flutter/painting.dart';

const readingCursorWidth = 2.0;
// RenderEditable reserves cursorWidth + a 1px gap even with a hidden cursor.
const readingCaretMargin = readingCursorWidth + 1.0;

// Preserve the font's natural final descent even with compact line spacing.
// EditableText and pagination must use this exact same vertical typography.
const readingTextHeightBehavior = TextHeightBehavior(
  applyHeightToLastDescent: false,
);

StrutStyle readingStrutStyle(TextStyle style) =>
    StrutStyle.fromTextStyle(style);

/// Measures a small window of text once per page, using the engine's line breaks.
/// Callers can yield between pages to keep the platform event loop responsive.
Iterable<String> paginateText({
  required String text,
  required double width,
  required double height,
  required TextStyle style,
  required TextScaler scaler,
  required TextDirection direction,
}) sync* {
  if (text.isEmpty) {
    yield '';
    return;
  }
  final safeHeight = math.max(1.0, height - 2.0);
  var start = 0;
  var window = 2048;
  while (start < text.length) {
    var length = math.min(window, text.length - start);
    var end = 0;
    while (true) {
      // Avoid ending a measured window in the middle of a UTF-16 pair.
      if (start + length < text.length &&
          text.codeUnitAt(start + length - 1) >= 0xD800 &&
          text.codeUnitAt(start + length - 1) <= 0xDBFF) {
        length++;
      }
      final painter = TextPainter(
        text: TextSpan(
          text: text.substring(start, start + length),
          style: style,
        ),
        textHeightBehavior: readingTextHeightBehavior,
        strutStyle: readingStrutStyle(style),
        textDirection: direction,
        textScaler: scaler,
      );
      try {
        painter.layout(maxWidth: math.max(1, width));
        if (painter.height <= safeHeight) {
          if (start + length == text.length) {
            end = length;
            break;
          }
          // A complete window fits: grow it until we see an actual page break.
          length = math.min(length * 2, text.length - start);
          continue;
        }
        final lineEnds = <int>[];
        for (final line in painter.computeLineMetrics()) {
          if (line.baseline + line.descent > safeHeight + 0.01) break;
          final position = painter.getPositionForOffset(
            Offset(line.left + line.width / 2, line.baseline - line.ascent / 2),
          );
          end = painter.getLineBoundary(position).end;
          lineEnds.add(end);
        }
        // Re-layout the actual prefix: paragraph endings and fallback fonts
        // can change its height compared with lines in the larger window.
        while (lineEnds.isNotEmpty) {
          end = lineEnds.last;
          painter.text = TextSpan(
            text: text.substring(start, start + end),
            style: style,
          );
          painter.layout(maxWidth: math.max(1, width));
          if (painter.height <= safeHeight) break;
          lineEnds.removeLast();
          end = 0;
        }
        break;
      } finally {
        painter.dispose();
      }
    }
    if (end <= 0) {
      // Extremely small viewports must still make progress without splitting pairs.
      final first = text.codeUnitAt(start);
      end = first >= 0xD800 && first <= 0xDBFF && start + 1 < text.length
          ? 2
          : 1;
    }
    end = math.min(end, text.length - start);
    yield text.substring(start, start + end);
    start += end;
    window = (end * 1.4 + 128).ceil().clamp(256, 4096);
  }
}
