import 'package:flutter/services.dart';

import 'books.dart';

const sampleBookName = 'Yalnız Efe.epub';
const bundledRemovalKey = 'library.bundled.removed.v1';

Future<BookFile> loadSampleBook() async {
  final data = await rootBundle.load('assets/books/yalniz-efe.epub');
  return BookFile(
    sampleBookName,
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    displayTitle: 'Yalnız Efe',
  );
}
