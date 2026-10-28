import 'dart:convert';

import 'package:e_reader/book_titles.dart';
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
    'Previously stored titles remain readable by content identity',
    () async {
      await SharedPreferencesAsync().setString(
        'library.titles.v1',
        jsonEncode({'same-content': 'Existing title'}),
      );
      final titles = BookTitles();
      await titles.load();
      expect(titles.title('same-content'), 'Existing title');
      expect(titles.title('changed-content'), isNull);
    },
  );

  testWidgets('Long press shows book actions with remove below upper shelf', (
    tester,
  ) async {
    final store = LiveBookStore();
    await tester.pumpWidget(MaterialApp(home: LibraryPage(store: store)));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    for (final grid in [true, false]) {
      if (!grid) {
        await tester.tap(find.byKey(const ValueKey('library-list')));
        await tester.pumpAndSettle();
      }
      if (grid) {
        await tester.tap(find.byKey(const ValueKey('book-options-First.epub')));
      } else {
        await tester.longPress(find.text('First'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Kitap bilgileri'), findsOneWidget);
      expect(find.text('Kitaplıktan kaldır'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Kitaplıktan kaldır')).dy,
        greaterThan(tester.getCenter(find.text('Üst rafa koy')).dy),
      );
      expect(find.text('EPUB'), findsWidgets);
      expect(find.text('First.epub'), findsOneWidget);
      expect(find.text('Henüz hesaplanmadı'), findsOneWidget);
      expect(find.text('Kitaplıktan sil'), findsNothing);
      expect(find.text('Kitabı düzenle'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    }
    expect(store.entries, hasLength(1));
    await tester.longPress(find.text('First'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kitaplıktan kaldır'));
    await tester.pumpAndSettle();
    expect(store.entries, isEmpty);
    expect(find.text('First'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await store.notifications.close();
  });
}
