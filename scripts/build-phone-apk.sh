#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

ip="${1:-}"
if [[ ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo 'Usage: bash scripts/build-phone-apk.sh <MAC_PRIVATE_LAN_IP>' >&2
  exit 2
fi
IFS=. read -r a b c d <<< "$ip"
for part in "$a" "$b" "$c" "$d"; do
  if (( 10#$part > 255 )); then echo 'Invalid IPv4 address' >&2; exit 2; fi
done
if ! (( a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168) )); then
  echo 'Use a private LAN IPv4 address for the Mac; do not expose the local API publicly.' >&2
  exit 2
fi

backend_url="http://$ip:3107"
(
  cd frontend
  flutter pub get
  flutter build apk --debug --dart-define="API_URL=$backend_url"
)
cp frontend/build/app/outputs/flutter-apk/app-debug.apk delivery/LudoClub-local-phone-debug.apk
echo "Phone APK: $PWD/delivery/LudoClub-local-phone-debug.apk"
echo "Backend URL embedded for this build: $backend_url"
echo 'Start backend with LUDO_API_HOST=0.0.0.0 bash scripts/dev-local.sh on a trusted LAN.'
