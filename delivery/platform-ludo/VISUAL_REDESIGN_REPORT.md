# Ludo match screen visual rebuild

## Reference and assets

- Reference inspected: `/Users/p/Documents/Codex/2026-09-06/files-pasted-by-the-user-text/outputs/ludo-club/WhatsApp Image 2026-10-16 at 19.42.46.jpeg` (900×1600 portrait screenshot).
- The requested `photots/` directory was absent when inspected. The existing `photos/` directory contains earlier reference sheets, but no clean, licensed standalone artwork matching this screenshot. No raster artwork or third-party logo was extracted from the screenshot.
- Created assets: none. Board decorations, tokens, portraits, buttons and background are independently drawn with Flutter canvas/widgets. The supplied screenshot is not rendered as an overlay.

## Implementation

- `frontend/lib/game/reference_game_scene.dart`: reference-composed navy patterned gameplay screen with four avatar seats, platform point indicator, gold and cyan controls, board placement, disabled voice/emote controls, chat/menu callbacks, turn cue, dice indicator and central roll action.
- `frontend/lib/game/board_surface.dart`: illustrated, interactive 15×15 board surface with four correctly placed home quadrants, beveled frame, color lanes, route tiles, decorative environments, safe shields and cosmetic striped start squares.
- `frontend/lib/game/token_art.dart`: original, transparent canvas illustrations for blue sailboat, red cupcake, green figure and orange/gold classic tokens. Other equipped token skins retain their previous painter.
- `frontend/lib/game/premium_board.dart`: beveled frame and larger animated/hit-testable tokens. Token positions and legal selection remain driven by server state.
- `frontend/lib/board.dart`: visual rotation of the board coordinate mapping to blue upper-left, red upper-right, orange lower-left and green lower-right. This rotates presentation only; server progress, dice and legal moves are unchanged. Corrected all four base slot positions.
- `frontend/lib/main.dart`: active matches render the new scene; waiting/results remain on the existing flow. Points are read from the server-refreshed platform user record. Roll/move still call the existing authoritative API. Navy Android system bars are applied during matches.
- `frontend/lib/visual_qa.dart`: development-only fixture entry point for device screenshot capture. It is **not** the production entry point or a real platform match.
- `frontend/test/board_test.dart`, `frontend/test/game_layout_test.dart`: updated geometry and narrow-screen expectations.

## Visual comparison

- Real Android emulator capture: `delivery/platform-ludo/builds/visual-qa-emulator.png` at 900×1600. Built and launched `lib/visual_qa.dart` on `Medium_Phone_API_36.0`; visually inspected the screenshot against the supplied reference and corrected the bottom two base positions, token scale, action emblem, player microphone indicators and navy system bars.
- Close structural matches: board size/location; four base colors and positions; colored lanes and center; top menu/gem; avatar seats; raised central action; three lower controls; navy backdrop.
- Known differences: code-drawn environments, character portraits and token illustrations have less detail and less dimensional shading than the commercial raster art in the reference. The reference's exact illustrated artwork was not available as separable licensed assets. Voice and emote controls are visibly disabled because no voice/emote service exists. The QA gem shows `—` because no platform balance was injected into the fixture.
- The captured screen is a **fixture on a real emulator**, not evidence of a live multiplayer session. The production screen consumes actual game state and platform points through the existing API.

## Verification

| Command | Result |
| --- | --- |
| `cd frontend && /Users/p/.codex/tools/bin/rtk flutter analyze` | PASS, no issues |
| `cd frontend && /Users/p/.codex/tools/bin/rtk flutter test` | PASS, 16 tests |
| `cd frontend && /Users/p/.codex/tools/bin/rtk flutter build apk --debug` | PASS |
| `cd frontend && /Users/p/.codex/tools/bin/rtk flutter build web --no-wasm-dry-run` | PASS; non-blocking icon font warning |
| Emulator install, launch and screenshot | PASS, development fixture |

The backend and platform financial integration were not modified. Existing board token selection tests and narrow 320/360 px match widget tests passed. A live multiplayer emulator match was not exercised in this visual pass.

## Delivery paths

- Production Android debug APK: `delivery/platform-ludo/builds/ludo-club-debug.apk`
- Production Web build: `delivery/platform-ludo/builds/web/`
- Source mirror: `delivery/platform-ludo/source/frontend/`
- Emulator capture: `delivery/platform-ludo/builds/visual-qa-emulator.png`
