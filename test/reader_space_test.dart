import 'package:e_reader/books.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/paged_book.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  testWidgets(
    'Phone devotes space to reading and displays a single page counter',
    (tester) async {
      tester.view.physicalSize = const Size(338, 730);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? count;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: PagedBook(
                bookId: 'space-test',
                book: const BookContent('Title', ['A short paragraph.']),
                paper: PaperTheme.ivory,
                font: 'Sistem',
                fontSize: 20,
                onPageCountChanged: (value) => count = value,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(count, 1);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text('1'), findsNothing);
      expect(find.text('Ekran'), findsNothing);
      expect(find.byIcon(Icons.info_outline), findsNothing);
      expect(
        tester.getCenter(find.byTooltip('Önceki sayfa')).dy,
        tester.getCenter(find.byTooltip('Ayraç ekle')).dy,
      );
      final page = tester.getRect(find.byKey(const ValueKey('reading-page-0')));
      expect(page.height, greaterThan(730 * .9));
      expect(tester.takeException(), isNull);
    },
  );
}
