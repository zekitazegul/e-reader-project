import 'dart:convert';
import 'dart:typed_data';

import 'package:e_reader/book_history.dart';
import 'package:e_reader/books.dart';
import 'package:e_reader/library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'library_view_test.dart' show LiveBookStore;

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test(
    'Pre-upgrade books preserve offset-sensitive text; new imports are cleaned',
    () async {
      final oldBook = BookFile('old.epub', Uint8List.fromList([8]));
      final newBook = BookFile('new.epub', Uint8List.fromList([9]));
      await SharedPreferencesAsync().setString(
        'library.history.v1',
        jsonEncode({
          bookFingerprint(oldBook.bytes): {'added': 1, 'read': 2},
        }),
      );
      final history = BookHistory();
      await history.register([oldBook, newBook]);
      expect(history.shouldClean(oldBook), isFalse);
      expect(history.shouldClean(newBook), isTrue);
      final reopened = BookHistory();
      await reopened.register([oldBook, newBook]);
      expect(reopened.shouldClean(oldBook), isFalse);
      expect(reopened.shouldClean(newBook), isTrue);
    },
  );
  test('Added and last-read dates survive reopening and scans', () async {
    var now = DateTime(2026, 10, 26);
    final history = BookHistory(now: () => now);
    final first = BookFile('Alpha.epub', Uint8List.fromList([1]));
    final second = BookFile('Zulu.epub', Uint8List.fromList([2]));
    await history.register([first]);
    expect(history.shouldClean(first), isTrue);
    now = now.add(const Duration(seconds: 1));
    await history.register([first, second]);
    expect(history.added(second), greaterThan(history.added(first)));
    now = now.add(const Duration(seconds: 1));
    await history.markRead(first);
    expect(history.read(first), greaterThan(history.read(second)));
    final restored = BookHistory();
    await restored.register([first, second]);
    expect(restored.read(first), history.read(first));
    expect(restored.added(first), history.added(first));
  });
  testWidgets('Default is last read; alphabetical and added sorting persist', (
    tester,
  ) async {
    final store = LiveBookStore();
    store.entries
      ..clear()
      ..addAll([
        BookFile('Alpha.epub', Uint8List.fromList([1])),
        BookFile('Zulu.epub', Uint8List.fromList([2])),
      ]);
    final prefs = SharedPreferencesAsync();
    await prefs.setBool('library.grid.v1', false);
    await prefs.setString(
      'library.history.v1',
      jsonEncode({
        bookFingerprint(store.entries[0].bytes): {'added': 20, 'read': 0},
        bookFingerprint(store.entries[1].bytes): {'added': 10, 'read': 30},
      }),
    );
    Widget app() => MaterialApp(home: LibraryPage(store: store));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    double y(String name) =>
        tester.getCenter(find.byKey(ValueKey('library-row-$name.epub'))).dy;
    expect(y('Zulu'), lessThan(y('Alpha')));
    await tester.tap(find.byKey(const ValueKey('library-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alfabetik'));
    await tester.pumpAndSettle();
    expect(y('Alpha'), lessThan(y('Zulu')));
    expect(await prefs.getString('library.sort.v1'), 'alphabetical');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(y('Alpha'), lessThan(y('Zulu')));
    await tester.tap(find.byKey(const ValueKey('library-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Son eklenen'));
    await tester.pumpAndSettle();
    expect(y('Alpha'), lessThan(y('Zulu')));
    expect(await prefs.getString('library.sort.v1'), 'added');
    await tester.pumpWidget(const SizedBox());
    await store.notifications.close();
  });
}
