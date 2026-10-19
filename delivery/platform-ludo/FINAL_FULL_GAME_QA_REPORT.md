# Final full-game QA report — 18 October 2026

## Final time-boxed release gate — 18 October 2026

**READY FOR PLATFORM INTEGRATION under the three-check release gate; broader full-game QA remains partial.** The checks below used an isolated MongoDB replica set (`ludo_release_gate`), Mock Platform `:3114`, backend `:3122`, and Android emulator `emulator-5554`. One Android client and one authenticated Node Socket.IO client were used for the private match. Neither a real platform nor commercial points were involved.

| Release-critical check | Result | Direct evidence |
|---|---|---|
| Human Android Roll, legal token tap, server-confirmed move | PASS | ADB taps in live Practice match; read-only Mongo state changed first red token from base `-1` to start `0`, revision `1→2`, after authoritative six. [Post-move Android screenshot](builds/release-gate-move.png); `backend/test/release-gate-roll.mjs` printed `pass:true` for game `6ad51a7a6847ffe7f9d06930`. |
| Two authenticated clients join private Classic room, start, exchange turns and synchronize | PASS | Android host and authenticated Socket.IO client joined room `432F8A0068`; [2/2 room screenshot](builds/release-gate-room-ready.png), [started board](builds/release-gate-private-start.png). Android host tapped Roll; second client received four `game_state` events, rolled via authenticated `roll_dice`, and its latest Socket.IO revision matched authenticated HTTP game state at revision 2. [Android turn indicator](builds/release-gate-private-turns.png); `backend/test/release-gate-private.mjs` printed `pass:true`. This was one emulator plus one headless client, not two emulators or a complete match. |
| Navigation, Forfeit, Exit, Return Home | PASS | Android Game Options [menu](builds/release-gate-menu.png) → [Forfeit confirmation](builds/release-gate-forfeit-confirm.png) → [server-completed forfeit result](builds/release-gate-forfeit-result.png). Result Back, active-match Android Back, Play tab, and Home tab remained usable; [Home](builds/release-gate-home.png). Exit means Android Back from the match, preserving Return to Match. |

**P0/P1 defect fixed in this gate:** four simultaneous legal-token buttons overflowed the Android game HUD by 34 px. `frontend/lib/game/reference_game_scene.dart` now wraps the buttons; `frontend/test/game_layout_test.dart` covers all four at 320/360 logical pixels. The post-fix Android move screenshot has no overflow. No other P0/P1 defect was found in these three checks.

**Post-fix checks:** `flutter analyze` PASS (no issues); `flutter test` PASS (21/21). The final standard-local APK was rebuilt after this fix; path and checksum are in the delivery section below. Historical statements later in this report describe the earlier broad QA pass and are superseded for these three release-gate scenarios.

## Verdict

**RELEASE GATE PASSED; broader full end-to-end QA remains PARTIAL.** The isolated Mock Platform and Android emulator exercised launch, navigation, matchmaking cancellation, Practice entry, private-room play with a second authenticated client, a human token move, confirmed forfeit, and cosmetic purchase/equip persistence. Automated suites and Android/Web builds pass. Complete human-played Classic 1v1/4-player matches, paid match through the app, reconnect, and every secondary control were **not** demonstrated on emulators. Do not call this 100% coverage or production acceptance.

The exact delivered debug APK was installed and launched through the local Mock Platform; [screenshot](builds/qa-final-apk-smoke.png). Its API URL is `http://10.0.2.2:3108` for the local launcher. Rebuild with a production HTTPS URL before external integration. The Web build uses `http://127.0.0.1:3108` for local development.

## Isolated environment and evidence types

