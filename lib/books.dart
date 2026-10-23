import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html;
import 'package:xml/xml.dart';

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

class BookFile {
  const BookFile(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
  String get title =>
      name.replaceFirst(RegExp(r'\.[^.]+$'), '').replaceAll('_', ' ');
  String get extension => extensionOf(name);
}

class BookContent {
  const BookContent(this.title, this.paragraphs);
  final String title;
  final List<String> paragraphs;
}

class BookReadException implements Exception {
  const BookReadException(this.message);
  final String message;
  @override
  String toString() => message;
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
          .where((text) => text.trim().isNotEmpty)
          .toList();
      if (paragraphs.isEmpty) {
        throw const BookReadException(
          'Bu belgede okunabilir metin bulunamadı.',
        );
      }
      return BookContent(book.title, paragraphs);
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
      if (blocks.isEmpty) {
        final text = document.body?.text.trim() ?? '';
        if (text.isNotEmpty) {
          paragraphs.add(text);
        }
      } else {
        paragraphs.addAll(
          blocks
              .where((e) {
                var parent = e.parent;
                while (parent != null) {
                  if (blocks.contains(parent)) {
                    return false;
                  }
                  parent = parent.parent;
                }
                return true;
              })
              .map((e) => e.text.trim())
              .where((s) => s.isNotEmpty),
        );
      }
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
    );
  } on BookReadException {
    rethrow;
  } catch (_) {
    throw const BookReadException(
      'Kitap açılamadı. Dosya bozuk, şifreli veya desteklenmeyen bir yapıda olabilir.',
    );
  }
}
