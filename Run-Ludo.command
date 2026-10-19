#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p data/logs
exec > >(tee -a data/logs/ios-launch.log) 2>&1
trap 'result=$?; if [ "$result" -ne 0 ]; then echo "Launch failed. See data/logs/ios-launch.log"; read -r -p "Press Enter to close." _ || true; fi' EXIT
export PATH="$HOME/development/flutter/bin:$PATH"
xcrun simctl list devices booted -j > data/logs/booted-ios.json
device_id="$(python3 - <<'PYDEVICE'
import json
from pathlib import Path
state=json.loads(Path('data/logs/booted-ios.json').read_text())
devices=[d for runtime,items in state['devices'].items() if '.iOS-' in runtime for d in items if d['state']=='Booted']
if len(devices)!=1:
    raise SystemExit('Expected exactly one already-running iOS Simulator. Keep the intended iPhone Simulator running and retry.')
print(devices[0]['udid'])
PYDEVICE
)"
echo "Using the already-running iOS Simulator: $device_id"
echo 'No simulator will be created or booted by this script.'
if ! curl -fsS http://127.0.0.1:3107/health | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get("ok") and d.get("currency")=="EGP"' 2>/dev/null; then
  bash scripts/dev-local.sh > data/logs/local-server.log 2>&1 &
  ready=''
  for attempt in $(seq 1 60); do
    if curl -fsS http://127.0.0.1:3107/health | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get("ok") and d.get("currency")=="EGP"' 2>/dev/null; then ready=1; break; fi
    sleep 2
  done
  if [ -z "$ready" ]; then echo 'Local API failed. See data/logs/local-server.log.'; exit 1; fi
fi
bash scripts/bootstrap-flutter.sh
cd frontend
flutter run --debug -d "$device_id" --dart-define=API_URL=http://127.0.0.1:3107
