# Ludo Club — local delivery

Flutter client → local Node.js/Express/Socket.IO server → local MongoDB replica set. The game server generates dice, validates moves, determines winners and performs all EGP wallet operations. This folder has no Git metadata; keep your own backup/version control before making further changes.

## LOCAL DELIVERY / LOCAL RUN

Prerequisites on this Mac: Flutter 3.44+ / Dart 3.12+, Node.js 20.16+, npm, MongoDB Community (`mongod` on PATH), Xcode + iOS Simulator. Android build additionally needs Android SDK and Java 17. No Atlas, cloud host or domain is needed. The MongoDB replica set is required for atomic financial transactions.

From the project root, in Terminal A:

```bash
node scripts/setup.mjs
cd backend && npm ci && cd ..
bash scripts/dev-local.sh
```

`dev-local.sh` starts or connects to a loopback MongoDB replica set `ludo` on port `27028`, initializes it, and starts the API on `127.0.0.1:3107`. Persistent application data is in `data/mongo`; the test database is separate (`ludo_test`). It never drops the application database. `backend/.env` is created with a random local JWT secret and is not committed. The backend creates its indexes on startup. Check `curl http://127.0.0.1:3107/health` for `ok: true` and `currency: EGP`. Keep Terminal A open.

For a local iOS Simulator, in Terminal B:

```bash
cd frontend
flutter pub get
flutter devices
flutter run -d <BOOTED_SIMULATOR_ID>
```

The iOS Simulator defaults to `http://127.0.0.1:3107`. `bash Run-Ludo.command` also detects the sole booted iOS simulator, starts the local backend if needed, and runs the app. It does not create or boot a simulator.

For an Android Emulator:

```bash
cd frontend
flutter pub get
flutter run -d <ANDROID_EMULATOR_ID>
```

The Android Emulator defaults to `http://10.0.2.2:3107`. For a physical phone, find the Mac's private Wi-Fi address with `ipconfig getifaddr en0` (or `en1`), start the backend with `LUDO_API_HOST=0.0.0.0 bash scripts/dev-local.sh`, then run `bash scripts/build-phone-apk.sh <MAC_LAN_IP>` from the project root. The script creates `delivery/LudoClub-local-phone-debug.apk`. API and Socket.IO use the same URL. Mac and phone must share a trusted LAN; allow TCP port 3107 through the Mac firewall. USB testing can use `adb reverse tcp:3107 tcp:3107` and `flutter build apk --debug --dart-define=API_URL=http://127.0.0.1:3107`. Never use loopback in a physical-phone APK without `adb reverse`. Do not expose the HTTP server publicly.

### Admin access

This delivery already contains one permanent local Admin. Its one-time credentials are in ignored, owner-readable `delivery/ADMIN_CREDENTIALS.txt`; change the password after first login. For a **fresh database without any Admin**, bootstrap once:

```bash
cd backend
MONGODB_URI='mongodb://127.0.0.1:27028/ludo_club?replicaSet=ludo' npm run admin -- --create-local --credentials-file=../delivery/ADMIN_CREDENTIALS.txt
```

The command refuses a database with an existing Admin and refuses to overwrite a credentials file. Admin email is `admin@ludo.local`; there is no default password. In the app: Profile → Administrator sign in → Administration → ADMINS to create/enable/disable Admins, reset passwords, or change your own password. The last active Admin cannot be disabled.

### Vodafone Cash local configuration

The current receiving number is `01004632660`, stored persistently in MongoDB `appsettings`. Admin → SETTINGS → Payment Settings → Vodafone Cash can change it; the backend audits old/new values and player deposit screens fetch it dynamically. No APK rebuild or backend restart is required. `VODAFONE_CASH_RECEIVING_NUMBER` in `backend/.env` is an **initial seed only for an empty settings collection**; it never overwrites a saved setting. No automatic Vodafone Cash provider API is integrated. Admin must independently verify transfer receipt before approval.

Local demo deposit: player submits amount, sender number and test transfer reference → request remains `PENDING` and balance unchanged → authenticated admin reviews and explicitly approves/rejects. Admin approval credits once, with ledger and audit record. For real operations the admin must verify actual receipt independently before approval; a submitted reference is not proof of payment.

