import 'app_language.dart';

import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'books.dart';
import 'main.dart';
import 'bookmark_controls.dart';
import 'reading_store.dart';
import 'reader_navigation.dart';
import 'text_direction.dart';
import 'text_pagination.dart';
import 'directional_pager.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'annotation_store.dart';
import 'offline_dictionary.dart';
import 'reader_selectable_text.dart';
import 'selection_labels.dart';
import 'book_reference_page.dart';
import 'book_progress_dialog.dart';

import 'package:shared_preferences/shared_preferences.dart';

class PagedBook extends StatefulWidget {
  const PagedBook({
    super.key,
    required this.book,
    required this.paper,
    required this.font,
    required this.fontSize,
    this.initialOffset = 0,
    this.onPositionChanged,
    this.onPageCountChanged,
    this.bookId,
    this.store,
    this.layout = 'auto',
    this.lineHeight = 1.15,
    this.controlsVisible = true,
    this.onToggleControls,
    this.onToggleFullscreen,
    this.onEscape,
    this.onPinch,
  });
  final String layout;
  final double lineHeight;
  final bool controlsVisible;
  final VoidCallback? onToggleControls;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onEscape;
  final ValueChanged<double>? onPinch;
  final String? bookId;
  final ReadingStore? store;
  final int initialOffset;
  final ValueChanged<int>? onPositionChanged;
  final ValueChanged<int>? onPageCountChanged;
  final BookContent book;
  final PaperTheme paper;
  final String font;
  final double fontSize;
  @override
  State<PagedBook> createState() => PagedBookState();
}

class PagedBookState extends State<PagedBook> {
  final annotationStore = AnnotationStore();
  List<BookAnnotation> annotations = [];
  int annotationRevision = 0;
  String get annotationBook =>
      widget.bookId ?? sha256.convert(utf8.encode(bookText)).toString();
  @override
  void initState() {
    super.initState();
    loadAnnotations();
    loadReferenceTotal();
  }

  int? _manualReferenceTotal;
  int? get referenceTotal =>
      _manualReferenceTotal ?? widget.book.printEdition?.pages;

  Future<void> loadReferenceTotal() async {
    final id = widget.bookId;
    if (id == null) return;
    try {
      final saved = await SharedPreferencesAsync().getInt(
        'reading.reference-total.v1.$id',
      );
      if (mounted && widget.bookId == id) {
        setState(
          () => _manualReferenceTotal =
              saved != null && saved > 0 && saved <= 100000 ? saved : null,
        );
      }
    } catch (_) {
      // Source page metadata and reading remain available without preferences.
    }
  }

