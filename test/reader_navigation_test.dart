import 'package:e_reader/books.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/paged_book.dart';
import 'package:e_reader/reader_selectable_text.dart';
import 'package:e_reader/reader_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Search respects Turkish casing, literal punctuation and offsets', () {
    expect(findBookMatches('İstanbul ve istanbul. IŞIK ve ışık', 'istanbul'), [
      0,
      12,
    ]);
    expect(findBookMatches('İstanbul ve istanbul. IŞIK ve ışık', 'ışık'), [
      22,
      30,
    ]);
    expect(findBookMatches('a.b a*b a.b', 'a.b'), [0, 8]);
    expect(findBookMatches('metin', '  '), isEmpty);
    expect(findBookMatches('aaaaa', 'a', limit: 2), [0, 1]);
  });

  testWidgets('Search jumps to a matching page and highlights the query', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int saved = 0;
    final readerKey = GlobalKey<PagedBookState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                tooltip: 'Kitap içinde ara',
                icon: const Icon(Icons.search),
                onPressed: () => readerKey.currentState?.searchBook(),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: PagedBook(
              key: readerKey,
              book: BookContent('Kitap', [
                ...List.filled(
                  25,
                  'Bu uzun paragraf sayfalara bölünür. Yeni bir dünyaya açılır.',
                ),
                'İstanbul eşsiz bir şehirdir.',
              ]),
              paper: PaperTheme.ivory,
              font: 'Lora',
              fontSize: 20,
              onPositionChanged: (value) => saved = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Kitap içinde ara'));
    await tester.tap(find.byTooltip('Kitap içinde ara'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'istanbul');
    await tester.tap(find.byTooltip('Metinde ara'));
    await tester.pumpAndSettle();
    expect(find.text('1 eşleşme'), findsOneWidget);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(saved, greaterThan(0));
    expect(find.byType(BookSearchDialog), findsNothing);
    expect(find.byTooltip('Arama vurgusunu temizle'), findsOneWidget);
    final highlighted = tester.widgetList<ReaderSelectableText>(
      find.byType(ReaderSelectableText),
    );
    expect(
      highlighted.any((t) => t.span.toPlainText().contains('İstanbul')),
      isTrue,
    );
    final pageNumber = find.textContaining(RegExp(r'^\d+ / \d+$'));
    await tester.ensureVisible(pageNumber);
    await tester.tap(pageNumber);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ekran sayfasına git'));
    await tester.pumpAndSettle();
    expect(find.text('Ekran sayfasına git'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1');
    await tester.tap(find.text('Git'));
    await tester.pumpAndSettle();
    expect(saved, 0);
    expect(find.textContaining('1 / '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Page jump rejects out of range numbers and accepts valid pages',
    (tester) async {
      int? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => selected = await showDialog<int>(
                  context: context,
                  builder: (_) => const PageNumberDialog(current: 1, total: 7),
                ),
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '8');
      await tester.tap(find.text('Git'));
      await tester.pumpAndSettle();
      expect(find.text('1–7 arasında bir sayfa gir.'), findsOneWidget);
      expect(selected, isNull);
      await tester.enterText(find.byType(TextField), '3');
      await tester.tap(find.text('Git'));
      await tester.pumpAndSettle();
      expect(selected, 3);
      expect(tester.takeException(), isNull);
    },
  );
}
