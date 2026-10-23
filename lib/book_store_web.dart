import 'books.dart';

class BookStore {
  final List<BookFile> _books = [];
  Future<String> location() async =>
      'Web: kitaplar bu oturum boyunca tutulur. Kalıcı klasör taraması mobil ve Windows sürümlerindedir.';
  Future<List<BookFile>> scan() async => List.of(_books);
  Future<void> add(BookFile book) async => _books.add(book);
}