  Future<void> showBookProgress() async {
    if (!initialized || cachedStarts.isEmpty) return;
    final offset = cachedStarts[current * columns];
    final source = referencePageAt(widget.book.referencePages, offset);
    final first = current * columns + 1;
    final result = await showDialog<BookProgressResult>(
      context: context,
      builder: (_) => BookProgressDialog(
        screenLabel: indexing
            ? tr(context, 'Yükleniyor')
            : '$first / ${cachedPages.length}',
        progress: bookText.isEmpty ? 0 : (offset / bookText.length).clamp(0, 1),
        referenceLabel: source?.label,
        referenceTotal: referenceTotal,
        canNavigate: !indexing,
        printEdition: widget.book.printEdition,
        screenTotal: indexing ? null : cachedPages.length,
      ),
    );
    if (!mounted || result == null) return;
    if (result.goToScreen) {
      if (!indexing) await goToPage(cachedPages.length);
      return;
    }
    final total = result.referenceTotal;
    if (total == null) return;
    try {
      final id = widget.bookId;
      if (id != null) {
        final prefs = SharedPreferencesAsync();
        if (total == 0) {
          await prefs.remove('reading.reference-total.v1.$id');
        } else {
          await prefs.setInt('reading.reference-total.v1.$id', total);
        }
      }
      if (mounted) {
        setState(() => _manualReferenceTotal = total == 0 ? null : total);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('İlerleme ayarı kaydedilemedi.')),
        );
      }
    }
  }

  Future<void> loadAnnotations() async {
    final book = annotationBook;
    try {
      final saved = await annotationStore.load(book);
      if (mounted && book == annotationBook) {
        setState(
          () => annotations = saved
              .where(
                (a) =>
                    a.end <= bookText.length &&
                    bookText.substring(a.start, a.end) == a.quote,
              )
              .toList(),
        );
      }
    } catch (_) {
      /* The book remains readable if local annotations are unavailable. */
    }
  }

  Future<void> saveAnnotations(List<BookAnnotation> updated) async {
    final previous = annotations;
    final revision = ++annotationRevision;
    setState(() => annotations = updated);
    try {
      await annotationStore.save(annotationBook, updated);
    } catch (_) {
      if (mounted && revision == annotationRevision) {
        setState(() => annotations = previous);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(selectionLabel(context, 'saveError'))),
        );
      }
    }
  }

  Future<void> editNote(
    int start,
    int end,
    String quote, {
    BookAnnotation? existing,
  }) async {
    var draft = existing?.note ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(selectionLabel(context, 'note')),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(quote, maxLines: 4, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('annotation-note-input'),
                  initialValue: draft,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 6,
                  onChanged: (value) => draft = value,
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: Text(selectionLabel(context, 'delete')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draft.trim()),
            child: Text(selectionLabel(context, 'save')),
          ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    final updated = annotations.where((a) => a.id != existing?.id).toList();
    if (result.isNotEmpty) {
      updated.add(
        BookAnnotation(
          id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          start: start,
          end: end,
          quote: quote,
          note: result,
        ),
      );
    }
    await saveAnnotations(updated);
  }

  late PageController controller;
  bool initialized = false;
  String layoutSignature = '';
  late String bookText = widget.book.paragraphs.join('\n\n');
  late TextDirection bookDirection = directionForText(bookText);
  List<String> cachedPages = const [];
  List<int> cachedStarts = const [];
  late int textOffset = widget.initialOffset;
  int current = 0;
  String searchQuery = '';
  int columns = 1;
  final readingFocus = FocusNode();
  int paginationGeneration = 0;
  final pendingYields = <Timer, Completer<void>>{};

  Future<void> yieldPagination() {
    final done = Completer<void>();
    late final Timer timer;
    timer = Timer(Duration.zero, () {
      pendingYields.remove(timer);
      done.complete();
    });
    pendingYields[timer] = done;
    WidgetsBinding.instance.scheduleFrame();
    return done.future;
  }

  bool preparing = true;
  bool preparationFailed = false;
  bool indexing = false;
  bool previewPending = false;
  Timer? paginationDebounce;
  bool indexFailed = false;
  int previewEnd = 0;
  double measureWidth = 1;
  double measureHeight = 1;
  TextStyle measureStyle = const TextStyle();
  TextScaler measureScaler = TextScaler.noScaling;
  final pageCache = <String, ({List<String> pages, List<int> starts})>{};
  final pagerKey = GlobalKey<DirectionalPagerState>();

  void publishPages(List<String> pages, List<int> starts, int target) {
    final previous = initialized ? controller : null;
    final fraction =
        previous != null &&
            previous.hasClients &&
            previous.position.hasContentDimensions
        ? (previous.page ?? 0) % 1
        : 0.0;
    controller = PageController(initialPage: target);
    initialized = true;
    current = target;
    cachedPages = pages;
    cachedStarts = starts;
    preparing = false;
    previewPending = false;
    // The old PageView detaches during this frame, before its controller is disposed.
    if (previous != null) {
      final next = controller;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previous.dispose();
        if (mounted &&
            identical(controller, next) &&
            next.hasClients &&
            fraction > 0) {
          next.jumpTo(
            ((target + fraction) * next.position.viewportDimension).clamp(
              0.0,
              next.position.maxScrollExtent,
            ),
          );
        }
      });
    }
  }

  void preparePreview(int anchor) {
    var start = anchor.clamp(0, math.max(0, bookText.length - 1)).toInt();
    if (start > 0 &&
        bookText.codeUnitAt(start) >= 0xDC00 &&
        bookText.codeUnitAt(start) <= 0xDFFF) {
      start--;
    }
    final pages = <String>[];
    final starts = <int>[];
    var offset = start;
    for (final page in paginateText(
      text: bookText.substring(start),
      width: measureWidth,
      height: measureHeight,
      style: measureStyle,
      scaler: measureScaler,
      direction: bookDirection,
    ).take(columns * 2)) {
      starts.add(offset);
      pages.add(page);
      offset += page.length;
    }
    previewEnd = offset;
    publishPages(pages, starts, 0);
  }

  void extendPreview() {
    if (!indexing || previewEnd >= bookText.length) return;
    final pages = [...cachedPages];
    final starts = [...cachedStarts];
    var offset = previewEnd;
    for (final page in paginateText(
      text: bookText.substring(offset),
      width: measureWidth,
      height: measureHeight,
      style: measureStyle,
      scaler: measureScaler,
      direction: bookDirection,
    ).take(4)) {
      starts.add(offset);
      pages.add(page);
      offset += page.length;
    }
    setState(() {
      cachedPages = pages;
      cachedStarts = starts;
      previewEnd = offset;
    });
  }

  void jumpToOffset(int offset) {
    if (!mounted || preparing || !controller.hasClients) return;
    if (indexing && (offset < cachedStarts.first || offset >= previewEnd)) {
      setState(() {
        textOffset = offset;
        preparePreview(offset);
      });
      widget.onPositionChanged?.call(offset);
    } else {
      final page = math.max(
        0,
        cachedStarts.lastIndexWhere((start) => start <= offset),
      );
      controller.jumpToPage(page ~/ columns);
    }
  }

  void prependPreview() {
    final end = cachedStarts.first;
    if (!indexing || end == 0) return;
    var start = math
        .max(
          0,
          end -
              math.min(
                8192,
                math.max(512, cachedPages.first.length * columns * 3),
              ),
        )
        .toInt();
    if (start > 0 &&
        bookText.codeUnitAt(start) >= 0xDC00 &&
        bookText.codeUnitAt(start) <= 0xDFFF) {
      start--;
    }
    final pages = <String>[];
    final starts = <int>[];
    var offset = start;
    for (final page in paginateText(
      text: bookText.substring(start, end),
      width: measureWidth,
      height: measureHeight,
      style: measureStyle,
      scaler: measureScaler,
      direction: bookDirection,
    )) {
      starts.add(offset);
      pages.add(page);
      offset += page.length;
    }
    final target = math.max(0, pages.length - columns) ~/ columns;
    setState(() {
      publishPages(
        [...pages, ...cachedPages],
        [...starts, ...cachedStarts],
        target,
      );
      textOffset = cachedStarts[target * columns];
    });
    widget.onPositionChanged?.call(textOffset);
  }

  Future<void> preparePages(
    int generation,
    double width,
    double height,
    TextStyle style,
    TextScaler scaler,
  ) async {
    if (!mounted || generation != paginationGeneration) return;
    final pages = <String>[];
    final starts = <int>[];
    var offset = 0;
    final slice = Stopwatch()..start();
    try {
      setState(() => preparePreview(textOffset));
      // Paint the nearby pages before building the full page-number index.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generation != paginationGeneration) return;
      await yieldPagination();
      if (!mounted || generation != paginationGeneration) return;
      for (final page in paginateText(
        text: bookText,
        width: width,
        height: height,
        style: style,
        scaler: scaler,
        direction: bookDirection,
      )) {
        if (!mounted || generation != paginationGeneration) return;
        starts.add(offset);
        pages.add(page);
        offset += page.length;
        if (slice.elapsedMilliseconds >= 4) {
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted || generation != paginationGeneration) return;
          await yieldPagination();
          if (!mounted || generation != paginationGeneration) return;
          slice.reset();
        }
      }
      if (!mounted || generation != paginationGeneration) return;
      pageCache[layoutSignature] = (pages: pages, starts: starts);
      while (pageCache.length > 3) {
        pageCache.remove(pageCache.keys.first);
      }
      while (controller.hasClients &&
          controller.position.isScrollingNotifier.value) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || generation != paginationGeneration) return;
      }
      final target =
          math.max(0, starts.lastIndexWhere((start) => start <= textOffset)) ~/
          columns;
      setState(() {
        publishPages(pages, starts, target);
        indexing = false;
      });
      widget.onPageCountChanged?.call(pages.length);
    } catch (_) {
      if (mounted && generation == paginationGeneration) {
        setState(() {
          preparing = false;
          indexing = initialized;
          indexFailed = initialized;
          preparationFailed = !initialized;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant PagedBook oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book != widget.book) {
      bookText = widget.book.paragraphs.join('\n\n');
      bookDirection = directionForText(bookText);
      layoutSignature = '';
      pageCache.clear();
      cachedPages = const [];
      textOffset = widget.initialOffset;
      searchQuery = '';
      annotations = [];
      loadAnnotations();
      _manualReferenceTotal = null;
      loadReferenceTotal();
    }
  }

  Future<void> searchBook() async {
    if (!initialized || cachedStarts.isEmpty) return;
    final result = await showDialog<BookSearchSelection>(
      context: context,
      builder: (_) => BookSearchDialog(
        text: bookText,
        pageStarts: cachedStarts,
        pageNumbersReady: !indexing,
      ),
    );
    if (!mounted || result == null || !controller.hasClients) return;
    setState(() => searchQuery = result.query);
    jumpToOffset(result.offset);
  }

  String bookmarkTitle(int offset) {
    final page = cachedStarts.lastIndexWhere((start) => start <= offset) + 1;
    return '${widget.book.title} — ${tr(context, 'Sayfa ${math.max(1, page)}')}';
  }

  Future<void> goToPage(int total) async {
    final number = await showDialog<int>(
      context: context,
      builder: (_) => PageNumberDialog(
        current: current * columns + 1,
        total: total,
        isScreenPage: true,
      ),
    );
    if (mounted && number != null && controller.hasClients) {
      controller.jumpToPage((number - 1) ~/ columns);
    }
  }

  Widget pageText(String text, TextStyle style, int pageOffset) {
    final marks = annotations
        .where((a) => a.start < pageOffset + text.length && a.end > pageOffset)
        .toList();
    final matches = searchQuery.isEmpty
        ? <int>[]
        : findBookMatches(text, searchQuery);
    final cuts = <int>{0, text.length};
    for (final mark in marks) {
      cuts.add((mark.start - pageOffset).clamp(0, text.length));
      cuts.add((mark.end - pageOffset).clamp(0, text.length));
    }
    for (final match in matches) {
      cuts.add(match);
      cuts.add(match + searchQuery.length);
    }
    final positions = cuts.toList()..sort();
    final spans = <TextSpan>[];
    for (var i = 0; i + 1 < positions.length; i++) {
      final from = positions[i], to = positions[i + 1];
      final active = marks.where(
        (a) => a.start < pageOffset + to && a.end > pageOffset + from,
      );
      final underline = active.any((a) => !a.isNote);
      final note = active.any((a) => a.isNote);
      final found = matches.any(
        (m) => m <= from && m + searchQuery.length >= to,
      );
      spans.add(
        TextSpan(
          text: text.substring(from, to),
          style: TextStyle(
            decoration: underline ? TextDecoration.underline : null,
            decorationColor: widget.paper.ink,
            backgroundColor: found
                ? (widget.paper == PaperTheme.night
                      ? const Color(0xFF705B16)
                      : const Color(0xFFFFDF75))
                : note
                ? widget.paper.ink.withValues(alpha: .12)
                : null,
          ),
        ),
      );
    }
    final notes = marks
        .where((a) => a.isNote && a.start >= pageOffset)
        .toList();
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textHeightBehavior: readingTextHeightBehavior,
      strutStyle: readingStrutStyle(style),
      textDirection: bookDirection,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: measureWidth);
    final height = painter.height;
    final noteOffsets = [
      for (final note in notes)
        painter
            .getOffsetForCaret(
              TextPosition(offset: note.start - pageOffset),
              Rect.zero,
            )
            .dy,
    ];
    painter.dispose();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ReaderSelectableText(
            span: TextSpan(style: style, children: spans),
            style: style,
            direction: bookDirection,
            onTap: () {
              readingFocus.requestFocus();
              widget.onToggleControls?.call();
            },
            onDoubleTap: widget.onToggleFullscreen,
            menuBuilder: (context, state) {
              final selected = state.textEditingValue.selection;
              if (!selected.isValid || selected.isCollapsed) {
                return const SizedBox.shrink();
              }
              final raw = selected.textInside(text);
              final quote = raw.trim();
              final start =
                  pageOffset +
                  selected.start +
                  raw.length -
                  raw.trimLeft().length;
              final end = start + quote.length;
              final underline = annotations
                  .where((a) => !a.isNote && a.start == start && a.end == end)
                  .firstOrNull;
              final note = annotations
                  .where((a) => a.isNote && a.start == start && a.end == end)
                  .firstOrNull;
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: state.contextMenuAnchors,
                buttonItems: [
                  ContextMenuButtonItem(
                    label: selectionLabel(context, 'translate'),
                    onPressed: () {
                      state.hideToolbar();
                      if (quote.isNotEmpty) {
                        showOfflineDictionary(context, quote);
                      }
                    },
                  ),
                  ContextMenuButtonItem(
                    label: selectionLabel(
                      context,
                      underline == null ? 'underline' : 'removeUnderline',
                    ),
                    onPressed: () {
                      state.hideToolbar();
                      if (quote.isEmpty) return;
                      saveAnnotations(
                        underline != null
                            ? annotations
                                  .where((a) => a.id != underline.id)
                                  .toList()
                            : [
                                ...annotations,
                                BookAnnotation(
                                  id: DateTime.now().microsecondsSinceEpoch
                                      .toString(),
                                  start: start,
                                  end: end,
                                  quote: quote,
                                ),
                              ],
                      );
                    },
                  ),
                  ContextMenuButtonItem(
                    label: selectionLabel(context, 'note'),
                    onPressed: () {
                      state.hideToolbar();
                      if (quote.isNotEmpty) {
                        editNote(start, end, quote, existing: note);
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ),
        SizedBox(
          width: 24,
          height: height,
          child: Stack(
            children: [
              for (var i = 0; i < notes.length; i++)
                Positioned(
                  top: noteOffsets[i].clamp(0, math.max(0, height - 24)),
                  left: 0,
                  width: 24,
                  height: 24,
                  child: IconButton(
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    key: ValueKey('annotation-bubble-${notes[i].id}'),
                    tooltip: notes[i].note,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                    icon: Icon(
                      Icons.sticky_note_2_outlined,
                      size: 18,
                      color: widget.paper.ink,
                    ),
                    onPressed: () => editNote(
                      notes[i].start,
                      notes[i].end,
                      notes[i].quote,
                      existing: notes[i],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    paginationGeneration++;
    for (final entry in pendingYields.entries) {
      entry.key.cancel();
      entry.value.complete();
    }
    pendingYields.clear();
    paginationDebounce?.cancel();
    readingFocus.dispose();
    if (initialized) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final requested = switch (widget.layout) {
        'single' => 1,
        'double' => 2,
        'triple' => 3,
        'quadruple' => 4,
        _ => constraints.maxWidth >= 1000 ? 2 : 1,
      };
      final capacity = constraints.maxWidth < 800
          ? 1
          : ((constraints.maxWidth + 6) / 286).floor().clamp(1, 4).toInt();
      columns = math.min(requested, capacity);
      final width = constraints.maxWidth;
      final pageWidth = (width - (columns - 1) * 6) / columns;
      final availableHeight = constraints.hasBoundedHeight
          ? constraints.maxHeight
          : MediaQuery.sizeOf(context).height - 100;
      final showFooter = widget.controlsVisible && availableHeight >= 220;
      final compactFooter = width >= 300;
      final footerScaler = MediaQuery.textScalerOf(context);
      final counterHeight =
          footerScaler.scale(10) + footerScaler.scale(13) * 1.1 + 12;
      final footerHeight = showFooter
          ? (compactFooter
                ? math.max(52.0, counterHeight)
                : math.max(98.0, counterHeight + 48))
          : 0.0;
      final height = math.max(1.0, availableHeight - footerHeight);
      final padding = pageWidth < 450 ? 12.0 : 18.0;
      // Text inherits Material typography (including letter spacing). Measure
      // exactly that same style or the displayed lines can wrap past the page.
      final style = DefaultTextStyle.of(context).style
          .merge(
            TextStyle(
              fontFamily: widget.font == 'Sistem' ? null : widget.font,
              fontSize: widget.fontSize,
              height:
                  MediaQuery.maybeLineHeightScaleFactorOverrideOf(context) ??
                  widget.lineHeight,
              letterSpacing: MediaQuery.maybeLetterSpacingOverrideOf(context),
              wordSpacing: MediaQuery.maybeWordSpacingOverrideOf(context),
              fontWeight: MediaQuery.boldTextOf(context)
                  ? FontWeight.bold
                  : null,
              color: widget.paper.ink,
            ),
          )
          .copyWith(
            inherit: false,
            locale: Localizations.maybeLocaleOf(context),
          );
      final scaler = MediaQuery.textScalerOf(context);
      final signature =
          '$pageWidth-$height-${widget.font}-${widget.fontSize}-${style.height}-${scaler.scale(widget.fontSize)}-$columns-${style.letterSpacing}-${style.wordSpacing}-${style.fontWeight}-${style.locale}';
      if (signature != layoutSignature) {
        layoutSignature = signature;
        preparing = cachedPages.isEmpty;
        indexing = true;
        indexFailed = false;
        previewPending = true;
        preparationFailed = false;
        final generation = ++paginationGeneration;
        paginationDebounce?.cancel();
        if (cachedPages.isNotEmpty) {
          current =
              math.max(
                0,
                cachedStarts.lastIndexWhere((start) => start <= textOffset),
              ) ~/
              columns;
        }
        measureWidth = pageWidth - padding * 2 - 24 - readingCaretMargin;
        measureHeight = math.max(1, height - 18 - 2);
        measureStyle = style;
        measureScaler = scaler;
        final cached = pageCache[signature];
        if (cached != null) {
          final target =
              math.max(
                0,
                cached.starts.lastIndexWhere((start) => start <= textOffset),
              ) ~/
              columns;
          publishPages(cached.pages, cached.starts, target);
          indexing = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && generation == paginationGeneration) {
              widget.onPageCountChanged?.call(cached.pages.length);
            }
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && generation == paginationGeneration) {
              paginationDebounce = Timer(
                const Duration(milliseconds: 80),
                () => preparePages(
                  generation,
                  measureWidth,
                  measureHeight,
                  style,
                  scaler,
                ),
              );
            }
          });
        }
      }
      if (preparing || preparationFailed) {
        return SizedBox(
          height: height,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: preparationFailed
                  ? [
                      const AppText('Sayfalar hazırlanamadı.'),
                      TextButton(
                        onPressed: () => setState(() => layoutSignature = ''),
                        child: const AppText('Tekrar dene'),
                      ),
                    ]
                  : [
                      CircularProgressIndicator(color: widget.paper.ink),
                      const SizedBox(height: 16),
                      AppText(
                        'Kitap açılıyor…',
                        style: TextStyle(color: widget.paper.ink),
                      ),
                    ],
            ),
          ),
        );
      }
      final pages = cachedPages;
      final starts = cachedStarts;
      final spreadCount = (pages.length / columns).ceil();
      final viewController = controller;
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      final rtl = bookDirection == TextDirection.rtl;
      final first = current * columns;
      final last = math.min(first + columns, pages.length);
      final pageLabel = columns == 1
          ? '${first + 1} / ${pages.length}'
          : '${first + 1}–$last / ${pages.length}';
      final sourcePage = referencePageAt(
        widget.book.referencePages,
        starts[first],
      );
      final printPosition = !indexing && referenceTotal != null
          ? printPagePosition(first, pages.length, referenceTotal!)
          : null;
      final counterLabel =
          sourcePage?.label ??
          (indexing
              ? tr(context, 'Yükleniyor')
              : printPosition != null
              ? '${printPosition.screen}/${printPosition.screens}   ${printPosition.page}/$referenceTotal'
              : pageLabel);

      void turn(bool next) {
        if (!controller.hasClients) return;
        if (!next && indexing && current == 0 && starts.first > 0) {
          prependPreview();
          return;
        }
        if (next && indexing && current >= spreadCount - 2) extendPreview();
        final count = (cachedPages.length / columns).ceil();
        final destination = (current + (next ? 1 : -1)).clamp(0, count - 1);
        if (reduceMotion) {
          controller.jumpToPage(destination);
        } else {
          controller.animateToPage(
            destination,
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeInOutCubic,
          );
        }
      }

      Widget sheet(int index) => Expanded(
        child: index >= pages.length
            ? Container(color: widget.paper.background)
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                child: Container(
                  key: ValueKey('reading-page-$index'),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: widget.paper.background,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.09),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: PaperPainter(widget.paper),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padding, 10, padding, 8),
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    readingFocus.requestFocus();
                                    widget.onToggleControls?.call();
                                  },
                                  onDoubleTap: widget.onToggleFullscreen,
                                ),
                                Align(
                                  alignment: rtl
                                      ? Alignment.topRight
                                      : Alignment.topLeft,
                                  child: pageText(
                                    pages[index],
                                    style,
                                    starts[index],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      );

      final navigation = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: tr(context, 'Önceki sayfa'),
            visualDensity: VisualDensity.compact,
            onPressed: current > 0 || (indexing && starts.first > 0)
                ? () => turn(false)
                : null,
            icon: Icon(rtl ? Icons.chevron_right : Icons.chevron_left),
          ),
          Tooltip(
            message: tr(
              context,
              indexing
                  ? 'Sayfa sayısı arka planda hesaplanıyor'
                  : 'Kitap sayfası ve ilerleme',
            ),
            child: TextButton(
              key: const ValueKey('book-progress'),
              style: TextButton.styleFrom(
                foregroundColor: widget.paper.ink,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              onPressed: showBookProgress,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    counterLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: tr(context, 'Sonraki sayfa'),
            visualDensity: VisualDensity.compact,
            onPressed:
                current < spreadCount - 1 ||
                    (indexing && previewEnd < bookText.length)
                ? () => turn(true)
                : null,
            icon: Icon(rtl ? Icons.chevron_left : Icons.chevron_right),
          ),
        ],
      );
      final tools = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (searchQuery.isNotEmpty)
            IconButton(
              tooltip: tr(context, 'Arama vurgusunu temizle'),
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => searchQuery = ''),
              icon: const Icon(Icons.search_off),
            ),
          if (widget.bookId != null)
            BookmarkControls(
              store: widget.store ?? ReadingStore.device,
              bookId: widget.bookId!,
              position: starts[first],
              label: bookmarkTitle,
              canAdd: !indexing,
              onJump: jumpToOffset,
            ),
        ],
      );

      void scrollVertically(bool down) {
        pagerKey.currentState?.alongAxis(Axis.vertical, () => turn(down));
      }

      return CallbackShortcuts(
        bindings: {
          SingleActivator(LogicalKeyboardKey.arrowRight): () => pagerKey
              .currentState
              ?.alongAxis(Axis.horizontal, () => turn(!rtl)),
          SingleActivator(LogicalKeyboardKey.arrowLeft): () => pagerKey
              .currentState
              ?.alongAxis(Axis.horizontal, () => turn(rtl)),
          SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              scrollVertically(true),
          SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              scrollVertically(false),
          SingleActivator(LogicalKeyboardKey.pageDown): () => turn(true),
          SingleActivator(LogicalKeyboardKey.pageUp): () => turn(false),
          SingleActivator(LogicalKeyboardKey.space): () => turn(true),
          if (widget.onToggleFullscreen != null)
            SingleActivator(LogicalKeyboardKey.f11): widget.onToggleFullscreen!,
          if (widget.onEscape != null || widget.onToggleControls != null)
            SingleActivator(LogicalKeyboardKey.escape):
                widget.onEscape ?? widget.onToggleControls!,
        },
        child: Focus(
          focusNode: readingFocus,
          autofocus: true,
          child: Center(
            child: SizedBox(
              width: width,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: height,
                    child: Listener(
                      onPointerDown: (_) => readingFocus.requestFocus(),
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(
                          dragDevices: {
                            PointerDeviceKind.touch,
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.trackpad,
                            PointerDeviceKind.stylus,
                          },
                        ),
                        child: DirectionalPager(
                          key: pagerKey,
                          controller: controller,
                          onPinch: widget.onPinch,
                          minPinchScale: 16 / widget.fontSize,
                          maxPinchScale: 32 / widget.fontSize,
                          builder: (axis) => Directionality(
                            textDirection: TextDirection.ltr,
                            child: PageView.builder(
                              key: ObjectKey(controller),
                              controller: controller,
                              reverse: axis == Axis.horizontal && rtl,
                              scrollDirection: axis,
                              physics: const NeverScrollableScrollPhysics(
                                parent: ClampingScrollPhysics(),
                              ),
                              itemCount: spreadCount,
                              onPageChanged: (value) {
                                if (previewPending ||
                                    !identical(controller, viewController)) {
                                  return;
                                }
                                setState(() => current = value);
                                textOffset = starts[value * columns];
                                widget.onPositionChanged?.call(textOffset);
                                if (indexing && value >= spreadCount - 2) {
                                  extendPreview();
                                }
                              },
                              itemBuilder: (context, index) => RepaintBoundary(
                                child: Row(
                                  textDirection: rtl
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                  children: [
                                    for (
                                      var column = 0;
                                      column < columns;
                                      column++
                                    ) ...[
                                      if (column > 0) const SizedBox(width: 6),
                                      sheet(index * columns + column),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showFooter) ...[
                    const SizedBox(height: 4),
                    IconTheme(
                      data: IconThemeData(color: widget.paper.ink),
                      child: compactFooter
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: navigation,
                                  ),
                                ),
                                tools,
                              ],
                            )
                          : Column(children: [navigation, tools]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
