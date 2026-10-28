import 'dart:async';
import 'dart:typed_data';

import 'package:e_reader/app_language.dart';
import 'package:e_reader/book_store.dart';
import 'package:e_reader/books.dart';
import 'package:e_reader/library.dart';
import 'package:e_reader/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class LiveBookStore extends BookStore {
  final notifications = StreamController<void>.broadcast();
  final entries = [BookFile('First.epub', Uint8List(0))];
  @override
  Stream<void> changes() => notifications.stream;
  @override
  Future<void> remove(BookFile book) async {
    entries.remove(book);
  }

  @override
  Future<String> location() async => '/test/e-books';
  @override
  Future<List<BookFile>> scan() async => List.of(entries);
  @override
  Future<bool> selectFolder() async {
    entries.add(BookFile('Chosen.epub', Uint8List(0)));
    return true;
  }
}

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  for (final size in [
    const Size(320, 750),
    const Size(800, 360),
    const Size(800, 1280),
  ]) {
    testWidgets(
      'Library remembers the view and updates without refresh at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = LiveBookStore();
        final language = LanguageController();
        Widget app() => LanguageScope(
          controller: language,
          child: MaterialApp(
            locale: const Locale('tr'),
            home: LibraryPage(store: store),
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('library-grid-books')),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsNothing);
        expect(find.byIcon(Icons.refresh), findsNothing);
        expect(find.text('Tr'), findsOneWidget);
        expect(
          tester.getCenter(find.byKey(const ValueKey('library-settings'))).dx,
          lessThan(tester.getCenter(find.byType(LanguageButton)).dx),
        );
        expect(
          tester.getCenter(find.byType(LanguageButton)).dx,
          greaterThan(
            tester.getCenter(find.byKey(const ValueKey('library-menu'))).dx,
          ),
        );
        await tester.tap(find.byKey(const ValueKey('library-list')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('library-row-First.epub')),
          findsOneWidget,
        );
        final firstRow = find.byKey(const ValueKey('library-row-First.epub'));
        expect(
          find.descendant(of: firstRow, matching: find.byType(Icon)),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('library-info-First.epub')),
          findsNothing,
        );
        await tester.tap(firstRow);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('library-info-First.epub')),
          findsOneWidget,
        );
        expect(find.byType(ReaderPage), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('library-row-First.epub')),
          findsOneWidget,
        );
        store.entries.add(BookFile('Second.docx', Uint8List(0)));
        store.notifications.add(null);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('library-row-Second.docx')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('library-grid')));
        await tester.pumpAndSettle();
        final grid = tester.widget<GridView>(
          find.byKey(const ValueKey('library-grid-books')),
        );
        expect(
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .childAspectRatio,
          0.70,
        );
        if (size.width < 600) {
          await tester.tap(find.byKey(const ValueKey('library-menu')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Klasör seç'));
        } else {
          await tester.tap(find.byKey(const ValueKey('library-folder')));
        }
        for (var frame = 0; frame < 5; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
        expect(
          find.text('Chosen'),
          findsOneWidget,
          reason:
              'entries=${store.entries.map((e) => e.title)}; text=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).join(" | ")}',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await store.notifications.close();
        language.dispose();
      },
    );
  }
}
