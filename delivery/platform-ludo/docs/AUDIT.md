# Repository audit and migration safety

Audit date: 2026-10-15. No MongoDB collection was deleted or reset in the player database. Integration tests use isolated `ludo_test*` databases and drop only those test databases.

| Area | Existing implementation | Active platform module treatment |
| --- | --- | --- |
| Flutter | `frontend/lib/main.dart`, game, shop, wallet, admin widgets | Bright game screens, native/Web launch handoff, wallet navigation removed |
| Server | Express `backend/src/app.js`, `service.js` | Existing engine and free match service retained; platform routes added |
| Game logic | `engine.js`, `board.dart`, server rolls, turn revision checks | Preserved; visual board painter keeps the same 15×15 geometry |
| Multiplayer | Socket.IO authenticated events, queue, room, sync, chat | Preserved; platform launches also checked on Socket.IO authentication |
| Storage | Mongoose users, games, queues, events, chat, money wallet/stakes/transactions | New platform IDs, launch records, cosmetic purchase records; old records retained |
| Legacy finance | EGP MoneyWallet/MoneyStake ledger, Vodafone requests and admin review | Player and finance routes absent when `PLATFORM_MODE=true`; old models/routes retained for rollback mode |
| Identity | Register/login/guest/admin JWT | Legacy auth endpoints disabled in platform mode; one-time platform exchange issues one-hour scoped JWT |
| Visual references | Actual directory is `photos/` (no `photots/`) | Seven JPEG reference sheets inspected; inventory in `photos/ASSET_INVENTORY.md`; no embedded third-party branding copied |
| Baseline | Flutter widgets, engine unit tests, Mongo integration suite | All original tests rerun; new platform adapter and integration tests added |

## Migration / rollback

`PLATFORM_MODE=true` selects the new player runtime. `PLATFORM_MODE=false` retains the old routes for migration or rollback under existing credentials and data. This flag does **not** convert legacy EGP balances to points. Platform-linked player records have a stable `platformId`, a synthetic internal username/email for schema compatibility, and no MoneyWallet created by game entry. Existing users and audit records remain untouched. Before retiring legacy routes in a production migration, export and archive its financial data under the platform team's retention policy; do not drop collections automatically.

The active player UI has no wallet, deposit, withdrawal, registration, or guest entry. Historical admin/finance widgets remain in source solely for legacy test and rollback code paths; platform players cannot navigate to them.
