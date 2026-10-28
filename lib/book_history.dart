import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'books.dart';

List<String> _ids(List<BookFile> books) =>
    books.map((b) => sha256.convert(b.bytes).toString()).toList();

class BookHistory {
  BookHistory({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  final _idsByBook = Expando<String>();
  final Map<String, Map<String, int>> _dates = {};
  final Set<String> _favorites = {};
  bool loaded = false;
  Future<void> register(List<BookFile> books) async {
    SharedPreferencesAsync? prefs;
    try {
      prefs = SharedPreferencesAsync();
    } catch (_) {
      /* Use memory when no preference backend exists. */
    }
    if (!loaded) {
      try {
        _favorites.addAll(
          await prefs?.getStringList('library.favorites.v1') ?? [],
        );
      } catch (_) {}
      String? raw;
      try {
        raw = await prefs?.getString('library.history.v1');
      } catch (_) {
        /* Keep history in memory when preferences are unavailable. */
      }
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          for (final entry in decoded.entries) {
            if (entry.value is! Map) continue;
            final data = entry.value as Map;
            _dates[entry.key] = {
              for (final key in ['added', 'read', 'clean'])
                if (data[key] is int) key: data[key] as int,
            };
          }
        } catch (_) {
          /* A damaged history must not prevent library access. */
        }
      }
      loaded = true;
    }
    final unknown = books.where((book) => _idsByBook[book] == null).toList();
    final byteCount = unknown.fold<int>(
      0,
      (total, book) => total + book.bytes.length,
    );
    final ids = unknown.isEmpty
        ? const <String>[]
        : byteCount <= 128 * 1024
        ? _ids(unknown)
        : await compute(_ids, unknown);
    for (var i = 0; i < unknown.length; i++) {
      _idsByBook[unknown[i]] = ids[i];
    }
    final now = _now().microsecondsSinceEpoch;
    var changed = false;
    for (final book in books) {
      final id = _idsByBook[book]!;
      if (!_dates.containsKey(id)) {
        _dates[id] = {'added': now, 'clean': 1};
        changed = true;
      }
    }
    if (changed) {
      try {
        await prefs?.setString('library.history.v1', jsonEncode(_dates));
      } catch (_) {
        /* Retain the in-memory history. */
      }
    }
  }

  int added(BookFile book) => _dates[_idsByBook[book]]?['added'] ?? 0;
  String? id(BookFile book) => _idsByBook[book];
  bool isFavorite(BookFile book) => _favorites.contains(id(book));

  Future<void> setFavorite(BookFile book, bool favorite) async {
    if (id(book) == null) await register([book]);
    final next = {..._favorites};
    if (favorite) {
      next.add(id(book)!);
    } else {
      next.remove(id(book));
    }
    await SharedPreferencesAsync().setStringList(
      'library.favorites.v1',
      next.toList(),
    );
    _favorites
      ..clear()
      ..addAll(next);
  }

  bool shouldClean(BookFile book) => _idsByBook[book] == null
      ? book.cleanWhitespace
      : _dates[_idsByBook[book]]?['clean'] == 1;
  int read(BookFile book) => _dates[_idsByBook[book]]?['read'] ?? 0;
  Future<void> markRead(BookFile book) async {
    if (_idsByBook[book] == null) await register([book]);
    _dates[_idsByBook[book]]!['read'] = _now().microsecondsSinceEpoch;
    try {
      await SharedPreferencesAsync().setString(
        'library.history.v1',
        jsonEncode(_dates),
      );
    } catch (_) {
      /* Reading remains available without persistent history. */
    }
  }
}
