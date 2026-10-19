#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/logs
(cd backend && npm ci && npm test) 2>&1 | tee data/logs/backend-unit.log
test_uri="${TEST_MONGODB_URI:-mongodb://127.0.0.1:27028/ludo_test?replicaSet=ludo}"
(cd backend && TEST_MONGODB_URI="$test_uri" npm run test:integration) 2>&1 | tee data/logs/backend-integration.log
bash scripts/bootstrap-flutter.sh 2>&1 | tee data/logs/flutter-validation.log
(cd frontend && flutter build apk --debug --dart-define=API_URL=http://10.0.2.2:3107) 2>&1 | tee data/logs/android-build.log
echo 'All checks passed. APK: frontend/build/app/outputs/flutter-apk/app-debug.apk'
