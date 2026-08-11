# Phone Agent Android

English | [简体中文](README.md)

Phone Agent is an Android voice-agent client for handling phone-based tasks. Users describe a task by voice or text, while a hosted service provides task understanding, call preparation, phone execution, real-time translation, and result delivery.

![Phone Agent home screen](docs/images/home.png)

## Open-source scope

This repository contains the Android client only. It does not contain the server implementation.

| Included | Not included |
| --- | --- |
| Kotlin and Jetpack Compose client source | Backend source, admin console, or database schema |
| Client networking, voice, SIP, and UI logic | Server-side model, SMS, SIP, or map credentials |
| Android tests and protocol fixtures | Deployment scripts, runtime configuration, or production data |
| Build guides, permission notes, and screenshots | Commercial SDK binaries without redistribution permission |

The client connects to the deployed Phone Agent hosted service by default:

```text
https://chaken-ai.vvtech.tech/aiassistant-api/
```

The hosted service is separate from the Apache-2.0 license of this repository. Availability, account access, SMS quotas, call charges, concurrency, and regional capabilities are governed by the actual service policy.

## Features

- Phone-number sign-in and registration with SMS verification.
- Home-screen task entries and call-model selection.
- Voice or text phone tasks with understanding, confirmation, and execution.
- Dialing, call-model selection, and real-time translated calls.
- Call history, transcripts, task results, and recording playback.
- Identity, AI voice, trusted-call, OTA update, and log-upload settings.
- Bundled first-party hardened CHAKEN trusted-call SDK, with optional voice-clone identity verification integration.

See the [English project introduction](docs/PROJECT_INTRODUCTION.en.md) or the [中文项目介绍](docs/PROJECT_INTRODUCTION.zh-CN.md) for the full product overview.

## How it works

```text
Phone sign-in
  -> choose a task or model
  -> describe the phone task by voice or text
  -> hosted backend understands and confirms the task
  -> backend and client coordinate the call or translation
  -> client displays transcripts, results, and call history
```

Model API keys, SMS credentials, SIP accounts, and map keys belong on the hosted backend. They must never be embedded in Android source, sample properties, APKs, or logs.

## Quick start

### Requirements

- Android Studio or Android SDK command-line tools
- JDK 11
- Android SDK 33
- Android 8.0 (API 26) or later
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

### Use an authorized compatible service

```bash
./gradlew :app:assembleLocalDebug -PserverBaseUrl=https://your-compatible-service.example/
```

The URL must start with `http://` or `https://`; use HTTPS in production. The server implementation is not open sourced, so third-party services must independently implement the client-facing request and event contracts.

See [Build and configuration](docs/BUILD_AND_CONFIGURATION.md) for details.

## Build variants

| Variant | Default service | Purpose |
| --- | --- | --- |
| `prod` | Phone Agent hosted service | Public evaluation and release builds |
| `dev` | Phone Agent hosted service | Development build with a separate application ID |
| `local` | Auto-detected LAN address or an explicit build property | Authorized compatible-service integration |

## SDK boundary

The public repository redistributes the company's own hardened CHAKEN trusted-call SDK under `app/libs/`. Client AppKey/Secret values are not committed; builders must inject authorized, revocable, least-privileged client parameters through local `local.properties` or Gradle properties.

Alibaba Cloud financial-grade identity verification, face, security, and risk-control binaries are not redistributed. Authorized integrators may place those separately licensed AAR/JAR files in the Git-ignored `app/private-libs/` directory. Without them, new voice-clone identity verification is unavailable, while sign-in, task handling, hosted AI calls, and history continue to work. See [Third-party notices](THIRD_PARTY_NOTICES.md).

## Permissions and data

Depending on the feature, the app requests microphone, camera, contacts, phone, call-log, location, overlay, and package-install permissions. Denying a nonessential permission should not prevent startup, but disables the related feature. Obtain required consent and follow applicable laws before testing real calls, recordings, identity data, or voice cloning.

See [Privacy and permissions](docs/PRIVACY_AND_PERMISSIONS.md) and [Backend service boundary](docs/BACKEND_SERVICE.md).

## Repository layout

```text
app/                         Android application module
  libs/                      Bundled CHAKEN trusted-call SDK
  src/main/                  Client source and resources
  src/test/                  Unit tests and protocol fixtures
  private-libs/              Other optional commercial SDKs (Git-ignored)
docs/                        Bilingual product, architecture, and usage docs
gradle/                      Gradle Wrapper
README.md / README_EN.md     Chinese and English entry points
```

## Security

Never commit real phone numbers, verification codes, tokens, model keys, SIP passwords, signing files, or production logs. Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) and run at least:

```bash
./gradlew :app:compileProdDebugUnitTestKotlin :app:assembleProdDebug
```

See [Known issues](docs/KNOWN_ISSUES.md) for the public-boundary smoke tests and the current full-suite status.

## License

First-party client source is licensed under the [Apache License 2.0](LICENSE). Third-party libraries, artwork, fonts, hosted services, and optional commercial SDKs remain subject to their own licenses and terms. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
