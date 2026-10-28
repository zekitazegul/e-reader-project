final _dictionaries = <String, String>{};
Future<String?> readDictionaryCache(String pair) async => _dictionaries[pair];
Future<void> writeDictionaryCache(String pair, String data) async {
  _dictionaries[pair] = data;
}
