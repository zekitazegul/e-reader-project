import 'package:e_reader/books.dart';
import 'package:e_reader/library.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/sample_book.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'books_test.dart' show zip;
import 'library_view_test.dart' show LiveBookStore;

void main() {
  testWidgets(
    'Book leaves an empty slot and fills the same slot after closing',
    (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final store = LiveBookStore();
      final sample = await loadSampleBook();
      addTearDown(store.notifications.close);
      store.entries
        ..clear()
        ..addAll([
          for (final name in ['A', 'C', 'D'])
            BookFile(
              '$name.docx',
              zip({
                'word/document.xml':
                    '<document><p><t>Reading $name.</t></p></document>',
              }),
            ),
          sample,
        ]);
      await tester.pumpWidget(MaterialApp(home: LibraryPage(store: store)));
      await tester.pumpAndSettle();
      final selected = find.byKey(
        const ValueKey('library-cover-$sampleBookName'),
      );
      final neighbor = find.byKey(const ValueKey('library-cover-A.docx'));
      final original = tester.getRect(selected);
      final neighborRect = tester.getRect(neighbor);
      await tester.tap(selected);
      await tester.pump();
      // Decoding must leave the original cover visible until its route exists.
      if (find.byType(ReaderPage).evaluate().isEmpty) {
        expect(selected, findsOneWidget);
        expect(tester.getRect(selected), original);
        expect(
          find.byKey(const ValueKey('library-vacant-$sampleBookName')),
          findsNothing,
        );
      }
      for (var attempt = 0; attempt < 60; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(ReaderPage).evaluate().isNotEmpty) break;
      }
      await tester.pumpAndSettle();
      expect(find.byType(ReaderPage), findsOneWidget);
      final vacant = find.byKey(
        const ValueKey('library-vacant-$sampleBookName'),
        skipOffstage: false,
      );
      expect(vacant, findsOneWidget);
      expect(tester.getRect(vacant), original);
      Navigator.of(tester.element(find.byType(ReaderPage))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(vacant, findsOneWidget);
      expect(tester.getRect(vacant), original);
      await tester.pump(const Duration(milliseconds: 301));
      // No extra settling frame may be needed to restore the shelf cover.
      expect(
        find.byKey(const ValueKey('library-vacant-$sampleBookName')),
        findsNothing,
      );
      expect(tester.getRect(selected), original);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('library-vacant-$sampleBookName')),
        findsNothing,
      );
      expect(tester.getRect(selected), original);
      expect(tester.getRect(neighbor), neighborRect);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
