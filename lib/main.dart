import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_language.dart';

import 'books.dart';
import 'library.dart';
import 'paged_book.dart';
import 'reading_store.dart';
import 'page_layout_icon.dart';
import 'reader_fullscreen.dart';
import 'app_navigation.dart';
import 'app_chrome.dart';
import 'book_opening_splash.dart';
import 'exit_confirmation.dart';

import 'package:flutter/services.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'FreeDict + WikDict dictionary data',
    ], await rootBundle.loadString('assets/dictionaries/LICENSE.txt'));
  });
  runApp(const EReaderApp());
}

class EReaderApp extends StatefulWidget {
  const EReaderApp({super.key});

  @override
  State<EReaderApp> createState() => _EReaderAppState();
}

class _EReaderAppState extends State<EReaderApp> {
  final language = LanguageController();
  @override
  void initState() {
    super.initState();
    language.restore().catchError((Object _) {});
  }

  @override
  void dispose() {
    language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LanguageScope(
    controller: language,
    child: ListenableBuilder(
      listenable: language,
      builder: (context, _) => MaterialApp(
        navigatorKey: AppNavigation.instance.navigatorKey,
        builder: (context, child) => BookOpeningSplash(
          child: AppChrome(child: child ?? const SizedBox.shrink()),
        ),
        locale: Locale(language.code),
        supportedLocales: [for (final code in appLanguages.keys) Locale(code)],
        localizationsDelegates: const [
          AppTranslations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        title: 'E-Reader',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF64745A)),
          scaffoldBackgroundColor: const Color(0xFFF0EEE8),
          useMaterial3: true,
        ),
        home: const ExitConfirmation(
          child: FirstLaunchLanguage(child: LibraryPage()),
        ),
      ),
    ),
  );
}

enum PaperTheme {
  ivory('Fildişi', Color(0xFFFAF5E8), Color(0xFF39352C)),
  parchment('Parşömen', Color(0xFFEBDDCA), Color(0xFF46382D)),
  white('Pamuk', Color(0xFFFCFCF8), Color(0xFF303832)),
  sage('Adaçayı', Color(0xFFE6EBDF), Color(0xFF303D33)),
  night('Gece', Color(0xFF292D30), Color(0xFFE3DBCC));

  const PaperTheme(this.label, this.background, this.ink);
  final String label;
  final Color background;
  final Color ink;
}

