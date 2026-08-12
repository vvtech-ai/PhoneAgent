# Phone Agent · AI Calling Agent

English | [简体中文](README.md)

> **Let AI handle the call. Build a Skill for every calling scenario.**

Phone Agent is an open-source Android client for AI-assisted phone tasks. Describe a restaurant reservation, meeting notification, coordination task, or cross-language conversation by voice or text; the client and hosted service work together to understand the request, confirm key details, make a real call, and return the result.

Our next step is **Call Skill** development: a way for developers to package domain knowledge, dialogue policy, tool use, and structured results into reusable calling experiences.

[Quick start](#quick-start) · [Product tour](docs/PROJECT_INTRODUCTION.en.md) · [Call Skill vision](docs/CALL_SKILLS.en.md) · [Contributing](CONTRIBUTING.md)

![Phone Agent home screen](docs/images/home.png)

## More than a chat—complete a phone task

```text
Speak or type a request
  → collect time, number, party size, and other key details
  → confirm the task and calling scope with the user
  → coordinate execution between the client and hosted service
  → review status, transcript, recording, and task result
```

| Scenario | How Phone Agent helps | Status |
| --- | --- | --- |
| Restaurant reservations | Understand time, party size, location, and preferences, then enter the call workflow | Built-in entry; actual capability depends on the hosted service |
| Meeting invitations | Organize contacts and invitation details, then collect call outcomes | Built-in entry; actual capability depends on service and telephony capacity |
| Real-time translation | Start a translated call and display transcripts and translated text | Available; model and regional coverage vary by service |
| General phone tasks | Describe a task by voice or text and execute after confirmation | Available |
| Community Call Skills | Let developers add appointments, support, logistics, and more | Planned; the SDK is not released yet |

## Why Phone Agent

- **Built for real phone tasks**: move from natural-language input to confirmation, calling, and results—not just another chat window.
- **A complete mobile experience**: native Android screens for sign-in, tasks, dialing, translation, history, voices, and settings.
- **Confirm before execution, review afterward**: verify important details first, then inspect task state, call history, transcripts, and receipts.
- **Composable communication foundations**: HTTP, SSE, WebSocket, SIP, WebRTC, audio, and trusted-call integration in one client.
- **A developer ecosystem in the making**: Call Skills will turn phone workflows into describable, testable, and shareable extensions.

## Product at a glance

| Create by voice | Complete by text | Dial and choose a model |
| --- | --- | --- |
| ![Voice task](docs/images/task-voice.png) | ![Text task](docs/images/task-text.png) | ![Dialer](docs/images/dialer.png) |

| Call history | Settings | AI voices |
| --- | --- | --- |
| ![Call history](docs/images/call-history.png) | ![Settings](docs/images/settings.png) | ![AI voice settings](docs/images/voice-settings.png) |

See the [product introduction](docs/PROJECT_INTRODUCTION.en.md) for the complete user journey.

## Call Skills: make every calling scenario programmable

We envision a Call Skill as a reusable package for a phone workflow. It describes:

- when the Skill should match;
- which details must be collected and confirmed;
- which dialogue policy and tools may be used during the call;
- what counts as successful completion;
- which structured result is returned to the user;
- which permissions, compliance rules, and safety limits apply.

Restaurant reservations, service appointments, meeting invitations, hotel confirmations, after-sales coordination, logistics, translated calls, and accessibility assistance can each become an independent Call Skill.

> Call Skills are a public roadmap direction, not a released SDK. See the [Call Skill vision](docs/CALL_SKILLS.en.md) and [roadmap](docs/ROADMAP.en.md) for the conceptual model and planned stages.

## Architecture at a glance

```text
Android UI / user confirmation
        ↓
Task, contact, call, and result state
        ↓
HTTP · SSE · WebSocket · SIP · WebRTC
        ↓
Phone Agent hosted service
        ↓
Models · SMS · maps · telephony · storage

Future Call Skill layer: matching · input schema · dialogue policy · tools · results
```

The client uses Kotlin, Jetpack Compose, AndroidX, MVVM, Coroutines, and Flow. See [Client architecture](docs/ARCHITECTURE.md) for details.

## Quick start

### Requirements

- JDK 11
- Android Studio or Android SDK command-line tools
- Android SDK 33
- A physical device running Android 8.0 (API 26) or later
- Network access to the hosted service

### Build a debug APK for the hosted service

Windows:

```powershell
Copy-Item local.properties.example local.properties
.\gradlew.bat :app:assembleProdDebug
```

macOS / Linux:

```bash
cp local.properties.example local.properties
./gradlew :app:assembleProdDebug
```

The APK is written to `app/build/outputs/apk/prod/debug/` and archived under `app/apks/`. Debug signing is for development only; configure your own signing identity for distribution.

Default hosted endpoint:

```text
https://chaken-ai.vvtech.tech/aiassistant-api/
```

See [Build and configuration](docs/BUILD_AND_CONFIGURATION.md) for detailed properties and compatible-service builds.

## Current project boundary

| Included in this repository | Not included |
| --- | --- |
| Kotlin and Jetpack Compose Android client source | Backend source, admin console, or database schema |
| Client networking, task, voice, SIP, WebRTC, and UI logic | Backend deployment scripts, production configuration, or production data |
| Android unit tests and protocol fixtures | Server-side model, SMS, SIP, map, or storage credentials |
| First-party hardened CHAKEN trusted-call SDK | Commercial SDK binaries without public redistribution permission |
| Build, architecture, privacy, and extension-roadmap documentation | The planned Call Skill SDK and distribution platform |

The hosted service is separate from the Apache-2.0 license of this repository. Availability, account access, SMS quotas, call charges, concurrency, model access, and regional coverage follow the actual service policy. See [Backend service boundary](docs/BACKEND_SERVICE.md) and [FAQ](docs/FAQ.en.md).

## SDKs, permissions, and security

- `app/libs/` includes the company's hardened CHAKEN trusted-call SDK and client-scoped parameters authorized for public distribution.
- Identity and other commercial binaries without redistribution rights are excluded. Their absence does not block basic sign-in, tasks, hosted AI calls, or history.
- Depending on the feature, the app requests microphone, camera, contacts, phone, call-log, location, overlay, and package-install permissions.
- Never commit real phone numbers, verification codes, tokens, model keys, SIP passwords, signing files, production logs, recordings, or identity material.

See [Third-party notices](THIRD_PARTY_NOTICES.md), [Privacy and permissions](docs/PRIVACY_AND_PERMISSIONS.md), and [Security policy](SECURITY.md).

## Roadmap

- **Now**: keep improving the Android phone-agent client, built-in scenarios, translated calls, history, and trusted-call experience.
- **In design**: the Call Skill lifecycle, manifest, input slots, result contracts, permission declarations, and compatibility rules.
- **Planned next**: a developer SDK, local debugging, simulation tests, example Skills, and community distribution.

The roadmap communicates direction, not a release or date commitment. See the [full roadmap](docs/ROADMAP.en.md).

## Contributing

Contributions are welcome across Android features, reliability, tests, documentation, translations, scenario proposals, and future Call Skill design. Read [CONTRIBUTING.md](CONTRIBUTING.md) and run at least:

```bash
./gradlew :app:compileProdDebugUnitTestKotlin :app:assembleProdDebug
```

Check [Known issues](docs/KNOWN_ISSUES.md) before troubleshooting.

## License

First-party client source is licensed under the [Apache License 2.0](LICENSE). Third-party libraries, artwork, fonts, hosted services, and optional commercial SDKs remain subject to their own licenses and terms. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
