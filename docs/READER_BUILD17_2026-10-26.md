# E-reader build 17 — 2026-10-26

The reading footer displays `1/10   31/304`: screen position within the current
print-page group on the left, print position and total on the right. Removes
the estimate caption and approximation symbol from the footer. Edition sources
and the explanation of proportional mapping remain available by tapping it.

Screen groups use exact integer boundaries from the fully calculated layout
total. Uneven ratios produce groups of adjacent sizes; every screen belongs to
one group and its counter resets to one when entering the next print page.
While indexing, the footer displays the loading state instead of inventing a
group size. Native EPUB fixed page labels retain precedence.

This build's Android APK targets arm64, matching the connected Samsung phone.

Validation: six focused tests passed, including uneven groups and narrow reader
layout; static analysis clean. Installed successfully. Samsung UI verified
`8/10   33/304` in Asayi Musa, without the estimate caption or approximation
symbol. Device UI evidence: build/phone-verification/build17-reader.xml.
