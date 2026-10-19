# Platform developer: start here

**Current handoff gate:** free Classic/Practice, cosmetics, and paid Classic match orchestration are implemented and tested against the local mock. Paid play requires a versioned, explicitly approved policy and an enabled tier. Production rejects a test-only policy; with no approved policy, positive-point entry returns `503`. The real platform is not connected. Magic/Fast are disabled pending rules.

## 1. Files and local reproduction

- Backend: `../source/backend/` (Node/Express, Socket.IO, MongoDB replica set).
- Flutter: `../source/frontend/`; emulator APK: `../builds/LudoClub-platform-emulator-debug.apk`; Web output: `../builds/web/`.
- Mock platform: `../source/mock-platform/server.mjs`; launcher at `http://127.0.0.1:3110/`.
- API contract: `../docs/openapi.yaml`; Postman: `../docs/Ludo-Platform.postman_collection.json`; fuller explanation: `../docs/PLATFORM_INTEGRATION.md`.

Install Node 20+, Flutter, Android SDK and MongoDB with replica-set support. From `../source/`: `cd backend && npm ci`; `cd ../frontend && flutter pub get`; build Web with `flutter build web --release --dart-define=API_URL=http://127.0.0.1:3108 --no-wasm-dry-run`; return to `../source/` and run `bash scripts/dev-platform.sh`. Open the mock launcher, select Ludo, play a free game, purchase and equip Gold Dice, then Return to platform. `node scripts/verify-platform-demo.mjs` verifies launch/replay/revocation. For the emulator, install the APK and run `node scripts/launch-android-demo.mjs` while local services are running.

## 2. Production deployment and catalog

Deploy `source/backend` with `npm ci --omit=dev` and `node src/server.js`; use one scheduler process because it owns match timeouts, bots and financial reconciliation. Supply a persistent MongoDB replica set, HTTPS ingress, WebSocket upgrade support, and approved `CORS_ORIGINS`. Set `NODE_ENV=production`, `PLATFORM_MODE=true`, `PLATFORM_MOCK=false`, `MONGODB_URI`, a random 32+ character `JWT_SECRET`, `PLATFORM_API_URL` (HTTPS), server-only `PLATFORM_API_KEY`, separate `PLATFORM_ADMIN_API_KEY`, `PLATFORM_COSMETIC_PRICES_JSON` (approved integer point prices), `PLATFORM_MATCH_POLICY_JSON` (approved schema below), `HOST`, `PORT`, and `CORS_ORIGINS`. Keep `PLATFORM_TEST_POLICY=false`. Store credentials in a secret manager. Never package service keys in Flutter. Production rejects placeholder URLs/keys, mock mode, and test-only policies. Do not migrate or delete legacy financial records automatically.

Register game ID `ludo-club` in the host catalog. Use authenticated `GET /api/v1/game/catalog-info`, `GET /api/v1/game/modes`, public `GET /api/v1/game/health`, and public `GET /api/v1/game/ready`. Classic supports free and approved positive-point tiers; Practice is free; Magic and Fast are unavailable. Serve the Web build over HTTPS with an appropriate Flutter `--base-href` for a subpath. Build Android with the production HTTPS `API_URL` and host-approved signing/package policy. The APK is separately launched; it is not an embeddable library. iOS requires a native channel implementation before release.

## 3. Launch, identity and return

Issue a short-lived one-time authorization code scoped to `ludo-club`, an opaque globally unique player ID, launch ID, tenant ID, expiry, display name and avatar. The current local profile key is `playerId`; if host IDs are tenant-local, coordinate a `(tenantId, playerId)` mapping change before production. Web opens `https://host/ludo/#session=<encoded-code>`; Flutter removes the fragment immediately. Android starts `club.ludo.ludo_club/.MainActivity` with string intent extra `platform_session`. Ludo Flutter calls:

```http
POST /api/v1/platform/session/exchange
Content-Type: application/json

{"sessionToken":"one-time-code"}
```

