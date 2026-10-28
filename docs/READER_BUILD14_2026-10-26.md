# E-reader build 14 — 2026-10-26

## Screen pages and book pages

The text reader labels reflowed pagination as Screen / Ekran. Its information
button opens reading position and print-edition settings without adding another
toolbar row. Publisher-defined EPUB 3 page-list links, EPUB 2 NCX pageTarget
links, epub:type=pagebreak and role=doc-pagebreak markers map to the existing
UTF-16 reading text. Roman labels are preserved. These are fixed source page
labels, not a guarantee of correspondence to every printed edition.

When source page information is unavailable, the user can enter the total pages
from their own print edition. The display explicitly says Estimated book /
Tahmini kitap and uses an approximation sign. This is a proportional estimate
from text position, never an exact print-page mapping or a count of uniquely
read pages. It does not depend on screen size or text size. Empty input removes
the saved estimate. Totals persist locally per content fingerprint. No page
count is guessed for Beyan, Asayı Musa or any other title.

The screen-page jump remains separate and is labelled as such. Reading text and
previously saved offsets remain unchanged by extracting reference-page metadata.

Format reference: https://www.w3.org/TR/epub-a11y-tech-12/#sec-nav-pagelist

## Android navigation

The app menu/home/back bar remains visible, including reader fullscreen mode.
Android navigation bars use transient reveal by edge swipe. Native window
insets changes, focus restoration and reader fullscreen are handled by a single
native visibility policy. A delayed restoration handles the interval after the
keyboard closes and system UI updates. Status bar visibility still follows
reader fullscreen. OS navigation is not disabled.

Platform reference: https://developer.android.com/develop/ui/views/layout/immersive

Validation: all 119 Flutter tests pass, including EPUB page mappings, whitespace
offsets, estimate persistence/removal, unknown print metadata, app navigation in
fullscreen and page-boundary checks. Final navigation tests pass; analyzer clean.
Android release APK builds successfully.

Device verification on the connected Samsung phone: app navigation is visible
in library and reader fullscreen; Android navigation is hidden by default,
reveals temporarily after an upward swipe from the bottom edge, then hides
automatically. It also hides after dismissing the page-jump keyboard. Captures
are in build/phone-verification/build14-navigation-{hidden,revealed,auto-hidden}.png,
build14-after-keyboard.png and build14-fullscreen.png. Asayı Musa's progress
dialog correctly reports that no source page mapping exists at the tested
position, offers the manual print-total field, and shows position 8.2% separately
from screen page 244/2867. No edition total was fabricated or saved for it.
