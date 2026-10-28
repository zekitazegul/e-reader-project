import 'dart:typed_data';

import 'package:e_reader/book_history.dart';
import 'package:e_reader/books.dart';
import 'package:e_reader/library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'library_view_test.dart' show LiveBookStore;

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );

  test('Upper-shelf choice survives restart and filename changes', () async {
    final book = BookFile('Original.pdf', Uint8List.fromList([1, 2, 3]));
    final first = BookHistory();
    await first.register([book]);
    await first.setFavorite(book, true);
    final renamed = BookFile('Renamed.pdf', book.bytes);
    final second = BookHistory();
    await second.register([renamed]);
    expect(second.isFavorite(renamed), isTrue);
    await second.setFavorite(renamed, false);
    final third = BookHistory();
    await third.register([book]);
    expect(third.isFavorite(book), isFalse);
  });

  testWidgets('Long press pins to upper shelf and can unpin after restart', (
    tester,
  ) async {
    final store = LiveBookStore();
    addTearDown(store.notifications.close);
    store.entries
      ..clear()
      ..addAll([
        BookFile('Alpha.pdf', Uint8List.fromList([1])),
        BookFile('Zulu.pdf', Uint8List.fromList([2])),
      ]);
    Widget app() => MaterialApp(home: LibraryPage(store: store));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final first = find.byKey(const ValueKey('library-cover-Alpha.pdf'));
    final favorite = find.byKey(const ValueKey('library-cover-Zulu.pdf'));
    final upperSlot = tester.getRect(first);
    await tester.tap(find.byKey(const ValueKey('book-options-Zulu.pdf')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Üst rafa koy'));
    await tester.pumpAndSettle();
    expect(tester.getRect(favorite), upperSlot);
    expect(find.byTooltip('Üst rafta'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(tester.getRect(favorite), upperSlot);
    await tester.tap(find.byKey(const ValueKey('book-options-Zulu.pdf')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Üst raftan çıkar'));
    await tester.pumpAndSettle();
    expect(tester.getRect(first), upperSlot);
    expect(find.byTooltip('Üst rafta'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
