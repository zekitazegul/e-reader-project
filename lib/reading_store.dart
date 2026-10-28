import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReadingSettings {
  const ReadingSettings({
    this.font = 'Lora',
    this.size = 20,
    this.paper = 'ivory',
    this.layout = 'auto',
    this.lineHeight = 1.15,
    this.bookAnimations = true,
  });
  final String font;
  final double size;
  final String paper;
  final String layout;
  final double lineHeight;
  final bool bookAnimations;
  Map<String, Object> toJson() => {
    'font': font,
    'size': size,
    'paper': paper,
    'layout': layout,
    'lineHeight': lineHeight,
    'bookAnimations': bookAnimations,
    'spacingVersion': 3,
  };
  factory ReadingSettings.fromJson(Map<String, dynamic> json) {
    final size = json['size'];
    final lineHeight = json['lineHeight'];
    return ReadingSettings(
      bookAnimations: json['bookAnimations'] != false,
      layout:
          const [
            'auto',
            'single',
            'double',
            'triple',
            'quadruple',
          ].contains(json['layout'])
          ? json['layout'] as String
          : 'auto',
      lineHeight:
          (json['spacingVersion'] != 3 &&
              (lineHeight == 1.3 ||
                  (json['spacingVersion'] == null && lineHeight == 1.75)))
          ? 1.15
          : lineHeight is num && lineHeight.isFinite
          ? lineHeight.toDouble().clamp(1.0, 2.1)
          : 1.15,
      font: const ['Lora', 'Literata', 'Sistem'].contains(json['font'])
          ? json['font'] as String
          : 'Lora',
      size: size is num && size.isFinite ? size.toDouble().clamp(16, 32) : 20,
      paper:
          const [
            'ivory',
            'parchment',
            'white',
            'sage',
            'night',
          ].contains(json['paper'])
          ? json['paper'] as String
          : 'ivory',
    );
  }
}

class ReadingBookmark {
  const ReadingBookmark({
    required this.offset,
    this.title = '',
    this.createdAt,
  });
  final int offset;
  final String title;
  final DateTime? createdAt;
  Map<String, Object?> toJson() => {
    'offset': offset,
    'title': title,
    'createdAt': createdAt?.toUtc().toIso8601String(),
  };
  static ReadingBookmark? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final offset = value['offset'];
    if (offset is! int || offset < 0) return null;
    return ReadingBookmark(
      offset: offset,
      title: value['title'] is String ? value['title'] as String : '',
      createdAt: value['createdAt'] is String
          ? DateTime.tryParse(value['createdAt'] as String)
          : null,
    );
  }
}

abstract class ReadingStore {
  static final ReadingStore device = DeviceReadingStore();
  Future<ReadingSettings> settings();
  Future<void> saveSettings(ReadingSettings settings);
  Future<int> position(String id);
  Future<void> savePosition(String id, int offset);
  Future<List<ReadingBookmark>> bookmarks(String id);
  Future<void> saveBookmarks(String id, List<ReadingBookmark> marks);
}

class DeviceReadingStore implements ReadingStore {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  Future<void> _pending = Future.value();
  Future<void> _write(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.catchError((Object _) {});
    return result;
  }

  @override
  Future<ReadingSettings> settings() async {
    await _pending;
    final json = await _prefs.getString('reader.settings.v1');
    if (json == null) {
      return const ReadingSettings();
    }
    try {
      return ReadingSettings.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on FormatException {
      return const ReadingSettings();
    } on TypeError {
      return const ReadingSettings();
    }
  }

  @override
  Future<void> saveSettings(ReadingSettings settings) => _write(
    () => _prefs.setString('reader.settings.v1', jsonEncode(settings.toJson())),
  );
  @override
  Future<int> position(String id) async {
    await _pending;
    return (await _prefs.getInt('reader.position.v1.$id') ?? 0).clamp(
      0,
      0x7fffffff,
    );
  }

  @override
  Future<void> savePosition(String id, int offset) =>
      _write(() => _prefs.setInt('reader.position.v1.$id', offset));

  @override
  Future<List<ReadingBookmark>> bookmarks(String id) async {
    await _pending;
    final json = await _prefs.getString('reader.bookmarks.v2.$id');
    if (json != null) {
      final values = jsonDecode(json);
      if (values is! List) throw const FormatException('Invalid bookmarks');
      return values
          .map(ReadingBookmark.fromJson)
          .whereType<ReadingBookmark>()
          .toList()
        ..sort((a, b) => a.offset.compareTo(b.offset));
    }
    final values = await _prefs.getStringList('reader.bookmarks.v1.$id') ?? [];
    final marks =
        values
            .map(int.tryParse)
            .whereType<int>()
            .where((v) => v >= 0)
            .toSet()
            .toList()
          ..sort();
    final migrated = marks
        .map((offset) => ReadingBookmark(offset: offset))
        .toList();
    if (migrated.isNotEmpty) await saveBookmarks(id, migrated);
    return migrated;
  }

  @override
  Future<void> saveBookmarks(String id, List<ReadingBookmark> marks) {
    final unique = {
      for (final mark in marks)
        if (mark.offset >= 0) mark.offset: mark,
    };
    final values = unique.values.toList()
      ..sort((a, b) => a.offset.compareTo(b.offset));
    return _write(
      () => _prefs.setString(
        'reader.bookmarks.v2.$id',
        jsonEncode(values.map((mark) => mark.toJson()).toList()),
      ),
    );
  }
}
