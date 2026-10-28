import 'package:e_reader/books.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/reading_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  final book = BookContent(
    'Kitap',
    List.filled(
      100,
      'Okurken sayfalar ve kaydırma arasında geçiş yapabilirim.',
    ),
  );

  for (final count in [3, 4]) {
    testWidgets(
      '$count pages display and advance together with icon-only controls',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = DeviceReadingStore();
        await tester.pumpWidget(
          MaterialApp(
            home: ReaderPage(book: book, store: store, bookId: 'modes'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('$count sayfa'));
        await tester.pumpAndSettle();
        for (var i = 0; i < count; i++) {
          expect(find.byKey(ValueKey('reading-page-$i')), findsOneWidget);
        }
        expect(find.textContaining('1–$count / '), findsOneWidget);
        expect(
          (await DeviceReadingStore().settings()).layout,
          count == 3 ? 'triple' : 'quadruple',
        );
        expect(find.text('Çift sayfa'), findsNothing);
        expect(find.text('Tek sayfa'), findsNothing);
        await tester.tap(find.byTooltip('Sonraki sayfa'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('${count + 1}–${count * 2} / '),
          findsOneWidget,
        );
        expect(await store.position('modes'), greaterThan(0));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Automatic vertical gestures and arrow keys preserve position', (
    tester,
  ) async {
    final store = DeviceReadingStore();
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(book: book, bookId: 'scroll', store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Dikey kaydırma'), findsNothing);
    // Touching the reading surface gives keyboard focus to the reader.
    await tester.drag(find.byType(PageView), const Offset(0, -500));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    final before = controller.offset;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      controller.offset,
      closeTo(before + controller.position.viewportDimension, 0.01),
    );
    final lower = controller.offset;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(before, 0.01));
    expect(controller.offset, lessThan(lower));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(await store.position('scroll'), greaterThan(0));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: ReaderPage(book: book, bookId: 'scroll', store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<PageView>(find.byType(PageView)).scrollDirection,
      Axis.horizontal,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Double tap enters fullscreen and Escape restores reading tools',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final calls = <bool>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('e_reader/window'), (
              call,
            ) async {
              calls.add(call.arguments as bool);
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('e_reader/window'),
                null,
              ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ReaderPage(book: book, store: DeviceReadingStore()),
          ),
        );
        await tester.pumpAndSettle();
        final page = find.byKey(const ValueKey('reading-page-0'));
        await tester.tap(page);
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tap(page);
        await tester.pumpAndSettle();
        expect(find.byType(AppBar), findsNothing);
        for (var frame = 0; frame < 50; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final controller = tester
            .widget<PageView>(find.byType(PageView))
            .controller!;
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(PageView)),
        );
        await gesture.moveBy(const Offset(0, -50));
        await tester.pump();
        await gesture.moveBy(const Offset(0, -70));
        await tester.pump();
        expect(
          tester.widget<PageView>(find.byType(PageView)).scrollDirection,
          Axis.vertical,
        );
        final duringDrag = controller.offset;
        expect(duringDrag, greaterThan(0));
        await gesture.moveBy(const Offset(0, -60));
        await tester.pump();
        expect(controller.offset - duringDrag, closeTo(60, 0.1));
        await gesture.moveBy(const Offset(0, -350));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(controller.page, closeTo(1, 0.01));
        await tester.drag(find.byType(PageView), const Offset(-550, 0));
        await tester.pumpAndSettle();
        expect(
          tester.widget<PageView>(find.byType(PageView)).scrollDirection,
          Axis.horizontal,
        );
        expect(controller.page, closeTo(2, 0.01));
        final surface =
            tester.getTopLeft(find.byType(PageView)) + const Offset(80, 80);
        await tester.tapAt(surface);
        await tester.pump(const Duration(milliseconds: 80));
        await tester.tapAt(surface);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Tam ekran'), findsNothing);
        expect(find.byTooltip('Okuma ayarları'), findsNothing);
        expect(calls, [true, false]);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
