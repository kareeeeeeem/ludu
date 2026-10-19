# LUDO CLUB → BETTING PLATFORM: REFACTOR PLAN

## Phase 0: Analysis Complete

### WHAT EXISTS ✅

#### Backend
- Node.js + Express + MongoDB (Mongoose) + Socket.io
- Auth: JWT + bcrypt, register/login/forgot/reset/me/logout
- Game engine: pure Ludo logic (engine.js) — UNTOUCHED
- Matchmaking: queue by capacity + ELO, private rooms, practice vs bots
- Wallet: free points only (claim 100/day)
- Stats/Leaderboard, Admin panel, Dispute system

#### Frontend (Flutter 3.x)
- main.dart: ClubHome, GameScreen, WalletScreen, AuthScreen, AdminScreen, DataScreen, ReplayScreen
- api.dart: HTTP + Socket.io client
- board.dart: Ludo board painter — UNTOUCHED

### WHAT IS MISSING ❌
- Entry fee on Game/Queue models
- Deduction on match start (atomic)
- Prize pool tracking + winner payout
- Refund on cancel/disconnect
- Deposit/Withdraw (simulated) endpoints
- Entry fee matchmaking filter
- Flutter: entry fee selection sheet
- Flutter: prize pool display in-game
- iOS simulator URL fix (10.0.2.2 → 127.0.0.1)

### DECISIONS
- Currency: existing `points` field = betting tokens
- All money ops: MongoDB transactions + $inc guards
- Guest mode: play free practice only
