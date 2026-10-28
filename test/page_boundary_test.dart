import 'package:e_reader/books.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/paged_book.dart';
import 'package:e_reader/reader_selectable_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 1.15, 1.3]) {
    testWidgets(
      'Every line and boundary is visible with large Lora at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(338, 730);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await (FontLoader(
          'Lora',
        )..addFont(rootBundle.load('assets/fonts/Lora.ttf'))).load();
        final text = List.generate(
          24,
          (i) =>
              'Bölüm $i: yanlışsız, hatasız, mükemmel; göklerin ve yerin taşımaktan çekindiği emanet. '
              'Bir bahar kadar kolay gelen saadet yurdu. Hiç şüphe yok ki bütün kelimeler görünür. '
              'gyjpq â î ş ğ İ ı 👩🏽‍💻 e\u0301.',
        ).join('\n\n');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(
                  textScaler: TextScaler.linear(scale),
                  lineHeightScaleFactorOverride: scale == 1.3 ? 1.6 : null,
                  letterSpacingOverride: scale == 1.3 ? 1.5 : null,
                  wordSpacingOverride: scale == 1.3 ? 2 : null,
                  boldText: scale == 1.3,
                ),
                child: PagedBook(
                  book: BookContent('Boundaries', [text]),
                  paper: PaperTheme.ivory,
                  font: 'Lora',
                  fontSize: 32,
                  lineHeight: 1.3,
                  controlsVisible: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final state = tester.state<PagedBookState>(find.byType(PagedBook));
        for (var frame = 0; frame < 1000 && state.indexing; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(state.indexing, isFalse);
        final pager = tester.widget<PageView>(find.byType(PageView));
        final count = pager.childrenDelegate.estimatedChildCount!;
        final collected = <String>[];
        for (var page = 0; page < count; page++) {
          pager.controller!.jumpToPage(page);
          await tester.pumpAndSettle();
          final sheet = find.byKey(ValueKey('reading-page-$page'));
          final selectable = find.descendant(
            of: sheet,
            matching: find.byType(ReaderSelectableText),
          );
          final value = tester
              .widget<ReaderSelectableText>(selectable)
              .span
              .toPlainText();
          collected.add(value);
          final editable = tester
              .state<EditableTextState>(
                find.descendant(of: sheet, matching: find.byType(EditableText)),
              )
              .renderEditable;
          final visible = tester
              .getRect(sheet)
              .intersect(
                Rect.fromLTWH(
                  editable.localToGlobal(Offset.zero).dx,
                  editable.localToGlobal(Offset.zero).dy,
                  editable.size.width,
                  editable.size.height,
                ),
              );
          final boxes = editable.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: value.length),
          );
          for (final box in boxes) {
            final rect = box.toRect().shift(
              editable.localToGlobal(Offset.zero),
            );
            expect(
              rect.top,
              greaterThanOrEqualTo(visible.top - .1),
              reason: 'Page ${page + 1} first glyph',
            );
            expect(
              rect.bottom,
              lessThanOrEqualTo(visible.bottom + .1),
              reason:
                  'Page ${page + 1} last glyph; editable=${editable.size}; '
                  'offset=${editable.offset.pixels}; tail=${value.substring(value.length > 100 ? value.length - 100 : 0)}',
            );
          }
        }
        expect(
          collected.join(),
          text,
          reason: 'No skipped or repeated text at any boundary',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
