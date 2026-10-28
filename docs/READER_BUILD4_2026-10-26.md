# Reader build 4

## Behavior

- Library explanation panel removed. Dense list rows contain only titles; first tap reveals file name/type/size at the right, second tap opens. No leading book icon in list rows.
- Reading settings are immediately left of the language control in the library. Reader settings/fullscreen buttons removed. Double tap and F11/Escape retain fullscreen controls. Search is in the reader's top toolbar. Reading percentages/bars removed from text and PDF footers.
- Direction inference includes displacement since pointer down. An established axis forwards the drag synchronously without another layout frame. A changed axis waits only for the viewport layout. Pinch resizes text within 16–32 and preserves text offsets while reflowing pages.
- Long press in EPUB/DOCX/converted MOBI text selects words, with native handles and a custom dictionary/underline/note menu. Annotations persist by book fingerprint and exact UTF-16 offsets. Note balloons use a reserved gutter so annotations do not push or cover the text.
- Offline dictionary pairs: nl-tr, nl-en, en-nl, en-tr, tr-nl, tr-en. Bundled data are adapted from FreeDict/WikDict TEI under CC BY-SA 3.0. Attribution and per-source checksums are in assets/dictionaries. No request occurs during bundled lookup. Sentence/paragraph lookup lists lexical meanings and is not a grammatical machine translator.
- Additional supported source languages require an explicit download confirmation. Downloads fetch only a language-pair TEI resource, with no selected text in the URL/body; parsed lookup data are stored locally. Unsupported language pairs fail visibly and remain retryable.
- Unencrypted uncompressed/PalmDOC MOBI6 files convert into deterministic EPUB files locally and are saved in the library. Duplicate converted content is reused. Source files are preserved. KF8/HUFF-CDIC and DRM are not decoded. Format reference: https://github.com/kovidgoyal/calibre/blob/master/format_docs/pdb/mobi.txt; no third-party decoder code was copied.
- Android proposes existing Kitaplar/kitaplar/Books/books directories under internal storage, Documents or Download when no folder has already been selected. OS read permission is still required. Explicit saved folder choices take precedence.

## Validation

- Full Flutter test suite: 87 passed (build/release4-tests.log).
- Static analysis: no issues (build/release4-analyze.log).
- Release APK: build/app/outputs/flutter-apk/app-release.apk, version 1.0.0+4, 79.8 MB.
- Real phone MOBI sample converted into a readable EPUB: 732 paragraphs / 151974 text characters. Source and output stay under ignored build/phone-verification, not in Git.
- Tests cover same-axis response without waiting for a frame, direction lock, pinch/position preservation, every word fitting across 1–4 columns, editable/persistent notes and underline, all six offline dictionaries with a client that rejects network, explicit download consent, two-tap list behavior, duplicate conversion, fullscreen and settings persistence.
- Wi-Fi reconnected after the phone's ADB port changed. Build 4 installed successfully; device package confirmed versionCode 4.
- Physical build-4 checks: compact list contains only titles; first tap reveals filename/type/size, second opens the book. Library settings button immediately left of language control opens the settings screen. Reader top bar contains search, with no settings/fullscreen buttons and no reading percentage.
- Physical long press on `huis` in our own Dutch EPUB showed selection controls and dictionary/underline/note actions. Bundled nl-tr lookup returned `ev · hane`. Underline applied; a test note saved and appeared as an anchored balloon, and tapping the balloon reopened that note. The test note and generated EPUB fixtures were cleaned up afterwards.
- Physical double-tap verification using consecutive ADB `input tap` commands was inconclusive because injected tap timing did not enter fullscreen; controlled gesture tests for double tap/fullscreen passed. Human pinch, double-tap and perceived smoothness remain suitable manual follow-up checks.
- The real MOBI decoder was verified on the phone's file locally and conversion/open/deduplication was verified by widget tests. The original MOBI title was not located in the bounded physical library scan; no physical conversion claim is made.
