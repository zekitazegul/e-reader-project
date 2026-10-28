import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BookTitles {
  final _titles = <String, String>{};
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final raw = await SharedPreferencesAsync().getString('library.titles.v1');
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in data.entries) {
          if (entry.value is String &&
              (entry.value as String).trim().isNotEmpty) {
            _titles[entry.key] = entry.value as String;
          }
        }
      } on FormatException {
        // Damaged metadata must not prevent reading the source books.
      } on TypeError {
        // Ignore invalid metadata from an older or damaged preference file.
      }
    }
    _loaded = true;
  }

  String? title(String? id) => _titles[id];
}
