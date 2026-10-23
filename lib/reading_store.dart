import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReadingSettings {
  const ReadingSettings({
    this.font = 'Lora',
    this.size = 20,
    this.paper = 'ivory',
  });
  final String font;
  final double size;
  final String paper;
  Map<String, Object> toJson() => {'font': font, 'size': size, 'paper': paper};
  factory ReadingSettings.fromJson(Map<String, dynamic> json) {
    final size = json['size'];
    return ReadingSettings(
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

abstract class ReadingStore {
  static final ReadingStore device = DeviceReadingStore();
  Future<ReadingSettings> settings();
  Future<void> saveSettings(ReadingSettings settings);
  Future<int> position(String id);
  Future<void> savePosition(String id, int offset);
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
}
