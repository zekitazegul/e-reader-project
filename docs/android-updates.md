# Android updates

The update menu queries the latest stable release of
`zekitazegul/e-reader-project` and starts an Android DownloadManager download
without opening a GitHub page. Android still requires user approval to install.
Startup and resume checks show a passive new-version notice and a menu badge.
No download starts until the user taps Update. Manual checks show release notes.
Checks on resume are limited to once every fifteen minutes; offline failures do
not interrupt reading.

Build with `flutter build apk --release`. When switching from tests/debug to
release, do not skip pub/platform tooling regeneration with `--no-pub`; the
generated Android registrant must exclude development-only plugins.

Publish the universal APK as **E-Reader-Installer.apk**. Use tags such as
**v1.0.0+21**, matching the version and monotonically increasing build number
in pubspec.yaml. Draft and prerelease versions are ignored. The same signing
key must be used for every update; keep the existing keystore private.

The first public stable release is `v1.0.0+21`, published on 2026-10-27:
https://github.com/zekitazegul/e-reader-project/releases/tag/v1.0.0%2B21
Its universal APK and update metadata were checked through anonymous download
URLs after publishing. Never publish an older build as the latest release.

Modern Android devices save the APK in Downloads. Older Android devices use
the app's external downloads directory to avoid storage permissions. The
completed-download notification opens the installer.
