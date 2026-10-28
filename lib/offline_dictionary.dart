import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

import 'app_language.dart';
import 'dictionary_storage.dart';
import 'selection_labels.dart';

const dictionaryLanguages = {
  'tr': 'tur',
  'en': 'eng',
  'nl': 'nld',
  'de': 'deu',
  'fr': 'fra',
  'es': 'spa',
  'it': 'ita',
  'pt': 'por',
  'ru': 'rus',
  'pl': 'pol',
  'cs': 'ces',
  'da': 'dan',
  'fi': 'fin',
  'sv': 'swe',
  'no': 'nor',
  'el': 'ell',
  'id': 'ind',
  'ja': 'jpn',
  'lt': 'lit',
  'ca': 'cat',
};
const bundledDictionaryLanguages = {'tr', 'en', 'nl'};

String dictionaryWord(String word, String language) {
  if (language == 'tr') word = word.replaceAll('I', 'ı').replaceAll('İ', 'i');
  return word.toLowerCase().trim().replaceAll('’', "'");
}

Map<String, List<String>> parseDictionaryTei((String, String) source) {
  final document = XmlDocument.parse(source.$1);
  const ns = 'http://www.tei-c.org/ns/1.0';
  // The downloadable files explicitly grant the data's redistribution license.
  final license = document
      .findAllElements('availability', namespaceUri: ns)
      .firstOrNull;
  if (license == null ||
      !license
          .findAllElements('ref', namespaceUri: ns)
          .any(
            (ref) =>
                ref
                    .getAttribute('target')
                    ?.contains('creativecommons.org/licenses/by-sa/') ==
                true,
          )) {
    throw const FormatException('Dictionary license missing');
  }
  final result = <String, List<String>>{};
  for (final entry in document.findAllElements('entry', namespaceUri: ns)) {
    final equivalents = <String>{};
    for (final cit
        in entry
            .findAllElements('cit', namespaceUri: ns)
            .where((c) => c.getAttribute('type') == 'trans')) {
      equivalents.addAll(
        cit
            .findAllElements('quote', namespaceUri: ns)
            .map((q) => q.innerText.trim())
            .where((s) => s.isNotEmpty),
      );
    }
    if (equivalents.isEmpty) continue;
    for (final form in entry.findElements('form', namespaceUri: ns)) {
      for (final orth in form.findElements('orth', namespaceUri: ns)) {
        final key = dictionaryWord(orth.innerText, source.$2);
        if (key.isEmpty) continue;
        result[key] = {...?result[key], ...equivalents}.toList();
      }
    }
  }
  if (result.isEmpty) throw const FormatException('Empty dictionary');
  return result;
}

class OfflineDictionary {
  OfflineDictionary({
    http.Client? client,
    Future<String?> Function(String)? readCache,
    Future<void> Function(String, String)? writeCache,
  }) : client = client ?? http.Client(),
       readCache = readCache ?? readDictionaryCache,
       writeCache = writeCache ?? writeDictionaryCache;
  static final instance = OfflineDictionary();
  final http.Client client;
  final Future<String?> Function(String) readCache;
  final Future<void> Function(String, String) writeCache;
  final _loaded = <String, Future<Map<String, List<String>>?>>{};
  Future<Map<String, List<String>>?> load(String source, String target) {
    final pair = '$source-$target';
    return _loaded.putIfAbsent(pair, () async {
      final bundled =
          bundledDictionaryLanguages.contains(source) &&
          bundledDictionaryLanguages.contains(target);
      final raw = bundled
          ? await rootBundle.loadString('assets/dictionaries/$pair.json')
          : await readCache(pair);
      if (raw == null) return null;
      return (jsonDecode(raw) as Map).map(
        (key, value) => MapEntry(key as String, (value as List).cast<String>()),
      );
    });
  }

  Future<void> download(String source, String target) async {
    final from = dictionaryLanguages[source], to = dictionaryLanguages[target];
    if (from == null || to == null || source == target) {
      throw const FormatException('Unsupported language');
    }
    Future<http.StreamedResponse> fetch(String path) => client
        .send(http.Request('GET', Uri.https('download.wikdict.com', path)))
        .timeout(const Duration(seconds: 30));
    var response = await fetch('/dictionaries/tei/recommended/$from-$to.tei');
    if (response.statusCode == 404) {
      await response.stream.drain<void>();
      response = await fetch(
        '/dictionaries/tei/recommended/small/$from-$to.tei',
      );
    }
    if (response.statusCode != 200) {
      throw const FormatException('Dictionary unavailable');
    }
    const maximum = 100 * 1024 * 1024;
    if ((response.contentLength ?? 0) > maximum) {
      throw const FormatException('Dictionary too large');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (bytes.length + chunk.length > maximum) {
        throw const FormatException('Dictionary too large');
      }
      bytes.add(chunk);
    }
    final data = await compute(parseDictionaryTei, (
      utf8.decode(bytes.takeBytes()),
      source,
    ));
    final pair = '$source-$target';
    await writeCache(pair, jsonEncode(data));
    _loaded[pair] = Future.value(data);
  }

