import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'books.dart';
import 'reading_store.dart';

class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({
    super.key,
    required this.book,
    required this.bookId,
    this.store,
  });
  final BookFile book;
  final String bookId;
  final ReadingStore? store;
  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  late final store = widget.store ?? ReadingStore.device;
  int? page;
  bool warned = false;
  @override
  void initState() {
    super.initState();
    restore();
  }

  Future<void> restore() async {
    var saved = 1;
    try {
      saved = await store.position('pdf.${widget.bookId}');
    } catch (_) {
      warn();
    }
    if (mounted) {
      setState(() => page = saved < 1 ? 1 : saved);
    }
  }

  void warn() {
    if (warned || !mounted) {
      return;
    }
    warned = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Okuma konumu kaydedilemiyor.')),
        );
      }
    });
  }

  Future<void> save(int? value) async {
    if (value == null) {
      return;
    }
    try {
      await store.savePosition('pdf.${widget.bookId}', value);
    } catch (_) {
      warn();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.book.title)),
    body: page == null
        ? const Center(child: CircularProgressIndicator())
        : PdfViewer.data(
            widget.book.bytes,
            sourceName: widget.bookId,
            initialPageNumber: page!,
            params: PdfViewerParams(onPageChanged: save),
          ),
  );
}
