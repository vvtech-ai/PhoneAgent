# Known Issues

- The historical client source is large. A first full Kotlin build with JDK 11 takes roughly 4–7 minutes on the verification machine. The project uses in-process Kotlin compilation and a 5 GB Gradle heap; at least 8 GB of available build memory is recommended.
- Baseline result on 2026-08-11: `testProdDebugUnitTest` ran 1,613 tests; 1,584 passed and 29 failed. Most failures are stale source-shape assertions from internal refactoring and pre-existing behavior regression tests. The open-source preparation does not misrepresent them as passing.
- Public CI compiles all main and test source, builds the `prodDebug` APK, and runs smoke tests for proprietary-SDK isolation, backend-assigned SIP leases, network configuration, home configuration, and call policy.
- The CHAKEN trusted-call SDK and its client-scoped AppKey/Secret authorized for public distribution are bundled, so a direct build performs service initialization. Alibaba Cloud identity binaries remain excluded, so new voice-clone identity verification is unavailable. Base sign-in, tasks, hosted AI calls, and history do not depend on that identity-verification capability.
- During real-device testing against `https://chaken-ai.vvtech.tech/aiassistant-api/` on 2026-08-11, the main business APIs succeeded, but the published home configuration referenced seven missing image assets. Those asset requests return 404 and the client displays local fallback images.
- In the same test, the Qwen TTS WebSocket closed with code `1007`, which affects Qwen voice playback. Sign-in, text tasks, and the other verified HTTP APIs remain available. The hosted Qwen TTS proxy or provider configuration needs server-side investigation.
- The backend is outside this repository, so the official complete service cannot be reproduced locally from this source alone.

Future client refactoring should triage each full-suite failure into an obsolete source-shape assertion, a fixture that needs updating, or an actual behavior regression.
