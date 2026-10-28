import 'package:e_reader/books.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/reading_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  final book = BookContent(
    'Adaptive screen test',
    List.generate(
      60,
      (i) =>
          'Paragraph $i. Reading should follow the finger and fit every screen. ' *
          6,
    ),
  );
  for (final size in [
    const Size(320, 240),
    const Size(320, 700),
    const Size(390, 844),
    const Size(844, 390),
    const Size(600, 960),
    const Size(1024, 768),
    const Size(1280, 800),
    const Size(1920, 1080),
    const Size(2560, 1080),
  ]) {
    testWidgets('Reader fits $size with large system text and safe insets', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
              padding: const EdgeInsets.only(top: 24, bottom: 24),
            ),
            child: child!,
          ),
          home: ReaderPage(
            book: book,
            bookId: 'adaptive',
            store: DeviceReadingStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final viewport = find.byType(PageView);
      expect(viewport, findsOneWidget);
      expect(tester.getRect(viewport).bottom, lessThanOrEqualTo(size.height));
      expect(
        tester.getSize(viewport).width,
        greaterThanOrEqualTo(size.width - 9),
      );
      expect(tester.takeException(), isNull);
      await tester.drag(
        viewport,
        Offset(0, -tester.getSize(viewport).height * .65),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<PageView>(viewport).scrollDirection, Axis.vertical);
      await tester.drag(
        viewport,
        Offset(-tester.getSize(viewport).width * .65, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<PageView>(viewport).scrollDirection,
        Axis.horizontal,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
