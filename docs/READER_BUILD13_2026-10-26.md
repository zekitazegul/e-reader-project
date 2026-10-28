# E-reader build 13 — 2026-10-26

Removes the library pencil buttons and all rename/remove dialogs and handlers.
Long press opens book information only, in both grid and list views. Previously
stored names and removal exclusions remain readable for upgrade compatibility.
Includes the complete wrapped titles, single-row phone navigation/bookmarks,
page-boundary correction, text preparation and opening animation improvements
from builds 10–12.

Initial pagination prepares the current and next spread so the first swipe works
while full indexing continues. The saved-position/loading regression now uses a
physical drag rather than the next-page button and passes. Final focused checks:
8 library/details/navigation tests plus 6 pagination tests pass; analyzer clean.

Final release APK built and installed successfully on the connected Android
phone. Visually verified complete wrapped titles with no pencil controls, and
Asayı Musa's single current/total counter and bookmark buttons on the same row
at the device's 130% text setting. Evidence: build/phone-verification/build13-library.png
and build13-reader.png. Source-file editing/removal was not exercised on the phone.
