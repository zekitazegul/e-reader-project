import 'app_language.dart';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'books.dart';
import 'reading_store.dart';
import 'bookmark_controls.dart';
import 'reader_navigation.dart';

class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({
    super.key,
    required this.book,
    required this.bookId,
    this.store,
    this.onPageCountChanged,
  });
  final BookFile book;
  final String bookId;
  final ReadingStore? store;
  final ValueChanged<int>? onPageCountChanged;
  @override
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  late final store = widget.store ?? ReadingStore.device;
  int? page;
  final controller = PdfViewerController();
  int pageCount = 0;
  int current = 1;

  Future<void> goToPage() async {
    final number = await showDialog<int>(
      context: context,
      builder: (_) => PageNumberDialog(current: current, total: pageCount),
    );
    if (mounted && number != null) {
      await controller.goToPage(pageNumber: number);
    }
  }

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
          const SnackBar(content: AppText('Okuma konumu kaydedilemiyor.')),
        );
      }
    });
  }

  Future<void> save(int? value) async {
    if (value == null) {
      return;
    }
    if (mounted) {
      setState(() => current = value);
    }
    try {
      await store.savePosition('pdf.${widget.bookId}', value);
    } catch (_) {
      warn();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.book.title),
      actions: [
        if (pageCount > 0)
          BookmarkControls(
            store: store,
            bookId: 'pdf.${widget.bookId}',
            position: current,
            label: (mark) =>
                '${widget.book.title} — ${tr(context, 'Sayfa $mark')}',
            onJump: (mark) =>
                controller.goToPage(pageNumber: mark.clamp(1, pageCount)),
          ),
      ],
    ),
    bottomNavigationBar: pageCount == 0
        ? null
        : SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton(
                    onPressed: goToPage,
                    child: AppText('$current / $pageCount'),
                  ),
                ),
              ],
            ),
          ),
    body: page == null
        ? const Center(child: CircularProgressIndicator())
        : PdfViewer.data(
            widget.book.bytes,
            controller: controller,
            sourceName: widget.bookId,
            initialPageNumber: page!,
            params: PdfViewerParams(
              onPageChanged: save,
              onViewerReady: (document, viewer) {
                if (mounted) {
                  setState(() {
                    pageCount = document.pages.length;
                    current = (viewer.pageNumber ?? page!).clamp(1, pageCount);
                  });
                  widget.onPageCountChanged?.call(pageCount);
                }
              },
            ),
          ),
  );
}