Local demo withdrawal: player submits amount and Egyptian mobile number → backend reserves funds, request `PENDING` → admin manually transfers externally, enters the unique payout reference and marks `PAID`, or rejects and releases the reservation. Request submitted is not paid. The app does not send a real transfer.

### Wallet and wagering

EGP is stored as integer piastres: `25.00 EGP = 2500` minor units. New monetary wallets start at zero. Old `User.points` and demo Wallet/Transaction collections are **not converted to EGP**; no silent monetary migration occurs. Admin-adjusted local test funding is available through the protected admin UI/CLI role and produces a ledger/audit record. There is no player funding endpoint.

Paid room/queue entry reserves the stake atomically. A match starts only with one matching reservation per human player. Start captures those reservations. A valid server-side result pays the gross captured pool once to the winner (default commission 0). Waiting cancellation releases only actual reservations; started cancellation refunds only actual captured stakes. Duplicate/retry operations cannot create a second financial result. Force Winner is disabled for financial matches. Free practice/bot games have no money reward.

### Tests and builds

Use a local MongoDB replica set, never the application database as a test target:

```bash
cd backend
npm test
TEST_MONGODB_URI='mongodb://127.0.0.1:27028/ludo_test?replicaSet=ludo' npm run test:integration
cd ../frontend
flutter pub get
dart format lib test integration_test
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --no-codesign
```

The integration test drops **only** a database whose name matches `ludo_test`/`ludo_test_*`; it does not touch `ludo_club`. `bash scripts/verify-local.sh` runs the test/build sequence. Android debug uses local cleartext for emulator access; no release signing is configured. For an on-device direct-entry/session test with the local backend running, use `flutter test integration_test/auth_wallet_e2e_test.dart -d <BOOTED_SIMULATOR_ID>`.

The historical full iOS UI/admin/financial E2E runner is `backend/test/run-local-ui-e2e.mjs`. It creates demo money data in `ludo_club` and expects a controlled `LOCAL_DEMO_NO_REAL_TRANSFER` setting. **Do not run it against this clean delivery database or the real receiving number.** Use a separate disposable local copy if repeating that test. The routine integration suite above uses `ludo_test` and is safe for the delivery database.

The emulator delivery artifact is a **debug APK** at `delivery/LudoClub-local-emulator-debug.apk`. Flutter reuses `frontend/build/app/outputs/flutter-apk/app-debug.apk` for whichever variant was built most recently; use the named files under `delivery/`. No release signing key is supplied. For a physical phone over trusted LAN, use `bash scripts/build-phone-apk.sh <MAC_LAN_IP>`; this creates a separate APK for the specified current IP. An APK compiled for one host does not automatically discover another host.

`delivery/LudoClub-local-phone-debug.apk` was also built for this Mac's observed `192.168.1.5` Wi-Fi address. It was verified on the Emulator using the LAN URL, not on a physical phone. Rebuild it when the Mac's LAN IP changes.

## Project map

| Path | Purpose |
| --- | --- |
| `backend/src/engine.js` | Pure server-side Ludo rules, moves, dice and bots |
| `backend/src/service.js` | Rooms, matchmaking, state revisions, settlement, scheduler |
| `backend/src/wallet.js` | Atomic EGP wallet movements and stake ledger |
| `backend/src/finance.js` | Deposit/withdrawal requests and admin review |
| `backend/src/models.js` | MongoDB schemas, unique references and indexes |
| `backend/src/app.js` | Auth, REST, Socket.IO and admin route guard |
| `frontend/lib/api.dart` | Persistent guest session, HTTP and Socket.IO |
| `frontend/lib/main.dart` | Game, lobby and admin UI |
| `frontend/lib/wallet_screen.dart` | EGP wallet and Vodafone Cash request UI |

## Scope and limits

This is a local software delivery, not a cloud deployment or legal/provider approval. Vodafone Cash transfer/verification is manual. The supplied receiving number is a configurable local business setting, not evidence of provider approval or a verified transfer. Financial correctness does not rely on Flutter. Gameplay scheduling uses a single Node process; the monetary ledger uses MongoDB transactions and unique references. Do not run multiple gameplay server instances without distributed scheduling/locking work.
# ludu
