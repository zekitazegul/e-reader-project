import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

import 'books.dart';

String _contentId(Uint8List bytes) => sha256.convert(bytes).toString();
Future<BookFile> _convert(BookFile source) =>
    compute(convertBookToEpub, source);

/// Prefer the converted format in the library without deleting source files.
/// Match the entire original filename stem, preserving volume/author suffixes.
List<BookFile> preferConvertedEpubs(List<BookFile> books) {
  String stem(BookFile book) =>
      book.name.replaceFirst(RegExp(r'\.[^.]+$'), '').toLowerCase();
  final epubs = books
      .where((book) => book.extension == 'epub')
      .map(stem)
      .toSet();
  return books
      .where(
        (book) => !needsEpubConversion(book) || !epubs.contains(stem(book)),
      )
      .toList();
}

/// Maps source contents to a verified EPUB already present in the library.
class MobiLibraryCache {
  MobiLibraryCache({this.convert = _convert});
  final Future<BookFile> Function(BookFile) convert;

  Future<List<BookFile>> libraryEntries(
    List<BookFile> books,
    String? Function(BookFile) fingerprint,
  ) async {
    final preferred = preferConvertedEpubs(books);
    if (!preferred.any(needsEpubConversion)) return preferred;
    final epubIds = books
        .where((book) => book.extension == 'epub')
        .map(fingerprint)
        .whereType<String>()
        .toSet();
    if (epubIds.isEmpty) return preferred;
    final prefs = SharedPreferencesAsync();
    final visible = await Future.wait(
      preferred.map((book) async {
        if (!needsEpubConversion(book)) return book;
        final id = fingerprint(book);
        if (id == null) return book;
        try {
          final convertedId = await prefs.getString('library.mobi.epub.v1.$id');
          if (epubIds.contains(convertedId)) return null;
        } catch (_) {
          // Optional cache failures must not hide an unconverted source.
        }
        return book;
      }),
    );
    return visible.whereType<BookFile>().toList();
  }

  Future<(BookFile book, bool added)> resolve(
    BookFile source, {
    required List<BookFile> library,
    required Future<void> Function(BookFile) add,
  }) async {
    final prefs = SharedPreferencesAsync();
    final sourceId = await compute(_contentId, source.bytes);
    final key = 'library.mobi.epub.v1.$sourceId';
    final savedId = await prefs.getString(key);
    final epubs = library.where((book) => book.extension == 'epub').toList();
    if (savedId != null) {
      for (final book in epubs) {
        if (await compute(_contentId, book.bytes) == savedId) {
          return (book, false);
        }
      }
    }
    final converted = await convert(source);
    final convertedId = await compute(_contentId, converted.bytes);
    BookFile? existing;
    for (final book in epubs) {
      if (await compute(_contentId, book.bytes) == convertedId) {
        existing = book;
        break;
      }
    }
    if (existing == null) await add(converted);
    await prefs.setString(key, convertedId);
    return (existing ?? converted, existing == null);
  }
}
