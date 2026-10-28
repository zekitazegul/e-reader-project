import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_language.dart';
import 'book_print_catalog.dart';

class BookProgressResult {
  const BookProgressResult({this.referenceTotal, this.goToScreen = false});
  final int? referenceTotal;
  final bool goToScreen;
}

class BookProgressDialog extends StatefulWidget {
  const BookProgressDialog({
    super.key,
    required this.screenLabel,
    required this.progress,
    required this.canNavigate,
    this.referenceLabel,
    this.referenceTotal,
    this.printEdition,
    this.screenTotal,
  });
  final String screenLabel;
  final double progress;
  final String? referenceLabel;
  final int? referenceTotal;
  final BookPrintEdition? printEdition;
  final int? screenTotal;
  final bool canNavigate;

  @override
  State<BookProgressDialog> createState() => _BookProgressDialogState();
}

class _BookProgressDialogState extends State<BookProgressDialog> {
  late final total = TextEditingController(
    text: widget.referenceTotal?.toString() ?? '',
  );
  String? error;

  @override
  void dispose() {
    total.dispose();
    super.dispose();
  }

  void save() {
    final raw = total.text.trim();
    final value = int.tryParse(raw);
    if (raw.isNotEmpty && (value == null || value < 1 || value > 100000)) {
      setState(
        () => error = tr(context, 'Geçerli bir toplam sayfa sayısı gir.'),
      );
      return;
    }
    Navigator.pop(context, BookProgressResult(referenceTotal: value ?? 0));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const AppText('Kitap sayfası ve ilerleme'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('Ekran sayfası'),
          Text(widget.screenLabel),
          const SizedBox(height: 12),
          if (widget.referenceTotal != null && widget.screenTotal != null) ...[
            const AppText('Sayfa karşılığı'),
            Text(
              '${tr(context, '1 kitap sayfası')} ≈ '
              '${(widget.screenTotal! / widget.referenceTotal!).toStringAsFixed(2)} '
              '${tr(context, 'ekran sayfası')}',
            ),
            const SizedBox(height: 12),
          ],
          if (widget.printEdition != null &&
              widget.referenceTotal == widget.printEdition!.pages) ...[
            const AppText('Referans baskı'),
            Text(widget.printEdition!.description),
            const SizedBox(height: 8),
            const AppText(
              'Baskı ve içerik farkları nedeniyle sayfa karşılığı yaklaşık değerdir.',
            ),
            const SizedBox(height: 8),
            const AppText('Kaynak'),
            SelectableText(widget.printEdition!.sources.join('\n\n')),
            const SizedBox(height: 12),
          ],
          const AppText('Kitaptaki konum'),
          Text('%${(widget.progress * 100).toStringAsFixed(1)}'),
          const SizedBox(height: 12),
          if (widget.referenceLabel != null) ...[
            const AppText('Kitabın sayfa işareti'),
            Text(widget.referenceLabel!),
            const SizedBox(height: 8),
            const AppText(
              'Bu numara dosyadaki sabit sayfa işaretinden alınır. Baskıya göre değişebilir.',
            ),
          ] else ...[
            const AppText('Bu konum için dosyada basılı sayfa bilgisi yok.'),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('reference-page-total'),
              controller: total,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: tr(context, 'Basılı toplam sayfa'),
                errorText: error,
              ),
              onSubmitted: (_) => save(),
            ),
            const SizedBox(height: 8),
            AppText(
              widget.printEdition == null
                  ? 'Toplamı kendi baskından gir. Gösterilen kitap sayfası, metindeki konumuna göre tahmin edilir; basılı sayfayla birebir eşleşmez. Boş bırakarak tahmini kapatabilirsin.'
                  : 'Toplamı kendi baskına göre değiştirebilirsin. Boş bırakırsan referans baskının toplamı kullanılır.',
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: widget.canNavigate
            ? () => Navigator.pop(
                context,
                const BookProgressResult(goToScreen: true),
              )
            : null,
        child: const AppText('Ekran sayfasına git'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const AppText('Kapat'),
      ),
      if (widget.referenceLabel == null)
        FilledButton(onPressed: save, child: const AppText('Kaydet')),
    ],
  );
}
