import 'app_language.dart';

import 'package:flutter/material.dart';

import 'reading_store.dart';
import 'text_direction.dart';

String bookmarkDate(DateTime? date) {
  if (date == null) return 'Eklenme tarihi bilinmiyor';
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}

class BookmarkControls extends StatefulWidget {
  const BookmarkControls({
    super.key,
    required this.store,
    required this.bookId,
    required this.position,
    required this.label,
    required this.onJump,
    this.canAdd = true,
  });
  final ReadingStore store;
  final String bookId;
  final int position;
  final String Function(int) label;
  final ValueChanged<int> onJump;
  final bool canAdd;

  @override
  State<BookmarkControls> createState() => _BookmarkControlsState();
}

class _BookmarkControlsState extends State<BookmarkControls> {
  List<ReadingBookmark> marks = [];
  bool busy = true;

  @override
  void initState() {
    super.initState();
    restore();
  }

  void warn() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Ayraçlar kaydedilemiyor veya yüklenemiyor.'),
        ),
      );
    }
  }

  Future<void> restore() async {
    try {
      final saved = await widget.store.bookmarks(widget.bookId);
      if (mounted) setState(() => marks = saved);
    } catch (_) {
      warn();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggle() async {
    final next = [...marks];
    final existing = next.indexWhere((mark) => mark.offset == widget.position);
    if (existing >= 0) {
      next.removeAt(existing);
    } else {
      if (!widget.canAdd) return;
      final position = widget.position;
      final title = widget.label(position);
      next.add(
        ReadingBookmark(
          offset: position,
          title: title,
          createdAt: DateTime.now(),
        ),
      );
    }
    next.sort((a, b) => a.offset.compareTo(b.offset));
    setState(() => busy = true);
    try {
      await widget.store.saveBookmarks(widget.bookId, next);
      if (mounted) setState(() => marks = next);
    } catch (_) {
      warn();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: tr(
          context,
          marks.any((mark) => mark.offset == widget.position)
              ? 'Ayracı kaldır'
              : 'Ayraç ekle',
        ),
        onPressed:
            busy ||
                (!widget.canAdd &&
                    !marks.any((mark) => mark.offset == widget.position))
            ? null
            : toggle,
        icon: Icon(
          marks.any((mark) => mark.offset == widget.position)
              ? Icons.bookmark
              : Icons.bookmark_border,
        ),
      ),
      PopupMenuButton<int>(
        tooltip: tr(context, 'Ayraçlar'),
        enabled: !busy,
        icon: const Icon(Icons.bookmarks_outlined),
        onSelected: widget.onJump,
        itemBuilder: (_) => marks.isEmpty
            ? [
                const PopupMenuItem(
                  enabled: false,
                  child: AppText('Henüz ayraç yok.'),
                ),
              ]
            : [
                for (final mark in marks)
                  PopupMenuItem(
                    value: mark.offset,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mark.title.isEmpty
                                ? widget.label(mark.offset)
                                : mark.title,
                            textDirection: directionForText(
                              mark.title.isEmpty
                                  ? widget.label(mark.offset)
                                  : mark.title,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            bookmarkDate(mark.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
      ),
    ],
  );
}
