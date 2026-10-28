import 'dart:typed_data';

import 'package:e_reader/book_store.dart';
import 'package:e_reader/books.dart';
import 'package:e_reader/library.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/reading_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class TestBookStore extends BookStore {
  @override
  Future<String> location() async => 'test/e-books';
  @override
  Future<List<BookFile>> scan() async => [
    BookFile('İstanbul.epub', Uint8List(0)),
    BookFile('Deniz.docx', Uint8List(0)),
  ];
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('Book titles follow Turkish alphabetical order', () {
    final titles = [
      'Üzüm',
      'İzmir',
      'Çınar',
      'Işık',
      'Ceviz',
      'Şehir',
      'Sahil',
    ];
    titles.sort(compareBookTitles);
    expect(titles, [
      'Ceviz',
      'Çınar',
      'Işık',
      'İzmir',
      'Sahil',
      'Şehir',
      'Üzüm',
    ]);
  });

  testWidgets('Library opens directly on the shelves without filters', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LibraryPage(store: TestBookStore())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Deniz'), findsOneWidget);
    expect(find.text('İstanbul'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('Sıralama'), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Settings and positions survive creating a new store', () async {
    final first = DeviceReadingStore();
    await first.saveSettings(
      const ReadingSettings(
        font: 'Literata',
        size: 26,
        paper: 'night',
        layout: 'single',
        lineHeight: 1.5,
        bookAnimations: false,
      ),
    );
    await first.savePosition('book-a', 920);
    await first.savePosition('book-b', 100);
    await first.saveBookmarks('book-a', [
      for (final offset in [920, 0, 920, -1]) ReadingBookmark(offset: offset),
    ]);
    final second = DeviceReadingStore();
    final settings = await second.settings();
    expect(settings.font, 'Literata');
    expect(settings.size, 26);
    expect(settings.paper, 'night');
    expect(settings.layout, 'single');
    expect(settings.lineHeight, 1.5);
    expect(settings.bookAnimations, isFalse);
    expect(ReadingSettings.fromJson({}).bookAnimations, isTrue);
    expect(await second.position('book-a'), 920);
    expect(await second.position('book-b'), 100);
    expect((await second.bookmarks('book-a')).map((mark) => mark.offset), [
      0,
      920,
    ]);
    expect(await second.bookmarks('book-b'), isEmpty);
    await second.saveBookmarks('book-a', [const ReadingBookmark(offset: 920)]);
    expect((await first.bookmarks('book-a')).map((mark) => mark.offset), [920]);
  });

  test(
    'Damaged settings fall back and concurrent writes retain latest choice',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({
            'reader.settings.v1': '{bad json',
          });
      final store = DeviceReadingStore();
      expect((await store.settings()).font, 'Lora');
      await Future.wait([
        store.savePosition('book', 12),
        store.savePosition('book', 24),
        store.savePosition('book', 36),
      ]);
      expect(await store.position('book'), 36);
      expect(
        ReadingSettings.fromJson({'size': 999, 'font': 'invalid'}).size,
        32,
      );
    },
  );

  testWidgets('Reader restores position and keeps it when font changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = DeviceReadingStore();
    final book = BookContent(
      'Uzun kitap',
      List.filled(
        60,
        'Bir kitap yeni dünyalara açılır. Her sayfada yeni bir yol başlar.',
      ),
    );
    Widget reader() => MaterialApp(
      home: ReaderPage(book: book, bookId: 'test-book', store: store),
    );
    await tester.pumpWidget(reader());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sonraki sayfa'));
    await tester.pumpAndSettle();
    final saved = await store.position('test-book');
    expect(saved, greaterThan(0));
    await tester.ensureVisible(find.byTooltip('Ayraç ekle'));
    await tester.tap(find.byTooltip('Ayraç ekle'));
    await tester.pumpAndSettle();
    expect((await store.bookmarks('test-book')).single.offset, saved);
    expect(
      (await store.bookmarks('test-book')).single.title,
      '${book.title} — Sayfa 2',
    );
    expect((await store.bookmarks('test-book')).single.createdAt, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(reader());
    await tester.pumpAndSettle();
    expect(find.textContaining('2 / '), findsOneWidget);
    expect(find.byTooltip('Ayracı kaldır'), findsOneWidget);
    await tester.tap(find.byTooltip('Sonraki sayfa'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Ayraçlar'));
    await tester.tap(find.byTooltip('Ayraçlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('${book.title} — Sayfa 2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 / '), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(home: ReaderPage(settingsOnly: true, store: store)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Literata'));
    await tester.tap(find.text('Literata'));
    await tester.pumpAndSettle();
    expect(await store.position('test-book'), saved);
    expect((await store.settings()).font, 'Literata');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Library shows all books on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 750);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: LibraryPage(store: TestBookStore())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Deniz'), findsOneWidget);
    expect(find.text('İstanbul'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
