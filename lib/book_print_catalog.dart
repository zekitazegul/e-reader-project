import 'dart:convert';

import 'package:flutter/services.dart';

/// A researched reference edition, not a claim that every digital file has
/// identical contents or printed page boundaries.
class BookPrintEdition {
  const BookPrintEdition({
    required this.title,
    required this.pages,
    required this.publisher,
    required this.sources,
    this.date = '',
    this.isbn = '',
    this.isBundle = false,
  });
  final String title;
  final int pages;
  final String publisher;
  final String date;
  final String isbn;
  final List<String> sources;
  final bool isBundle;

  String get description => [
    title,
    publisher,
    if (date.isNotEmpty) date,
    if (isbn.isNotEmpty) 'ISBN $isbn',
  ].join(' · ');

  double? screensPerPage(int? screens) =>
      screens != null && screens > 0 ? screens / pages : null;
}

String printCatalogKey(String value) {
  var result = value.toLowerCase();
  const replacements = {
    'ı': 'i',
    'İ': 'i',
    'ç': 'c',
    'ğ': 'g',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'â': 'a',
    'î': 'i',
    'û': 'u',
  };
  for (final entry in replacements.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result.replaceAll(RegExp('[^a-z0-9]'), '');
}

class BookPrintCatalog {
  BookPrintCatalog.fromJson(List<dynamic> rows) {
    for (final raw in rows.cast<Map<String, dynamic>>()) {
      final pages = raw['pages'] as int?;
      if (pages == null || pages <= 0) continue;
      final edition = BookPrintEdition(
        title: raw['editionTitle'] as String,
        pages: pages,
        publisher: raw['publisher'] as String,
        date: raw['date'] as String? ?? '',
        isbn: raw['isbn'] as String? ?? '',
        sources: List<String>.from(raw['sources'] as List),
        isBundle: raw.containsKey('components'),
      );
      for (final alias in List<String>.from(raw['aliases'] as List)) {
        _files[printCatalogKey(alias)] = edition;
      }
      for (final title in List<String>.from(raw['titles'] as List)) {
        _titles[printCatalogKey(title)] = (
          author: printCatalogKey(raw['author'] as String),
          edition: edition,
        );
      }
    }
  }

  final _files = <String, BookPrintEdition>{};
  final _titles = <String, ({String author, BookPrintEdition edition})>{};
  static Future<BookPrintCatalog>? _loaded;
  static Future<BookPrintCatalog> load() => _loaded ??= rootBundle
      .loadString('assets/books/print_editions.json')
      .then((text) => BookPrintCatalog.fromJson(jsonDecode(text) as List))
      .catchError((Object _) => BookPrintCatalog.fromJson(const []));

  BookPrintEdition? find(String filename, {String? title, String? author}) {
    final stem = filename.replaceFirst(
      RegExp(r'\.(epub|mobi|pdf|prc|docx|azw3?)$', caseSensitive: false),
      '',
    );
    final direct = _files[printCatalogKey(stem)];
    if (direct != null) return direct;
    // No fuzzy or ISBN-only match: several source volumes share one ISBN.
    final match = _titles[printCatalogKey(title ?? stem)];
    final authorKey = printCatalogKey(author ?? '');
    if (match == null || authorKey.isEmpty) return null;
    if (match.author == authorKey ||
        (match.author.contains('fethullahgulen') &&
            authorKey.contains('fethullahgulen'))) {
      return match.edition;
    }
    return null;
  }
}
