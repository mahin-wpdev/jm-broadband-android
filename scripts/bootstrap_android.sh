#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -e android/app/build.gradle && ! -e android/app/build.gradle.kts ]]; then
  flutter create --platforms=android --org com.jmbroadband --project-name jm_broadband_app .
fi
python3 - <<'PY'
from pathlib import Path
p=Path('android/app/src/main/AndroidManifest.xml')
s=p.read_text()
permission='<uses-permission android:name="android.permission.INTERNET" />'
if permission not in s:
    s=s.replace('<application',f'{permission}\n    <application',1)
    p.write_text(s)
print('Android project scaffold and INTERNET permission ready')
PY
