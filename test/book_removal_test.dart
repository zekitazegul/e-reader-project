import 'dart:io';
import 'dart:typed_data';

import 'package:e_reader/book_store_io.dart';
import 'package:e_reader/books.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class FolderStore extends BookStore {
  FolderStore(this.directory) : super(includeSampleBook: false);
  final Directory directory;
  @override
  Future<Directory> folder() async => directory;
}

void main() {
  test(
    'Removed books stay out of scans while source files remain intact',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final directory = await Directory.systemTemp.createTemp(
        'reader-removal-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/Book.epub');
      await file.writeAsBytes([1, 2, 3]);
      final store = FolderStore(directory);
      final book = (await store.scan()).single;
      await store.remove(book);
      expect(await file.readAsBytes(), [1, 2, 3]);
      expect(await FolderStore(directory).scan(), isEmpty);
      // A new file with the same name but different content is not hidden.
      await file.writeAsBytes([4, 5]);
      expect((await store.scan()).single.bytes, [4, 5]);
      await store.add(BookFile('Restored.epub', Uint8List.fromList([1, 2, 3])));
      expect((await store.scan()).length, 2);
    },
  );
}
