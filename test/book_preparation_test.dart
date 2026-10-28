import 'package:e_reader/books.dart';
import 'package:flutter_test/flutter_test.dart';

import 'books_test.dart' show zip;

void main() {
  test('Existing books can retain original text offsets', () {
    final content = readBook(
      BookFile(
        'old.docx',
        zip({
          'word/document.xml':
              '<document><p><t>  Old   text  </t></p></document>',
        }),
        cleanWhitespace: false,
      ),
    );
    expect(content.paragraphs, ['  Old   text  ']);
  });
  test(
    'EPUB cleans layout whitespace, preserves paragraphs and reads author',
    () {
      final content = readBook(
        BookFile(
          'test.epub',
          zip({
            'META-INF/container.xml':
                '<container><rootfile full-path="book.opf"/></container>',
            'book.opf': '<package><metadata><title>Title</title><creator>Author Name</creator></metadata><manifest><item id="a" href="a.xhtml"/></manifest><spine><itemref idref="a"/></spine></package>',
            'a.xhtml': '<html><body><p>  First\n\n   paragraph&nbsp;&nbsp;text. </p><p> \n </p><blockquote><p> Second\t paragraph. </p></blockquote></body></html>',
          }),
        ),
      );
      expect(content.author, 'Author Name');
      expect(content.paragraphs, [
        'First paragraph text.',
        'Second paragraph.',
      ]);
    },
  );

  test(
    'DOCX cleans repeated spaces and empty paragraphs without joining words',
    () {
      final content = readBook(
        BookFile(
          'test.docx',
          zip({
            'word/document.xml': '<document><p><r><t> First  </t><t> word </t><tab/><t> next. </t></r></p><p><r><t>  </t></r></p><p><r><t>Second paragraph.</t></r></p></document>',
            'docProps/core.xml':
                '<properties><creator>Document Author</creator></properties>',
          }),
        ),
      );
      expect(content.author, 'Document Author');
      expect(content.paragraphs, ['First word next.', 'Second paragraph.']);
    },
  );

  test('Large EPUB chapter preserves all nested and sibling blocks in order', () {
    final content = readBook(
      BookFile(
        'large.epub',
        zip({
          'META-INF/container.xml':
              '<container><rootfile full-path="book.opf"/></container>',
          'book.opf': '<package><manifest><item id="a" href="a.xhtml"/></manifest><spine><itemref idref="a"/></spine></package>',
          'a.xhtml':
              '<html><body>${List.generate(12000, (i) => '<blockquote><p>Paragraph $i</p></blockquote>').join()}</body></html>',
        }),
      ),
    );
    expect(content.paragraphs, hasLength(12000));
    expect(content.paragraphs.first, 'Paragraph 0');
    expect(content.paragraphs.last, 'Paragraph 11999');
  });
}
