import 'package:e_reader/bookmark_controls.dart';
import 'package:e_reader/reading_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('Bookmark titles and creation dates survive reopening', () async {
    final date = DateTime.utc(2026, 10, 24, 12, 30);
    await DeviceReadingStore().saveBookmarks('book', [
      ReadingBookmark(offset: 400, title: 'İkinci Lem’a', createdAt: date),
    ]);
    final mark = (await DeviceReadingStore().bookmarks('book')).single;
    expect(mark.offset, 400);
    expect(mark.title, 'İkinci Lem’a');
    expect(mark.createdAt, date);
  });

  test('Legacy positions migrate without inventing creation dates or resurrecting deleted marks', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'reader.bookmarks.v1.old': ['920', '0', '920', 'invalid', '-1'],
        });
    final store = DeviceReadingStore();
    final marks = await store.bookmarks('old');
    expect(marks.map((mark) => mark.offset), [0, 920]);
    expect(marks.every((mark) => mark.createdAt == null), isTrue);
    expect(bookmarkDate(marks.first.createdAt), 'Eklenme tarihi bilinmiyor');
    await store.saveBookmarks('old', []);
    expect(await DeviceReadingStore().bookmarks('old'), isEmpty);
  });

  testWidgets(
    'Bookmark list displays its name and date and jumps to the saved position',
    (tester) async {
      final store = DeviceReadingStore();
      int? jumped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookmarkControls(
              store: store,
              bookId: 'book',
              position: 240,
              label: (_) => 'Lemalar — Sayfa 12',
              onJump: (value) => jumped = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ayraç ekle'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      final mark = (await store.bookmarks('book')).single;
      expect(mark.createdAt, isNotNull);
      expect(mark.title, 'Lemalar — Sayfa 12');
      await tester.tap(find.byTooltip('Ayraçlar'));
      await tester.pumpAndSettle();
      expect(find.text(mark.title), findsOneWidget);
      expect(find.text('Sayfa 12'), findsNothing);
      expect(find.text(bookmarkDate(mark.createdAt)), findsOneWidget);
      expect(find.textContaining('Kitabın %'), findsNothing);
      await tester.tap(find.text(mark.title));
      await tester.pumpAndSettle();
      expect(jumped, 240);
      await tester.tap(find.byTooltip('Ayracı kaldır'));
      await tester.pumpAndSettle();
      expect(await store.bookmarks('book'), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
