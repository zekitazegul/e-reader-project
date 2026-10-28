import 'package:e_reader/books.dart';
import 'package:e_reader/book_reference_page.dart';
import 'package:e_reader/book_print_catalog.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/paged_book.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  Widget reader(BookContent book, {double size = 20}) => MaterialApp(
    home: Scaffold(
      body: PagedBook(
        book: book,
        bookId: 'progress-test',
        paper: PaperTheme.ivory,
        font: 'Sistem',
        fontSize: size,
      ),
    ),
  );

  testWidgets(
    'Unknown print pages are labelled screen; manual estimate persists and can be cleared',
    (tester) async {
      const book = BookContent('Beyan', ['Some text to read.']);
      await tester.pumpWidget(reader(book));
      await tester.pumpAndSettle();
      expect(find.text('Ekran'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('book-progress')));
      await tester.pumpAndSettle();
      expect(
        find.text('Bu konum için dosyada basılı sayfa bilgisi yok.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('reference-page-total')),
        '0',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('Geçerli bir toplam sayfa sayısı gir.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('reference-page-total')),
        '300',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('Tahmini kitap'), findsNothing);
      expect(find.text('1/1   1/300'), findsOneWidget);
      expect(
        await SharedPreferencesAsync().getInt(
          'reading.reference-total.v1.progress-test',
        ),
        300,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(reader(book, size: 30));
      await tester.pumpAndSettle();
      expect(find.text('1/1   1/300'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('book-progress')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('reference-page-total')),
        '',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('Ekran'), findsNothing);
      expect(
        await SharedPreferencesAsync().getInt(
          'reading.reference-total.v1.progress-test',
        ),
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Researched edition supplies the total and manual override can be reset',
    (tester) async {
      const book = BookContent(
        'Beyan',
        ['Short text.'],
        printEdition: BookPrintEdition(
          title: 'Beyan',
          pages: 179,
          publisher: 'Nil',
          date: '2004',
          sources: ['https://ci.nii.ac.jp/ncid/BA7687945X'],
        ),
      );
      await tester.pumpWidget(reader(book));
      await tester.pumpAndSettle();
      expect(find.text('1/1   1/179'), findsOneWidget);
      expect(find.text('Ekran'), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsNothing);
      await tester.tap(find.byKey(const ValueKey('book-progress')));
      await tester.pumpAndSettle();
      expect(find.text('Referans baskı'), findsOneWidget);
      expect(find.text('1 kitap sayfası ≈ 0.01 ekran sayfası'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('reference-page-total')),
        '300',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('1/1   1/300'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('book-progress')));
      await tester.pumpAndSettle();
      expect(find.text('Referans baskı'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('reference-page-total')),
        '',
      );
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(find.text('1/1   1/179'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Publisher page marker is shown without inventing a print total',
    (tester) async {
      await tester.pumpWidget(
        reader(
          const BookContent(
            'Book',
            ['Short text.'],
            referencePages: [BookReferencePage(0, 'iv')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kitap'), findsNothing);
      expect(find.text('iv'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('book-progress')));
      await tester.pumpAndSettle();
      expect(find.text('Kitabın sayfa işareti'), findsOneWidget);
      expect(find.byKey(const ValueKey('reference-page-total')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
