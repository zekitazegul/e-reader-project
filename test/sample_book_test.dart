import 'dart:io';

import 'package:e_reader/book_store_io.dart' as native;
import 'package:e_reader/book_store_web.dart' as web;
import 'package:e_reader/books.dart';
import 'package:e_reader/sample_book.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class BundledFolderStore extends native.BookStore {
  BundledFolderStore(this.directory);
  final Directory directory;
  @override
  Future<Directory> folder() async => directory;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'Bundled EPUB has complete Latin-script Turkish story and credits',
    () async {
      final content = readBook(await loadSampleBook());
      expect(content.title, 'Yalnız Efe');
      expect(content.author, 'Ömer Seyfettin');
      final text = content.paragraphs.join('\n');
      expect(text, contains('Sabahtan beri yürüyorduk.'));
      expect(text, contains('nur iner mi?'));
      expect(text, contains('CC BY-SA 4.0'));
      expect(text, contains('169450'));
      expect(text.length, greaterThan(7000));
    },
  );

  test('Native initial library includes sample; removal survives new store and content hash changes', () async {
    final directory = await Directory.systemTemp.createTemp('reader-sample-');
    addTearDown(() => directory.delete(recursive: true));
    final store = BundledFolderStore(directory);
    final book = (await store.scan()).single;
    expect(book.name, sampleBookName);
    await store.remove(book);
    // A future repackaging of the EPUB must not undo the user's choice.
    await SharedPreferencesAsync().remove('library.removed.v1');
    expect(await BundledFolderStore(directory).scan(), isEmpty);
  });

  test(
    'Web initial library includes sample and remembers its removal',
    () async {
      final store = web.BookStore();
      final book = (await store.scan()).single;
      expect(book.name, sampleBookName);
      await store.remove(book);
      expect(await web.BookStore().scan(), isEmpty);
    },
  );
}
