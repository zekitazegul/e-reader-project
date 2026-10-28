import 'dart:convert';
import 'dart:io';

import 'package:e_reader/book_print_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rows = jsonDecode(
    File('assets/books/print_editions.json').readAsStringSync(),
  ) as List;
  final catalog = BookPrintCatalog.fromJson(rows);

  test(
    'Every researched file has either a sourced edition or an explicit gap',
    () {
      expect(rows, hasLength(94));
      for (final row in rows.cast<Map<String, dynamic>>()) {
        for (final alias in List<String>.from(row['aliases'])) {
          final edition = catalog.find('$alias.epub');
          expect(edition?.pages, row['pages'], reason: alias);
          if (edition == null) {
            expect(row['reason'], isNotEmpty);
          } else {
            expect(edition.pages, greaterThan(0));
            expect(edition.sources, isNotEmpty);
            for (final source in edition.sources) {
              expect(Uri.parse(source).scheme, 'https');
            }
          }
        }
      }
    },
  );

  test(
    'Known phone titles resolve without mixing authors, volumes or bundles',
    () {
      expect(
        catalog.find('Asayi Musa - Bediuzzaman Said Nursi.epub')?.pages,
        304,
      );
      expect(catalog.find('Suat Yıldırım - Kuran Meali.epub')?.pages, 625);
      expect(catalog.find('Beyan - M. Fethullah GULEN.epub')?.pages, 179);
      expect(
        catalog.find('renamed.epub', title: 'Beyan', author: 'Another author'),
        isNull,
      );
      expect(catalog.find('Prizma 4 - M. Fethullah GULEN.epub'), isNull);
      expect(catalog.find('Prizma 1 - M. Fethullah GULEN.epub')?.pages, 260);
      expect(
        catalog.find('Prizma - I,II,III,IV - M. Fethullah GULEN.epub'),
        isNull,
      );
      expect(
        catalog.find('Sonsuz Nur I-II - M. Fethullah GULEN.epub')?.pages,
        1311,
      );
      expect(
        catalog.find('Kirik Testi (1-10) - M. Fethullah GULEN.epub')?.pages,
        3040,
      );
    },
  );

  test(
    'Ratio uses actual layout total and does not fabricate unopened totals',
    () {
      final edition = catalog.find('Beyan - M. Fethullah GULEN.epub')!;
      expect(edition.screensPerPage(1229), closeTo(6.8659, 0.001));
      expect(edition.screensPerPage(179), 1);
      expect(edition.screensPerPage(null), isNull);
      expect(edition.screensPerPage(0), isNull);
    },
  );
}
