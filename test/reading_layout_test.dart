import 'package:e_reader/books.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/reading_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'Wide reader shows a spread, supports keys and toggles focus tools',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = DeviceReadingStore();
      final book = BookContent(
        'Uzun kitap',
        List.filled(
          80,
          'Bir kitap yeni dünyalara açılır. Her sayfada yeni bir yol başlar.',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderPage(book: book, bookId: 'wide', store: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byKey(const ValueKey('reading-page-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('reading-page-1')), findsOneWidget);
      expect(find.textContaining('1–2 / '), findsOneWidget);
      expect(
        tester.getSize(find.byType(PageView)).width,
        greaterThanOrEqualTo(1270),
      );
      final readingHeight = tester.getSize(find.byType(PageView)).height;
      expect(readingHeight, greaterThan(780));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.textContaining('3–4 / '), findsOneWidget);
      final saved = await store.position('wide');
      expect(saved, greaterThan(0));
      await tester.tap(find.byKey(const ValueKey('reading-page-2')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
      expect(
        tester.getSize(find.byType(PageView)).height,
        greaterThan(readingHeight),
      );
      expect(find.byTooltip('Kitap içinde ara').hitTestable(), findsNothing);
      expect(await store.position('wide'), saved);
      await tester.tapAt(
        tester.getTopLeft(find.byType(PageView)) + const Offset(80, 80),
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Kitap içinde ara').hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('1 sayfa').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('1 sayfa').last);
      await tester.pumpAndSettle();
      expect((await store.settings()).layout, 'single');
      expect(await store.position('wide'), saved);
      expect(find.textContaining(RegExp(r'^\d+ / \d+$')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Small phone keeps one page even when double is preferred', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = DeviceReadingStore();
    await store.saveSettings(const ReadingSettings(layout: 'double'));
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(
          store: store,
          bookId: 'phone',
          book: BookContent(
            'Kitap',
            List.filled(40, 'Dar bir ekranda da rahat okumak mümkün.'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1 / '), findsOneWidget);
    await tester.tap(find.byTooltip('Sonraki sayfa'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 / '), findsOneWidget);
    await tester.tap(find.byTooltip('Kitap içinde ara'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'rahat');
    await tester.tap(find.byTooltip('Metinde ara'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('Arama vurgusunu temizle').hitTestable(),
      findsOneWidget,
    );
    expect(find.byTooltip('Ayraç ekle').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Desktop wide single page and larger type persist across reopening',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = DeviceReadingStore();
      final book = BookContent(
        'Kitap',
        List.filled(40, 'Geniş bir sayfada büyük yazılarla rahat okuma.'),
      );
      Widget reader() => MaterialApp(
        home: ReaderPage(book: book, store: store),
      );
      await tester.pumpWidget(reader());
      await tester.pumpAndSettle();
      final spreadPageWidth = tester
          .getSize(find.byKey(const ValueKey('reading-page-0')))
          .width;
      await tester.tap(find.byTooltip('1 sayfa'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 / '), findsOneWidget);
      final singlePageWidth = tester
          .getSize(find.byKey(const ValueKey('reading-page-0')))
          .width;
      expect(singlePageWidth, greaterThan(spreadPageWidth));
      expect((await store.settings()).layout, 'single');
      expect((await store.settings()).size, 24);
      await tester.tap(find.byTooltip('Yazıyı büyüt'));
      await tester.pumpAndSettle();
      expect((await store.settings()).size, 26);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(reader());
      await tester.pumpAndSettle();
      expect(find.textContaining('1 / '), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('reading-page-0'))).width,
        singlePageWidth,
      );
      expect((await store.settings()).size, 26);
      expect(tester.takeException(), isNull);
    },
  );
}
