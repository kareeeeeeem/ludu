# API and real-time contract

HTTP base: `/api`. JSON request/response bodies. Send `Authorization: Bearer <JWT>` except guest creation, refresh, optional legacy login and recovery. Errors are `{ "error": "message" }` with 400/401/402/403/404/409/410/429/503 as appropriate. Health is `/health`.

## Accounts

| Method | Path | Body |
|---|---|---|
| POST | `/auth/register` | `username,email,password` |
| POST | `/auth/login` | `email,password` |
| POST | `/auth/guest` | empty; creates server identity and refresh token |
| POST | `/auth/refresh` | `refreshToken`; rotates session token |
| POST | `/auth/admin-login` | `email,password`; separate admin UI |
| POST | `/auth/forgot-password` | `email` |
| POST | `/auth/reset-password` | `token,password` |
| GET | `/auth/me` | — |
| PATCH | `/auth/me` | `username,avatar` |
| POST | `/auth/logout` | — |

Normal startup creates/restores a guest automatically; no player login UI is required. Passwords for optional legacy/admin accounts: 10–72 characters. Username: 3–24 letters/numbers/spaces/underscore/hyphen. Avatars: 🎲 🦊 🐼 🐯 🐸 🦁. Access tokens expire after seven days; guest refresh tokens rotate. Logout/reset/ban revoke previously issued sessions.

## EGP wallet and manual Vodafone Cash requests

Amounts are integer piastres (`amountMinor`); currency is EGP. Legacy points are not monetary and never converted automatically. `GET /wallet/balance` returns `availableMinor` and `reservedMinor`. `GET /wallet/transactions`, `/wallet/deposits`, `/wallet/withdrawals` return the authenticated player's latest 100 records. `GET /wallet/config` returns receiving information and `localDemo` status.

| Method | Path | Body / result |
| --- | --- | --- |
| POST | `/wallet/deposits` | `amountMinor,requestId(UUID),senderPhone,transferReference,note?`; creates PENDING, no credit |
| POST | `/wallet/withdrawals` | `amountMinor,requestId(UUID),phone`; reserves funds, creates PENDING |
| PUT (admin) | `/admin/deposits/:id/approve` | `reason`; credits once after manual verification |
| PUT (admin) | `/admin/deposits/:id/reject` | `reason`; no credit |
| PUT (admin) | `/admin/withdrawals/:id/paid` | `reason,payoutReference`; completes reserved amount after manual transfer; reference is unique |
| PUT (admin) | `/admin/withdrawals/:id/reject` | `reason`; releases reserved amount |

The old player `/wallet/deposit`, `/wallet/withdraw`, and `/wallet/claim` mutation endpoints return 410. A request reference/UUID must be reused on retry. Unique indexes and MongoDB transactions protect duplicate processing.

## Games

| Method | Path | Body |
|---|---|---|
| POST | `/rooms/create` | `capacity: 2 or 4, stakeMinor: integer (0 for free)` |
| POST | `/rooms/join` | `code` |
| GET | `/rooms/:code` | —, members only |
| POST | `/games/practice` | `capacity` |
| POST | `/matchmaking/queue` | `capacity, stakeMinor` |
| DELETE | `/matchmaking/queue` | — |
| GET | `/matchmaking/status` | — |
| GET | `/games/history?page=0&mode=quick` | —, mode optional |
| GET | `/games/:id` | — |
| POST | `/games/:id/start` | —, host only |
| POST | `/games/:id/leave` | —, waiting room only |
| POST | `/games/:id/action` | `type: roll/move/forfeit`, `revision`, `token` for move |
| GET | `/games/:id/replay` | — |
| GET / POST | `/games/:id/chat` | POST: `message` |
| POST | `/games/:id/disputes` | `message` |
| GET | `/disputes` | — |

One active game or queue membership per user. History pages have up to 25 games. Every game response has `id`, `status`, `members`, `names`, `state`, `legalMoves`, and `serverTime`. Compare `state.revision`; a stale action returns 409. Clients submit a token index only, never destination, dice or winner. Refresh after a conflict.

Replay: `{initial,events}`; events contain actor, action, state snapshot and revision. Chat reads return the last 100 messages in chronological order. Maximum message length: 280. All game reads, chat and replay require membership or explicit admin read access.

## Statistics

`GET /stats/user`, `GET /stats/leaderboard?period=all|week|month`. Rankings contain actual completed competitive games only, at most 100 players.

## Administration

Role is checked server-side on every request. `GET /admin/analytics`; paged `GET /admin/games|users|transactions|disputes|audit` (50 rows).

- `PUT /admin/games/:id/cancel`: `{reason}`.
- `PUT /admin/games/:id/result`: `{winner,reason}`. Disabled for any financial match; final results cannot be overwritten.
- `PUT /admin/users/:id/ban`: `{banned,reason}`.
- `PUT /admin/users/:id/balance`: `{amountMinor,requestId,reason}`. Protected, ledgered adjustment; `requestId` is a UUID idempotency key.
- `GET /admin/deposits|withdrawals|transactions|audit|wallets/:userId`: financial review and audit.
- `PUT /admin/disputes/:id`: `{reason}` resolves an open report.

Reasons are 5–500 characters. Administrative writes and audit entries are transactional.

## Socket.io

Connect with `auth: {token}`. Server assigns the authenticated socket to its own user room; clients cannot request arbitrary subscriptions. Reauthentication occurs for every client event. Each event supports acknowledgement `{ok:true,data}` or `{ok:false,error}`.

| Client event | Payload |
|---|---|
| `sync` | `{}`; restore current game or queue status after reconnect |
| `join_queue` / `leave_queue` | `{capacity,stakeMinor}` / `{}` |
| `create_room` / `join_room` | `{capacity,stakeMinor}` / `{code}` |
| `start_game` / `leave_room` | `{gameId}` |
| `roll_dice` | `{gameId,revision}` |
| `make_move` | `{gameId,revision,token}` |
| `forfeit_game` | `{gameId,revision}` |
| `send_chat` | `{gameId,message}` |

Server pushes `game_state` and `chat_message` to participating user rooms. The Flutter app uses HTTP for acknowledged mutations and Socket.io for pushed updates; both paths call the same game service. On reconnect, it requests `sync`. There are no client-controlled result or reward events.

The scheduler restores waiting queues and active games from MongoDB after restart, processes bots, expires turns, and closes stale waiting rooms. Run one server instance. MongoDB must be a replica set for multi-document transactions.

Reference documentation consulted: [Mongoose transactions](https://mongoosejs.com/docs/transactions.html), [Socket.io server](https://socket.io/docs/v4/server-api/), [Resend email API](https://resend.com/docs/api-reference/emails/send-email), [Flutter Android builds](https://docs.flutter.dev/deployment/android).