  List<(String, List<String>)> lookup(
    Map<String, List<String>> dictionary,
    String text,
    String language,
  ) {
    final exact = dictionary[dictionaryWord(text, language)];
    if (exact != null) return [(text, exact)];
    final words = RegExp(
      r"[\p{L}\p{M}]+(?:['’\-][\p{L}\p{M}]+)*",
      unicode: true,
    ).allMatches(text).map((match) => match[0]!).toList();
    final seen = <String>{};
    return [
      for (final word in words)
        if (seen.add(dictionaryWord(word, language)))
          (word, dictionary[dictionaryWord(word, language)] ?? <String>[]),
    ];
  }
}

Future<void> showOfflineDictionary(BuildContext context, String selection) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DictionarySheet(text: selection),
    );

class DictionarySheet extends StatefulWidget {
  const DictionarySheet({super.key, required this.text, this.repository});
  final String text;
  final OfflineDictionary? repository;
  @override
  State<DictionarySheet> createState() => _DictionarySheetState();
}

class _DictionarySheetState extends State<DictionarySheet> {
  OfflineDictionary get repository =>
      widget.repository ?? OfflineDictionary.instance;
  String source = 'nl', target = 'tr';
  Map<String, List<String>>? dictionary;
  bool busy = true, failed = false;
  int revision = 0;
  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    try {
      final prefs = SharedPreferencesAsync();
      final from = await prefs.getString('dictionary.source.v1');
      final to = await prefs.getString('dictionary.target.v1');
      if (!mounted) return;
      source = dictionaryLanguages.containsKey(from) ? from! : 'nl';
      target = bundledDictionaryLanguages.contains(to) && to != source
          ? to!
          : (source == 'tr' ? 'en' : 'tr');
    } catch (_) {
      /* Bundled defaults work without stored preferences. */
    }
    if (mounted) await load();
  }

  Future<void> load() async {
    final current = ++revision;
    setState(() {
      busy = true;
      failed = false;
      dictionary = null;
    });
    try {
      final data = await repository.load(source, target);
      if (mounted && current == revision) setState(() => dictionary = data);
      final prefs = SharedPreferencesAsync();
      await prefs.setString('dictionary.source.v1', source);
      await prefs.setString('dictionary.target.v1', target);
    } catch (_) {
      if (mounted && current == revision) setState(() => failed = true);
    } finally {
      if (mounted && current == revision) setState(() => busy = false);
    }
  }

  Future<void> download() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(selectionLabel(context, 'download')),
        content: Text(
          '${appLanguages[source]} → ${appLanguages[target]}\n\n${selectionLabel(context, 'downloadInfo')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(selectionLabel(context, 'download')),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => busy = true);
    try {
      await repository.download(source, target);
      if (mounted) await load();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          failed = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(selectionLabel(context, 'downloadError'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = dictionary == null
        ? <(String, List<String>)>[]
        : repository.lookup(dictionary!, widget.text, source);
    return FractionallySizedBox(
      heightFactor: .8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectionLabel(context, 'dictionary'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('dictionary-source-$source'),
                    initialValue: source,
                    decoration: InputDecoration(
                      labelText: selectionLabel(context, 'source'),
                    ),
                    isExpanded: true,
                    items: [
                      for (final code in dictionaryLanguages.keys)
                        DropdownMenuItem(
                          value: code,
                          child: Text(
                            appLanguages[code]!,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) {
                            if (value == null) return;
                            source = value;
                            if (target == source) {
                              target = source == 'tr' ? 'en' : 'tr';
                            }
                            load();
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('dictionary-target-$source-$target'),
                    initialValue: target,
                    decoration: InputDecoration(
                      labelText: selectionLabel(context, 'target'),
                    ),
                    isExpanded: true,
                    items: [
                      for (final code in ['tr', 'en', 'nl'])
                        if (code != source)
                          DropdownMenuItem(
                            value: code,
                            child: Text(
                              appLanguages[code]!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) {
                            if (value == null) return;
                            target = value;
                            load();
                          },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (busy) const LinearProgressIndicator(),
          Expanded(
            child: busy
                ? const SizedBox.shrink()
                : dictionary == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (failed)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              selectionLabel(context, 'loadingError'),
                            ),
                          ),
                        FilledButton.icon(
                          onPressed: download,
                          icon: const Icon(Icons.download),
                          label: Text(selectionLabel(context, 'download')),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(selectionLabel(context, 'meanings')),
                      ),
                      for (final result in results)
                        ListTile(
                          title: Text(result.$1),
                          subtitle: Text(
                            result.$2.isEmpty
                                ? selectionLabel(context, 'missing')
                                : result.$2.join(' · '),
                          ),
                        ),
                    ],
                  ),
          ),
          TextButton(
            onPressed: () => showLicensePage(context: context),
            child: const Text('FreeDict + WikDict · CC BY-SA 3.0'),
          ),
        ],
      ),
    );
  }
}
