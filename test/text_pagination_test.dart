import 'package:e_reader/books.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/paged_book.dart';
import 'package:e_reader/text_pagination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Line-based pages preserve text and fit Latin, Cyrillic and Arabic content',
    () {
      const style = TextStyle(fontSize: 20, height: 1.75);
      for (final direction in TextDirection.values) {
        final text = List.filled(
          100,
          'İstanbul 😀 yeni bir dünya. Привет мир. مرحبًا بالعالم.\n\n',
        ).join();
        final pages = paginateText(
          text: text,
          width: 400,
          height: 550,
          style: style,
          scaler: TextScaler.noScaling,
          direction: direction,
        ).toList();
        expect(pages.length, greaterThan(1));
        expect(pages.join(), text);
        for (final page in pages) {
          expect(page.isNotEmpty, isTrue);
          expect(
            page.codeUnitAt(page.length - 1),
            isNot(inInclusiveRange(0xD800, 0xDBFF)),
          );
          final painter = TextPainter(
            text: TextSpan(text: page.trimRight(), style: style),
            textDirection: direction,
          )..layout(maxWidth: 400);
          expect(painter.height, lessThanOrEqualTo(550.01));
          painter.dispose();
        }
      }
    },
  );

  test(
    'Empty text and tiny viewports terminate without losing Unicode pairs',
    () {
      List<String> pages(String text) => paginateText(
        text: text,
        width: 1,
        height: 1,
        style: const TextStyle(fontSize: 20),
        scaler: TextScaler.noScaling,
        direction: TextDirection.ltr,
      ).toList();
      expect(pages(''), ['']);
      expect(pages('😀a😀').join(), '😀a😀');
      expect(pages('😀a😀'), ['😀', 'a', '😀']);
    },
  );

  testWidgets('Large-book pagination paints loading UI and can be cancelled', (
    tester,
  ) async {
    final book = BookContent(
      'Büyük kitap',
      List.filled(
        25000,
        'Bir kitap yeni dünyalara açılır. Her sayfada yeni bir yol başlar.',
      ),
    );
    var open = true;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, update) => Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  tooltip: 'Kapat',
                  onPressed: () => update(() => open = false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            body: open
                ? PagedBook(
                    book: book,
                    paper: PaperTheme.ivory,
                    font: 'Lora',
                    fontSize: 20,
                  )
                : const Text('Kapandı'),
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Kapandı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'A new book cancels in-flight pages instead of publishing stale text',
    (tester) async {
      Widget reader(BookContent book) => MaterialApp(
        home: Scaffold(
          body: PagedBook(
            book: book,
            paper: PaperTheme.ivory,
            font: 'Lora',
            fontSize: 20,
          ),
        ),
      );
      await tester.pumpWidget(
        reader(
          BookContent('Eski', List.filled(25000, 'Uzun eski kitap metni.')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(PageView), findsOneWidget);
      await tester.pumpWidget(
        reader(const BookContent('Yeni', ['Yeni kitabın metni.'])),
      );
      await tester.pumpAndSettle();
      expect(find.text('Yeni kitabın metni.'), findsOneWidget);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Saved position and page turns work before the full index finishes',
    (tester) async {
      final paragraphs = [
        ...List.filled(20000, 'Önceki uzun bölümün metni.'),
        'Özel başlangıç cümlesi.',
        ...List.filled(500, 'Okumaya hemen devam edebilirim.'),
      ];
      final text = paragraphs.join('\n\n');
      final anchor = text.indexOf('Özel başlangıç');
      var saved = anchor;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PagedBook(
              book: BookContent('Uzun', paragraphs),
              initialOffset: anchor,
              onPositionChanged: (offset) => saved = offset,
              paper: PaperTheme.ivory,
              font: 'Lora',
              fontSize: 20,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.textContaining('Özel başlangıç'), findsWidgets);
      expect(find.text('Yükleniyor'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(saved, greaterThan(anchor));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byTooltip('Önceki sayfa'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(saved, lessThan(anchor));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Returning to a cached font layout does not restart preparation',
    (tester) async {
      final book = BookContent(
        'Kitap',
        List.filled(100, 'Okumak için beklemek gerekmiyor.'),
      );
      Widget reader(double size) => MaterialApp(
        home: Scaffold(
          body: PagedBook(
            book: book,
            paper: PaperTheme.ivory,
            font: 'Lora',
            fontSize: size,
          ),
        ),
      );
      await tester.pumpWidget(reader(20));
      await tester.pumpAndSettle();
      await tester.pumpWidget(reader(24));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      await tester.pumpWidget(reader(20));
      expect(find.text('Yükleniyor'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(PageView), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
