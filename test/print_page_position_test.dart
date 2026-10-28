import 'package:e_reader/book_reference_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ten screens per print page reset at the next page', () {
    expect(printPagePosition(300, 3040, 304), (
      page: 31,
      screen: 1,
      screens: 10,
    ));
    expect(printPagePosition(309, 3040, 304), (
      page: 31,
      screen: 10,
      screens: 10,
    ));
    expect(printPagePosition(310, 3040, 304), (
      page: 32,
      screen: 1,
      screens: 10,
    ));
  });
  test('Uneven screen groups cover all pages with no gaps or duplicates', () {
    for (final total in [2867, 1229]) {
      final printTotal = total == 2867 ? 304 : 179;
      var previousPage = 0;
      var previousScreen = 0;
      var previousScreens = 0;
      for (var i = 0; i < total; i++) {
        final p = printPagePosition(i, total, printTotal);
        expect(p.screen, inInclusiveRange(1, p.screens));
        if (p.page == previousPage) {
          expect(p.screen, previousScreen + 1);
        } else {
          expect(p.page, previousPage + 1);
          expect(previousScreen, previousScreens);
          expect(p.screen, 1);
        }
        previousPage = p.page;
        previousScreen = p.screen;
        previousScreens = p.screens;
      }
      expect(previousPage, printTotal);
      expect(previousScreen, previousScreens);
    }
  });
}
