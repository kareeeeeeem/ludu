#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../frontend"
flutter create --project-name ludo_club --org club.ludo --platforms android,ios .
python3 - <<'PY'
from pathlib import Path
p = Path('android/app/src/main/AndroidManifest.xml')
s = p.read_text()
if 'android.permission.INTERNET' not in s:
    s = s.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
s = s.replace('android:label="ludo_club"', 'android:label="Ludo Club"')
s = s.replace('<application', '<application android:allowBackup="false"', 1) if 'android:allowBackup' not in s else s
p.write_text(s)
debug = Path('android/app/src/debug/AndroidManifest.xml')
if debug.exists():
    d = debug.read_text()
    if 'usesCleartextTraffic' not in d:
        d = d.replace('</manifest>', '<application android:usesCleartextTraffic="true"/>\n</manifest>')
    debug.write_text(d)
generated_test = Path('test/widget_test.dart')
if generated_test.exists() and 'MyApp' in generated_test.read_text():
    generated_test.unlink()
PY
flutter pub get
flutter analyze
flutter test
