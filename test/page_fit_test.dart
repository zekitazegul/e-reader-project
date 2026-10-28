import 'package:e_reader/books.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/paged_book.dart';
import 'package:e_reader/reader_selectable_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final columns in [1, 2, 3, 4]) {
    testWidgets('$columns columns retain every word inside the page', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await (FontLoader(
        'Lora',
      )..addFont(rootBundle.load('assets/fonts/Lora.ttf'))).load();
      final text = List.generate(
        30,
        (i) =>
            'Paragraf $i: Bir kitap yeni dunyalara acilir. Her sayfada okunacak kelimeler ve uzun cumleler bulunur. ' *
            5,
      ).join('\n\n');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: DefaultTextStyle.merge(
                style: const TextStyle(letterSpacing: 1.2),
                child: PagedBook(
                  book: BookContent('Test', [text]),
                  paper: PaperTheme.ivory,
                  font: 'Lora',
                  fontSize: 30,
                  controlsVisible: false,
                  layout: [
                    'single',
                    'double',
                    'triple',
                    'quadruple',
                  ][columns - 1],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Background pagination deliberately yields between batches, even when
      // there is no animation keeping pumpAndSettle active.
      for (var frame = 0; frame < 100; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final pageView = tester.widget<PageView>(find.byType(PageView));
      final count = pageView.childrenDelegate.estimatedChildCount!;
      final collected = <String>[];
      for (var group = 0; group < count; group++) {
        pageView.controller!.jumpToPage(group);
        await tester.pumpAndSettle();
        for (var column = 0; column < columns; column++) {
          final page = find.byKey(
            ValueKey('reading-page-${group * columns + column}'),
          );
          if (page.evaluate().isEmpty) continue;
          final texts = find.descendant(
            of: page,
            matching: find.byType(EditableText),
          );
          final paragraph = tester.state<EditableTextState>(texts.first).renderEditable;
          final painter = TextPainter(
            text: paragraph.text,
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler,
            textHeightBehavior: paragraph.textHeightBehavior,
          )..layout(maxWidth: paragraph.constraints.maxWidth);
          expect(
            painter.height,
            lessThanOrEqualTo(tester.getSize(page).height - 18),
          );
          collected.add(tester.widget<ReaderSelectableText>(find.descendant(of: page,
            matching: find.byType(ReaderSelectableText))).span.toPlainText());
          painter.dispose();
        }
      }
      expect(collected.join(), text);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