- **Live Android UI:** Android API 36 emulator `emulator-5554`, 900×1600, `adb shell input` taps/swipes/back/text and `screencap`; isolated Ludo backend `127.0.0.1:3120`, MongoDB replica set `127.0.0.1:27028/ludo_club_qa`, Mock Platform `127.0.0.1:3113`. QA player `qa_1792230603684` had 175 mock points before a 75-point Gold Dice purchase and 100 after reopening the app. No production services or real money were used. The final APK was also launched with the standard local Mock Platform on ports 3108/3110.
- **Backend automated:** isolated `ludo_test_qa`, `ludo_test_platform`, and `ludo_test_paid` databases on the local replica set. Platform/paid suites exercise real HTTP/Socket.IO and database-backed mock transactions; these are **not** emulator interactions.
- **Flutter widget tests:** rendering and interaction inside the test runner; these are **not** emulator interactions.
- The reference screenshot is at `WhatsApp Image 2026-10-16 at 19.42.46.jpeg` in the project root. No `photots` directory was present in this checkout. Gameplay screenshot: [Practice board](builds/qa-final-practice-game.png). A pixel-difference comparison against the reference was not performed in this QA pass.

## Screens and visible controls

| Screen/control | Result | Evidence and limitation |
|---|---|---|
| One-time platform launch, loading, direct Home, name/avatar/points | PASS — live UI | [isolated Home](builds/qa-booted.png), [final APK Home](builds/qa-final-apk-smoke.png); no second login. |
| Home Play Now and 2/4 capacity selection | PASS — live UI | [capacity](builds/qa-capacity.png); 2-player selection used. Four-player selection was not followed through in UI. |
| Home scroll, Shop shortcut, Join Room, profile/nav tabs | PASS — live UI | [Home actions](builds/qa-final-home-actions.png), [join dialog](builds/qa-final-join-room.png), [Profile](builds/qa-final-profile.png). |
| Balance refresh and Return to Platform | NOT TESTED — live UI | Visible Home header controls; no verified host navigation target in isolated Android session. |
| Classic free public queue and cancellation | PASS — live UI | [queue](builds/qa-final-play.png), [cancelled](builds/qa-final-queue-cancel.png). |
| Classic 1v1/4-player completed on emulator | NOT TESTED | Backend platform suite covers free 2/4-player match lifecycle; no multi-emulator complete match was observed. |
| Practice 2-player against bot, board/HUD/timer | PASS — live UI | [active match](builds/qa-final-practice-game.png); server later completed the match with Bot 1 winner, [result](builds/qa-final-result-scrolled.png). Human dice/token move was not confirmed before timeout. |
| Practice 4-player | NOT TESTED — live UI | Backend platform suite exercises Practice bots. |
| Private room creation, room code, copy, disabled start, close | PASS — live UI | [room](builds/qa-final-private-room.png), [Android clipboard](builds/qa-final-private-copy.png), [closed](builds/qa-final-room-closed.png). Joining with a second emulator and starting a private match were not observed. |
| Join invalid code and error feedback | PARTIAL — live UI + widget | Invalid `BADCODE123` produced an error snackbar, but its text was unreadable in the installed build [before fix](builds/qa-final-invalid-room.png). Text contrast was fixed and widget-tested; the corrected snackbar was not recaptured on emulator. |
| Game menu and Forfeit confirmation | PASS — live UI | [menu](builds/qa-final-game-menu.png), [confirmation before fix](builds/qa-final-forfeit-confirm.png). Menu fits screen after fix. Confirmed forfeit action was not executed on live UI. |
| Result, Back to Home | PASS — live UI | [scrollable result](builds/qa-final-result-scrolled.png), [returned Home/Play](builds/qa-final-after-result.png). Winner name is now resolved from player data. |
| New Game result button | PARTIAL | Label was shortened from clipped “PLAY AGAIN” to “NEW GAME”; returns to Play tab. Latest label has widget/build verification, no final emulator capture. |
| Shop Dice/Frames categories, purchase confirmation, equip | PASS — live UI | [shop](builds/qa-final-shop.png), [Frames](builds/qa-final-frames.png), [purchase confirmation](builds/qa-purchase-dialog.png), [purchase](builds/qa-shop-purchased.png), [equip](builds/qa-shop-equipped.png). Tokens/Boards category taps were not individually recorded. |
| Inventory and profile persistence | PASS — live UI | [Inventory](builds/qa-final-inventory.png), [Profile](builds/qa-final-profile.png), [relaunch](builds/qa-relaunch-persistence.png). Points stayed 100 and Gold Dice remained equipped. |
| Leaderboard, history, settings, rules, report problem, chat | NOT TESTED — live UI | Backend/widget tests do not establish that every control works on emulator. |
| Emoji and microphone/voice controls | PARTIAL | Emoji control was outside this release gate. In the subsequent UI-only change, all microphone buttons and avatar voice indicators were removed from the Flutter game scene; no voice service is advertised. |
| Magic/Fast | NOT TESTED — live UI | Disabled by product configuration pending approved rules; no paid gameplay enabled. |
| Paid match via Android UI | NOT TESTED | Paid tiers were not exposed in isolated UI because no commercial policy was configured. Mock paid lifecycle was covered by backend test-only suite only. |
| No standalone login/Vodafone player flow | PASS — live UI | Direct platform launch and no such player controls on visited screens; legacy Flutter finance widget tests still exist but are not part of platform player navigation. |

