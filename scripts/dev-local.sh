#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
project_dir="$PWD"
mkdir -p data/mongo data/logs
node scripts/setup.mjs
if [ ! -d backend/node_modules ]; then (cd backend && npm ci); fi
mongo_port="${LUDO_MONGO_PORT:-27028}"
api_port="${LUDO_API_PORT:-3107}"
mongo_pid=''
api_pid=''
cleanup() {
  if [ -n "$api_pid" ]; then kill "$api_pid" 2>/dev/null || true; fi
  if [ -n "$mongo_pid" ]; then kill "$mongo_pid" 2>/dev/null || true; fi
}
trap cleanup EXIT INT TERM
if ! nc -z 127.0.0.1 "$mongo_port" 2>/dev/null; then
  command -v mongod >/dev/null || { echo 'Install MongoDB Community 7 or use docker compose.'; exit 1; }
  mongod --dbpath "$project_dir/data/mongo" --port "$mongo_port" --bind_ip 127.0.0.1 --replSet ludo --logpath "$project_dir/data/logs/mongo.log" &
  mongo_pid=$!
fi
LUDO_MONGO_PORT="$mongo_port" node scripts/init-local-mongo.mjs
if nc -z 127.0.0.1 "$api_port" 2>/dev/null; then
  echo "Port $api_port is already occupied. Stop your previous Ludo server, or use LUDO_API_PORT=3108."
  exit 1
fi
cd backend
MONGODB_URI="mongodb://127.0.0.1:$mongo_port/ludo_club?replicaSet=ludo" PORT="$api_port" HOST="${LUDO_API_HOST:-127.0.0.1}" PLATFORM_MODE=true PLATFORM_MOCK=true node src/server.js &
api_pid=$!
cd "$project_dir"
echo "Local API: http://127.0.0.1:$api_port/health"
echo 'Leave this terminal open. Ctrl+C stops only processes started by this script.'
wait "$api_pid"
