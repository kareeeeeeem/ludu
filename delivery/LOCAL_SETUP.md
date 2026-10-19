# Ludo Club — local client handoff

The source project is the parent folder. No cloud service, payment gateway or automatic Vodafone Cash transfer is used.

## FIRST TIME SETUP

On this Mac install Flutter 3.44+/Dart 3.12+, Node.js 20.16+, npm, MongoDB Community 7+, Java 17 and Android SDK (Xcode for iOS Simulator). From the project root:

```bash
node scripts/setup.mjs
cd backend && npm ci && cd ..
```

Keep the delivered `data/mongo` directory if you want the existing Admin and payment setting. On a fresh database, create the first Admin with the bootstrap command below.

When copying this project folder to another location, stop `dev-local.sh` first so the MongoDB files are not copied while live. Preserve `data/mongo`, the ignored local `backend/.env`, and the owner-only credentials file if you intend to keep this exact Admin account; otherwise start with a fresh database and bootstrap a new Admin.

## START MONGODB AND BACKEND

```bash
bash scripts/dev-local.sh
```

This starts the local MongoDB replica set on `127.0.0.1:27028` and the Node/Socket.IO API on `127.0.0.1:3107`. Keep the terminal open. Check `curl http://127.0.0.1:3107/health`.

## ADMIN LOGIN

This delivery's credentials are in `delivery/ADMIN_CREDENTIALS.txt` (owner-readable, ignored by Git). In Flutter: Profile → Administrator sign in → Administration. Change the password after first login under ADMINS → Change my password. To manage other Admins, use ADMINS → Create, Enable/Disable or Reset password. The last active Admin cannot be disabled. Do not put passwords in source control.

If using a *fresh database* with no Admin, bootstrap once:

```bash
cd backend
MONGODB_URI='mongodb://127.0.0.1:27028/ludo_club?replicaSet=ludo' npm run admin -- --create-local --credentials-file=../delivery/ADMIN_CREDENTIALS.txt
```

Do not overwrite an existing credentials file; the bootstrap refuses this. Routine Admin management is through the app.

## CHANGE VODAFONE CASH NUMBER

Current number: `01004632660`. Admin → SETTINGS → Payment Settings → Vodafone Cash → Edit receiving number. The number is stored in MongoDB and player deposit screens fetch it from the backend. Changing it requires **no APK rebuild**. `backend/.env` has `VODAFONE_CASH_RECEIVING_NUMBER` only as a seed for a brand-new settings collection. Deposits and payouts require manual Admin review; do not mark money received or paid without the external action.

## RUN ANDROID EMULATOR

Start the Android Emulator and backend, then from the project root:

```bash
adb install -r delivery/LudoClub-local-emulator-debug.apk
```

Or run Flutter directly: `cd frontend && flutter pub get && flutter run -d <ANDROID_EMULATOR_ID>`. The emulator reaches the Mac at `10.0.2.2:3107`.

## BUILD APK FOR REAL PHONE

Find the Mac Wi-Fi private IPv4 address (usually `en0`, otherwise try `en1`):

```bash
ipconfig getifaddr en0
```

Start the backend intentionally bound to the trusted LAN with `LUDO_API_HOST=0.0.0.0 bash scripts/dev-local.sh` (stop the loopback instance first). Then:

```bash
bash scripts/build-phone-apk.sh <MAC_LAN_IP>
```

Example: `bash scripts/build-phone-apk.sh 192.168.1.20`. This builds `delivery/LudoClub-local-phone-debug.apk` with the current Mac IP; rebuild if the IP changes. The app's API and Socket.IO use the same configured URL. Mac and phone must be on the same trusted Wi-Fi, and the Mac firewall must allow TCP 3107. Do not expose the local HTTP service to the public internet.

The included phone APK was built for this Mac's observed address `192.168.1.5` on 2026-09-28. Check `ipconfig getifaddr en0` before using it; if different, rerun the script with the new address. It has **not** been tested on a physical phone.

Optional USB testing: `adb reverse tcp:3107 tcp:3107`, then build with `cd frontend && flutter build apk --debug --dart-define=API_URL=http://127.0.0.1:3107`.

## INSTALL ON PHONE

Copy the phone APK to the Android device and open it, allowing installation from that source if Android asks. Start local MongoDB/backend first. A phone cannot use the emulator's `10.0.2.2` host alias.

## IOS SIMULATOR

`cd frontend && flutter pub get && flutter run -d <BOOTED_IOS_SIMULATOR_ID>`; iOS Simulator uses Mac loopback by default.

## TESTS

```bash
cd backend && npm test
TEST_MONGODB_URI='mongodb://127.0.0.1:27028/ludo_test?replicaSet=ludo' npm run test:integration
cd ../frontend && flutter pub get && flutter analyze && flutter test
```

Integration tests use only the separate `ludo_test` database. No real Vodafone Cash transfer is sent by tests. The APK is DEBUG-signed for local installation, not store distribution or evidence of provider/legal approval.