## Gameplay, multiplayer, financial scenarios

| Scenario | Result | Evidence |
|---|---|---|
| Two-/four-player game logic, legal moves, safe cells, exact finish, turn authority | PASS — backend automated only | `npm test`, `npm run test:integration`, `npm run test:platform`. |
| Public queue and cancellation | PASS — backend + live UI | Screenshots above. |
| Private room, capacity/start/leave | PASS — backend automated; partial live UI | Creation/copy/closure tested on emulator; joining with another live app not tested. |
| Bots, timeout, forfeit, disconnect/reconnect | PASS — backend automated; partial live UI | Practice start and timeout result shown; live reconnect/forfeit confirmation action not completed. |
| Dice authority, token movement, capture, three sixes, exact finish on emulator | NOT TESTED | Do not infer live UI operation from backend test coverage. |
| Mock launch, replay, revocation | PASS — automated | `scripts/verify-platform-demo.mjs` against QA ports; final APK one-time launch smoke. |
| Paid 2/4-player reservations, commit, settlement, commission, cancellation, outage/recovery | PASS — backend mock test-only policy | `npm run test:paid`; no commercial policy enabled, no real platform connected. |
| Cosmetic payment, duplicate prevention, ownership/equip | PASS — backend mock + partial live UI | 75-point purchase and persistent equip observed; duplicate/outage tested by platform suite, not live Android. |

## Bugs found and repaired

1. Short-phone game menu overflow hid Forfeit. Made sheet scrollable and bottom sheet height flexible; `game_menu_test.dart` passes and [emulator menu](builds/qa-final-game-menu.png) has no overflow.
2. Shop card/badge overflow and clipped Shop/Inventory headings. Adjusted card extent/wrap and headings; `shop_layout_test.dart` passes and [Shop](builds/qa-final-shop.png) was inspected on emulator.
3. Queued user had no clear cancel action on Play tab and could tap conflicting entries. Added queue status/cancel and disabled conflicting actions; `platform_home_test.dart` and [live cancellation](builds/qa-final-queue-cancel.png) pass.
4. Practice capacity sheet incorrectly said “Play for ranking.” It now says “Free practice · No ranking or points.” Final build compiled; no post-change screenshot of that sheet.
5. Practice Forfeit dialog claimed stake forfeiture on a free match and could submit after status changed. The message is stake-aware and action checks active status before and after confirmation. Live race reproduction was captured; post-fix behavior has not been re-enacted under the same timing.
6. Completed result overflowed on a short display and showed generic winner. Made result vertically scrollable, flexible finance rows, and resolved winner name; `match_result_layout_test.dart` passes, [emulator result](builds/qa-final-result-scrolled.png) is usable.
7. Error snackbar had light text on a light surface. Set dark text; `error_feedback_test.dart` passes. [Before-fix capture](builds/qa-final-invalid-room.png); no corrected emulator capture.
8. Home quick-match CTA and result New Game labels clipped. Shortened labels; added a translucent backing behind the Home hero title for readability. Final analyzer/tests/build pass; the revised title was inspected in the [final APK screenshot](builds/qa-final-apk-smoke.png).

