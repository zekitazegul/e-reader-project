# E-reader build 9 — 2026-10-26

Library heading explicitly disables wrapping and limits the title to one line.
The existing scale-down layout fits the full localized title beside the sorting
and view controls, including narrow phone screens.

Validation: Flutter analyze reports no issues. All 6 library view and app
navigation tests pass, including 320-pixel phone width and tablet layouts.

Release APK built successfully and installed over the existing app on the
connected Android phone. Device screenshot confirms Kütüphanem is fully visible
on one line beside all three controls: build/phone-verification/build9.png.
