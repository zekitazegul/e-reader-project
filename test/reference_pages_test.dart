import 'package:e_reader/books.dart';
import 'package:e_reader/book_reference_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'books_test.dart' show zip;

BookContent epub(
  String body, {
  String nav = '',
  String ncx = '',
  bool clean = true,
}) => readBook(
  BookFile(
    'book.epub',
    zip({
      'META-INF/container.xml':
          '<container><rootfile full-path="OPS/book.opf"/></container>',
      'OPS/book.opf':
          '<package><manifest><item id="text" href="text.xhtml"/>'
          '${nav.isEmpty ? '' : '<item id="nav" href="nav.xhtml" properties="nav"/>'}'
          '${ncx.isEmpty ? '' : '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>'}'
          '</manifest><spine><itemref idref="text"/></spine></package>',
      'OPS/text.xhtml': '<html><body>$body</body></html>',
      if (nav.isNotEmpty) 'OPS/nav.xhtml': nav,
      if (ncx.isNotEmpty) 'OPS/toc.ncx': ncx,
    }),
    cleanWhitespace: clean,
  ),
);

void main() {
  test(
    'Inline EPUB markers map to exact UTF-16 text without changing content',
    () {
      final content = epub(
        '<p>Ön 👩🏽‍💻 <span epub:type="pagebreak" aria-label="17"/>Devam.</p>'
        '<span role="doc-pagebreak" title="18"/><p>Yeni sayfa.</p>',
      );
      final text = content.paragraphs.join('\n\n');
      expect(text, 'Ön 👩🏽‍💻 Devam.\n\nYeni sayfa.');
      expect(content.referencePages.map((p) => p.label), ['17', '18']);
      expect(content.referencePages[0].offset, text.indexOf('Devam'));
      expect(content.referencePages[1].offset, text.indexOf('Yeni'));
      expect(referencePageAt(content.referencePages, 0), isNull);
      expect(
        referencePageAt(content.referencePages, text.indexOf('Yeni'))?.label,
        '18',
      );
    },
  );

  test(
    'EPUB 3 page-list resolves arbitrary IDs and preserves roman labels',
    () {
      final content = epub(
        '<p id="intro">Ön söz.</p><p>Bir <span id="arbitrary"/>kitap.</p>',
        nav:
            '<html><body><nav epub:type="page-list"><ol>'
            '<li><a href="text.xhtml#arbitrary">1</a></li>'
            '<li><a href="text.xhtml#intro">iv</a></li>'
            '</ol></nav></body></html>',
      );
      expect(content.referencePages.map((p) => p.label), ['iv', '1']);
      expect(
        content.referencePages.last.offset,
        content.paragraphs.join('\n\n').indexOf('kitap'),
      );
    },
  );

  test('EPUB 2 NCX pageTarget is read independently of screen pagination', () {
    final content = epub(
      '<p id="target">Kitabın metni.</p>',
      ncx:
          '<ncx><pageList><pageTarget value="42"><navLabel><text>42</text></navLabel>'
          '<content src="text.xhtml#target"/></pageTarget></pageList></ncx>',
    );
    expect(content.referencePages.single.label, '42');
    expect(content.referencePages.single.offset, 0);
  });

  for (final clean in [false, true]) {
    test(
      'Offsets match whitespace mode clean=$clean and do not shift existing text',
      () {
        final content = epub(
          '<p>  Ön  \t söz <span role="doc-pagebreak" aria-label="8"/>devam.</p>',
          clean: clean,
        );
        expect(
          content.referencePages.single.offset,
          content.paragraphs.single.indexOf('devam'),
        );
      },
    );
  }

  test('Footnotes and guessed numeric IDs are not treated as book pages', () {
    final content = epub('<p>Bir <span id="page_300">300</span> kelime.</p>');
    expect(content.referencePages, isEmpty);
  });

  test('Malformed optional navigation does not block reading', () {
    final content = epub('<p>Sağlam metin.</p>', ncx: 'not valid XML');
    expect(content.paragraphs, ['Sağlam metin.']);
    expect(content.referencePages, isEmpty);
  });

  test(
    'Manual estimate depends only on text position and supplied edition total',
    () {
      expect(estimatedReferencePage(0, 10000, 300), 1);
      expect(estimatedReferencePage(5000, 10000, 300), 151);
      expect(estimatedReferencePage(10000, 10000, 300), 300);
    },
  );
}
