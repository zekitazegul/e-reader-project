# E-reader build 16 — 2026-10-26

Adds an offline catalog of researched print reference editions for the current
library. The 94 researched file/title variants include duplicate editions and
bundles: 87 have sourced reference totals, 7 remain explicitly unresolved.
Full references and limitations are in PRINT_PAGE_RESEARCH_2026-10-26.md.

Long-press book information now shows the print total, reference edition, source
URLs and average screen pages per print page, calculated from the last completed
reader layout. An unopened book does not receive an invented screen total.
Reader progress automatically uses the researched total when no manual total
exists. Embedded page markers retain precedence. Clearing a manual override
restores the researched reference total. Unknown editions keep manual entry.

The compact footer still has no Ekran caption or information icon. Tap its
counter to inspect the conversion and reference edition. Print position remains
approximate unless the file supplies fixed page markers. Catalog data does not
change the book text, reading offsets or annotations.

The app uses exact known filename aliases or a full title plus matching author;
it does not fuzzy-match volumes or trust copied ISBNs. Bibliographic metadata
only is bundled; none of the user's source books are included in the app.

Validation: all 123 Flutter tests passed; static analysis found no issues.
Release APK built and installed successfully on the connected Samsung phone;
Android reports versionCode 16. Device UI confirmed Asayi Musa's stored layout
total 2867, reference print total 304 and conversion 9.43 screen pages per print
page. Evidence: build/phone-verification/build16-print-details-bottom.png.
