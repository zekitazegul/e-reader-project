import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_reader/books.dart';
import 'package:e_reader/main.dart';
import 'package:e_reader/paged_book.dart';

Uint8List zip(Map<String, String> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  test('EPUB follows spine order and resolves relative chapter paths', () {
    final content = readBook(
      BookFile(
        'test.epub',
        zip({
          'META-INF/container.xml': '<container><rootfiles><rootfile full-path="OPS/book.opf"/></rootfiles></container>',
          'OPS/book.opf': '<package><metadata><title>Test kitabı</title></metadata><manifest><item id="b" href="Text/b.xhtml"/><item id="a" href="Text/a.xhtml"/></manifest><spine><itemref idref="a"/><itemref idref="b"/></spine></package>',
          'OPS/Text/a.xhtml': '<html><body><p>Birinci bölüm.</p></body></html>',
          'OPS/Text/b.xhtml': '<html><body><p>İkinci bölüm.</p></body></html>',
        }),
      ),
    );
    expect(content.title, 'Test kitabı');
    expect(content.paragraphs, ['Birinci bölüm.', 'İkinci bölüm.']);
  });

  test('DOCX preserves runs inside paragraphs', () {
    final content = readBook(
      BookFile(
        'not.docx',
        zip({
          'word/document.xml': '<w:document xmlns:w="urn:test"><w:body><w:p><w:r><w:t>Merhaba </w:t></w:r><w:r><w:t>dünya</w:t></w:r></w:p></w:body></w:document>',
        }),
      ),
    );
    expect(content.paragraphs, ['Merhaba dünya']);
  });

  test('Corrupt and unsupported books produce readable errors', () {
    expect(
      () => readBook(BookFile('bad.epub', Uint8List(0))),
      throwsA(isA<BookReadException>()),
    );
    expect(
      () => readBook(BookFile('book.kfx', Uint8List(0))),
      throwsA(isA<BookReadException>()),
    );
  });

  testWidgets('Long text paginates and next page opens', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PagedBook(
            book: BookContent(
              'Uzun kitap',
              List.filled(
                35,
                'Bu paragraf sayfalara bölünerek okunur. Kelimeler kaybolmadan bir sonraki sayfaya taşınır.',
              ),
            ),
            paper: PaperTheme.ivory,
            font: 'Lora',
            fontSize: 20,
          ),
        ),
      ),
    );
    expect(find.textContaining('1 / '), findsOneWidget);
    await tester.tap(find.byTooltip('Sonraki sayfa'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 / '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
