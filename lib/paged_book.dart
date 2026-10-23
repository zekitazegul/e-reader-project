import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'books.dart';
import 'main.dart';

class PagedBook extends StatefulWidget {
  const PagedBook({
    super.key,
    required this.book,
    required this.paper,
    required this.font,
    required this.fontSize,
    this.initialOffset = 0,
    this.onPositionChanged,
  });
  final int initialOffset;
  final ValueChanged<int>? onPositionChanged;
  final BookContent book;
  final PaperTheme paper;
  final String font;
  final double fontSize;
  @override
  State<PagedBook> createState() => _PagedBookState();
}

class _PagedBookState extends State<PagedBook> {
  late PageController controller;
  bool initialized = false;
  String layoutSignature = '';
  late int textOffset = widget.initialOffset;
  int current = 0;
  @override
  void dispose() {
    if (initialized) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> paginate(
    String text,
    double width,
    double height,
    TextStyle style,
    TextScaler scaler,
  ) {
    final pages = <String>[];
    var start = 0;
    while (start < text.length) {
      var low = 1;
      var high = math.min(text.length - start, 12000);
      var fit = 0;
      while (low <= high) {
        final middle = (low + high) ~/ 2;
        final painter = TextPainter(
          text: TextSpan(
            text: text.substring(start, start + middle),
            style: style,
          ),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout(maxWidth: width);
        final fits = painter.height <= height;
        painter.dispose();
        if (fits) {
          fit = middle;
          low = middle + 1;
        } else {
          high = middle - 1;
        }
      }
      if (fit == 0) {
        fit = 1;
      }
      var end = start + fit;
      if (end < text.length) {
        final space = text.lastIndexOf(RegExp(r'\s'), end - 1);
        if (space > start + fit ~/ 2) {
          end = space + 1;
        }
        if (end > start &&
            text.codeUnitAt(end - 1) >= 0xD800 &&
            text.codeUnitAt(end - 1) <= 0xDBFF) {
          end--;
        }
      }
      if (end <= start) {
        end = math.min(start + 2, text.length);
      }
      pages.add(text.substring(start, end));
      start = end;
    }
    return pages.isEmpty ? [''] : pages;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(constraints.maxWidth, 760.0);
      final height = (MediaQuery.sizeOf(context).height - 170).clamp(
        420.0,
        880.0,
      );
      final padding = width < 450 ? 24.0 : 48.0;
      final style = TextStyle(
        fontFamily: widget.font == 'Sistem' ? null : widget.font,
        fontSize: widget.fontSize,
        height: 1.75,
        color: widget.paper.ink,
      );
      final scaler = MediaQuery.textScalerOf(context);
      final pages = paginate(
        widget.book.paragraphs.join('\n\n'),
        width - padding * 2 - 6,
        height - 120,
        style,
        scaler,
      );
      final starts = <int>[];
      var total = 0;
      for (final page in pages) {
        starts.add(total);
        total += page.length;
      }
      var target = 0;
      for (var i = 0; i < starts.length; i++) {
        if (starts[i] <= textOffset) {
          target = i;
        }
      }
      final signature = '$width-$height-${scaler.scale(widget.fontSize)}';
      if (!initialized) {
        current = target;
        controller = PageController(initialPage: target);
        initialized = true;
        layoutSignature = signature;
      } else if (signature != layoutSignature) {
        layoutSignature = signature;
        current = target;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && controller.hasClients) {
            controller.jumpToPage(target);
          }
        });
      }
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      return Column(
        children: [
          Text(
            widget.book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Lora', fontSize: 20),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: height,
            width: width,
            child: PageView.builder(
              controller: controller,
              itemCount: pages.length,
              onPageChanged: (value) {
                setState(() => current = value);
                textOffset = starts[value];
                widget.onPositionChanged?.call(textOffset);
              },
              itemBuilder: (context, index) => AnimatedBuilder(
                animation: controller,
                builder: (context, child) {
                  final offset =
                      controller.hasClients &&
                          controller.position.hasContentDimensions
                      ? (controller.page ?? 0) - index
                      : 0.0;
                  return Transform(
                    alignment: offset > 0
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(
                        reduceMotion ? 0 : offset.clamp(-1.0, 1.0) * 0.32,
                      ),
                    child: child,
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  color: widget.paper.background,
                  child: CustomPaint(
                    painter: PaperPainter(widget.paper),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padding, 30, padding, 24),
                      child: Column(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(pages[index], style: style),
                            ),
                          ),
                          Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: widget.paper.ink,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Önceki sayfa',
                onPressed: current > 0
                    ? () => controller.previousPage(
                        duration: Duration(
                          milliseconds: reduceMotion ? 1 : 380,
                        ),
                        curve: Curves.easeInOutCubic,
                      )
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${current + 1} / ${pages.length}'),
              IconButton(
                tooltip: 'Sonraki sayfa',
                onPressed: current < pages.length - 1
                    ? () => controller.nextPage(
                        duration: Duration(
                          milliseconds: reduceMotion ? 1 : 380,
                        ),
                        curve: Curves.easeInOutCubic,
                      )
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      );
    },
  );
}
