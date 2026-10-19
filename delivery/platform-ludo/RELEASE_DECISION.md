# Release decision — 18 October 2026

## READY FOR PLATFORM INTEGRATION

This decision covers the three time-boxed gameplay checks, not production launch or exhaustive gameplay QA. Mock Platform only; no real points or commercial paid play.

| Check | Decision | Evidence |
|---|---|---|
| Android human Roll → legal token → server-confirmed move | PASS | `release-gate-move.png`; Mongo state changed token `-1→0`, revision `1→2` after server six. |
| Two authenticated private-room clients, Classic start, exchanged turns, synchronized state | PASS | Android host + authenticated Socket.IO client; `release-gate-room-ready.png`, `release-gate-private-start.png`, `release-gate-private-turns.png`; B received four state events and its final revision matched HTTP at 2. One emulator and one headless client. |
| Navigation, Forfeit, Exit, Return Home | PASS | `release-gate-menu.png`, `release-gate-forfeit-confirm.png`, `release-gate-forfeit-result.png`, `release-gate-exit.png`, `release-gate-home.png`; confirmed server forfeit and Android Back/Home remained usable. |

**P0/P1:** One P1 HUD overflow with four legal tokens was fixed by wrapping move buttons. Post-fix `flutter analyze` passed; `flutter test` passed 21/21; Android debug APK rebuilt. No remaining P0/P1 was reproduced in this gate.

**Final APK:** [builds/ludo-club-debug.apk](builds/ludo-club-debug.apk) — SHA-256 `b913b9a48139b57989d1b59958438f27e3ea1741714492a2876fd95475296337`; local debug endpoint `http://10.0.2.2:3108`. The later [Classic gameplay audit](CLASSIC_GAMEPLAY_AUDIT.md) documents the corrected board path and replacement build.

**External platform dependencies:** real one-time launch verification and key rotation; points balance/reserve/commit/release/settle/purchase/status APIs with idempotency and escrow conservation; approved financial policy and tiers; production cosmetic prices; HTTPS/WSS, CORS/CSP, host return handoff, and signed production build. Magic/Fast remain disabled pending approved rules. See [integration guide](integration/PLATFORM_DEVELOPER_START_HERE.md).
