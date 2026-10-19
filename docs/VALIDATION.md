# Local validation record — 2026-09-27

The app uses a local MongoDB replica set and loopback Node/Socket.IO backend. No cloud deployment, real Vodafone Cash transfer, or regulatory approval was tested.

## Automated checks

- `cd backend && npm test`: 10/10 pure Ludo engine tests passed (2/4 players, sixes, capture, safe cells, exact home, invalid actions, forfeits, timeouts, bots).
- `cd backend && TEST_MONGODB_URI='mongodb://127.0.0.1:27029/ludo_test?replicaSet=ludoAudit' npm run test:integration`: 14/14 tests passed on an isolated local replica set. Covers guest identity, no direct mint endpoint, pending/approved/rejected deposits, concurrent admin approval, withdrawal reserve/paid/reject, concurrent withdrawals, waiting cancellation before/after reservation, double refund, 100 settlement retries, 4-player paid matchmaking, Socket.IO auth/revision/reconnect, scheduler recovery and waiting-room expiry, admin guards/bans and ledger conservation. The test database is dropped before and after the suite; `ludo_club` is untouched.
- `cd frontend && flutter pub get`: succeeded.
- `cd frontend && dart format lib test integration_test`: completed.
- `cd frontend && flutter analyze --no-pub`: no issues.
- `cd frontend && flutter test --no-pub`: 8/8 tests passed, including wallet EGP parsing/UI and admin deposit review UI.
- `cd frontend && flutter test integration_test/auth_wallet_e2e_test.dart -d 5A86C7C4-DE3C-4C27-A0E7-AE1A9C553FF9 --no-pub`: passed on the booted iPhone 16e Simulator (iOS 26.3). Actual scenarios: anonymous entry, Wallet, local-demo deposit request PENDING without credit, invalid withdrawal phone, app widget restart/session restoration, bot practice room, server dice request, forfeit.
- `cd backend && node test/run-local-ui-e2e.mjs`: 1/1 complete local UI E2E scenario passed on that iPhone 16e. The real Flutter UI submitted a 100 EGP test deposit, authenticated the temporary admin and approved it, created and started a 25 EGP paid private match; a second authenticated HTTP player joined and legitimately forfeited after the Flutter player rolled. Flutter restarted during the active match and restored it. The UI submitted 20 EGP and 10 EGP withdrawals; actual AdminScreen controls marked the first PAID (without a real transfer) and rejected the second. The test checked duplicate approval, PAID, rejection, cancelled-room release, authorization, ledger history and value conservation. The runner then retried settlement on the same completed match 20 times internally: balances unchanged, one PRIZE transaction. Its temporary admin was disabled; test data and audit records were retained.

## Builds

- iOS Simulator `flutter build ios --simulator --no-codesign --no-pub`: passed; `build/ios/iphonesimulator/Runner.app`.
- Android debug `flutter build apk --debug --no-pub`: passed; `build/app/outputs/flutter-apk/app-debug.apk`.
- Flutter emits a future Swift Package Manager support warning for `flutter_secure_storage`; current CocoaPods build succeeds.

## Actual runtime boundaries

- `/health` on local `127.0.0.1:3107` returned `ok: true`, `currency: EGP` with manual deposit/withdrawal mode.
- The iPhone 16e Simulator displayed the real Home screen with a restored guest and `0.00 EGP`, no login prompt. Its Wallet showed `LOCAL DEMO MODE` and no transfer was sent.
- After the full E2E, the normal app was launched, terminated with `simctl terminate`, and relaunched with `simctl launch`. Home returned without login and showed the same previous guest name and 0.00 EGP. The local API still returned healthy EGP/manual-review status.
- Two human players and four human players were exercised through real authenticated backend HTTP/Socket.IO clients in integration tests, **not** on two/four visual simulators.
- Admin deposit/withdrawal decisions were exercised through the actual Flutter AdminScreen on one simulator, then the player session was restored. The second player was a real authenticated backend HTTP client, **not** a second visual simulator. No external transfer occurred.
- Final handoff Android Emulator runtime validation: `Medium_Phone_API_36.0` (`emulator-5554`) installed `delivery/LudoClub-local-emulator-debug.apk` successfully. It opened Home directly as a restored guest through `10.0.2.2:3107`; Wallet displayed 0.00 EGP available, 0.00 EGP reserved and empty history. Deposit displayed the MongoDB number `01004632660`. An Admin API change to controlled test number `01000000000` appeared on the same APK's Deposit screen, then changing back displayed `01004632660`, with no APK rebuild between setting changes. No Android financial transaction was initiated.
- The separate `delivery/LudoClub-local-phone-debug.apk` was built for this Mac's observed private Wi-Fi IP `192.168.1.5`. The backend answered `/health` on that LAN address. The phone APK was installed on the Android Emulator and loaded Home/Wallet through that LAN configuration. **No physical phone was connected or tested.** Rebuild the phone APK if the Mac's IP changes.
- Final shared Flutter changes also passed `flutter build ios --simulator --no-codesign --no-pub`; this was a build check, not a repeat of the earlier iOS visual E2E.

## Clean delivery state

After the historical E2E above, `ludo_club` was explicitly cleared of 19 local demo/test users, 39 test money transactions and related requests/matches. Backend startup recreated its indexes. Final regressions after cleanup: backend unit 10/10, backend integration 14/14 on separate `ludo_test`, Flutter widget 8/8, `flutter analyze` no issues. Android Debug APK built after `flutter clean` and copied to `delivery/`; APK SHA-256 matches the build output. The running Android Emulator then created exactly one new normal guest with 0 available and 0 reserved; there are 0 financial transactions, 0 pending deposits, 0 pending withdrawals and 0 active paid matches. No permanent admin account has been created; the documented one-time CLI command remains for the recipient.

## Known scope limits

The receiving number `01004632660` is persisted in MongoDB and editable by Admin. `LOCAL_DEMO_NO_REAL_TRANSFER` was an explicit, labeled test marker used only during historical E2E and is not a Vodafone Cash number. The admin must independently verify any transfer before approval. The local demo is not evidence of actual payment/provider/legal authorization. The gameplay scheduler/process queue is single-instance; monetary writes are transactional with unique references. Legacy demo points are intentionally not migrated to EGP. Do not deploy or operate real-money wagering without independent legal, provider, security and operations review.
