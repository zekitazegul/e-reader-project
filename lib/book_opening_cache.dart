import 'package:flutter/foundation.dart';

import 'books.dart';

/// Reuses decoded text without retaining an unbounded collection of books.
class BookOpeningCache {
  BookOpeningCache({
    this.maxCharacters = 4000000,
    this.maxBooks = 3,
    Future<BookContent> Function(BookFile)? decode,
  }) : _decode = decode ?? ((book) => compute(readBook, book));

  final int maxCharacters;
  final int maxBooks;
  final Future<BookContent> Function(BookFile) _decode;
  final _books = <String, BookContent>{};
  final _pending = <String, Future<BookContent>>{};
  int _characters = 0;

  int size(BookContent book) =>
      book.paragraphs.fold(0, (total, paragraph) => total + paragraph.length);

  Future<BookContent> open(String contentId, BookFile book) async {
    contentId = '$contentId:${book.cleanWhitespace ? 'clean-v1' : 'original'}';
    final cached = _books.remove(contentId);
    if (cached != null) {
      _books[contentId] = cached;
      return cached;
    }
    final pending = _pending[contentId];
    if (pending != null) return pending;
    final future = _load(contentId, book);
    _pending[contentId] = future;
    try {
      return await future;
    } finally {
      _pending.remove(contentId);
    }
  }

  Future<BookContent> _load(String contentId, BookFile book) async {
    final content = await _decode(book);
    final length = size(content);
    if (length <= maxCharacters && maxBooks > 0) {
      while (_books.isNotEmpty &&
          (_books.length >= maxBooks || _characters + length > maxCharacters)) {
        _characters -= size(_books.remove(_books.keys.first)!);
      }
      _books[contentId] = content;
      _characters += length;
    }
    return content;
  }
}
