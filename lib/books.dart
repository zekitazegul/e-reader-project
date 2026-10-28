import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html;
import 'package:xml/xml.dart';

import 'mobi_conversion.dart';
import 'epub_reference_pages.dart';
import 'book_reference_page.dart';
import 'book_print_catalog.dart';

const bookExtensions = [
  'epub',
  'pdf',
  'docx',
  'mobi',
  'prc',
  'azw',
  'azw3',
  'azw4',
  'kfx',
  'kpf',
];
String extensionOf(String name) => name.split('.').last.toLowerCase();
bool isBook(String name) => bookExtensions.contains(extensionOf(name));

final _readingWhitespace = RegExp(r'[\s\u00a0\u2007\u202f]+');

/// Normalize layout whitespace inside a paragraph, preserving paragraph breaks.
String normalizeReadingParagraph(String text) =>
    text.replaceAll(_readingWhitespace, ' ').trim();

String? cleanBookAuthor(String? value) {
  if (value == null) return null;
  final names = value.split(RegExp(r'[,;|]')).map((name) => name.trim()).where((
    name,
  ) {
    final normalized = name.replaceAll('İ', 'i').toLowerCase();
    return name.isNotEmpty &&
        !const {
          'bilinmeyen',
          'bilinmeyen yazar',
          'unknown',
          'unknown author',
          'belirtilmemiş',
        }.contains(normalized);
  }).toList();
  return names.isEmpty ? null : names.join(', ');
}

class BookFile {
  const BookFile(
    this.name,
    this.bytes, {
    this.displayTitle,
    this.cleanWhitespace = true,
  });
  final String name;
  final Uint8List bytes;
  final String? displayTitle;
  final bool cleanWhitespace;
  String get title =>
      displayTitle ??
      name.replaceFirst(RegExp(r'\.[^.]+$'), '').replaceAll('_', ' ');
  String get extension => extensionOf(name);
}

class BookContent {
  const BookContent(
    this.title,
    this.paragraphs, {
    this.author,
    this.referencePages = const [],
    this.printEdition,
  });
  final String title;
  final List<String> paragraphs;
  final String? author;
  final List<BookReferencePage> referencePages;
  final BookPrintEdition? printEdition;
}

class BookReadException implements Exception {
  const BookReadException(this.message);
  final String message;
  @override
  String toString() => message;
}

bool needsEpubConversion(BookFile book) =>
    ['mobi', 'prc'].contains(book.extension);

BookFile convertBookToEpub(BookFile book) {
  try {
    return BookFile('${book.title}.epub', mobiToEpub(book.bytes, book.title));
  } catch (_) {
    throw const BookReadException(
      'Kitap açılamadı. Dosya bozuk, şifreli veya desteklenmeyen bir yapıda olabilir.',
    );
  }
}

