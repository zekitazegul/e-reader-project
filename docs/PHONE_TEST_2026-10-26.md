# Android phone test — build 2

- Release APK installed over Wi-Fi on SM-S926B. Existing imported books remained visible.
- Library opens directly with no search, sorting, format filters, or refresh icon.
- Square grid and list modes are user selectable; persistence and automatic refresh covered at phone/tablet portrait/landscape sizes.
- Language control is the last toolbar action and shows globe + saved language code (Tr on device).
- Default line height reduced from 1.75 to 1.3. Legacy default migrates once; later custom settings round-trip unchanged. Text offsets and bookmarks are preserved.
- Gesture direction uses accumulated movement, favors vertical intent for diagonal gestures, and stays locked until pointer release. Automated regressions cover initial sideways jitter and subsequent horizontal swipes.
- Android folder picker grants persistent read access. Native document queries read supported books without changing their originals. A retained provider cursor keeps document change notifications active.
- On-device verification: selected Documents/EReader-Test-20261026, granted Android access, saw Folder Test automatically appear, opened it, restarted the app, and confirmed the folder/book were still available.
- While the app remained open, adding Auto-Test-2.epub directly to the selected directory caused it to appear without pressing refresh or restarting. Temporary Auto-Test copies were removed; Folder Test remains available for manual reading checks.
- Device reading moved from page 1/59 to 2/59 with a mostly vertical swipe and to 3/59 with a horizontal swipe. Direction locking is additionally checked by widget tests. A later downward physical check was interrupted by the system notification shade and is not counted as verified.
- 41 focused tests passed. The three library tests were rerun with folder selection checks and passed. Final Flutter analysis: no issues. Android release compilation passed after the retained-cursor change.
- Device captures/XML and build/test logs are under build/phone-verification and build/, excluded from source control.

Manual follow-up: select the intended book directory with the folder icon and test upward/downward gestures while reading a real book.
