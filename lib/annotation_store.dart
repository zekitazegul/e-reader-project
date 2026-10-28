import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BookAnnotation {
  const BookAnnotation({
    required this.id,
    required this.start,
    required this.end,
    required this.quote,
    this.note,
  });
  final String id;
  final int start, end;
  final String quote;
  final String? note;
  bool get isNote => note != null;
  Map<String, Object?> toJson() => {
    'id': id,
    'start': start,
    'end': end,
    'quote': quote,
    'note': note,
  };
  static BookAnnotation? fromJson(Object? value) {
    if (value is! Map ||
        value['id'] is! String ||
        value['start'] is! int ||
        value['end'] is! int ||
        value['quote'] is! String ||
        value['start'] < 0 ||
        value['end'] <= value['start'] ||
        (value['note'] != null && value['note'] is! String)) {
      return null;
    }
    return BookAnnotation(
      id: value['id'],
      start: value['start'],
      end: value['end'],
      quote: value['quote'],
      note: value['note'],
    );
  }
}

class AnnotationStore {
  late final _preferences = SharedPreferencesAsync();
  Future<void> _pending = Future<void>.value();
  Future<List<BookAnnotation>> load(String book) async {
    await _pending;
    final raw = await _preferences.getString('reader.annotations.v1.$book');
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('Invalid annotations');
    return decoded
        .map(BookAnnotation.fromJson)
        .whereType<BookAnnotation>()
        .toList();
  }

  Future<void> save(String book, List<BookAnnotation> annotations) {
    final data = jsonEncode(annotations.map((a) => a.toJson()).toList());
    _pending = _pending
        .catchError((Object _) {})
        .then(
          (_) => _preferences.setString('reader.annotations.v1.$book', data),
        );
    return _pending;
  }
}
