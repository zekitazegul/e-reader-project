import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';

import 'pdf_reader.dart';

import 'book_store.dart';
import 'books.dart';
import 'main.dart';

String bookFingerprint(Uint8List bytes) => sha256.convert(bytes).toString();

String searchKey(String text) =>
    text.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, this.store});
  final BookStore? store;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with WidgetsBindingObserver {
  late final store = widget.store ?? BookStore();
  List<BookFile> books = [];
  String location = '';
  String query = '';
  List<BookFile> get filteredBooks => books
      .where((book) => searchKey(book.title).contains(searchKey(query.trim())))
      .toList();
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) {
      refresh();
    }
  }

  Future<void> refresh() async {
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final path = await store.location();
      final found = await store.scan();
      if (mounted) {
        setState(() {
          books = found;
          location = path;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Kitap klasörü okunamadı. Yeniden deneyin.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> add() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      var skipped = 0;
      for (final file in files) {
        final size = await file.length();
        if (!isBook(file.name) || (size != null && size > 100 * 1024 * 1024)) {
          skipped++;
          continue;
        }
        final bytes = await file.readAsBytes();
        if (bytes.length > 100 * 1024 * 1024) {
          skipped++;
          continue;
        }
        await store.add(BookFile(file.name, bytes));
      }
      await refresh();
      if (skipped > 0 && mounted) {
        message(
          '$skipped dosya eklenmedi: desteklenmeyen uzantı veya 100 MB sınırı.',
        );
      }
    } catch (_) {
      if (mounted) {
        message('Dosya eklenemedi. Tekrar deneyin.');
      }
    }
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> open(BookFile book) async {
    try {
      final id = await compute(bookFingerprint, book.bytes);
      if (!mounted) {
        return;
      }
      if (book.extension == 'pdf') {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => PdfReaderPage(book: book, bookId: id),
          ),
        );
        return;
      }
      final content = await compute(readBook, book);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReaderPage(book: content, bookId: id),
        ),
      );
    } on BookReadException catch (e) {
      if (mounted) {
        message(e.message);
      }
    } catch (_) {
      if (mounted) {
        message('Kitap açılamadı. Dosyayı kontrol edin.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/branding/e-reader-logo.png',
              width: 32,
              height: 32,
            ),
          ),
          const SizedBox(width: 8),
          const Flexible(child: Text('E-Reader')),
        ],
      ),
      actions: [
        IconButton(
          onPressed: busy ? null : refresh,
          tooltip: 'Klasörü tara',
          icon: const Icon(Icons.refresh),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: MediaQuery.sizeOf(context).width < 400
              ? IconButton(
                  tooltip: 'Kitap ekle',
                  onPressed: busy ? null : add,
                  icon: const Icon(Icons.add),
                )
              : FilledButton.icon(
                  onPressed: busy ? null : add,
                  icon: const Icon(Icons.add),
                  label: const Text('Kitap ekle'),
                ),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Kitaplığım',
            style: TextStyle(fontFamily: 'Lora', fontSize: 34),
          ),
          const SizedBox(height: 8),
          const Text('Bir kitap seç. Yeni bir dünyaya açıl.'),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Kitaplığında ara',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 20),
          if (books.isNotEmpty && filteredBooks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aramana uygun kitap bulunamadı.'),
            ),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (books.isEmpty && !busy)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  const Icon(Icons.menu_book_outlined, size: 64),
                  const SizedBox(height: 16),
                  const Text('Rafların ilk kitabını bekliyor.'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: add,
                    child: const Text('Kitaplarını ekle'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ReaderPage(),
                      ),
                    ),
                    child: const Text('Okuma görünümünü dene'),
                  ),
                ],
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = (constraints.maxWidth / 165).floor().clamp(1, 7);
              return Column(
                children: [
                  for (var row = 0; row * columns < filteredBooks.length; row++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 30),
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Color(0xFF9A7450),
                            width: 12,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x15000000),
                            blurRadius: 10,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var column = 0; column < columns; column++)
                            Expanded(
                              child:
                                  row * columns + column < filteredBooks.length
                                  ? cover(
                                      filteredBooks[row * columns + column],
                                      row * columns + column,
                                    )
                                  : const SizedBox(),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          ExpansionTile(
            title: const Text('Kitap klasörü ve biçimler'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(location),
                    const SizedBox(height: 12),
                    const Text(
                      'e-books klasörü açılışta, uygulamaya dönüldüğünde ve yenile düğmesiyle taranır. Dosya başına sınır: 100 MB.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'EPUB ve DOCX: metin okuma. PDF: özgün sayfa görünümü. MOBI, PRC, AZW, AZW3, AZW4, KFX ve KPF: kitaplığa eklenir; okumak için EPUB/PDF dönüşümü gerekir. DRM korumalı içerik açılamaz.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget cover(BookFile book, int index) {
    const colors = [
      Color(0xFF476658),
      Color(0xFF8A5346),
      Color(0xFF4D6076),
      Color(0xFF867042),
    ];
    final native = ['epub', 'pdf', 'docx'].contains(book.extension);
    return Semantics(
      button: true,
      label: '${book.title}, ${book.extension}',
      child: InkWell(
        onTap: () => open(book),
        child: Container(
          height: 210,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors[index % colors.length],
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(6),
            ),
            gradient: LinearGradient(
              colors: [
                colors[index % colors.length].withValues(alpha: 0.7),
                colors[index % colors.length],
                colors[index % colors.length],
              ],
              stops: const [0, 0.08, 1],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x30000000),
                blurRadius: 5,
                offset: Offset(3, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_stories, color: Color(0xFFE7D7B6)),
              const SizedBox(height: 16),
              Expanded(
                child: Text(
                  book.title,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Lora',
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                book.extension.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFFE7D7B6),
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
              if (!native)
                const Text(
                  'Dönüşüm gerekli',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
