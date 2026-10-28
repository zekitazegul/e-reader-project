import 'dart:collection';

import 'package:e_reader/books.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/paged_book.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TrackedParagraphs extends ListBase<String> {
  TrackedParagraphs(this.values);
  final List<String> values;
  int reads = 0;
  @override
  int get length => values.length;
  @override
  set length(int value) => values.length = value;
  @override
  String operator [](int index) {
    reads++;
    return values[index];
  }

  @override
  void operator []=(int index, String value) => values[index] = value;
}

void main() {
  testWidgets('Page changes and paper themes reuse the prepared book text', (
    tester,
  ) async {
    final paragraphs = TrackedParagraphs(
      List.filled(
        50,
        'Bir kitap yeni dünyalara açılır. Her sayfada yeni bir yol başlar.',
      ),
    );
    final book = BookContent('Uzun kitap', paragraphs);
    Widget reader(PaperTheme paper) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PagedBook(
            book: book,
            paper: paper,
            font: 'Lora',
            fontSize: 20,
          ),
        ),
      ),
    );
    await tester.pumpWidget(reader(PaperTheme.ivory));
    await tester.pumpAndSettle();
    final reads = paragraphs.reads;
    expect(reads, greaterThan(0));
    await tester.ensureVisible(find.byTooltip('Sonraki sayfa'));
    await tester.tap(find.byTooltip('Sonraki sayfa'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 / '), findsOneWidget);
    await tester.pumpWidget(reader(PaperTheme.night));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 / '), findsOneWidget);
    expect(paragraphs.reads, reads);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Font, viewport and book changes invalidate cached pages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final book = BookContent(
      'Uzun kitap',
      List.filled(
        50,
        'Bir kitap yeni dünyalara açılır. Her sayfada yeni bir yol başlar.',
      ),
    );
    Widget reader(BookContent content, double size) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PagedBook(
            book: content,
            paper: PaperTheme.ivory,
            font: 'Lora',
            fontSize: size,
          ),
        ),
      ),
    );
    String pageLabel() =>
        tester.widget<Text>(find.textContaining(RegExp(r'^\d+ / \d+$'))).data!;
    await tester.pumpWidget(reader(book, 16));
    await tester.pumpAndSettle();
    final initialCount = int.parse(pageLabel().split(' / ').last);
    await tester.pumpWidget(reader(book, 32));
    await tester.pumpAndSettle();
    final largerFontCount = int.parse(pageLabel().split(' / ').last);
    expect(largerFontCount, greaterThan(initialCount));
    tester.view.physicalSize = const Size(400, 900);
    await tester.pumpAndSettle();
    expect(
      int.parse(pageLabel().split(' / ').last),
      greaterThan(largerFontCount),
    );
    await tester.pumpWidget(
      reader(
        const BookContent('Yeni kitap', ['Kısa ve farklı bir metin.']),
        20,
      ),
    );
    await tester.pumpAndSettle();
    expect(pageLabel(), '1 / 1');
    expect(find.text('Kısa ve farklı bir metin.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