class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    this.book,
    this.bookId,
    this.store,
    this.settingsOnly = false,
    this.initialOffset,
    this.onPageCountChanged,
  });
  final bool settingsOnly;
  final int? initialOffset;
  final ValueChanged<int>? onPageCountChanged;
  final String? bookId;
  final ReadingStore? store;
  final BookContent? book;
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  String font = 'Lora';
  double fontSize = 20;
  PaperTheme paper = PaperTheme.ivory;
  String layout = 'auto';
  double lineHeight = 1.15;
  bool bookAnimations = true;
  final readerKey = GlobalKey<PagedBookState>();
  bool controlsVisible = true;
  bool fullscreen = false;
  bool fullscreenBusy = false;
  late final VoidCallback stopFullscreenListener;

  void applyFullscreen(bool value) {
    if (!mounted || fullscreen == value) return;
    AppNavigation.instance.fullscreen.value = value;
    if (!value) hideSystemNavigation();
    setState(() {
      fullscreen = value;
      controlsVisible = !value;
    });
  }

  Future<void> toggleFullscreen() async {
    if (fullscreenBusy) return;
    fullscreenBusy = true;
    try {
      final value = !fullscreen;
      await setReaderFullscreen(value);
      applyFullscreen(value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('Tam ekran açılamadı.')),
        );
      }
    } finally {
      fullscreenBusy = false;
    }
  }

  Widget layoutButtons({bool automatic = false}) => Wrap(
    spacing: 2,
    children: [
      if (automatic)
        IconButton(
          tooltip: tr(context, 'Otomatik sayfa düzeni'),
          isSelected: layout == 'auto',
          onPressed: () => selectLayout('auto'),
          icon: const Icon(Icons.auto_awesome_mosaic_outlined),
        ),
      for (final entry in {
        1: 'single',
        2: 'double',
        3: 'triple',
        4: 'quadruple',
      }.entries)
        IconButton(
          tooltip: tr(context, '${entry.key} sayfa'),
          isSelected:
              layout == entry.value ||
              (!automatic &&
                  layout == 'auto' &&
                  entry.key ==
                      (MediaQuery.sizeOf(context).width >= 1008 ? 2 : 1)),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            foregroundColor: automatic ? null : paper.ink,
            backgroundColor: layout == entry.value
                ? (automatic
                      ? const Color(0xFFE1E7DC)
                      : paper.ink.withValues(alpha: 0.1))
                : null,
          ),
          onPressed: () => selectLayout(entry.value),
          icon: PageLayoutIcon(count: entry.key),
        ),
    ],
  );

  void selectLayout(String value) {
    setState(() {
      layout = value;
      if (value == 'single' && fontSize < 24) fontSize = 24;
    });
    saveSettings();
  }

  void resizeFont(double change) {
    setState(() => fontSize = (fontSize + change).clamp(16, 32));
    saveSettings();
  }

  late final ReadingStore store = widget.store ?? ReadingStore.device;
  bool loading = true;
  int offset = 0;
  bool storageWarningShown = false;

  @override
  void initState() {
    super.initState();
    stopFullscreenListener = listenReaderFullscreen(applyFullscreen);
    restore();
  }

  @override
  void dispose() {
    stopFullscreenListener();
    if (fullscreen) {
      setReaderFullscreen(false)
          .then((_) => hideSystemNavigation())
          .catchError((Object _) {});
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => AppNavigation.instance.fullscreen.value = false,
      );
    }
    super.dispose();
  }

  Future<void> restore() async {
    try {
      final saved = await store.settings();
      final position = widget.bookId == null
          ? 0
          : await store.position(widget.bookId!);
      if (!mounted) {
        return;
      }
      setState(() {
        font = saved.font;
        fontSize = saved.size;
        layout = saved.layout;
        lineHeight = saved.lineHeight;
        bookAnimations = saved.bookAnimations;
        paper = PaperTheme.values.firstWhere((p) => p.name == saved.paper);
        offset = widget.initialOffset ?? position;
      });
    } catch (_) {
      storageWarning();
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void storageWarning() {
    if (!mounted || storageWarningShown) {
      return;
    }
    storageWarningShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: AppText(
              'Okuma tercihleri kaydedilemiyor. Cihaz depolamasını kontrol edin.',
            ),
          ),
        );
      }
    });
  }

  Future<void> saveSettings() async {
    try {
      await store.saveSettings(
        ReadingSettings(
          font: font,
          size: fontSize,
          paper: paper.name,
          layout: layout,
          lineHeight: lineHeight,
          bookAnimations: bookAnimations,
        ),
      );
    } catch (_) {
      storageWarning();
    }
  }

  Future<void> savePosition(int value) async {
    offset = value;
    if (widget.bookId == null) {
      return;
    }
    try {
      await store.savePosition(widget.bookId!, value);
    } catch (_) {
      storageWarning();
    }
  }

  Widget settings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const LanguagePicker(),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const AppText('Kitap açılış ve kapanış animasyonu'),
        value: bookAnimations,
        onChanged: (value) {
          setState(() => bookAnimations = value);
          saveSettings();
        },
      ),
      const AppText(
        'OKUMA GÖRÜNÜMÜ',
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 24),
      const AppText('Yazı tipi'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in {
            'Lora': 'Lora',
            'Literata': 'Literata',
            'Sistem': 'Sade',
          }.entries)
            ChoiceChip(
              label: AppText(
                entry.value,
                style: TextStyle(
                  fontFamily: entry.key == 'Sistem' ? null : entry.key,
                ),
              ),
              selected: font == entry.key,
              onSelected: (_) {
                setState(() => font = entry.key);
                saveSettings();
              },
            ),
        ],
      ),
      const SizedBox(height: 24),
      AppText('Yazı boyutu · ${fontSize.round()}'),
      Slider(
        value: fontSize,
        min: 16,
        max: 32,
        divisions: 16,
        label: '${fontSize.round()}',
        onChanged: (value) => setState(() => fontSize = value),
        onChangeEnd: (_) => saveSettings(),
      ),
      const SizedBox(height: 12),
      const AppText('Sayfa düzeni'),
      const SizedBox(height: 8),
      layoutButtons(automatic: true),
      const SizedBox(height: 8),
      const SizedBox(height: 20),
      const AppText('Satır aralığı'),
      Slider(
        value: lineHeight,
        min: 1.0,
        max: 2.1,
        divisions: 22,
        label: lineHeight.toStringAsFixed(2),
        onChanged: (value) => setState(() => lineHeight = value),
        onChangeEnd: (_) => saveSettings(),
      ),
      const SizedBox(height: 12),
      const AppText('Sayfa dokusu'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final theme in PaperTheme.values)
            Semantics(
              selected: paper == theme,
              child: Tooltip(
                message: tr(context, theme.label),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() => paper = theme);
                    saveSettings();
                  },
                  child: Container(
                    width: 108,
                    height: 76,
                    decoration: BoxDecoration(
                      color: theme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: paper == theme
                            ? const Color(0xFF64745A)
                            : const Color(0xFFCBC7BC),
                        width: paper == theme ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppText(
                          'Aa',
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 23,
                            color: theme.ink,
                          ),
                        ),
                        AppText(
                          theme.label,
                          style: TextStyle(fontSize: 11, color: theme.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 24),
    ],
  );

  Widget page() => widget.book != null
      ? PagedBook(
          key: readerKey,
          book: widget.book!,
          bookId: widget.bookId,
          store: store,
          initialOffset: offset,
          onPositionChanged: savePosition,
          onPageCountChanged: widget.onPageCountChanged,
          paper: paper,
          font: font,
          fontSize: fontSize,
          layout: layout,
          lineHeight: lineHeight,
          onPinch: (scale) {
            final size = (fontSize * scale).clamp(16.0, 32.0);
            if (size == fontSize) return;
            setState(() => fontSize = size);
            saveSettings();
          },
          controlsVisible: controlsVisible,
          onToggleControls: () =>
              setState(() => controlsVisible = !controlsVisible),
          onToggleFullscreen: toggleFullscreen,
          onEscape: () {
            if (fullscreen) {
              toggleFullscreen();
            } else {
              setState(() => controlsVisible = !controlsVisible);
            }
          },
        )
      : Container(
          constraints: const BoxConstraints(maxWidth: 760),
          decoration: BoxDecoration(
            color: paper.background,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(
            painter: PaperPainter(paper),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 600 ? 26 : 60,
                vertical: 48,
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  fontFamily: font == 'Sistem' ? null : font,
                  fontSize: fontSize,
                  height: lineHeight,
                  color: paper.ink,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'OKUMA ÖNİZLEMESİ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 3,
                        color: paper.ink.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Bir sayfanın sessizliği',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 30, height: 1.3),
                    ),
                    const SizedBox(height: 16),
                    const Text('❧', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    const Text(
                      'Sabahın ilk ışığı pencerenin kenarına düşerken evin içi usulca aydınlandı. Masanın üzerinde açık duran kitap, kaldığı yerden devam edecek bir yolculuğu bekliyordu.',
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Bir sayfayı çevirmek bazen uzak bir şehre varmak gibidir. Kelimeler, hiç görmediğimiz sokaklara açılır; tanımadığımız insanların sesini bize yaklaştırır. Zaman biraz yavaşlar, dışarıdaki dünya bir süreliğine sessizleşir.',
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Rahat bir yer bul. Işığı sevdiğin gibi ayarla. Bu küçük sessizlikte, bir sonraki cümlenin seni nereye götüreceğini merak ederek okumaya devam et.',
                    ),
                    const SizedBox(height: 40),
                    Text(
                      '—  1  —',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: paper.ink.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

  @override
  Widget build(BuildContext context) => widget.settingsOnly
      ? Scaffold(
          appBar: AppBar(title: const AppText('Okuma ayarları')),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [settings()],
                  ),
                ),
        )
      : CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.f11): toggleFullscreen,
            if (fullscreen)
              const SingleActivator(LogicalKeyboardKey.escape):
                  toggleFullscreen,
          },
          child: PopScope(
            canPop: !fullscreen,
            onPopInvokedWithResult: (didPop, result) {
              if (!didPop && fullscreen) toggleFullscreen();
            },
            child: Scaffold(
              backgroundColor: paper.background,
              appBar: fullscreen
                  ? null
                  : AppBar(
                      toolbarHeight: controlsVisible
                          ? (MediaQuery.sizeOf(context).width >= 650 ? 40 : 48)
                          : 28,
                      backgroundColor: paper.background,
                      foregroundColor: paper.ink,
                      automaticallyImplyLeading: controlsVisible,
                      title: controlsVisible
                          ? Text(
                              widget.book?.title ?? tr(context, 'Okuma odası'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Lora',
                                fontSize: 16,
                              ),
                            )
                          : null,
                      actions: [
                        if (controlsVisible && widget.book != null)
                          IconButton(
                            tooltip: tr(context, 'Kitap içinde ara'),
                            onPressed: () =>
                                readerKey.currentState?.searchBook(),
                            icon: const Icon(Icons.search),
                          ),
                        if (controlsVisible &&
                            widget.book != null &&
                            MediaQuery.sizeOf(context).width >= 800) ...[
                          layoutButtons(),
                          IconButton(
                            tooltip: tr(context, 'Yazıyı küçült'),
                            onPressed: fontSize > 16
                                ? () => resizeFont(-2)
                                : null,
                            icon: const Icon(Icons.text_decrease),
                          ),
                          IconButton(
                            tooltip: tr(context, 'Yazıyı büyüt'),
                            onPressed: fontSize < 32
                                ? () => resizeFont(2)
                                : null,
                            icon: const Icon(Icons.text_increase),
                          ),
                        ],
                      ],
                    ),
              body: loading
                  ? const Center(child: CircularProgressIndicator())
                  : SafeArea(
                      child: GestureDetector(
                        onDoubleTap: widget.book == null
                            ? toggleFullscreen
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: widget.book == null
                              ? SingleChildScrollView(
                                  child: Center(child: page()),
                                )
                              : page(),
                        ),
                      ),
                    ),
            ),
          ),
        );
}

class PaperPainter extends CustomPainter {
  PaperPainter(this.theme);
  final PaperTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final grain = Paint()..color = theme.ink.withValues(alpha: 0.045);
    for (var i = 0; i < size.width * size.height / 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + random.nextDouble() * 1.8, y + 0.5),
        grain,
      );
    }
    final edge = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.black.withValues(alpha: 0.06),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.04),
          Colors.black.withValues(alpha: 0.025),
        ],
        stops: const [0, 0.045, 0.9, 1],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, edge);
  }

  @override
  bool shouldRepaint(PaperPainter oldDelegate) => oldDelegate.theme != theme;
}
