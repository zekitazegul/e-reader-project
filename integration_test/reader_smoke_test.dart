import 'package:e_reader/books.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/reading_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class MemoryReadingStore implements ReadingStore {
  ReadingSettings value = const ReadingSettings();
  int offset = 0;
  List<ReadingBookmark> marks = [];
  @override
  Future<ReadingSettings> settings() async => value;
  @override
  Future<void> saveSettings(ReadingSettings settings) async {
    value = settings;
  }

  @override
  Future<int> position(String id) async => offset;
  @override
  Future<void> savePosition(String id, int position) async {
    offset = position;
  }

  @override
  Future<List<ReadingBookmark>> bookmarks(String id) async => marks;
  @override
  Future<void> saveBookmarks(String id, List<ReadingBookmark> bookmarks) async {
    marks = bookmarks;
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Large book: responsive touch, fullscreen, bookmark and navigation',
    (tester) async {
      var store = MemoryReadingStore();
      final book = BookContent(
        'Device performance test',
        List.generate(
          4473,
          (i) =>
              'Paragraph $i. Bir kitap yeni dünyalara açılır. İstanbul ve güzel günler. '
              'Чтение открывает новый мир. Українська мова. مرحبًا بالعالم. 阅读带来新的世界。 पढ़ना एक नई दुनिया खोलता है। '
              'The next page keeps every word, with enough text to measure a large book.',
        ),
      );
      final startup = Stopwatch()..start();
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderPage(
            book: book,
            bookId: '__performance_test__',
            store: store,
          ),
        ),
      );
      final view = find.byType(PageView);
      while (view.evaluate().isEmpty &&
          startup.elapsed < const Duration(seconds: 30)) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(view, findsOneWidget);
      final firstPageMs = startup.elapsedMilliseconds;
      Future<void> dragWithFrames(Offset delta) async {
        final gesture = await tester.startGesture(tester.getCenter(view));
        for (var step = 0; step < 18; step++) {
          await gesture.moveBy(delta / 18);
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
      }

      await binding.watchPerformance(() async {
        for (var i = 0; i < 4; i++) {
          final size = tester.getSize(view);
          final before = tester.widget<PageView>(view).controller!.page!;
          await dragWithFrames(Offset(-size.width * .65, 0));
          expect(
            tester.widget<PageView>(view).controller!.page!,
            greaterThan(before),
          );
          final horizontal = tester.widget<PageView>(view).controller!.page!;
          await dragWithFrames(Offset(0, -size.height * .65));
          expect(tester.widget<PageView>(view).scrollDirection, Axis.vertical);
          expect(
            tester.widget<PageView>(view).controller!.page!,
            greaterThan(horizontal),
          );
        }
      }, reportKey: 'page_swipes');
      binding.reportData!['first_readable_page_ms'] = firstPageMs;
      binding.reportData!['logical_view_size'] = {
        'width': tester.view.physicalSize.width / tester.view.devicePixelRatio,
        'height':
            tester.view.physicalSize.height / tester.view.devicePixelRatio,
      };
      binding.reportData!['device_pixel_ratio'] = tester.view.devicePixelRatio;
      // Use a separate short fixture for bookmark/fullscreen checks. The large
      // fixture above specifically exercises reading while indexing continues.
      store = MemoryReadingStore();
      final smokeBook = BookContent(
        book.title,
        book.paragraphs.take(40).toList(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderPage(
            key: const ValueKey('short-fixture'),
            book: smokeBook,
            bookId: '__smoke_test__',
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (
        var frame = 0;
        frame < 100 && find.text('Yükleniyor').evaluate().isNotEmpty;
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('Yükleniyor'), findsNothing);
      await tester.ensureVisible(find.byTooltip('Ayraç ekle'));
      await tester.tap(find.byTooltip('Ayraç ekle'));
      await tester.pumpAndSettle();
      expect(store.marks, hasLength(1));
      expect(store.marks.single.title, startsWith('${book.title} — Sayfa '));
      expect(store.marks.single.createdAt, isNotNull);
      await tester.tap(find.byTooltip('Ayraçlar'));
      await tester.pumpAndSettle();
      expect(find.text(store.marks.single.title), findsOneWidget);
      await tester.tap(find.text(store.marks.single.title));
      await tester.pumpAndSettle();
      Future<void> doubleTapSurface() async {
        final point = tester.getTopLeft(view) + const Offset(70, 70);
        await tester.tapAt(point);
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tapAt(point);
        await tester.pumpAndSettle();
      }

      await doubleTapSurface();
      expect(find.byType(AppBar), findsNothing);
      for (
        var i = 0;
        i < 100 && find.text('Yükleniyor').evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final beforeFull = tester.widget<PageView>(view).controller!.page!;
      await tester.drag(view, Offset(0, -tester.getSize(view).height * .7));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(view).controller!.page!,
        greaterThan(beforeFull),
      );
      final beforeHorizontal = tester.widget<PageView>(view).controller!.page!;
      await tester.drag(view, Offset(-tester.getSize(view).width * .7, 0));
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(view).controller!.page!,
        greaterThan(beforeHorizontal),
      );
      await doubleTapSurface();
      expect(find.byTooltip('Okuma ayarları'), findsNothing);
      expect(find.byIcon(Icons.settings_outlined), findsNothing);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
      expect(find.byTooltip('Dikey kaydırma'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
