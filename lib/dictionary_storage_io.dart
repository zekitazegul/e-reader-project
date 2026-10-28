import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<File> _file(String pair) async {
  if (!RegExp(r'^[a-z]{2}-[a-z]{2}$').hasMatch(pair)) {
    throw const FormatException('Invalid dictionary pair');
  }
  final base = await getApplicationSupportDirectory();
  final folder = await Directory('${base.path}/dictionaries')
      .create(recursive: true);
  return File('${folder.path}/$pair.json');
}

Future<String?> readDictionaryCache(String pair) async {
  final file = await _file(pair);
  return await file.exists() ? file.readAsString() : null;
}

Future<void> writeDictionaryCache(String pair, String data) async {
  final file = await _file(pair);
  await file.writeAsString(data, flush: true);
}
