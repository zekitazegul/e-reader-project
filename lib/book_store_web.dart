import 'books.dart';
import 'sample_book.dart';

import 'package:shared_preferences/shared_preferences.dart';

class BookStore {
  BookStore({this.includeSampleBook = true});
  final bool includeSampleBook;
  bool get supportsFolderSelection => false;
  Future<bool> discoverFolder() async => false;
  Future<bool> selectFolder() async => false;
  Stream<void> changes() => const Stream<void>.empty();
  final List<BookFile> _books = [];
  Future<String> location() async =>
      'Web: kitaplar bu oturum boyunca tutulur. Kalıcı klasör taraması mobil ve Windows sürümlerindedir.';
  Future<List<BookFile>> scan() async => [
    if (includeSampleBook &&
        !(await SharedPreferencesAsync().getStringList(bundledRemovalKey) ?? [])
            .contains(sampleBookName))
      await loadSampleBook(),
    ..._books,
  ];
  Future<void> remove(BookFile book) async {
    if (book.name == sampleBookName) {
      final prefs = SharedPreferencesAsync();
      final removed = (await prefs.getStringList(bundledRemovalKey) ?? [])
          .toSet();
      removed.add(sampleBookName);
      await prefs.setStringList(bundledRemovalKey, removed.toList());
    }
    _books.remove(book);
  }

  Future<void> add(BookFile book) async => _books.add(book);
}
