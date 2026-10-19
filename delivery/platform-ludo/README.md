# Ludo Club platform module — local handoff

This package contains the Flutter source, Node/Socket.IO backend, local mock platform, API contract, integration guide, Android emulator debug APK and Web output. Start with [integration/PLATFORM_DEVELOPER_START_HERE.md](integration/PLATFORM_DEVELOPER_START_HERE.md) and [FINAL_FUNCTIONAL_HANDOFF_REPORT.md](FINAL_FUNCTIONAL_HANDOFF_REPORT.md). The game-owned paid match lifecycle is implemented and tested against a **test-only** policy and local mock; commercial enablement requires the host's approved policy and real-platform contract tests. Build artifacts use development loopback addresses and contain no platform service credential.

From `source/`, install Flutter and Node dependencies, build Web as described in the guide, then run `bash scripts/dev-platform.sh`. The local launcher at `http://127.0.0.1:3110/` issues a one-time launch code and opens Ludo Web. The backend alone verifies the code. The Android APK is a separate test client requiring a host-provided `platform_session` intent extra.

## Handoff state

- Platform login handoff, revocable game sessions, authenticated sockets, platform balance display, free Classic/Practice games, cosmetics with server-approved point prices and persistent ownership/equipment, local mock, and bright Flutter presentation are implemented.
- Positive-point Classic entry is enabled only with a validated, approved policy and an enabled tier. The persistent reserve/commit/release/settle lifecycle is integrated and locally tested in private and public matches, including reconciliation and escrow conservation. No commercial policy is supplied in this package.
- Magic and Fast remain unavailable until approved rules exist. iOS needs a native launch bridge. Supplied reference collages require license verification before any commercial artwork reuse.
- The actual external platform API has not been supplied or connected. The host team must adapt and verify the server-to-server contract before production.

The package intentionally excludes `.env`, private keys, legacy administrator credentials, database dumps, `node_modules`, build caches, and the unlicensed reference collages. Legacy EGP/Vodafone records and backend code remain in source for migration, but the platform player runtime excludes those routes and screens.