The Ludo backend, not Flutter, calls `POST {PLATFORM_API_URL}/ludo/session/verify` with `Authorization: Bearer <PLATFORM_API_KEY>` and `{ "sessionToken": "one-time-code" }`. Required verified response: `{ "playerId":"opaque-id", "launchId":"unique-launch-id", "tenantId":"tenant", "gameId":"ludo-club", "expiresAt":"ISO-8601-within-5-minutes", "displayName":"Player", "avatar":"🎲" }`. Consume codes once. Ludo returns `{token,expiresIn:3600,user}`; send `Authorization: Bearer <token>` on game HTTP and Socket.IO `auth.token`. The game checks launch revocation and expiry on both transports. `POST /api/v1/game/session/end` revokes the game launch; Android finishes the activity. The host provides its own return navigation for Web. Never send client balances or roles as identity.

## 4. Points adapter contract

All calls below are **outbound from the Ludo backend** with server bearer authorization. Point amounts are nonnegative safe integers. Mutation calls use `Idempotency-Key` equal to the stable `reference`; the platform must atomically persist and replay the same result for duplicate keys. A timeout is ambiguous: query status before retrying.

| Platform endpoint | Request body | Expected result |
| --- | --- | --- |
| `POST /ludo/points/balance` | `{playerId}` | `{points:250}` |
| `POST /ludo/points/reserve` | `{playerId,matchId,points,reference}` | `{reservationId,status:"RESERVED",reference}`; atomically move available points into escrow |
| `POST /ludo/points/commit` | `{playerId,reservationId,matchId,reference}` | `{status:"COMMITTED",reservationId,reference}` |
| `POST /ludo/points/release` | same fields as commit | `{status:"RELEASED",reservationId,reference}` |
| `POST /ludo/points/settle` | `{matchId,awards:[{playerId,points}],commissionPoints,funding:"committed-entry-escrow",reference}` | `{status:"SETTLED",matchId,reference}`; atomically distribute the exact committed escrow once |
| `POST /ludo/points/purchase` | `{playerId,itemId,points,reference}` | `{approved:true,status:"COMMITTED",reference}` |
| `POST /ludo/points/transaction-status` | `{reference}` | durable transaction status, including pending/committed/declined |

The adapter and local mock are connected to paid private and public matches. Room creation and queue browsing do not reserve points. Once the room fills, Ludo persists the policy snapshot and reservation intents, reserves every participant, commits every reservation, then starts gameplay. A declined reservation releases confirmed holds. Ambiguous operations remain pending under the same idempotency key; the scheduler queries status and retries. Partial commit conflicts go to `MANUAL_REVIEW`. Completion records the server winner and sends one settlement; active cancellation returns entries through an escrow-funded settlement according to policy. Mongo stores `Game.platformFinance` state and references; `Audit` records transitions. A Mongo lease limits concurrent progress; deploy one scheduler owner. Monitor `RESERVING`, `RELEASING`, `COMMITTING`, `SETTLING` age and `MANUAL_REVIEW`. Never infer failure from timeout or manually release a committed reservation.

The platform **must** atomically enforce: unique `(matchId, playerId)` reservation, one final commit/release per reservation, one settlement per match, identical replay for the same key and payload, rejection of key reuse with changed payload, and `sum(awards.points)+commissionPoints == sum(committed entry points)` from that match. Committed entry points fund settlement. `commissionPoints` stays with the platform; Ludo never credits itself. A transaction-status response must include the original `reference`, `status`, and any `reservationId`/`matchId`; `404` means unknown, not proof that a timed-out mutation failed. The local mock enforces this contract but is process-memory test data, not a production financial service.

**Policy approval:** `PLATFORM_MATCH_POLICY_JSON` is validated against `source/backend/src/match-policy.js`. Example **TEST-ONLY**, never deploy as commercial policy:

```json
{"version":1,"policyId":"test-only-policy-v1","approved":false,"testOnly":true,"settlementFunding":"committed-entry-escrow","beforeStart":"release-reservations","afterStart":"return-entries-via-settlement","forfeit":"remaining-player-wins","timeout":"engine-three-misses-forfeit","rounding":"integer-exact","tiers":[{"points":10,"capacity":2,"winnerPoints":18,"commissionPoints":2},{"points":10,"capacity":4,"winnerPoints":36,"commissionPoints":4}]}
```

