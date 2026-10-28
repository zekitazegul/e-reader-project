import 'app_language.dart';

import 'package:flutter/material.dart';

import 'book_store.dart';
import 'online_catalog.dart';
import 'book_suggestions.dart';
import 'text_direction.dart';

class OnlineSearchPage extends StatefulWidget {
  const OnlineSearchPage({
    super.key,
    required this.query,
    required this.store,
    this.catalog,
  });
  final String query;
  final BookStore store;
  final OnlineCatalog? catalog;
  @override
  State<OnlineSearchPage> createState() => _OnlineSearchPageState();
}

class _OnlineSearchPageState extends State<OnlineSearchPage> {
  late final catalog = widget.catalog ?? OnlineCatalog();
  late final controller = TextEditingController(text: widget.query);
  List<OnlineBook> results = [];
  final downloaded = <int>{};
  bool busy = false;
  int? downloading;
  String? error;
  BookSuggestion? recognized;

  @override
  void initState() {
    super.initState();
    search();
  }

  @override
  void dispose() {
    controller.dispose();
    if (widget.catalog == null) catalog.close();
    super.dispose();
  }

  Future<void> search() async {
    if (busy || controller.text.trim().isEmpty) return;
    setState(() {
      busy = true;
      error = null;
      results = [];
      recognized = identifyBook(controller.text);
    });
    try {
      final found = await catalog.search(controller.text);
      if (mounted) setState(() => results = found);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'İnternette arama yapılamadı. Bağlantını kontrol edip tekrar dene.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> download(OnlineBook book) async {
    setState(() => downloading = book.id);
    try {
      final file = await catalog.download(book);
      await widget.store.add(file);
      if (mounted) {
        setState(() => downloaded.add(book.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('Kitap kitaplığına eklendi.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'Kitap indirilemedi veya kaydedilemedi. Bağlantını ve depolamayı kontrol et. Web’de kaynak indirmeye izin vermeyebilir.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => downloading = null);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('İnternette kitap ara')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const AppText(
          'Ücretsiz EPUB kitaplar · Project Gutenberg',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const AppText(
          'Ücretsiz EPUB kitaplarında önce Türkçe sürümler, ardından indirilme sayısı dikkate alınır. İlk 32 sonuç gösterilir. Katalog ağırlıklı olarak yabancı dildedir.',
        ),
        const SizedBox(height: 8),
        const AppText(
          'Bu eserler ABD’de kamu malıdır; bulunduğun ülkedeki telif koşullarını kontrol et.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          textDirection: directionForText(controller.text),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => search(),
          decoration: InputDecoration(
            labelText: tr(context, 'Kitap veya yazar adı'),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: tr(context, 'İnternette ara'),
              onPressed: busy ? null : search,
              icon: const Icon(Icons.search),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (busy) const LinearProgressIndicator(),
        if (recognized != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppText(
              'Alternatif adlarıyla da aranıyor: ${recognized!.label}',
            ),
          ),
        if (error != null) ...[
          AppText(error!),
          TextButton(onPressed: search, child: const AppText('Tekrar dene')),
        ],
        if (!busy && error == null && results.isEmpty)
          const AppText(
            'Uygun ücretsiz EPUB bulunamadı. Farklı bir kitap veya yazar adı dene.',
          ),
        for (final book in results)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    textDirection: directionForText(book.title),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    book.author,
                    textDirection: directionForText(book.author),
                  ),
                  AppText(
                    'EPUB · ${languageLabel(book.languages)} · ${book.downloads} indirme',
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed:
                        downloading != null || downloaded.contains(book.id)
                        ? null
                        : () => download(book),
                    icon: Icon(
                      downloaded.contains(book.id)
                          ? Icons.check
                          : Icons.download,
                    ),
                    label: AppText(
                      downloaded.contains(book.id)
                          ? 'Kitaplığa eklendi'
                          : downloading == book.id
                          ? 'İndiriliyor…'
                          : 'Ücretsiz indir',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
