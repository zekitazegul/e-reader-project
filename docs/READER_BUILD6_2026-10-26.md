# E-reader build 6 — 2026-10-26

- Added hamburger before library logo: library, import, folder, reading settings, language, other app installers, support.
- Bottom navigation: library list, main menu drawer, back. Hidden during reader fullscreen.
- Android navigation bar hidden with transient swipe access; app navigation stays available.
- One-time 1.2-second red book opening animation; reduced-motion preference skips it.
- Removed library slogan. On narrow screens import moved into drawer to preserve toolbar space.
- Default reading line height reduced to 1.15, adjustable 1.0–2.1. Previous defaults migrate; custom values persist. Text and annotation offsets unchanged.

Validation: existing suite plus phone-width navigation and animation tests. Device installation and final validation recorded in session.

Final automated checks: all 89 Flutter tests passed; Flutter analyze reported no issues; Android release APK built successfully.

Installed on SM-S926B, versionCode 6 confirmed. Home screenshot verified hamburger before logo, gear before language, app bottom navigation and hidden Android navigation bar. Drawer entries verified via device UI hierarchy.