Local test execution passes this policy to `createApp({test:true,...})`; a local server may set `PLATFORM_TEST_POLICY=true`. Production requires `approved:true,testOnly:false`, an approved policy ID/version, and platform-admin configuration of matching `matchTiers` through `PUT /api/v1/platform/admin/config`. The platform business owner must approve actual tiers, winner award, commission, cancellation refund, forfeit and timeout rules. No EGP conversion occurs. Cosmetic prices are independently approved in `PLATFORM_COSMETIC_PRICES_JSON`. The client calls `GET /api/shop/catalog`, `POST /api/shop/buy` with `{itemId,requestId:<UUID>}`, `GET /api/shop/purchases/{requestId}/status`, and `POST /api/inventory/equip` with `{category,itemId}`. Ownership is recorded only after a confirmed platform debit.

## 5. Game access, Socket.IO and admin

Authenticated free-play endpoints include `POST /api/rooms/create` with `{capacity:2|4,stakeMinor:0}`, `POST /api/rooms/join` with `{code}`, `POST /api/games/practice`, `POST /api/matchmaking/queue`, `GET /api/matchmaking/status`, `POST /api/games/{id}/start`, `POST /api/games/{id}/action` with `{type:"roll"|"move"|"forfeit",token?:0..3,revision}`, `GET /api/games/history`, `GET /api/stats/user`, and `GET /api/stats/leaderboard?period=all|week|month&page=0`. Socket.IO authenticates with the same game JWT; client events include `sync`, `join_queue`, `leave_queue`, `create_room`, `join_room`, `start_game`, `leave_room`, `roll_dice`, `make_move`, `forfeit_game`, `send_chat`; server emits `game_state` and `chat_message`. The server generates dice and validates revisions, turns, moves and winners. Allow WebSocket upgrades and route clients to the scheduler owner or add an approved shared adapter before horizontal scaling.

Game configuration uses `GET/PUT /api/v1/platform/admin/config` with `Authorization: Bearer <PLATFORM_ADMIN_API_KEY>`. A PUT requires `{gameEnabled,maintenanceMessage,enabledModes:["classic","practice"],matchTiers:[0],cosmeticAvailability:{},reason}`; it is audited. This is game configuration, not platform financial administration. Never accept client `isAdmin` claims.

The same service credential may call `GET /api/v1/platform/admin/finance` to inspect pending or manual-review matches and `POST /api/v1/platform/admin/finance/{id}/reconcile` to retry a pending operation using its original key. `MANUAL_REVIEW` cannot be auto-settled or refunded through this endpoint; compare platform transaction records and obtain an operator decision. The Ludo API exposes no client-side award endpoint.
An authorized game operator can call `POST /api/v1/platform/admin/matches/{id}/cancel` with `{ "reason": "specific incident reason" }`. Before funding, confirmed holds are released; after a funded match starts, the approved policy returns entries by escrow-funded settlement. Ambiguous partial commits remain in manual review. A 200 game response can still have pending financial state; inspect the finance endpoint until confirmed.

## 6. Tests, monitoring and production gate

From `source/backend`, run `npm test`, then `TEST_MONGODB_URI=mongodb://127.0.0.1:27028/ludo_test?replicaSet=ludo npm run test:integration`, `TEST_MONGODB_URI=mongodb://127.0.0.1:27028/ludo_test_platform?replicaSet=ludo npm run test:platform`, and `TEST_MONGODB_URI=mongodb://127.0.0.1:27028/ludo_test_paid?replicaSet=ludo npm run test:paid`. These suites drop only their named isolated test databases. From `source/frontend`, run `flutter analyze`, `flutter test`, and target builds. The paid suite covers 2/4-player matches, public/private entry, no queue charge, reserve/commit/settle, partial rollback, restart, outage retry, cancellation, duplicate start and point conservation. Verify the same against the **real** platform before commercial enablement. Monitor Ludo API errors, `CosmeticPurchase` pending age, `Game.platformFinance` state age, platform reference/status mismatches, scheduler failures, Mongo health, and WebSocket disconnects. Configure retries without changing idempotency keys.

**Production acceptance requires:** real launch verifier and key rotation; globally unique player identity or composite mapping; approved financial policy and tiers; HTTPS/WSS and CORS/CSP; production cosmetic prices; real-platform contract tests for success, decline, timeout, duplicate calls and escrow conservation; Android host handoff and return; iOS bridge if needed; signed release builds. Until then, only the local mock integration is demonstrated.
