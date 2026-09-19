
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Generate Android project if missing
if [[ ! -e android/app/build.gradle && ! -e android/app/build.gradle.kts ]]; then
  flutter create \
    --platforms=android \
    --org com.jmbroadband \
    --project-name jm_broadband_app .
fi

# Remove only Flutter's generated default MyApp test.
# Preserve all our real application tests.
if [[ -f test/widget_test.dart ]] && grep -q 'MyApp' test/widget_test.dart; then
  rm test/widget_test.dart
  echo "Removed outdated default Flutter widget test"
fi

# Add Android Internet permission
python3 - <<'PY'
from pathlib import Path

p = Path('android/app/src/main/AndroidManifest.xml')

s = p.read_text()

permission = '<uses-permission android:name="android.permission.INTERNET" />'

if permission not in s:
    s = s.replace(
        '<application',
        f'{permission}\n    <application',
        1
    )
    p.write_text(s)

print('Android project scaffold and INTERNET permission ready')
PY
