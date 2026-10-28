# E-reader build 10 — 2026-10-26

- Pencil buttons on the right of list entries and covers open a rename/remove
  dialog. Empty titles are rejected, cancellation leaves metadata unchanged,
  removal retains its separate confirmation. Source filenames remain unchanged.
- Custom titles persist by content fingerprint and appear in the reader,
  alphabetical sorting, and the annotation index.
- Long press opens book information: title, author when present in EPUB/DOCX
  metadata, extension, original filename, size, and last calculated page count.
  Reflowable page counts depend on reading layout; uncalculated counts are
  explicitly identified. PDF author metadata is not extracted.
- EPUB nested-block filtering uses set membership instead of repeatedly scanning
  the complete chapter block list. Opening reuses history fingerprints and decoded
  text in a bounded LRU cache (3 books / 4 million text characters). Concurrent
  requests share decoding; failed decodes can be retried. Cache is session-only.
- Initial pagination prepares the visible spread, then builds the full index in
  the background. The repeated in-page number is removed; navigation retains the
  single current/total counter. Normal-scale phone footer tools share one row;
  large system text retains the two-row layout. Removed number space is reclaimed.
- Newly registered books normalize repeated spaces, tabs and layout line breaks
  within paragraphs, retaining paragraph boundaries. EPUB, DOCX and converted
  MOBI reading all use this pipeline. Existing history entries retain original
  text extraction so saved UTF-16 annotation and reading offsets remain valid.
- New labels are localized in Turkish, English and Dutch; other offered languages
  use English for these new labels.

## Page-boundary defect

RenderEditable reserves 3 logical pixels for its hidden cursor and caret gap.
The previous paginator measured the full editable width, so near-boundary words
could wrap into another line in the actual reader and be clipped. The decoded
text still existed, but some words were visually inaccessible at the page edge.
Pagination now subtracts the exact margin, shares strut metrics with rendering,
and includes accessibility line/letter/word spacing and bold settings in layout.

A regression checks actual RenderEditable selection boxes on every page at
32-point Lora and three text scales, as well as exact concatenation of all pages
back into the original text. It reproduced clipping before the caret-margin fix
and passes afterward. The specific Asayı Musa EPUB in the phone's private app
storage was not extracted; this is a reproduced layout defect, not a completed
source-file comparison of that edition.

## Opening animation

Duration is 2.2 seconds. Static shelf/background and live library use separate
repaint boundaries; home growth uses a paint transform with fixed layout, and
the dynamic painter no longer allocates a full-canvas saveLayer. A stable home
key preserves its state when the scene disappears. Folder exclusion fingerprint
calculations run off the UI thread; no hashes are calculated when there are no
exclusions. Reduced-motion behavior remains covered by tests.

Validation so far: analyzer clean; 109 tests pass including page-boundary checks.
