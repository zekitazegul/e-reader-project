import 'dart:convert';

import 'package:e_reader/book_store.dart';
import 'package:e_reader/books.dart';
import 'package:e_reader/online_catalog.dart';
import 'package:e_reader/online_search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object> entry(
  int id,
  int downloads, {
  bool copyrighted = false,
  String host = 'www.gutenberg.org',
}) => {
  'id': id,
  'title': 'Kitap $id',
  'authors': [
    {'name': 'Yazar'},
  ],
  'languages': ['tr'],
  'copyright': copyrighted,
  'download_count': downloads,
  'formats': {'application/epub+zip': 'https://$host/cache/$id.epub'},
};

class DownloadStore extends BookStore {
  final saved = <BookFile>[];
  @override
  Future<void> add(BookFile book) async => saved.add(book);
}

void main() {
  test('Misspelled multilingual titles expand aliases, deduplicate and prefer Turkish', () async {
    final requests = <String>{};
    final catalog = OnlineCatalog(
      client: MockClient((request) async {
        final term = request.url.queryParameters['search']!;
        requests.add(term);
        final turkish = request.url.queryParameters['languages'] == 'tr';
        final item = entry(turkish ? 10 : 20, turkish ? 2 : 1000);
        item['languages'] = turkish ? ['tr'] : ['ru'];
        return http.Response(
          jsonEncode({
            'results': [item],
          }),
          200,
        );
      }),
    );
    addTearDown(catalog.close);
    final result = await catalog.search('Montr Ktisto kontu');
    expect(
      requests,
      containsAll([
        'Montr Ktisto kontu',
        'Monte Kristo Kontu',
        'Monte Cristo',
        'Граф Монте-Кристо',
        'الكونت دي مونت كريستو',
      ]),
    );
    expect(result.map((book) => book.id), [10, 20]);
    expect(languageLabel('tr, ru, ar'), 'Türkçe, Rusça, Arapça');
  });

  test(
    'A failed alternative does not discard successful language results',
    () async {
      final catalog = OnlineCatalog(
        client: MockClient((request) async {
          if (request.url.queryParameters['languages'] == 'tr') {
            return http.Response('Unavailable', 503);
          }
          return http.Response(
            jsonEncode({
              'results': [entry(1, 2)],
            }),
            200,
          );
        }),
      );
      addTearDown(catalog.close);
      expect((await catalog.search('kitap')).single.id, 1);
    },
  );
  test(
    'Search requests free readable books and ranks popular downloads first',
    () async {
      final catalog = OnlineCatalog(
        client: MockClient((request) async {
          expect(request.url.queryParameters['search'], 'İstanbul');
          expect(request.url.queryParameters['copyright'], 'false');
          expect(
            request.url.queryParameters['mime_type'],
            'application/epub+zip',
          );
          expect(request.url.queryParameters['sort'], 'popular');
          return http.Response(
            jsonEncode({
              'results': [
                entry(1, 3),
                entry(2, 90),
                entry(3, 100, copyrighted: true),
                entry(4, 120, host: 'example.com'),
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(catalog.close);
      final result = await catalog.search(' İstanbul ');
      expect(result.map((b) => b.id), [2, 1]);
    },
  );

  test('Invalid download responses never become books', () async {
    final catalog = OnlineCatalog(
      client: MockClient((_) async => http.Response('<html>Error</html>', 200)),
    );
    addTearDown(catalog.close);
    final book = OnlineBook(
      id: 1,
      title: 'Kitap',
      author: '',
      downloads: 1,
      languages: 'tr',
      url: Uri.https('www.gutenberg.org', '/1.epub'),
    );
    await expectLater(catalog.download(book), throwsException);
  });

  testWidgets(
    'Search result downloads into the library and prevents repeat taps',
    (tester) async {
      final catalog = OnlineCatalog(
        client: MockClient((request) async {
          if (request.url.host == 'gutendex.com') {
            return http.Response(
              jsonEncode({
                'results': [entry(1, 30)],
              }),
              200,
            );
          }
          return http.Response.bytes([0x50, 0x4b, 3, 4], 200);
        }),
      );
      addTearDown(catalog.close);
      final store = DownloadStore();
      await tester.pumpWidget(
        MaterialApp(
          home: OnlineSearchPage(
            query: 'Kitap',
            store: store,
            catalog: catalog,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kitap 1'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Ücretsiz indir'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(store.saved.single.name, 'Kitap 1 - PG1.epub');
      expect(find.text('Kitaplığa eklendi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
