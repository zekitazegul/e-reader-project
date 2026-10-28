# E-reader build 7 — 2026-10-26

- 2.8-second perspective book opening: red book leaves a bookshelf, opens in mid-air, and the live home page grows out of its right page. Reduced-motion skips the sequence. No bitmap or remote asset dependency.
- Library title and menu both use Kütüphanem. Toolbar uses e-Reader wordmark, with settings immediately before language; folder selection remains in the drawer on phones.
- Bottom left opens drawer; center Home returns to library and closes drawer; right goes back.
- Long press a cover/list row to remove a book, with confirmation. Source files stay intact. Persistent content-specific exclusions prevent automatic rescans from restoring removed entries.
- Update shortcut opens the repository Releases page. Share opens Android's chooser with a read-only FileProvider URI for the installed APK. Nothing is sent automatically. No release was published by this change.
- Underlines and notes shortcut lists quotes, book names and notes. Tapping opens the book at the stored UTF-16 text offset. List refreshes after returning from reading.
- Selection menu label is Translate / Tercüme / Vertalen without Dictionary suffix. Offline lexical translation behavior is unchanged.
- Reading text preserves natural last-line descent in both measurement and EditableText. Pagination reserves an extra 2 logical pixels; pinch test loads Lora and checks natural glyph descent fits after enlargement.
- MOBI source fingerprint maps to a verified library EPUB. Repeated opens and app restarts reuse it; changed source or a missing converted EPUB regenerates it. Existing converted books from before this mapping may require one initial conversion to establish the mapping.

Validation: 93 tests passed together before the final wordmark change; focused library/navigation tests rerun after that change. Animation stages rendered and visually inspected in build/splash-{shelf,open,reveal}.png. Final analyzer/build/device results are recorded below.

Library sorting: default recently read, with alphabetical and recently added choices. Sort choice and per-content dates persist; subsequent scans keep existing dates. Existing books receive their first-seen date on this upgrade because earlier builds did not record import dates.

Final automated validation including sorting: all 95 Flutter tests passed; Flutter analyze reports no issues.

Device checks on build 7: sort popup shows Recently read checked by default, Recently added and Alphabetical; bottom-left opens drawer with annotation/update/share shortcuts; center Home returns to library; APK chooser shows E-Reader.apk without sending. Build 8 only fits the library heading on one line; 8 focused tests and analyzer pass.
