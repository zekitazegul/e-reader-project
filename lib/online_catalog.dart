import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'books.dart';
import 'book_suggestions.dart';

String languageLabel(String codes) {
  const names = {
    'tr': 'Türkçe',
    'ru': 'Rusça',
    'ar': 'Arapça',
    'en': 'İngilizce',
    'fr': 'Fransızca',
    'de': 'Almanca',
    'es': 'İspanyolca',
    'it': 'İtalyanca',
  };
  if (codes.trim().isEmpty) return 'Dil belirtilmemiş';
  return codes
      .split(',')
      .map((code) => names[code.trim()] ?? code.trim())
      .join(', ');
}

class OnlineBook {
  const OnlineBook({
    required this.id,
    required this.title,
    required this.author,
    required this.url,
    required this.downloads,
    required this.languages,
  });
  final int id;
  final String title;
  final String author;
  final Uri url;
  final int downloads;
  final String languages;
}

class OnlineCatalog {
  OnlineCatalog({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  void close() => client.close();

  Future<List<OnlineBook>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final recognized = identifyBook(query);
    final terms = <String>{query.trim()};
    if (recognized != null) {
      terms.add(recognized.title);
      if (recognized.aliases.isNotEmpty) terms.add(recognized.aliases.first);
      for (final script in [
        RegExp(r'[\u0400-\u052f]'),
        RegExp(r'[\u0600-\u06ff]'),
      ]) {
        final aliases = recognized.aliases.where(script.hasMatch);
        if (aliases.isNotEmpty) terms.add(aliases.first);
      }
    }
    var successes = 0;
    final combined = <int, OnlineBook>{};
    final requests = [
      (term: recognized?.title ?? query.trim(), language: 'tr'),
      for (final term in terms) (term: term, language: null),
    ];
    await Future.wait(
      requests.map((request) async {
        try {
          final found = await _search(request.term, language: request.language);
          successes++;
          for (final book in found) {
            combined[book.id] = book;
          }
        } catch (_) {
          // Keep successful searches if an alternative title request fails.
        }
      }),
    );
    if (successes == 0) throw Exception('Arama servisi yanıt vermedi.');
    final books = combined.values.toList();
    books.sort((a, b) {
      bool turkish(OnlineBook book) =>
          book.languages.split(',').any((code) => code.trim() == 'tr');
      final languageOrder = (turkish(b) ? 1 : 0).compareTo(turkish(a) ? 1 : 0);
      if (languageOrder != 0) return languageOrder;
      final popularity = b.downloads.compareTo(a.downloads);
      return popularity == 0 ? a.id.compareTo(b.id) : popularity;
    });
    return books.take(32).toList();
  }

  Future<List<OnlineBook>> _search(String query, {String? language}) async {
    final response = await client
        .get(
          Uri.https('gutendex.com', '/books/', {
            'search': query.trim(),
            'copyright': 'false',
            'mime_type': 'application/epub+zip',
            'sort': 'popular',
            'languages': ?language,
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw Exception('Arama servisi yanıt vermedi.');
    }
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final books = <OnlineBook>[];
    for (final item in json['results'] as List) {
      if (item['copyright'] != false) continue;
      final url = Uri.tryParse(
        item['formats']['application/epub+zip'] as String? ?? '',
      );
      if (url == null ||
          url.scheme != 'https' ||
          !(url.host == 'gutenberg.org' ||
              url.host.endsWith('.gutenberg.org'))) {
        continue;
      }
      books.add(
        OnlineBook(
          id: item['id'] as int,
          title: item['title'] as String,
          author: (item['authors'] as List).map((a) => a['name']).join(', '),
          languages: (item['languages'] as List).join(', '),
          url: url,
          downloads: item['download_count'] as int? ?? 0,
        ),
      );
    }
    books.sort((a, b) => b.downloads.compareTo(a.downloads));
    return books;
  }

  Future<BookFile> download(OnlineBook book) async {
    const limit = 100 * 1024 * 1024;
    final response = await client
        .send(http.Request('GET', book.url))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) throw Exception('Kitap indirilemedi.');
    if ((response.contentLength ?? 0) > limit) {
      throw Exception('100 MB sınırı aşıldı.');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (bytes.length + chunk.length > limit) {
        throw Exception('100 MB sınırı aşıldı.');
      }
      bytes.add(chunk);
    }
    final data = bytes.takeBytes();
    if (data.length < 4 || data[0] != 0x50 || data[1] != 0x4b) {
      throw Exception('İndirilen dosya geçerli bir EPUB değil.');
    }
    final title = book.title.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    final shortTitle = title.length > 100 ? title.substring(0, 100) : title;
    return BookFile('$shortTitle - PG${book.id}.epub', data);
  }
}
