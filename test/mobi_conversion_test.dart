import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:e_reader/books.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List mobiFixture(
  List<List<int>> records, {
  int compression = 1,
  int encrypted = 0,
  int trailing = 0,
  int? textLength,
}) {
  final title = utf8.encode('İstanbul & Reading');
  final header = Uint8List(248 + title.length);
  final data = ByteData.sublistView(header);
  data.setUint16(0, compression);
  data.setUint32(4, textLength ?? records.fold(0, (sum, r) => sum + r.length));
  data.setUint16(8, records.length);
  data.setUint16(10, 4096);
  data.setUint16(12, encrypted);
  header.setRange(16, 20, ascii.encode('MOBI'));
  data.setUint32(20, 232);
  data.setUint32(28, 65001);
  data.setUint32(36, 6);
  data.setUint32(84, 248);
  data.setUint32(88, title.length);
  data.setUint16(242, trailing);
  header.setRange(248, header.length, title);
  final all = [header, ...records];
  final start = 78 + all.length * 8 + 2;
  final file = Uint8List(start + all.fold<int>(0, (sum, r) => sum + r.length));
  final fileData = ByteData.sublistView(file);
  file.setRange(60, 68, ascii.encode('BOOKMOBI'));
  fileData.setUint16(76, all.length);
  var offset = start;
  for (var i = 0; i < all.length; i++) {
    fileData.setUint32(78 + i * 8, offset);
    file.setRange(offset, offset + all[i].length, all[i]);
    offset += all[i].length;
  }
  return file;
}

void main() {
  test(
    'Converts UTF-8 MOBI to deterministic readable EPUB with valid mimetype',
    () {
      final source = BookFile(
        'sample.mobi',
        mobiFixture([
          utf8.encode('<p>İstanbul &amp; Türkçe.</p><p>Next paragraph.</p>'),
        ]),
      );
      final epub = convertBookToEpub(source);
      expect(epub.name, 'sample.epub');
      expect(convertBookToEpub(source).bytes, orderedEquals(epub.bytes));
      final archive = ZipDecoder().decodeBytes(epub.bytes);
      expect(archive.files.first.name, 'mimetype');
      expect(archive.files.first.compression, CompressionType.none);
      expect(utf8.decode(archive.files.first.content), 'application/epub+zip');
      final book = readBook(epub);
      expect(book.title, 'İstanbul & Reading');
      expect(book.paragraphs, ['İstanbul & Türkçe.', 'Next paragraph.']);
      expect(source.bytes.sublist(60, 68), ascii.encode('BOOKMOBI'));
    },
  );

  test('Decodes PalmDOC overlapping back references and indexing trailers', () {
    final compressed = [
      ...ascii.encode('<p>abc'),
      0x80,
      0x1b,
      ...ascii.encode('</p>'),
      0xaa,
      0x82,
    ];
    final source = BookFile(
      'compressed.mobi',
      mobiFixture(
        [compressed],
        compression: 2,
        trailing: 2,
        textLength: '<p>abcabcabc</p>'.length,
      ),
    );
    expect(readBook(convertBookToEpub(source)).paragraphs, ['abcabcabc']);
  });

  test('Joins UTF-8 characters across records before decoding', () {
    final text = utf8.encode('<p>İstanbul</p>');
    final first = [...text.sublist(0, 4), text[4], 1];
    final second = [...text.sublist(4), 0];
    final source = BookFile(
      'split.mobi',
      mobiFixture([first, second], trailing: 1, textLength: text.length),
    );
    expect(readBook(convertBookToEpub(source)).paragraphs, ['İstanbul']);
  });

  test('Rejects encrypted, malformed and unsupported compressed files', () {
    for (final bytes in [
      Uint8List(0),
      mobiFixture([ascii.encode('<p>Secret</p>')], encrypted: 2),
      mobiFixture([
        [0x80],
      ], compression: 2),
      mobiFixture([
        [1],
      ], compression: 17480),
    ]) {
      expect(
        () => convertBookToEpub(BookFile('bad.mobi', bytes)),
        throwsA(isA<BookReadException>()),
      );
    }
  });
}
