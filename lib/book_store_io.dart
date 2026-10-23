import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'books.dart';

class BookStore {
  Future<Directory> folder() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}${Platform.pathSeparator}e-books')
        .create(recursive: true);
  }

  Future<String> location() async => (await folder()).path;
  Future<List<BookFile>> scan() async {
    final books = <BookFile>[];
    await for (final entity in (await folder()).list()) {
      if (entity is File &&
          isBook(entity.path) &&
          await entity.length() <= 100 * 1024 * 1024) {
        books.add(
          BookFile(entity.uri.pathSegments.last, await entity.readAsBytes()),
        );
      }
    }
    books.sort((a, b) => a.name.compareTo(b.name));
    return books;
  }

  Future<void> add(BookFile book) async {
    final safeName = book.name.replaceAll(
      RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
      '_',
    );
    final directory = await folder();
    var destination = File(
      '${directory.path}${Platform.pathSeparator}$safeName',
    );
    var suffix = 1;
    while (await destination.exists()) {
      final dot = safeName.lastIndexOf('.');
      final stem = dot < 0 ? safeName : safeName.substring(0, dot);
      final ext = dot < 0 ? '' : safeName.substring(dot);
      destination = File(
        '${directory.path}${Platform.pathSeparator}$stem (${suffix++})$ext',
      );
    }
    await destination.writeAsBytes(book.bytes, flush: true);
  }
}
