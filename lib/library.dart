import 'book_history.dart';
import 'book_opening_cache.dart';
import 'book_titles.dart';
import 'book_details_dialog.dart';
import 'book_print_catalog.dart';
import 'mobi_library_cache.dart';
import 'library_book_cover.dart';
import 'book_cover_route.dart';
import 'book_cover_image.dart';
import 'library_shelf.dart';
import 'annotation_index_page.dart';
import 'app_navigation.dart';
import 'app_update.dart';
import 'reading_store.dart';

import 'package:flutter/services.dart';

import 'app_language.dart';

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pdf_reader.dart';

import 'book_store.dart';
import 'books.dart';
import 'main.dart';
import 'text_direction.dart';

String bookFingerprint(Uint8List bytes) => sha256.convert(bytes).toString();

String searchKey(String text) =>
    text.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

int compareBookTitles(String first, String second) {
  const alphabet = 'abcçdefgğhıijklmnoöpqrsştuüvwxyz';
  final a = searchKey(first);
  final b = searchKey(second);
  for (var i = 0; i < a.length && i < b.length; i++) {
    if (a[i] == b[i]) continue;
    final left = alphabet.indexOf(a[i]);
    final right = alphabet.indexOf(b[i]);
    final leftRank = left < 0 ? a.codeUnitAt(i) : 0x10000 + left;
    final rightRank = right < 0 ? b.codeUnitAt(i) : 0x10000 + right;
    return leftRank.compareTo(rightRank);
  }
  return a.length.compareTo(b.length);
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, this.store});
  final BookStore? store;
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with WidgetsBindingObserver {
  final history = BookHistory();
  final titles = BookTitles();
  final openingCache = BookOpeningCache();
  final coverLoads = Expando<Future<Uint8List?>>();
  String titleFor(BookFile book) =>
      titles.title(history.id(book)) ?? book.title;
  String sortOrder = 'read';
  final mobiCache = MobiLibraryCache();
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late final store = widget.store ?? BookStore();
  List<BookFile> books = [];
  BookFile? expandedBook;
  bool gridView = true;
  int layoutRevision = 0;
  Future<void> layoutWrite = Future<void>.value();
  StreamSubscription<void>? folderChanges;
  Timer? scanDelay;
  bool refreshPending = false;
  bool busy = false;
  String? openingTitle;
  String? liftedBook;
  bool openingFromShelf = false;
  List<String>? shelfOrder;
  String? error;
  AppRelease? availableUpdate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final navigation = AppNavigation.instance;
    navigation.libraryOwner = this;
    navigation.showBooks = () {
      Navigator.of(context).popUntil((route) => route.isFirst);
      selectLayout(false);
    };
    navigation.showHome = () {
      Navigator.of(context).popUntil((route) => route.isFirst);
      scaffoldKey.currentState?.closeDrawer();
    };
    navigation.showMenu = toggleLibraryMenu;
    restoreLayout();
    loadLibrary();
    watchFolder();
  }

  Future<void> loadLibrary() async {
    await refresh();
    if (!mounted) return;
    try {
      if (await store.discoverFolder() && mounted) await chooseFolder();
    } catch (_) {
      /* Manual folder selection remains available. */
    }
  }

  void toggleLibraryMenu() {
    if (scaffoldKey.currentState?.isDrawerOpen ?? false) {
      scaffoldKey.currentState?.closeDrawer();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
      scaffoldKey.currentState?.openDrawer();
    }
  }

  Future<void> watchFolder() async {
    await folderChanges?.cancel();
    if (!mounted) return;
    folderChanges = store.changes().listen(
      (_) {
        scanDelay?.cancel();
        scanDelay = Timer(const Duration(milliseconds: 350), refresh);
      },
      onError: (Object _) {
        /* Resume/import still trigger a fresh scan. */
      },
    );
  }

  Future<void> restoreLayout() async {
    try {
      final prefs = SharedPreferencesAsync();
      final order = await prefs.getString('library.sort.v1');
      if (mounted && ['alphabetical', 'added', 'read'].contains(order)) {
        setState(() => sortOrder = order!);
      }
      final saved = await prefs.getBool('library.grid.v1');
      if (mounted && layoutRevision == 0 && saved != null) {
        setState(() => gridView = saved);
      }
    } catch (_) {
      /* Keep the default view if storage is unavailable. */
    }
  }

  Future<void> selectLayout(bool grid) async {
    setState(() {
      gridView = grid;
      layoutRevision++;
    });
    layoutWrite = layoutWrite
        .catchError((Object _) {})
        .then((_) => SharedPreferencesAsync().setBool('library.grid.v1', grid));
    try {
      await layoutWrite;
    } catch (_) {
      if (mounted) message('Görünüm kaydedilemedi.');
    }
  }

  @override
  void dispose() {
    if (identical(AppNavigation.instance.libraryOwner, this)) {
      AppNavigation.instance.libraryOwner = null;
      AppNavigation.instance.showBooks = null;
      AppNavigation.instance.showHome = null;
      AppNavigation.instance.showMenu = null;
    }
    folderChanges?.cancel();
    scanDelay?.cancel();
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
      refreshPending = true;
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final found = await store.scan();
      await history.register(found);
      final libraryEntries = await mobiCache.libraryEntries(found, history.id);
      try {
        await titles.load();
      } catch (_) {
        // Keep the source titles available if metadata storage is unavailable.
      }
      if (mounted) {
        setState(() {
          books = libraryEntries;
          expandedBook = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Kitap klasörü okunamadı. Yeniden deneyin.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        if (refreshPending) {
          refreshPending = false;
          unawaited(refresh());
        }
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
        var book = BookFile(file.name, bytes);
        if (needsEpubConversion(book)) {
          final (converted, _) = await mobiCache.resolve(
            book,
            library: books,
            add: store.add,
          );
          if (mounted && !books.contains(converted)) {
            setState(() => books.add(converted));
          }
        } else {
          await store.add(book);
        }
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

  Future<void> chooseFolder() async {
    if (busy) return;
    try {
      if (!await store.selectFolder() || !mounted) return;
      await refresh();
      if (mounted) unawaited(watchFolder());
    } catch (_) {
      if (mounted) message('Kitap klasörü okunamadı. Yeniden deneyin.');
    }
  }

  void message(String text) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(text)));

  Future<void> open(
    BookFile book, {
    int? initialOffset,
    BookCoverOpening? openingCover,
  }) async {
    if (openingTitle != null) return;
    final selectedBook = book;
    setState(() {
      openingTitle = titleFor(book);
      openingFromShelf = openingCover != null;
    });
    try {
      if (needsEpubConversion(book)) {
        final (converted, added) = await mobiCache.resolve(
          book,
          library: books,
          add: store.add,
        );
        book = converted;
        if (!mounted) return;
        if (added) await refresh();
      }
      final id =
          history.id(book) ??
          await compute<Uint8List, String>(bookFingerprint, book.bytes);
      if (!mounted) {
        return;
      }
      final bookAnimations =
          (await ReadingStore.device.settings()).bookAnimations;
      if (!mounted) return;
      if (book.extension == 'pdf') {
        await history.markRead(selectedBook);
        if (!mounted) return;
        setState(() {});
        final route = bookReaderRoute(
          PdfReaderPage(
            book: BookFile(
              book.name,
              book.bytes,
              displayTitle: titleFor(selectedBook),
            ),
            bookId: id,
            onPageCountChanged: (count) => savePageCount(selectedBook, count),
          ),
          cover: openingCover,
          animationsEnabled: bookAnimations,
          reduceMotion: MediaQuery.disableAnimationsOf(context),
        );
        await presentBook(route, selectedBook, openingCover);
        return;
      }
      final decoded = await openingCache.open(
        id,
        BookFile(
          book.name,
          book.bytes,
          cleanWhitespace: history.shouldClean(selectedBook),
        ),
      );
      final customTitle =
          titles.title(history.id(selectedBook)) ?? selectedBook.displayTitle;
      final edition = (await BookPrintCatalog.load()).find(
        selectedBook.name,
        title: decoded.title,
        author: decoded.author,
      );
      final content = BookContent(
        customTitle ?? decoded.title,
        decoded.paragraphs,
        author: decoded.author,
        referencePages: decoded.referencePages,
        printEdition: decoded.printEdition ?? edition,
      );
      if (!mounted) {
        return;
      }
      await history.markRead(selectedBook);
      if (!mounted) return;
      setState(() {});
      final route = bookReaderRoute(
        ReaderPage(
          book: content,
          bookId: id,
          initialOffset: initialOffset,
          onPageCountChanged: (count) => savePageCount(selectedBook, count),
        ),
        cover: openingCover,
        animationsEnabled: bookAnimations,
        reduceMotion: MediaQuery.disableAnimationsOf(context),
      );
      await presentBook(route, selectedBook, openingCover);
    } on BookReadException catch (e) {
      if (mounted) {
        message(e.message);
      }
    } catch (_) {
      if (mounted) {
        message('Kitap açılamadı. Dosyayı kontrol edin.');
      }
    } finally {
      if (mounted) {
        setState(() {
          openingTitle = null;
          liftedBook = null;
          openingFromShelf = false;
        });
      }
    }
  }

  Future<void> presentBook(
    TransitionRoute<void> route,
    BookFile book,
    BookCoverOpening? cover,
  ) async {
    setState(() => liftedBook = cover == null ? null : book.name);
    final pushed = Navigator.of(context).push(route);
    void handBackCover(AnimationStatus status) {
      if (status == AnimationStatus.dismissed && mounted) {
        // Rebuild the shelf in the very frame that removes the moving cover.
        // route.completed resolves later, after its overlay is already gone.
        setState(() => liftedBook = null);
      }
    }

    final animation = route.animation;
    animation?.addStatusListener(handBackCover);
    try {
      await pushed;
      await route.completed;
    } finally {
      animation?.removeStatusListener(handBackCover);
    }
  }

  Widget menuItem(
    IconData icon,
    String label,
    VoidCallback action, {
    bool hasUpdate = false,
  }) => ListTile(
    leading: Icon(icon),
    title: AppText(label),
    trailing: hasUpdate ? const Badge(label: AppText('Yeni')) : null,
    onTap: () {
      Navigator.of(context).pop();
      action();
    },
  );

  Future<void> openShortcut(String key) async {
    if (key == 'update') {
      await showDialog<void>(
        context: context,
        builder: (_) => const AppUpdateDialog(),
      );
      return;
    }
    try {
      await const MethodChannel('e_reader/chrome').invokeMethod<void>(
        'openShortcut',
        {'key': key, 'language': LanguageScope.of(context)?.code ?? 'tr'},
      );
    } catch (_) {
      if (mounted) message('Bağlantı açılamadı.');
    }
  }

  void showOtherApps() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const AppText('Diğer uygulamalarım')),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('Kuran'),
              trailing: const Icon(Icons.download),
              onTap: () => openShortcut('kuran'),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('Cevşen'),
              trailing: const Icon(Icons.download),
              onTap: () => openShortcut('cevsen'),
            ),
          ],
        ),
      ),
    ),
  );

  List<BookFile> visibleShelfBooks() {
    return [...books]..sort((a, b) {
      final favoriteOrder =
          (history.isFavorite(b) ? 1 : 0) - (history.isFavorite(a) ? 1 : 0);
      if (favoriteOrder != 0) return favoriteOrder;
      if (gridView && shelfOrder != null) {
        final left = shelfOrder!.indexOf(a.name);
        final right = shelfOrder!.indexOf(b.name);
        if (left >= 0 && right >= 0) return left.compareTo(right);
        if (left >= 0) return -1;
        if (right >= 0) return 1;
      }
      final order = switch (sortOrder) {
        'added' => history.added(b).compareTo(history.added(a)),
        'read' => history.read(b).compareTo(history.read(a)),
        _ => 0,
      };
      return order != 0 ? order : compareBookTitles(titleFor(a), titleFor(b));
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleBooks = visibleShelfBooks();
    return Scaffold(
      key: scaffoldKey,
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'E-Reader',
                  style: TextStyle(fontSize: 26, fontFamily: 'Lora'),
                ),
              ),
              menuItem(
                Icons.local_library_outlined,
                'Kütüphanem',
                () => selectLayout(false),
              ),
              menuItem(Icons.add, 'Kitap ekle', add),
              if (store.supportsFolderSelection)
                menuItem(
                  Icons.folder_open_outlined,
                  'Klasör seç',
                  chooseFolder,
                ),
              menuItem(
                Icons.settings_outlined,
                'Okuma ayarları',
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReaderPage(settingsOnly: true),
                  ),
                ),
              ),
              menuItem(
                Icons.language,
                'Uygulama dili',
                () => showLanguagePicker(context),
              ),
              menuItem(
                Icons.bookmarks_outlined,
                'Altı çizilenler ve notlar',
                () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AnnotationIndexPage(
                      books: [
                        for (final book in books)
                          BookFile(
                            book.name,
                            book.bytes,
                            displayTitle: titleFor(book),
                            cleanWhitespace: history.shouldClean(book),
                          ),
                      ],
                      openBook: (book, offset) =>
                          open(book, initialOffset: offset),
                    ),
                  ),
                ),
              ),
              const Divider(),
              menuItem(
                Icons.system_update,
                'Uygulamayı güncelle',
                () => openShortcut('update'),
                hasUpdate: availableUpdate != null,
              ),
              menuItem(
                Icons.share_outlined,
                'Uygulamayı paylaş',
                () => openShortcut('share'),
              ),
              menuItem(Icons.apps, 'Diğer uygulamalarım', showOtherApps),
              menuItem(
                Icons.help_outline,
                'Destek',
                () => openShortcut('support'),
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('library-menu'),
          tooltip: tr(context, 'Ana menü'),
          icon: const Icon(Icons.menu),
          onPressed: toggleLibraryMenu,
        ),
        title: const Text('E-Reader'),
        actions: [
          if (store.supportsFolderSelection &&
              MediaQuery.sizeOf(context).width >= 600)
            IconButton(
              key: const ValueKey('library-folder'),
              tooltip: tr(context, 'Klasör seç'),
              onPressed: busy ? null : chooseFolder,
              icon: const Icon(Icons.folder_open_outlined),
            ),
          if (MediaQuery.sizeOf(context).width >= 400)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: MediaQuery.sizeOf(context).width < 400
                  ? IconButton(
                      tooltip: tr(context, 'Kitap ekle'),
                      onPressed: busy ? null : add,
                      icon: const Icon(Icons.add),
                    )
                  : FilledButton.icon(
                      onPressed: busy ? null : add,
                      icon: const Icon(Icons.add),
                      label: const AppText('Kitap ekle'),
                    ),
            ),
          IconButton(
            key: const ValueKey('library-settings'),
            tooltip: tr(context, 'Okuma ayarları'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ReaderPage(settingsOnly: true),
              ),
            ),
          ),
          const LanguageButton(),
        ],
      ),
      bottomSheet: AppUpdateBanner(
        onAvailable: (release) {
          if (mounted) setState(() => availableUpdate = release);
        },
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AppText(
                      'Kütüphanem',
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(fontFamily: 'Lora', fontSize: 28),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  key: const ValueKey('library-sort'),
                  tooltip: tr(context, 'Sıralama'),
                  icon: const Icon(Icons.sort),
                  initialValue: sortOrder,
                  onSelected: (value) async {
                    setState(() {
                      sortOrder = value;
                      shelfOrder = null;
                    });
                    try {
                      await SharedPreferencesAsync().setString(
                        'library.sort.v1',
                        value,
                      );
                    } catch (_) {
                      if (mounted) message('Sıralama kaydedilemedi.');
                    }
                  },
                  itemBuilder: (_) => [
                    for (final entry in const {
                      'read': 'Son okunan',
                      'added': 'Son eklenen',
                      'alphabetical': 'Alfabetik',
                    }.entries)
                      CheckedPopupMenuItem(
                        value: entry.key,
                        checked: sortOrder == entry.key,
                        child: AppText(entry.value),
                      ),
                  ],
                ),
                IconButton(
                  key: const ValueKey('library-grid'),
                  tooltip: tr(context, 'Kare görünüm'),
                  isSelected: gridView,
                  onPressed: () => selectLayout(true),
                  icon: const Icon(Icons.grid_view_rounded),
                ),
                IconButton(
                  key: const ValueKey('library-list'),
                  tooltip: tr(context, 'Liste görünümü'),
                  isSelected: !gridView,
                  onPressed: () => selectLayout(false),
                  icon: const Icon(Icons.view_list_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 20),
            if (busy && !openingFromShelf) const LinearProgressIndicator(),
            if (openingTitle != null && !openingFromShelf)
              AppText('$openingTitle açılıyor…'),
            if (error != null)
              AppText(
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
                    const AppText('Rafların ilk kitabını bekliyor.'),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: add,
                      child: const AppText('Kitaplarını ekle'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ReaderPage(),
                        ),
                      ),
                      child: const AppText('Okuma görünümünü dene'),
                    ),
                  ],
                ),
              ),
            if (gridView)
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = (constraints.maxWidth / 180).floor().clamp(
                    2,
                    6,
                  );
                  return CustomPaint(
                    painter: LibraryShelfPainter(
                      columns: columns,
                      bookCount: visibleBooks.length,
                    ),
                    child: GridView.builder(
                      key: const ValueKey('library-grid-books'),
                      padding: const EdgeInsets.only(bottom: 20),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 32,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.70,
                      ),
                      itemCount: visibleBooks.length,
                      itemBuilder: (_, index) =>
                          cover(visibleBooks[index], index),
                    ),
                  );
                },
              )
            else
              for (final book in visibleBooks) listEntry(book),
          ],
        ),
      ),
    );
  }

  Future<void> savePageCount(BookFile book, int count) async {
    try {
      final id =
          history.id(book) ??
          await compute<Uint8List, String>(bookFingerprint, book.bytes);
      await SharedPreferencesAsync().setInt('library.pages.v1.$id', count);
    } catch (_) {
      // Optional details must never interrupt reading.
    }
  }

  Future<BookDetails> loadDetails(BookFile book) async {
    final id =
        history.id(book) ??
        await compute<Uint8List, String>(bookFingerprint, book.bytes);
    int? pages;
    try {
      pages = await SharedPreferencesAsync().getInt('library.pages.v1.$id');
    } catch (_) {}
    String? author;
    if (book.bytes.isNotEmpty &&
        (book.extension == 'epub' || book.extension == 'docx')) {
      try {
        author = (await openingCache.open(
          id,
          BookFile(
            book.name,
            book.bytes,
            cleanWhitespace: history.shouldClean(book),
          ),
        )).author;
      } catch (_) {
        // Show file details even when text or author metadata cannot be read.
      }
    }
    final edition = (await BookPrintCatalog.load()).find(
      book.name,
      title: titleFor(book),
      author: author,
    );
    int? manual;
    try {
      manual = await SharedPreferencesAsync().getInt(
        'reading.reference-total.v1.$id',
      );
    } catch (_) {}
    return (
      author: author,
      pages: pages,
      edition: edition,
      printPages: manual != null && manual > 0 && manual <= 100000
          ? manual
          : edition?.pages,
    );
  }

  void showBookDetails(BookFile book) => showDialog<void>(
    context: context,
    builder: (_) => BookDetailsDialog(
      book: book,
      title: titleFor(book),
      details: loadDetails(book),
      isFavorite: history.isFavorite(book),
      onRemove: () {
        Navigator.of(context).pop();
        removeLibraryBook(book);
      },
      onToggleFavorite: () {
        Navigator.of(context).pop();
        toggleFavorite(book);
      },
    ),
  );

  Future<void> toggleFavorite(BookFile book) async {
    try {
      await history.setFavorite(book, !history.isFavorite(book));
      if (!mounted) return;
      setState(() => shelfOrder = null);
    } catch (_) {
      if (mounted) message('Üst raf tercihi kaydedilemedi. Tekrar deneyin.');
    }
  }

  Future<void> removeLibraryBook(BookFile book) async {
    try {
      await store.remove(book);
      if (mounted) await refresh();
    } catch (_) {
      if (mounted) message('Kitap kaldırılamadı. Tekrar deneyin.');
    }
  }

  Widget listEntry(BookFile book) {
    final expanded = identical(expandedBook, book);
    final size = book.bytes.length < 1024 * 1024
        ? '${(book.bytes.length / 1024).toStringAsFixed(0)} KB'
        : '${(book.bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB';
    return LayoutBuilder(
      builder: (context, constraints) => Material(
        color: expanded
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.transparent,
        child: InkWell(
          key: ValueKey('library-row-${book.name}'),
          onLongPress: () => showBookDetails(book),
          onTap: () {
            if (expanded) {
              open(book);
            } else {
              setState(() => expandedBook = book);
            }
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(
              children: [
                if (history.isFavorite(book))
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.star, size: 18, color: Color(0xFFAA792D)),
                  ),
                Expanded(
                  child: Text(
                    titleFor(book),
                    textDirection: directionForText(titleFor(book)),
                    softWrap: true,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.centerLeft,
                  child: expanded
                      ? SizedBox(
                          key: ValueKey('library-info-${book.name}'),
                          width: (constraints.maxWidth * .46).clamp(0, 220),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: DefaultTextStyle.merge(
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: directionForText(book.name),
                                  ),
                                  Text(
                                    '${book.extension.toUpperCase()} · $size',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget cover(BookFile book, int index) {
    const colors = [
      Color(0xFF476658),
      Color(0xFF8A5346),
      Color(0xFF4D6076),
      Color(0xFF867042),
    ];
    if (liftedBook == book.name) {
      return SizedBox.expand(key: ValueKey('library-vacant-${book.name}'));
    }
    return FutureBuilder<Uint8List?>(
      future: coverLoads[book] ??= compute(readBookCover, book),
      builder: (context, snapshot) => Builder(
        key: ValueKey('library-cover-${book.name}'),
        builder: (coverContext) => Semantics(
          button: true,
          label: '${titleFor(book)}, ${book.extension}',
          child: InkWell(
            onSecondaryTap: () => showBookDetails(book),
            onLongPress: () => showBookDetails(book),
            onTap: () {
              final tile = coverContext.findRenderObject() as RenderBox;
              final navigator =
                  Navigator.of(context).context.findRenderObject() as RenderBox;
              final origin = navigator.localToGlobal(Offset.zero);
              shelfOrder = [
                for (final entry in visibleShelfBooks()) entry.name,
              ];
              open(
                book,
                openingCover: BookCoverOpening(
                  rect: (tile.localToGlobal(Offset.zero) - origin) & tile.size,
                  title: titleFor(book),
                  format: book.extension.toUpperCase(),
                  color: colors[index % colors.length],
                  imageBytes: snapshot.data,
                ),
              );
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                LibraryBookCover(
                  title: titleFor(book),
                  format: book.extension.toUpperCase(),
                  color: colors[index % colors.length],
                  imageBytes: snapshot.data,
                  requiresConversion: ![
                    'epub',
                    'pdf',
                    'docx',
                    'mobi',
                    'prc',
                  ].contains(book.extension),
                ),
                Positioned(
                  top: 2,
                  left: 4,
                  child: IconButton(
                    key: ValueKey('book-options-${book.name}'),
                    tooltip: tr(context, 'Kitap seçenekleri'),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xDDF8F1E2),
                      foregroundColor: const Color(0xFF39352C),
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => showBookDetails(book),
                    icon: const Icon(Icons.more_horiz, size: 20),
                  ),
                ),
                if (history.isFavorite(book))
                  Positioned(
                    top: 4,
                    right: 9,
                    child: Tooltip(
                      message: tr(context, 'Üst rafta'),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFFFFF2CB),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.star,
                            size: 17,
                            color: Color(0xFF91651E),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
