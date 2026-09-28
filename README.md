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

### Release 1.0.7+8: Android restored-key recovery

On reinstall, Android previously restored encrypted login preferences without
restoring the original device-bound Keystore key. The first secure-storage
read then threw BAD_DECRYPT and left the app on an infinite startup spinner.
The app now resets unreadable local secure storage and shows Login, explicitly
ignores the storage plugin's `Data has been reset` marker as a server URL, and
has a bounded startup recovery path. Android auto-backup is disabled and
shared preferences are excluded from cloud/device-transfer data extraction.
Existing logged-in installs are updated in place using the **release signing
key**. Real device verification: `1.0.7` launches to Login with the configured
default Panel address and no repeat BAD_DECRYPT exception. Only local login
may need re-entry; server-owned RADIUS peak history is unchanged.
