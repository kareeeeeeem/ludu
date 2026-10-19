# Build information — 2026-10-17

| Artifact | Build target | Result |
| --- | --- | --- |
| `builds/LudoClub-platform-emulator-debug.apk` | Android emulator, debug; `API_URL=http://10.0.2.2:3108` | Built, installed and launched with one-time mock platform code |
| `builds/web/` | Flutter Web release; `API_URL=http://127.0.0.1:3108` | Built successfully |

APK SHA-256: `66a81fa3b577a29bee7e57ff0798ee9ea3b0db77f56a5f671b46bf85536ad7c2`

Both are local integration builds. Build again with approved HTTPS API addresses, signing, package identity and host deployment settings before distribution. No iOS simulator build was run; the native iOS launch bridge is not implemented.
