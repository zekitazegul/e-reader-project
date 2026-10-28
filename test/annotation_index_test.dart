import 'dart:typed_data';

import 'package:e_reader/annotation_index_page.dart';
import 'package:e_reader/annotation_store.dart';
import 'package:e_reader/books.dart';
import 'package:e_reader/library.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/paged_book.dart';
import 'package:e_reader/reading_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets(
    'Notes and underlines open their exact text and refresh after editing',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final book = BookFile('Marked.epub', Uint8List.fromList([1, 2, 3]));
      final id = bookFingerprint(book.bytes);
      final store = AnnotationStore();
      await store.save(id, const [
        BookAnnotation(
          id: 'underline',
          start: 50,
          end: 60,
          quote: 'underlined',
        ),
        BookAnnotation(
          id: 'note',
          start: 100,
          end: 105,
          quote: 'noted',
          note: 'My thought',
        ),
      ]);
      await DeviceReadingStore().savePosition(id, 5);
      int? opened;
      late BuildContext host;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              host = context;
              return AnnotationIndexPage(
                books: [book, book],
                openBook: (selected, offset) async {
                  opened = offset;
                  await Navigator.of(host).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReaderPage(
                        book: BookContent('Marked', [
                          List.filled(100, 'A gypsy enjoys reading.').join(' '),
                        ]),
                        bookId: id,
                        initialOffset: offset,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
      for (
        var attempt = 0;
        attempt < 40 && find.text('underlined').evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('underlined'), findsOneWidget);
      expect(find.text('My thought'), findsOneWidget);
      await tester.tap(find.text('My thought'));
      await tester.pumpAndSettle();
      expect(opened, 100);
      expect(
        tester.widget<PagedBook>(find.byType(PagedBook)).initialOffset,
        100,
      );
      await store.save(id, const []);
      Navigator.of(host).pop();
      for (
        var attempt = 0;
        attempt < 40 &&
            find
                .text('Henüz altı çizilen metin veya not yok.')
                .evaluate()
                .isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(find.text('underlined'), findsNothing);
      expect(
        find.text('Henüz altı çizilen metin veya not yok.'),
        findsOneWidget,
      );
    },
  );
}
