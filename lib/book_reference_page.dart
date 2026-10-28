class BookReferencePage {
  const BookReferencePage(this.offset, this.label);
  final int offset;
  final String label;
}

/// Partition screen pages into contiguous print-page groups. Integer bounds
/// ensure every screen belongs to exactly one group, including uneven ratios.
({int page, int screen, int screens}) printPagePosition(
  int screenIndex,
  int screenTotal,
  int printTotal,
) {
  assert(screenTotal > 0 && printTotal > 0);
  final index = screenIndex.clamp(0, screenTotal - 1);
  final page = index * printTotal ~/ screenTotal + 1;
  final start = ((page - 1) * screenTotal + printTotal - 1) ~/ printTotal;
  final end = (page * screenTotal + printTotal - 1) ~/ printTotal;
  return (page: page, screen: index - start + 1, screens: end - start);
}

BookReferencePage? referencePageAt(List<BookReferencePage> pages, int offset) {
  var low = 0;
  var high = pages.length;
  while (low < high) {
    final middle = (low + high) ~/ 2;
    if (pages[middle].offset <= offset) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low == 0 ? null : pages[low - 1];
}

int estimatedReferencePage(int offset, int textLength, int total) =>
    ((offset.clamp(0, textLength) / (textLength > 0 ? textLength : 1) * total)
                .floor() +
            1)
        .clamp(1, total);
