import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'books.dart';
import 'library.dart';
import 'paged_book.dart';

void main() => runApp(const EReaderApp());

class EReaderApp extends StatelessWidget {
  const EReaderApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'E-Reader',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF64745A)),
      scaffoldBackgroundColor: const Color(0xFFF0EEE8),
      useMaterial3: true,
    ),
    home: const LibraryPage(),
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
  const ReaderPage({super.key, this.book});
  final BookContent? book;
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  String font = 'Lora';
  double fontSize = 20;
  PaperTheme paper = PaperTheme.ivory;

  Widget settings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'OKUMA GÖRÜNÜMÜ',
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 24),
      const Text('Yazı tipi'),
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
              label: Text(
                entry.value,
                style: TextStyle(
                  fontFamily: entry.key == 'Sistem' ? null : entry.key,
                ),
              ),
              selected: font == entry.key,
              onSelected: (_) => setState(() => font = entry.key),
            ),
        ],
      ),
      const SizedBox(height: 24),
      Text('Yazı boyutu · ${fontSize.round()}'),
      Slider(
        value: fontSize,
        min: 16,
        max: 32,
        divisions: 16,
        label: '${fontSize.round()}',
        onChanged: (value) => setState(() => fontSize = value),
      ),
      const SizedBox(height: 12),
      const Text('Sayfa dokusu'),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final theme in PaperTheme.values)
            Semantics(
              selected: paper == theme,
              child: Tooltip(
                message: theme.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => paper = theme),
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
                        Text(
                          'Aa',
                          style: TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 23,
                            color: theme.ink,
                          ),
                        ),
                        Text(
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
      const Text(
        'Biraz yavaşla. Kendine bir sayfa ayır.',
        style: TextStyle(color: Color(0xFF66705E), height: 1.6),
      ),
    ],
  );

  Widget page() => widget.book != null
      ? PagedBook(
          key: ValueKey('${widget.book!.title}-$font-$fontSize'),
          book: widget.book!,
          paper: paper,
          font: font,
          fontSize: fontSize,
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
                  height: 1.85,
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: const Color(0xFFF0EEE8),
      title: const Row(
        children: [
          Icon(Icons.auto_stories_outlined, size: 22),
          SizedBox(width: 12),
          Text('E-Reader'),
        ],
      ),
      actions: [
        if (MediaQuery.sizeOf(context).width >= 480)
          const Padding(
            padding: EdgeInsets.only(right: 20),
            child: Center(child: Text('Okuma odası')),
          ),
      ],
    ),
    body: LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        return SingleChildScrollView(
          padding: EdgeInsets.all(wide ? 36 : 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: page()),
                        const SizedBox(width: 36),
                        SizedBox(width: 270, child: settings()),
                      ],
                    )
                  : Column(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: settings(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        page(),
                      ],
                    ),
            ),
          ),
        );
      },
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
