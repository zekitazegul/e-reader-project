import 'package:flutter/services.dart';
import 'package:e_reader/books.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/paged_book.dart';
import 'package:e_reader/reading_store.dart';
import 'package:e_reader/sample_book.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  for (final size in [const Size(360, 640), const Size(800, 360)]) {
    testWidgets('Pinch resizes and reflows without turning pages at $size', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await (FontLoader(
        'Lora',
      )..addFont(rootBundle.load('assets/fonts/Lora.ttf'))).load();
      final store = DeviceReadingStore();
      final sample = readBook(await loadSampleBook());
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderPage(book: sample, bookId: 'pinch-test', store: store),
        ),
      );
      await tester.pumpAndSettle();
      final page = find.byType(PageView);
      expect(
        tester.getCenter(find.byTooltip('Kitap içinde ara')).dy,
        lessThan(tester.getTopLeft(page).dy),
      );
      expect(find.textContaining(RegExp(r'%\d')), findsNothing);
      final before = tester.widget<PagedBook>(find.byType(PagedBook)).fontSize;
      Future<void> pinch(double distance, double step) async {
        final center = tester.getCenter(page);
        final left = await tester.startGesture(
          center - Offset(distance, 0),
          pointer: 1,
        );
        final right = await tester.startGesture(
          center + Offset(distance, 0),
          pointer: 2,
        );
        for (var frame = 0; frame < 6; frame++) {
          await left.moveBy(Offset(-step, 0));
          await right.moveBy(Offset(step, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        // Both fingers are still down: the painted text must already resize.
        final preview = tester.widget<Transform>(
          find.byKey(const ValueKey('pinch-live-preview')),
        );
        expect(
          preview.transform.entry(0, 0),
          step > 0 ? greaterThan(1) : lessThan(1),
        );
        expect(await store.position('pinch-test'), 0);
        await left.up();
        await right.up();
        await tester.pumpAndSettle();
      }

      await pinch(35, 8);
      final enlarged = tester
          .widget<PagedBook>(find.byType(PagedBook))
          .fontSize;
      expect(enlarged, greaterThan(before));
      expect(enlarged, lessThanOrEqualTo(32));
      final editable = tester
          .state<EditableTextState>(find.byType(EditableText).first)
          .renderEditable;
      expect(editable.textHeightBehavior?.applyHeightToLastDescent, isFalse);
      final displayed = TextPainter(
        text: editable.text,
        textDirection: editable.textDirection,
        textScaler: editable.textScaler,
        textHeightBehavior: editable.textHeightBehavior,
      )..layout(maxWidth: editable.constraints.maxWidth);
      final natural = TextPainter(
        text: TextSpan(
          text: 'gyjpq',
          style: TextStyle(fontFamily: 'Lora', fontSize: enlarged),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final bottom = displayed.computeLineMetrics().last;
      expect(
        bottom.baseline + natural.computeLineMetrics().single.descent,
        lessThanOrEqualTo(editable.size.height + .01),
      );
      displayed.dispose();
      natural.dispose();
      expect(await store.position('pinch-test'), 0);
      expect((await store.settings()).size, enlarged);
      await pinch(100, -10);
      final smaller = tester.widget<PagedBook>(find.byType(PagedBook)).fontSize;
      expect(smaller, lessThan(enlarged));
      expect(smaller, greaterThanOrEqualTo(16));
      expect(await store.position('pinch-test'), 0);
      expect(tester.getRect(page).right, lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
