# Feature and verification status

| Area | Status |
| --- | --- |
| Verified platform launch, replay rejection, scoped game JWT, Socket.IO authentication, session revocation | Implemented and integration tested with local mock |
| Platform identity and points balance; no player login, deposit or withdrawal UI | Implemented |
| Free 2/4-player Classic, private rooms, matchmaking, practice bots, reconnect and forfeit | Existing engine retained; regression suite passed |
| Platform point reservation, commit, release, settlement | Persistent live-match orchestration implemented/tested with a test-only policy and mock; production requires approved policy and real-platform contract tests |
| Cosmetic point purchase, pending reconciliation, persistent inventory and equip | Implemented/tested with mock approved prices |
| Premium board, tokens, dice, backgrounds and game UI | Implemented using Flutter painting and original hero artwork; source collage skins not commercially cleared |
| Magic and Fast | Mode entries unavailable pending approved rules |
| Android and Web | Local debug APK and Web output; iOS bridge outstanding |
| External platform | Contract documented; real API and credentials outstanding |

## Verification performed

- Backend engine unit tests: **12 passed**.
- Legacy Mongo/Socket/finance regression tests on isolated `ludo_test`: **15 passed**.
- Platform mock integration on isolated `ludo_test_platform`: **passed**, including launch/replay, invalid Socket.IO auth, points, cosmetic purchase, ambiguous recovery, reserve/release/commit/settle, concurrent reservation, admin config, and revocation.
- Paid-match integration on isolated `ludo_test_paid`: **passed**, including private/public 2/4-player matches, partial reservation rollback, commit/settlement outages, backend-app restart recovery, cancellation, timeout, concurrent start, commission and point conservation.
- Local launcher smoke test against the running mock and updated backend: **passed**, including launch, exchange, balance, replay rejection and revocation.
- Flutter analyze: **clean**; Flutter tests: **16 passed**, including platform home and equipped cosmetic game rendering checks.
- Flutter Web release build: **succeeded**.
- Android debug APK build: **succeeded**; installed and launched on emulator with a one-time mock platform code. Home displayed verified `Club Player` and 250 mock platform points. The emulator shop purchased Gold Dice for 75 mock points, displayed 175 points, then equipped it. Return to platform closed the game activity. Previews are in `builds/android-home-preview.png` and `builds/android-shop-equipped-preview.png`.

These are local verification results under a test-only policy, not production certification. See `PLATFORM_INTEGRATION.md`, `openapi.yaml`, and `../integration/PLATFORM_DEVELOPER_START_HERE.md` for contract and dependencies.
