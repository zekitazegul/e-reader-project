import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:e_reader/books.dart';
import 'package:e_reader/mobi_library_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  test('Only the EPUB is listed for a converted source, in either order', () {
    final mobi = BookFile('Book 1 - Author.mobi', Uint8List(0));
    final epub = BookFile('Book 1 - Author.epub', Uint8List(0));
    final other = BookFile('Book 2 - Author.mobi', Uint8List(0));
    final pdf = BookFile('Book 1 - Author.pdf', Uint8List(0));
    expect(preferConvertedEpubs([mobi, epub, other, pdf]), [epub, other, pdf]);
    expect(preferConvertedEpubs([epub, mobi]), [epub]);
    expect(preferConvertedEpubs([mobi, other]), [mobi, other]);
    final prc = BookFile('BOOK 1 - AUTHOR.PRC', Uint8List(0));
    expect(preferConvertedEpubs([prc, epub]), [epub]);
  });
  test('Reuses converted EPUB across restarts; changed or missing files regenerate', () async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    var calls = 0;
    final library = <BookFile>[];
    Future<BookFile> convert(BookFile source) async {
      calls++;
      return BookFile('Book.epub', Uint8List.fromList([7, ...source.bytes]));
    }

    Future<void> add(BookFile book) async {
      library.add(book);
    }

    final source = BookFile('Book.mobi', Uint8List.fromList([1, 2, 3]));
    final first = await MobiLibraryCache(convert: convert)
        .resolve(source, library: library, add: add);
    expect(first.$2, isTrue);
    final renamed = BookFile('Renamed.epub', first.$1.bytes);
    String id(BookFile book) => sha256.convert(book.bytes).toString();
    expect(await MobiLibraryCache().libraryEntries([source, renamed], id), [
      renamed,
    ]);
    expect(await MobiLibraryCache().libraryEntries([source], id), [source]);
    final second = await MobiLibraryCache(convert: convert)
        .resolve(source, library: library, add: add);
    expect(second.$2, isFalse);
    expect(calls, 1);
    expect(library, hasLength(1));
    final changed = BookFile('Book.mobi', Uint8List.fromList([4, 5]));
    await MobiLibraryCache(convert: convert)
        .resolve(changed, library: library, add: add);
    expect(calls, 2);
    library.clear();
    await MobiLibraryCache(convert: convert)
        .resolve(source, library: library, add: add);
    expect(calls, 3);
    expect(library, hasLength(1));
  });
}
