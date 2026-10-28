import 'dart:io';

import 'package:e_reader/book_store_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class CachedFolderStore extends BookStore {
  CachedFolderStore(this.directory) : super(includeSampleBook: false);
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
    'Unchanged scans reuse bytes; changed and deleted files stay current',
    () async {
      final directory = await Directory.systemTemp.createTemp('reader-scan-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/test.epub');
      await file.writeAsBytes([1, 2]);
      final store = CachedFolderStore(directory);
      final first = (await store.scan()).single;
      expect(identical((await store.scan()).single, first), isTrue);
      await file.writeAsBytes([3, 4, 5]);
      final changed = (await store.scan()).single;
      expect(changed.bytes, [3, 4, 5]);
      expect(identical(changed, first), isFalse);
      final previousModified = await file.lastModified();
      await file.writeAsBytes([6, 7, 8]);
      await file.setLastModified(
        previousModified.add(const Duration(seconds: 2)),
      );
      expect((await store.scan()).single.bytes, [6, 7, 8]);
      await file.delete();
      expect(await store.scan(), isEmpty);
    },
  );
}
