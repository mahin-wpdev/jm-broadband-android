# Arivo Android next-release (2026-09-22)

Companion PHP panel repository: `mahin-wpdev/panel`, branch `next-release`.
These are two independently versioned and deployed applications. This branch
does not change any installed phone app or running phpNuxBill instance.

## Verification on Windows
- Flutter 3.47.5 (stable); Flutter and Dart dependencies resolved.
- `flutter test --reporter expanded`: 8 tests passed.
- `flutter analyze --no-pub`: no issues found.
- `flutter build apk --release --no-pub`: succeeded.
- Signed release APK `build/app/outputs/flutter-apk/app-release.apk`:
  application ID `com.jmbroadband.jm_broadband_app`, version 1.0.4+5.
  APK Signature Scheme v2 verification succeeded with Arivo release signer.
- Build outputs and keystore credentials are local and must NOT be committed
  or uploaded with the public source repository.

## Not proven by these checks
- Complete Android flows under real account permissions, slow/unavailable
  RouterOS API, and expired user sessions.
- Backend transactional correctness for payments, PPPoE expiry,
  reseller/tenant visibility and ONU deletion.
- Production Panel and app SHA/version parity.
- Persistent one-second server-side traffic history (the current Live view
  samples while the screen is active).

## Release gate
The matching Panel `next-release` branch must pass PHP CI and its payment,
security and OLT acceptance checklist. Do not distribute this APK publicly
until production web-server log/installer exposure and historical private-log
publication have been handled. The APK's successful signature check is not a
substitute for server-side acceptance.