## Automated commands and exact results

| Command | Result |
|---|---|
| `cd backend && /Users/p/.codex/tools/bin/rtk npm test` | PASS: 13 tests, 0 failures. |
| `TEST_MONGODB_URI='mongodb://127.0.0.1:27028/ludo_test_qa?replicaSet=ludo' /Users/p/.codex/tools/bin/rtk npm run test:integration` (backend) | PASS: 15 tests, 0 failures. Initial sandbox-only localhost `EPERM` run was retried outside sandbox. |
| `TEST_MONGODB_URI='mongodb://127.0.0.1:27028/ludo_test_platform?replicaSet=ludo' /Users/p/.codex/tools/bin/rtk npm run test:platform` (backend) | PASS; script emits scenario summary, no TAP count. |
| `TEST_MONGODB_URI='mongodb://127.0.0.1:27028/ludo_test_paid?replicaSet=ludo' /Users/p/.codex/tools/bin/rtk npm run test:paid` (backend) | PASS; script emits scenario summary, no TAP count. |
| `MOCK_PLATFORM_URL=http://127.0.0.1:3113 LUDO_API_URL=http://127.0.0.1:3120 LUDO_WEB_URL=http://127.0.0.1:8081 node scripts/verify-platform-demo.mjs` | PASS: local launch/replay/revocation smoke. |
| `cd frontend && /Users/p/.codex/tools/bin/rtk flutter analyze` | PASS: no issues. |
| `cd frontend && /Users/p/.codex/tools/bin/rtk flutter test` | PASS: 21 tests, 0 failures. Includes legacy finance widgets, which do not prove active platform flows. |
| `cd frontend && /Users/p/.codex/tools/bin/rtk flutter build apk --debug --dart-define=API_URL=http://10.0.2.2:3108` | PASS; exact APK installed and launched on emulator. |
| `cd frontend && /Users/p/.codex/tools/bin/rtk flutter build web --no-wasm-dry-run --dart-define=API_URL=http://127.0.0.1:3108` | PASS; browser interactions were not retested in this pass. |

**Counted automated tests:** 49 passed, 0 failed (13 backend unit + 15 backend integration + 21 Flutter). Platform and paid script suites passed but publish no individual count. Android UI integration-test runner was not executed; interactions above were manual ADB input on the actual emulator. iOS was not tested.

## Delivery and remaining work

- APK: [builds/ludo-club-debug.apk](builds/ludo-club-debug.apk) (later rebuilt after the [Classic board-path correction](CLASSIC_GAMEPLAY_AUDIT.md); SHA-256 `b913b9a48139b57989d1b59958438f27e3ea1741714492a2876fd95475296337`).
- Web: [builds/web/index.html](builds/web/index.html).
- Source: [source/frontend](source/frontend), [source/backend](source/backend), [source/mock-platform](source/mock-platform).
- Platform integration: [integration/PLATFORM_DEVELOPER_START_HERE.md](integration/PLATFORM_DEVELOPER_START_HERE.md).
- Screenshots: `builds/qa-*.png`; the linked files above are live emulator captures.

**Remaining validation:** complete actual Classic 1v1 and 4-player matches with multiple emulator clients; observe dice/token selection, capture/safe cells/three sixes/exact finish; live paid test-only policy flow; live reconnect/restart; all settings/chat/leaderboard/history controls; rerun corrected snackbar and forfeit race on emulator; responsive checks on a second device size; browser interaction QA. Real platform integration and commercial financial policy remain external dependencies. No confirmed game-owned backend failure remains from this pass, but these unexecuted scenarios prevent a full QA pass.
