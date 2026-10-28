import 'package:flutter/material.dart';

import 'app_language.dart';
import 'books.dart';
import 'book_print_catalog.dart';

typedef BookDetails = ({
  String? author,
  int? pages,
  BookPrintEdition? edition,
  int? printPages,
});

class BookDetailsDialog extends StatelessWidget {
  const BookDetailsDialog({
    super.key,
    required this.book,
    required this.title,
    required this.details,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.onRemove,
  });
  final BookFile book;
  final String title;
  final Future<BookDetails> details;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const AppText('Kitap bilgileri'),
    content: SingleChildScrollView(
      child: FutureBuilder<BookDetails>(
        future: details,
        builder: (context, snapshot) {
          final author = cleanBookAuthor(snapshot.data?.author);
          final pages = snapshot.data?.pages;
          final edition = snapshot.data?.edition;
          final printPages = snapshot.data?.printPages;
          final ratio = printPages != null && pages != null && pages > 0
              ? pages / printPages
              : null;
          Widget field(String label, String value) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(label, style: Theme.of(context).textTheme.labelMedium),
                SelectableText(value),
              ],
            ),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              field('Kitap adı', title),
              if (author != null) field('Yazar', author),
              field('Dosya türü', book.extension.toUpperCase()),
              field('Dosya adı', book.name),
              field(
                'Dosya boyutu',
                book.bytes.length < 1024 * 1024
                    ? '${(book.bytes.length / 1024).toStringAsFixed(0)} KB'
                    : '${(book.bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB',
              ),
              field(
                'Sayfa sayısı',
                pages == null ? tr(context, 'Henüz hesaplanmadı') : '$pages',
              ),
              if (book.extension != 'pdf')
                const AppText('Sayfa sayısı son okuma düzenine göredir.'),
              if (book.extension != 'pdf') ...[
                const SizedBox(height: 12),
                field(
                  'Basılı toplam sayfa',
                  printPages?.toString() ??
                      tr(
                        context,
                        'Doğrulanmış basılı sayfa sayısı bulunamadı.',
                      ),
                ),
                if (ratio != null)
                  field(
                    'Sayfa karşılığı',
                    '${tr(context, '1 kitap sayfası')} ≈ '
                        '${ratio.toStringAsFixed(2)} ${tr(context, 'ekran sayfası')}',
                  ),
                if (printPages != null && ratio == null)
                  const AppText('Karşılık, kitap açıldığında hesaplanır.'),
                if (edition != null && printPages == edition.pages) ...[
                  const SizedBox(height: 12),
                  field('Referans baskı', edition.description),
                  const AppText(
                    'Baskı ve içerik farkları nedeniyle sayfa karşılığı yaklaşık değerdir.',
                  ),
                  const SizedBox(height: 8),
                  field('Kaynak', edition.sources.join('\n\n')),
                ],
              ],
              if (snapshot.connectionState != ConnectionState.done)
                const LinearProgressIndicator(),
            ],
          );
        },
      ),
    ),
    actions: [
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onToggleFavorite != null)
            OutlinedButton.icon(
              onPressed: onToggleFavorite,
              icon: Icon(isFavorite ? Icons.star : Icons.star_border),
              label: AppText(isFavorite ? 'Üst raftan çıkar' : 'Üst rafa koy'),
            ),
          if (onRemove != null)
            OutlinedButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              label: const AppText('Kitaplıktan kaldır'),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(MaterialLocalizations.of(context).closeButtonLabel),
            ),
          ),
        ],
      ),
    ],
  );
}
