#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -f frontend/build/web/index.html ]; then
  echo 'Build Web first: cd frontend && flutter build web --dart-define=API_URL=http://127.0.0.1:3108'
  exit 1
fi
if [ ! -d backend/node_modules ]; then (cd backend && npm ci); fi
mongo_port="${LUDO_MONGO_PORT:-27028}"
mkdir -p data/mongo data/logs
mongo_pid=''
if ! nc -z 127.0.0.1 "$mongo_port" 2>/dev/null; then
  command -v mongod >/dev/null || { echo 'Install MongoDB Community 7.'; exit 1; }
  mongod --dbpath "$PWD/data/mongo" --port "$mongo_port" --bind_ip 127.0.0.1 --replSet ludo --logpath "$PWD/data/logs/mongo.log" & mongo_pid=$!
fi
LUDO_MONGO_PORT="$mongo_port" node scripts/init-local-mongo.mjs
mock_key="${MOCK_PLATFORM_KEY:-local-only-mock-key}"
MOCK_PLATFORM_KEY="$mock_key" node mock-platform/server.mjs & mock_pid=$!
(cd backend
  MONGODB_URI="mongodb://127.0.0.1:$mongo_port/ludo_club?replicaSet=ludo" \
    NODE_ENV=development PORT=3108 HOST=127.0.0.1 PLATFORM_MODE=true PLATFORM_MOCK=false \
    JWT_SECRET=local-demo-only-platform-jwt-secret-32-characters \
    PLATFORM_API_URL=http://127.0.0.1:3110 PLATFORM_API_KEY="$mock_key" \
    PLATFORM_ADMIN_API_KEY="$mock_key" \
    PLATFORM_COSMETIC_PRICES_JSON='{"dice_gold":75,"token_metallic":60}' \
    CORS_ORIGINS=http://127.0.0.1:8080 \
    node src/server.js) & api_pid=$!
node scripts/serve-web.mjs & web_pid=$!
cleanup() {
  kill "$mock_pid" "$api_pid" "$web_pid" 2>/dev/null || true
  if [ -n "$mongo_pid" ]; then kill "$mongo_pid" 2>/dev/null || true; fi
}
trap cleanup EXIT INT TERM
echo 'Open http://127.0.0.1:3110/ for the local platform launcher.'
wait "$api_pid"
