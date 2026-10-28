import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:e_reader/book_cover_image.dart';
import 'package:e_reader/books.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pixels = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jN1sAAAAASUVORK5CYII=',
  );
  BookFile epub(String metadata, String item) {
    final archive = Archive();
    void text(String name, String value) {
      final bytes = utf8.encode(value);
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    text(
      'META-INF/container.xml',
      '<container><rootfile full-path="OPS/book.opf"/></container>',
    );
    text(
      'OPS/book.opf',
      '<package><metadata>$metadata</metadata><manifest>$item</manifest></package>',
    );
    archive.addFile(
      ArchiveFile('OPS/images/front cover.png', pixels.length, pixels),
    );
    return BookFile(
      'cover.epub',
      Uint8List.fromList(ZipEncoder().encode(archive)),
    );
  }

  test('EPUB 3 and EPUB 2 declared covers resolve relative image paths', () {
    for (final modern in [true, false]) {
      final book = epub(
        modern ? '' : '<meta name="cover" content="jacket"/>',
        '<item id="jacket" href="images/front%20cover.png" media-type="image/png" ${modern ? 'properties="cover-image"' : ''}/>',
      );
      expect(readBookCover(book), orderedEquals(pixels));
    }
  });

  test('Interior images, remote covers and damaged books use fallback', () {
    expect(
      readBookCover(
        epub(
          '',
          '<item id="photo" href="images/front%20cover.png" media-type="image/png"/>',
        ),
      ),
      isNull,
    );
    expect(
      readBookCover(
        epub(
          '',
          '<item id="cover" href="https://example.com/cover.png" media-type="image/png" properties="cover-image"/>',
        ),
      ),
      isNull,
    );
    expect(readBookCover(BookFile('broken.epub', Uint8List(0))), isNull);
    expect(readBookCover(BookFile('book.pdf', pixels)), isNull);
  });
}