BookContent readBook(BookFile book) {
  if (!['epub', 'docx'].contains(book.extension)) {
    throw const BookReadException(
      'Bu Kindle biçimi henüz doğrudan okunamıyor. DRM koruması olmayan kitabı EPUB veya PDF biçimine dönüştürerek ekleyin.',
    );
  }
  try {
    final archive = ZipDecoder().decodeBytes(book.bytes);
    if (archive.files.fold<int>(0, (sum, file) => sum + file.size) >
        100 * 1024 * 1024) {
      throw const BookReadException(
        'Kitabın açılmış boyutu 100 MB sınırını aşıyor.',
      );
    }
    String source(String path) {
      final file = archive.findFile(path);
      if (file == null) {
        throw const BookReadException('Kitabın içeriği eksik veya bozuk.');
      }
      return utf8.decode(file.content);
    }

    if (book.extension == 'docx') {
      final document = XmlDocument.parse(source('word/document.xml'));
      final paragraphs = document.descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'p')
          .map(
            (p) => p.descendants
                .whereType<XmlElement>()
                .where(
                  (e) =>
                      e.name.local == 't' ||
                      e.name.local == 'tab' ||
                      e.name.local == 'br',
                )
                .map((e) => e.name.local == 't' ? e.innerText : ' ')
                .join(),
          )
          .map(
            (text) =>
                book.cleanWhitespace ? normalizeReadingParagraph(text) : text,
          )
          .where((text) => text.trim().isNotEmpty)
          .toList();
      if (paragraphs.isEmpty) {
        throw const BookReadException(
          'Bu belgede okunabilir metin bulunamadı.',
        );
      }
      final core = archive.findFile('docProps/core.xml');
      String? author;
      if (core != null) {
        try {
          final creators = XmlDocument.parse(utf8.decode(core.content))
              .descendants
              .whereType<XmlElement>()
              .where((e) => e.name.local == 'creator');
          if (creators.isNotEmpty) author = creators.first.innerText.trim();
        } catch (_) {
          // Optional author metadata must not prevent reading a valid document.
        }
      }
      return BookContent(
        book.title,
        paragraphs,
        author: cleanBookAuthor(author),
      );
    }
    final container = XmlDocument.parse(source('META-INF/container.xml'));
    final root = container.descendants
        .whereType<XmlElement>()
        .firstWhere((e) => e.name.local == 'rootfile')
        .getAttribute('full-path')!;
    final package = XmlDocument.parse(source(root));
    final manifest = <String, String>{};
    for (final item in package.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'item',
    )) {
      manifest[item.getAttribute('id')!] = item.getAttribute('href')!;
    }
    final paragraphs = <String>[];
    final referencePages = EpubReferencePages(archive, package, root);
    var textLength = 0;
    for (final ref in package.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'itemref',
    )) {
      final href = manifest[ref.getAttribute('idref')];
      if (href == null) {
        continue;
      }
      final path = Uri(path: root).resolve(href).path;
      final document = html.parse(source(path));
      document.querySelectorAll('script, style').forEach((e) => e.remove());
      final blocks = document.querySelectorAll(
        'h1, h2, h3, h4, p, li, blockquote',
      );
      final blockSet = blocks.toSet();
      final selected = blocks.isEmpty
          ? [if (document.body != null) document.body!]
          : blocks.where((element) {
              var parent = element.parent;
              while (parent != null) {
                if (blockSet.contains(parent)) return false;
                parent = parent.parent;
              }
              return true;
            }).toList();
      final mappedBlocks = <ReferenceTextBlock>[];
      for (final element in selected) {
        final raw = element.text;
        final text = book.cleanWhitespace
            ? normalizeReadingParagraph(raw)
            : raw.trim();
        if (text.isEmpty) continue;
        if (paragraphs.isNotEmpty) textLength += 2;
        mappedBlocks.add(ReferenceTextBlock(element, raw, text, textLength));
        paragraphs.add(text);
        textLength += text.length;
      }
      referencePages.addChapter(
        path,
        document,
        mappedBlocks,
        cleanWhitespace: book.cleanWhitespace,
      );
    }
    if (paragraphs.isEmpty) {
      throw const BookReadException(
        'Kitapta okunabilir metin bulunamadı. Görsel veya korumalı EPUB olabilir.',
      );
    }
    final titles = package.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'title',
    );
    return BookContent(
      titles.isEmpty ? book.title : titles.first.innerText,
      paragraphs,
      referencePages: referencePages.finish(),
      author: cleanBookAuthor(
        package.descendants
            .whereType<XmlElement>()
            .where((e) => e.name.local == 'creator')
            .map((e) => e.innerText.trim())
            .where((s) => s.isNotEmpty)
            .join(', '),
      ),
    );
  } on BookReadException {
    rethrow;
  } catch (_) {
    throw const BookReadException(
      'Kitap açılamadı. Dosya bozuk, şifreli veya desteklenmeyen bir yapıda olabilir.',
    );
  }
}
