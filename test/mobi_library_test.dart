import 'dart:async';
import 'dart:convert';

import 'package:e_reader/book_store.dart';
import 'package:e_reader/books.dart';
import 'package:e_reader/library.dart';
import 'package:e_reader/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'mobi_conversion_test.dart' show mobiFixture;

class MobiStore extends BookStore {
  final entries = [
    BookFile(
      'Sample.mobi',
      mobiFixture([utf8.encode('<p>A book converted automatically.</p>')]),
    ),
  ];
  int added = 0;
  @override
  Stream<void> changes() => const Stream.empty();
  @override
  Future<String> location() async => '/test';
  @override
  Future<List<BookFile>> scan() async => List.of(entries);
  @override
  Future<void> add(BookFile book) async {
    entries.add(book);
    added++;
  }
}

void main() {
  testWidgets(
    'First list tap reveals info; second converts MOBI and opens EPUB once',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await SharedPreferencesAsync().setBool('library.grid.v1', false);
      final store = MobiStore();
      await tester.pumpWidget(MaterialApp(home: LibraryPage(store: store)));
      await tester.pumpAndSettle();
      for (var repeat = 0; repeat < 2; repeat++) {
        final extension = repeat == 0 ? 'mobi' : 'epub';
        final original = find.byKey(ValueKey('library-row-Sample.$extension'));
        await tester.tap(original);
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('library-info-Sample.$extension')),
          findsOneWidget,
        );
        expect(find.byType(ReaderPage), findsNothing);
        await tester.tap(original);
        for (var attempt = 0; attempt < 20; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 50));
          if (find.byType(ReaderPage).evaluate().isNotEmpty) break;
        }
        await tester.pumpAndSettle();
        expect(find.byType(ReaderPage), findsOneWidget);
        expect(
          find.textContaining('A book converted automatically.'),
          findsOneWidget,
        );
        expect(store.added, 1);
        expect(
          store.entries.where((book) => book.extension == 'epub'),
          hasLength(1),
        );
        final context = tester.element(find.byType(ReaderPage));
        Navigator.of(context).pop();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('library-row-Sample.mobi')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('library-row-Sample.epub')),
          findsOneWidget,
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
