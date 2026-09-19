# JM Broadband Android — development foundation

Flutter Android client for a user-entered ISP panel URL + username + password. After a successful login, it displays the server-authorized customer/reseller/admin/superadmin shell. It needs the matching HTTPS PHP mobile API on the same server; the app alone cannot access the billing or ONU data.

**Status:** first source checkpoint. No production APK and no 29-feature completion claim.

## Browser-only GitHub Actions debug APK

1. Upload the entire *contents* of this archive into `mahin-wpdev/jm-broadband-android` (root of repo), including `.github/workflows/android-debug.yml` and `scripts/bootstrap_android.sh`.
2. Open repository **Actions** → **Android debug APK** → **Run workflow** (or push a commit to main).
3. Once all checks pass, open that run → **Artifacts** → `jm-broadband-debug-apk`. The artifact contains a debug `app-debug.apk` for testing; it is **not** a signed release build.

GitHub may ask you to enable Actions for a new repository. The generated Android scaffold exists only in the CI workspace unless committed separately; the bootstrap script creates it each build.

## Local development (optional)

```bash
bash scripts/bootstrap_android.sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Before production: run live API integration, fix reported analyzer/test issues, configure a reviewed package ID/signing process, create persistent Android project scaffolding, and use a signed release pipeline. Never upload private signing credentials, API keys or password files.
