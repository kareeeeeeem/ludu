# Database migration and rollback

The platform mode adds `User.platformId`, `PlatformLaunch`, `CosmeticPurchase`, and game configuration fields; it does not convert or delete legacy users, EGP wallets, deposits, withdrawals or ledgers. Existing local money is **not** converted into platform points. Start with a MongoDB replica set and take a verified snapshot/backup under the owner's retention policy before deployment.

1. Deploy the new backend against a staging copy of MongoDB with `PLATFORM_MODE=true` and the real adapter configuration. Startup calls `models.map(model => model.init())`, creating indexes. Verify unique `User.platformId`, `PlatformLaunch.launchId`, `CosmeticPurchase.requestId`, and the pending-purchase partial index before routing traffic.
2. Verify `GET /api/v1/game/ready` returns 200 and the old collection document counts are unchanged. Exchange a test launch and confirm its profile has a platform ID, no `MoneyWallet`, and no local point balance. Confirm old guest/login, wallet and payment routes are inaccessible to platform sessions.
3. The host must supply globally unique `playerId` values across tenants. If IDs are tenant-local, implement and test composite tenant/player mapping before migration; current profiles key by `platformId` alone.
4. Rollback by stopping new launch traffic and deploying the previous backend against the preserved data snapshot. Do not delete new collections or overwrite historical ledgers automatically. Reconcile pending cosmetic transactions with the platform before any rollback; a committed platform debit must never lose item ownership.

There is no automatic bulk user conversion. Profiles are created only after verified platform launches. The local test suites drop **only** explicitly named `ludo_test` and `ludo_test_platform` databases; never run them against production data.
