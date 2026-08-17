# Contributing

Phone Agent welcomes contributions to the Android client, reliability, tests, documentation, translations, and future Call Skill design.

## Ways to contribute

- Fix Android features or compatibility issues.
- Add unit, protocol, or manual verification coverage.
- Improve documentation, screenshots, and accessibility.
- Propose a phone scenario with a risk analysis.
- Help design Call Skill manifests, inputs, results, permissions, and tests.

## Call Skill proposals

The Call Skill SDK has not been released, so contribute design proposals rather than claiming executable Skill packages. A proposal should include:

1. Scenario, target users, and explicit non-goals.
2. Required and optional inputs, and confirmation points.
3. Call policy and possible external tools.
4. Success, partial, failure, and human-handoff outcomes.
5. Telephony, contacts, recording, location, and retention risks.
6. Happy-path, rejection, no-answer, conflicting-data, and failure tests.

See the [Call Skill vision](docs/CALL_SKILLS.md).

## Engineering rules

1. Do not commit backend source, server configuration, accounts, credentials, production data, or commercial SDKs without redistribution rights.
2. Keep UI, Domain, Data, and Integration dependencies directional. Composables must not start network, SIP, ASR, or TTS operations directly.
3. New state needs a single source of truth; one-shot work should use an explicit effect or event stream.
4. Logs must be correlatable and must not leak sensitive data.
5. Detect hosted capabilities at runtime; do not hard-code promises about accounts, models, regions, or telephony.

## Before submitting

Run at least:

```bash
./gradlew :app:compileProdDebugUnitTestKotlin :app:assembleProdDebug
```

Pull requests should include:

- Behavior change and user impact.
- Backend-contract, permission, and privacy impact.
- Automated results and manual verification path.
- Screenshots for UI changes.
- Known limits and rollback approach.

Never attach real numbers, verification codes, tokens, audio, transcripts, or identity material when working on calls, recordings, translation, or voice cloning.
