# Performance and stability work — 2026-10-28

Projects: `C:/e-reader`, `C:/cevsenApp`, `C:/KuranApp/kuran_app`.

## Changes saved

- E-reader: reuse unchanged local and Android-imported book objects using file metadata, with a 32 MiB cache budget. Discard entries no longer present after a scan. Hash only book objects not already registered in reading history; this also lets existing cover futures survive an unchanged scan. Decode cover thumbnails at 512 pixels wide. Skip MOBI preference initialization entirely when no conversion candidates exist; unavailable preference storage previously prevented an ordinary EPUB library from appearing. Bundle explicit runtime assets and retain dictionary licenses/source attribution. Resolve seven analyzer style findings.
- Cevsen: read preferences and both startup data files concurrently, decode JSON through `compute`, and avoid retaining their original JSON strings. Failure of the screen-awake platform service no longer blocks startup. Decode the logo at display resolution. Remove the unused `Motif` painter. Flush audio download buffers at 256 KiB boundaries instead of on every network chunk, preserving bounded buffering, cancellation and incomplete-file cleanup. Calculate total download size once per download operation.
- Quran: find a verse's page directly in raw references rather than allocating every page's `VerseRegion` and `Rect` objects. Use this path for voice navigation and next-verse playback. Add a regression test covering every reference in all bundled editions, missing references and page bounds.

## Verification

- Static analysis: no findings in all three projects.
- Cevsen: all 33 tests passed.
- Quran: 31 focused tests passed, covering the new lookup, voice navigation and audio service. The complete suite returned 305 passed and 14 failed. Failures concern dashboard drag feedback, fullscreen repeat-status visibility (12 language/size cases), and fullscreen memorization controls. These results do not establish a fully passing application suite.
- E-reader: all 145 tests passed, including unchanged-file reuse, changed content with unchanged size, deletion, book removal and multilingual library loading.
- Android release builds: all three succeeded, including the final incremental e-reader build with the last cache and asset changes. APKs are at `build/app/outputs/flutter-apk/app-release.apk` in each project. Reported sizes: e-reader 80.9 MB, Cevsen 51.6 MB, Quran 82.5 MB. These are build outputs, not measured size reductions.
- Initially no phone was available. The user subsequently connected a Samsung SM-S926B through wireless ADB; all three updates were installed with `adb install -r`, preserving application data. Installed build numbers: e-reader 22, Cevsen 25, Quran 95. Source version numbers and the Quran release record were updated accordingly; feature-only release notes remain empty because this update adds no user-facing feature.

## Phone follow-up

- All three installed applications launched successfully, and their home and reading screens were captured. Cevsen retained Bab 5; Quran retained page 506. E-reader retained its library and reopened the bundled book.
- Portrait and actual landscape screenshots were inspected for all three applications. Quran's full-sensor orientation required a temporary WindowManager override; screenshots and UI hierarchy rotation values establish the actual test orientation. Original automatic-rotation, user-rotation and WindowManager preferences were restored after checks.
- Explicit device assertions passed for e-reader 8/24 → 9/24 → 8/24 and Quran 506/604 → 507/604 → 506/604, after restarting each application and reopening its saved reading position. Results are saved as `reader-page-check.json` and `quran-page-check.json` with the phone verification artifacts.
- Evidence is stored under `build/phone-performance-2026-10-28/`; the reproducible local harness is `tool/phone_performance_check.py`. Captures and APKs are build artifacts, not source assets.
- Single Android activity-launch samples were collected before/after installation. They are not full reader-ready timings, are affected by installation and device/system caching, and do not establish a measured speedup. No download or microphone/voice-recognition test was performed on the phone. The earlier 14 Quran suite failures remain unresolved by this deployment.

No measured cold-start or frame-time improvement is claimed. Existing user work was preserved; source files are saved, with no repository-wide commit or cleanup of unrelated files.
