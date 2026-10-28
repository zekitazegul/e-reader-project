# E-reader build 19 — 2026-10-26

Replaces square grid tiles with portrait volumes at width/height ratio 0.65.
Code-drawn cloth covers include a shaded spine groove, fine gold border,
visible paper edges and a soft shadow. Titles wrap in full and scale to the
available cover area. Existing opening and long-press details remain available.
The list layout is unchanged. No generated images or new image dependencies.
Each grid row stands on a continuous wooden shelf with a lit top edge, wood
grain and a soft shadow. Shelf spacing follows the responsive column count.

Tapping a grid cover uses an 800 ms perspective opening transition anchored at
the selected cover. The jacket grows and pivots around its spine as the live
reader is revealed. List entries retain normal route behavior. Reduced-motion
settings also use the normal route. EPUB and PDF openings share this behavior;
the reader is opened after decoding, with no added artificial loading delay.

Validation: grid/list layouts, conversion reopening, book transition completion
and back navigation tests pass; static analysis clean.
Installed on the Samsung phone. Device screenshot confirms portrait covers on
continuous shelves; tapping Asayi Musa successfully opens the reader. Evidence:
build/phone-verification/build19-shelves.png and build19-reader.xml.
