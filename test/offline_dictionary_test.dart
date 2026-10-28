import 'dart:convert';

import 'package:e_reader/offline_dictionary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class ConsentDictionary extends OfflineDictionary {
  int downloads = 0;
  @override
  Future<Map<String, List<String>>?> load(String source, String target) async =>
      downloads == 0
      ? null
      : {
          'haus': ['ev'],
        };
  @override
  Future<void> download(String source, String target) async {
    downloads++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty(),
  );
  test(
    'All six bundled language pairs work without any network request',
    () async {
      var requests = 0;
      final repository = OfflineDictionary(
        client: MockClient((_) async {
          requests++;
          throw StateError('No network allowed');
        }),
      );
      for (final entry in [
        ('nl', 'tr', 'huis', 'ev'),
        ('nl', 'en', 'huis', 'house'),
        ('en', 'tr', 'book', 'kitap'),
        ('en', 'nl', 'house', 'huis'),
        ('tr', 'en', 'kitap', 'book'),
        ('tr', 'nl', 'kitap', 'boek'),
      ]) {
        final dictionary = await repository.load(entry.$1, entry.$2);
        expect(dictionary, isNotNull);
        expect(dictionary!.length, greaterThan(1000));
        final result = repository.lookup(dictionary, entry.$3, entry.$1);
        expect(
          result.first.$2.any((s) => s.toLowerCase().contains(entry.$4)),
          isTrue,
          reason: '${entry.$1}-${entry.$2}',
        );
      }
      expect(requests, 0);
    },
  );

  test('Paragraph lookup reports individual meanings and missing words', () {
    final repository = OfflineDictionary();
    final result = repository.lookup(
      {
        'huis': ['ev'],
        'boek': ['kitap'],
      },
      'Huis, boek en huis.',
      'nl',
    );
    expect(result.map((r) => r.$1), ['Huis', 'boek', 'en']);
    expect(result.last.$2, isEmpty);
    expect(dictionaryWord('IŞIK', 'tr'), 'ışık');
  });

  test(
    'Downloaded data is cached locally; lookup sends no selected text',
    () async {
      final cache = <String, String>{};
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect(request.url.path, endsWith('/deu-tur.tei'));
        expect(request.url.query, isEmpty);
        expect(request.body, isEmpty);
        return http.Response(
          '''<TEI xmlns="http://www.tei-c.org/ns/1.0"><teiHeader><availability><ref target="https://creativecommons.org/licenses/by-sa/3.0/legalcode"/></availability></teiHeader><text><body><entry><form><orth>Haus</orth></form><sense><cit type="trans"><quote>ev</quote></cit></sense></entry></body></text></TEI>''',
          200,
        );
      });
      final repository = OfflineDictionary(
        client: client,
        readCache: (pair) async => cache[pair],
        writeCache: (pair, data) async {
          cache[pair] = data;
        },
      );
      expect(await repository.load('de', 'tr'), isNull);
      expect(requests, 0);
      await repository.download('de', 'tr');
      expect((await repository.load('de', 'tr'))!['haus'], ['ev']);
      expect(jsonDecode(cache['de-tr']!)['haus'], ['ev']);
      expect(requests, 1);
    },
  );

  testWidgets('Extra dictionary download requires explicit consent', (
    tester,
  ) async {
    final repository = ConsentDictionary();
    await SharedPreferencesAsync().setString('dictionary.source.v1', 'de');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DictionarySheet(text: 'Haus', repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.downloads, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Download dictionary'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(repository.downloads, 0);
    await tester.tap(
      find.text(
        MaterialLocalizations.of(tester.element(find.byType(AlertDialog)))
            .cancelButtonLabel,
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.downloads, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Download dictionary'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Download dictionary').last,
    );
    await tester.pumpAndSettle();
    expect(repository.downloads, 1);
    expect(find.text('ev'), findsOneWidget);
  });
}
