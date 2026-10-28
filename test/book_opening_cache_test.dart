import 'dart:typed_data';

import 'package:e_reader/book_opening_cache.dart';
import 'package:e_reader/books.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final book = BookFile('test.epub', Uint8List(0));

  test(
    'Repeated and concurrent opens share decoded text; changed IDs reload',
    () async {
      var reads = 0;
      final cache = BookOpeningCache(
        decode: (_) async {
          reads++;
          return const BookContent('Title', ['text'], author: 'Author');
        },
      );
      final results = await Future.wait([
        cache.open('a', book),
        cache.open('a', book),
      ]);
      expect(reads, 1);
      expect(identical(results[0], results[1]), isTrue);
      expect((await cache.open('a', book)).author, 'Author');
      expect(reads, 1);
      await cache.open('changed-content', book);
      expect(reads, 2);
    },
  );

  test(
    'Cache evicts least recently used text within character budget',
    () async {
      var reads = 0;
      final cache = BookOpeningCache(
        maxCharacters: 8,
        decode: (_) async {
          reads++;
          return const BookContent('Title', ['text']);
        },
      );
      await cache.open('a', book);
      await cache.open('b', book);
      await cache.open('a', book);
      await cache.open('c', book);
      await cache.open('a', book);
      expect(reads, 3);
      await cache.open('b', book);
      expect(reads, 4);
    },
  );

  test('A failed decode can be retried', () async {
    var reads = 0;
    final cache = BookOpeningCache(
      decode: (_) async {
        if (++reads == 1) throw const BookReadException('Broken');
        return const BookContent('Title', ['text']);
      },
    );
    await expectLater(cache.open('a', book), throwsA(isA<BookReadException>()));
    expect((await cache.open('a', book)).paragraphs, ['text']);
  });
}
