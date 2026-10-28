import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'annotation_store.dart';
import 'app_language.dart';
import 'books.dart';

String _fingerprint(Uint8List bytes) => sha256.convert(bytes).toString();

class AnnotationIndexPage extends StatefulWidget {
  const AnnotationIndexPage({
    super.key,
    required this.books,
    required this.openBook,
  });
  final List<BookFile> books;
  final Future<void> Function(BookFile book, int offset) openBook;
  @override
  State<AnnotationIndexPage> createState() => _AnnotationIndexPageState();
}

class _AnnotationIndexPageState extends State<AnnotationIndexPage> {
  late Future<List<(BookFile, BookAnnotation)>> entries = load();
  bool opening = false;
  Future<List<(BookFile, BookAnnotation)>> load() async {
    final store = AnnotationStore();
    final result = <(BookFile, BookAnnotation)>[];
    final seen = <String>{};
    for (final book in widget.books) {
      final id = await compute(_fingerprint, book.bytes);
      if (!seen.add(id)) continue;
      final marks = await store.load(id)
        ..sort((a, b) => a.start.compareTo(b.start));
      result.addAll(marks.map((mark) => (book, mark)));
    }
    return result;
  }

  Future<void> open(BookFile book, BookAnnotation mark) async {
    if (opening) return;
    setState(() => opening = true);
    try {
      await widget.openBook(book, mark.start);
    } finally {
      if (mounted) {
        setState(() {
          opening = false;
          entries = load();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const AppText('Altı çizilenler ve notlar')),
    body: FutureBuilder<List<(BookFile, BookAnnotation)>>(
      future: entries,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: AppText('İşaretlemeler yüklenemedi.'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final marks = snapshot.data!;
        if (marks.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: AppText('Henüz altı çizilen metin veya not yok.'),
            ),
          );
        }
        return Column(
          children: [
            if (opening) const LinearProgressIndicator(),
            Expanded(
              child: ListView.separated(
                itemCount: marks.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final (book, mark) = marks[index];
                  return ListTile(
                    key: ValueKey('annotation-entry-${mark.id}-$index'),
                    leading: Icon(
                      mark.isNote
                          ? Icons.sticky_note_2_outlined
                          : Icons.format_underlined,
                    ),
                    title: Text(
                      mark.quote,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (mark.isNote)
                          Text(
                            mark.note!,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: opening ? null : () => open(book, mark),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}
