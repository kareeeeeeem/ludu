# Classic Ludo gameplay audit — 19 October 2026

## Rules verified

- The shared ring has 52 distinct cells. Red, green, yellow, and blue start at physical ring indices 13, 26, 39, and 0; two-player games use red/yellow. Each token traverses 51 ring cells (`0..50`), then turns from the cell beside its own lane into six private cells (`51..56`), and reaches the central finish at `57`.
- All four lanes, all 52 global squares, all eight safe squares (`0,8,13,21,26,34,39,47`), and the backend-to-Flutter coordinate mapping passed deterministic tests. The four corner transitions are diagonal; all other adjacent ring transitions are cardinal.
- A six is required to leave base. Dice move exactly their value; overshooting home is illegal. The player chooses among legal tokens; forged, duplicate, and out-of-turn moves are rejected. A six, unsafe capture, or home arrival grants one extra roll. The third consecutive six discards that roll and passes the turn. An unusable roll, including six, passes the turn.
- Unsafe landing captures every opponent token on that square and returns it to base; all safe squares prevent capture. Friendly tokens may stack and do not block movement. Turn order, elimination, forfeit, 30-second timeout, and three missed turns follow the documented variant. Four tokens at `57` produce the winner and end the match. Bots call the same legal move/action functions as human players.
- Server-generated dice, revision checks, Socket.IO authentication/reconnect, and stale-action rejection passed the existing integration suite.

## Defect fixed

The old route kept a token on the ring for progress `51`, then jumped diagonally from the square before its own start to lane progress `52`. The visible board's lane is reached directly from progress `50`. Corrected the backend outer-square boundary, both Flutter board coordinate/painter mappings, and `docs/RULES.md`. The six-cell lane is now `51..56`; `57` is central home. No other gameplay rule was changed.

## Test results

| Command | Result |
|---|---|
| `cd backend && npm test` | PASS: 23/23, including deterministic full 2-/4-player bot matches, all colors, 52 capture/safety destinations, dice/lane combinations, extra turns, three sixes, and invalid actions. |
| `cd backend && TEST_MONGODB_URI='mongodb://127.0.0.1:27028/ludo_test_classic?replicaSet=ludo' npm run test:integration` | PASS: 15/15 in an isolated database; includes authoritative Socket.IO/revision/reconnect checks. |
| `cd frontend && flutter test` | PASS: 22/22, including board mapping and token selection. |
| `cd frontend && flutter analyze` | PASS: no issues. |
| `cd frontend && flutter build apk --debug --dart-define=API_URL=http://10.0.2.2:3108` | PASS. [Replacement APK](builds/ludo-club-debug.apk), SHA-256 `b913b9a48139b57989d1b59958438f27e3ea1741714492a2876fd95475296337`. |

## Remaining gameplay uncertainty

The documented variant ends when the first player brings all four tokens home. It does not define second-through-fourth in-match placements; no placement rule was invented. This audit used engine, integration, and Flutter widget tests, without a new manual emulator match. Persisted matches created under the old route encode the previous progress positions; they should not span deployment of the corrected engine.
