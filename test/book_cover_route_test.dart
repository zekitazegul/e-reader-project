import 'package:e_reader/book_cover_route.dart';
import 'package:e_reader/library_book_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cover = BookCoverOpening(
    rect: Rect.fromLTWH(24, 100, 130, 200),
    title: 'A long book title that must remain complete',
    format: 'EPUB',
    color: Color(0xFF476658),
  );
  test(
    'List and reduced motion use normal routes; cover uses book opening',
    () {
      expect(bookReaderRoute(const SizedBox()), isA<MaterialPageRoute<void>>());
      expect(
        bookReaderRoute(const SizedBox(), cover: cover, reduceMotion: true),
        isA<MaterialPageRoute<void>>(),
      );
      expect(
        bookReaderRoute(const SizedBox(), cover: cover),
        isA<PageRouteBuilder<void>>(),
      );
      final disabled = bookReaderRoute(
        const SizedBox(),
        cover: cover,
        animationsEnabled: false,
      ) as PageRouteBuilder<void>;
      expect(disabled.transitionDuration, Duration.zero);
      expect(disabled.reverseTransitionDuration, Duration.zero);
    },
  );
  testWidgets('Book cover opens into a live reader and is removed afterwards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(338, 730);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                bookReaderRoute(
                  const Scaffold(body: Text('Live reader')),
                  cover: cover,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(LibraryBookCover), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 350));
    final hinge = tester.widget<Transform>(
      find.byKey(const ValueKey('book-opening-hinge')),
    );
    // The free edge comes toward the viewer around the left spine.
    expect(hinge.alignment, Alignment.centerLeft);
    expect(hinge.transform.entry(2, 0), lessThan(0));
    // The reader keeps its final dimensions throughout the opening.
    expect(
      tester.getSize(find.text('Live reader')).width,
      lessThanOrEqualTo(338),
    );
    expect(tester.getSize(find.byType(Scaffold).last), const Size(338, 730));
    await tester.pumpAndSettle();
    expect(find.text('Live reader'), findsOneWidget);
    expect(find.byType(LibraryBookCover), findsNothing);
    Navigator.of(tester.element(find.text('Live reader'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byKey(const ValueKey('book-opening-hinge')), findsOneWidget);
    expect(find.byType(LibraryBookCover), findsOneWidget);
    expect(find.text('Live reader'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
