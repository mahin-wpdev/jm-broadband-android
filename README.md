# jm-broadband-android

## Builds and signing

- Internal test: `flutter build apk --debug`. This uses the machine's
  Android Debug key and is **not** a public release.
- Public distribution: configure untracked `android/key.properties` and its
  release keystore, then `flutter build apk --release --no-pub`. The release
  task fails closed if signing configuration is missing. Verify its certificate
  using Android SDK `apksigner verify --print-certs` before distribution.
- Do not commit signing credentials, keystores, private customer data or
  previously pulled APKs. Android release signing and internal debug signing
  must remain separate.

### Updating an existing debug-signed install

A previously installed 1.0.4 on the test handset uses the Android Debug
certificate; JM Broadband's public 1.0.5+6 APK uses a different release
certificate. Android rejects in-place upgrades across certificate changes,
even if the package name and version are correct. An internal 1.0.5+6
Debug APK signed with the **same original debug key** can update 1.0.4
in place via `adb install -r`, preserving local app data.

Never uninstall or clear an existing app as an automatic signing workaround.
Moving that device to public release requires a separate, user-approved
local-data backup/re-login/reinstall process (or intentionally distinct
application ID), not a silent in-place update. Peak speed data belongs to
the server and is not reset by changing the phone app.
