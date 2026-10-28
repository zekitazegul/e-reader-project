import 'app_language.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String normalizeBookSearch(String value) =>
    value.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

List<int> findBookMatches(String text, String query, {int limit = 200}) {
  final needle = normalizeBookSearch(query.trim());
  if (needle.isEmpty) return [];
  final haystack = normalizeBookSearch(text);
  final matches = <int>[];
  var from = 0;
  while (matches.length < limit) {
    final found = haystack.indexOf(needle, from);
    if (found < 0) break;
    matches.add(found);
    from = found + needle.length;
  }
  return matches;
}

class BookSearchSelection {
  const BookSearchSelection(this.offset, this.query);
  final int offset;
  final String query;
}

class BookSearchDialog extends StatefulWidget {
  const BookSearchDialog({
    super.key,
    required this.text,
    required this.pageStarts,
    this.pageNumbersReady = true,
  });
  final String text;
  final List<int> pageStarts;
  final bool pageNumbersReady;
  @override
  State<BookSearchDialog> createState() => _BookSearchDialogState();
}

class _BookSearchDialogState extends State<BookSearchDialog> {
  final controller = TextEditingController();
  List<int> matches = [];
  String query = '';
  bool searched = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void search() {
    setState(() {
      query = controller.text.trim();
      searched = true;
      matches = findBookMatches(widget.text, query);
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const AppText('Kitap içinde ara'),
    content: SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            onSubmitted: (_) => search(),
            decoration: InputDecoration(
              labelText: tr(context, 'Kelime veya ifade'),
              suffixIcon: IconButton(
                tooltip: tr(context, 'Metinde ara'),
                onPressed: search,
                icon: const Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (searched)
            AppText(
              query.isEmpty
                  ? 'Aramak için bir kelime yaz.'
                  : matches.isEmpty
                  ? 'Eşleşme bulunamadı.'
                  : '${matches.length == 200 ? "İlk " : ""}${matches.length} eşleşme',
            ),
          if (matches.isNotEmpty)
            Flexible(
              child: SizedBox(
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final offset = matches[index];
                    final page =
                        widget.pageStarts.lastIndexWhere(
                          (start) => start <= offset,
                        ) +
                        1;
                    final snippet = widget.text
                        .substring(
                          math.max(0, offset - 30),
                          math.min(
                            widget.text.length,
                            offset + query.length + 65,
                          ),
                        )
                        .replaceAll('\n', ' ');
                    return ListTile(
                      title: AppText(
                        widget.pageNumbersReady
                            ? 'Sayfa $page'
                            : 'Eşleşme ${index + 1}',
                      ),
                      subtitle: Text(
                        snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(
                        context,
                        BookSearchSelection(offset, query),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const AppText('Kapat'),
      ),
    ],
  );
}

class PageNumberDialog extends StatefulWidget {
  const PageNumberDialog({
    super.key,
    required this.current,
    required this.total,
    this.isScreenPage = false,
  });
  final int current;
  final int total;
  final bool isScreenPage;
  @override
  State<PageNumberDialog> createState() => _PageNumberDialogState();
}

class _PageNumberDialogState extends State<PageNumberDialog> {
  late final controller = TextEditingController(text: '${widget.current}');
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    final number = int.tryParse(controller.text);
    if (number == null || number < 1 || number > widget.total) {
      setState(() => error = '1–${widget.total} arasında bir sayfa gir.');
      return;
    }
    Navigator.pop(context, number);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: AppText(widget.isScreenPage ? 'Ekran sayfasına git' : 'Sayfaya git'),
    content: TextField(
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: (_) => submit(),
      decoration: InputDecoration(
        labelText: tr(
          context,
          widget.isScreenPage ? 'Ekran sayfası' : 'Sayfa numarası',
        ),
        helperText: tr(context, 'Toplam ${widget.total} sayfa'),
        errorText: error == null ? null : tr(context, error!),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const AppText('İptal'),
      ),
      FilledButton(onPressed: submit, child: const AppText('Git')),
    ],
  );
}
