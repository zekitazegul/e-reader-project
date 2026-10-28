import 'package:e_reader/annotation_store.dart';
import 'package:e_reader/books.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/paged_book.dart';
import 'package:e_reader/reader_selectable_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test(
    'Annotations retain exact text offsets and stay separate per book',
    () async {
      final store = AnnotationStore();
      await store.save('first', [
        const BookAnnotation(id: '1', start: 0, end: 5, quote: 'Hallo'),
        const BookAnnotation(
          id: '2',
          start: 6,
          end: 12,
          quote: 'wereld',
          note: 'My note',
        ),
      ]);
      final loaded = await AnnotationStore().load('first');
      expect(loaded.first.start, 0);
      expect(loaded.last.note, 'My note');
      expect(loaded.last.quote, 'wereld');
      expect(await store.load('second'), isEmpty);
    },
  );

  testWidgets(
    'Long press has handles, underline and anchored editable notes persist',
    (tester) async {
      final book = BookContent(
        'Selection test',
        List.filled(12, 'Hallo wereld. Dit is een boek. ' * 5),
      );
      Widget reader() => MaterialApp(
        home: ReaderPage(book: book, bookId: 'selection-test'),
      );
      await tester.pumpWidget(reader());
      await tester.pumpAndSettle();
      Future<void> selectWord() async {
        final editable = tester.state<EditableTextState>(
          find.byType(EditableText).first,
        );
        final rect = editable.renderEditable.getLocalRectForCaret(
          const TextPosition(offset: 2),
        );
        final point = editable.renderEditable.localToGlobal(
          rect.center + const Offset(1, 0),
        );
        await tester.longPressAt(point);
        await tester.pumpAndSettle();
      }

      await selectWord();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .showSelectionHandles,
        isTrue,
      );
      expect(find.text('Translate'), findsOneWidget);
      expect(find.text('Translate · Dictionary'), findsNothing);
      expect(find.text('Underline'), findsOneWidget);
      await tester.tap(find.text('Underline'));
      await tester.pumpAndSettle();
      expect(
        (await AnnotationStore().load('selection-test')).single.quote,
        'Hallo',
      );
      await selectWord();
      await tester.tap(find.text('Add note'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('annotation-note-input')),
        'A saved thought',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
      expect(
        (await AnnotationStore().load('selection-test'))
            .where((a) => a.isNote)
            .single
            .note,
        'A saved thought',
      );
      await tester.tap(find.byIcon(Icons.sticky_note_2_outlined));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(
        find.text('A saved thought'),
        findsOneWidget,
        reason:
            'dialogs=${find.byType(AlertDialog).evaluate().length}; fields=${tester.widgetList<EditableText>(find.byType(EditableText)).map((e) => e.controller.text).join(" | ")}',
      );
      await tester.enterText(
        find.byKey(const ValueKey('annotation-note-input')),
        'Edited thought',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      tester.widget<PagedBook>(find.byType(PagedBook)).onPinch!(1.3);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(reader());
      await tester.pumpAndSettle();
      final saved = await AnnotationStore().load('selection-test');
      expect(saved.where((a) => !a.isNote).single.quote, 'Hallo');
      expect(saved.where((a) => a.isNote).single.note, 'Edited thought');
      expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);
      final spans = tester
          .widget<ReaderSelectableText>(find.byType(ReaderSelectableText).first)
          .span
          .children!
          .whereType<TextSpan>();
      expect(
        spans.any((s) => s.style?.decoration == TextDecoration.underline),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
