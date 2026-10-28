import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'books.dart';

/// Read an explicitly declared EPUB cover; never guess from content images.
Uint8List? readBookCover(BookFile book) {
  if (book.extension != 'epub') return null;
  try {
    final archive = ZipDecoder().decodeBytes(book.bytes);
    if (archive.files.fold<int>(0, (sum, file) => sum + file.size) >
        100 * 1024 * 1024) {
      return null;
    }
    XmlDocument document(String path) =>
        XmlDocument.parse(utf8.decode(archive.findFile(path)!.content));
    final container = document('META-INF/container.xml');
    final root = container.descendants
        .whereType<XmlElement>()
        .firstWhere((e) => e.name.local == 'rootfile')
        .getAttribute('full-path')!;
    final package = document(root);
    final elements = package.descendants.whereType<XmlElement>();
    String? coverId;
    for (final e in elements) {
      if (e.name.local == 'meta' && e.getAttribute('name') == 'cover') {
        coverId = e.getAttribute('content');
      }
    }
    for (final item in elements.where((e) => e.name.local == 'item')) {
      final properties = (item.getAttribute('properties') ?? '').split(
        RegExp(r'\s+'),
      );
      if (!properties.contains('cover-image') &&
          (coverId == null || item.getAttribute('id') != coverId)) {
        continue;
      }
      final type = item.getAttribute('media-type');
      if (![
        'image/jpeg',
        'image/png',
        'image/webp',
        'image/gif',
      ].contains(type)) {
        continue;
      }
      final href = item.getAttribute('href');
      if (href == null) continue;
      final resolved = Uri(path: root).resolve(href);
      if (resolved.hasScheme || resolved.hasAuthority) continue;
      final file = archive.findFile(Uri.decodeComponent(resolved.path));
      if (file == null || file.size > 4 * 1024 * 1024) continue;
      return Uint8List.fromList(file.content);
    }
  } catch (_) {
    // Missing, malformed or unsupported covers use the cloth cover.
  }
  return null;
}
