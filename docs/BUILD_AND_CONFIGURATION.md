# Build and Configuration

### Build environment

- JDK 11
- Android SDK 33
- Gradle Wrapper 7.5.1
- Android Gradle Plugin 7.4.2
- Android 8.0 (API 26) or later

Copy the local example and set the Android SDK path:

```bash
cp local.properties.example local.properties
```

`local.properties` is Git-ignored. Never copy real client parameters, signing passwords, or backend secrets into the example file.

### Official signed APK

Users who do not need a local build can download the signed package from [GitHub Releases](https://github.com/vvtech-ai/PhoneAgent/releases/latest). The current package is [PhoneAgent v1.0.36](https://github.com/vvtech-ai/PhoneAgent/releases/download/v1.0.36/PhoneAgent-1.0.36.apk):

- Package: `com.vvtech.aiassistant`
- Version: `1.0.36` (versionCode `30`)
- ABI: `arm64-v8a`
- UI languages: English and Simplified Chinese
- File SHA-256: `38da610a814ab331fa5bfa29bba33a6eeec5f365a6f9d1017dfe8f225aa3f5ec`
- Signing certificate SHA-256: `017bb27a94baf1549ce7021363e2efc0bf86d93e6a48834c7489288966af2a4b`

The current public APK uses the project's existing test-distribution certificate. It supports upgrades from earlier builds signed with the same certificate, but it is not an app-store production signature. The private key and passwords are not included in this repository. Any future migration to a production certificate will be documented in the release notes.

### Common commands

```bash
# Hosted-service debug APK
./gradlew :app:assembleProdDebug

# Hosted-service release APK (uses configured local signing, or the local debug certificate when unset)
./gradlew :app:assembleProdRelease

# Hosted-service unit tests
./gradlew :app:testProdDebugUnitTest

# Authorized compatible service
./gradlew :app:assembleLocalDebug -PserverBaseUrl=https://service.example/
```

### Properties

| Property | Default | Purpose |
| --- | --- | --- |
| `hostedServerBaseUrl` | `https://chaken-ai.vvtech.tech/aiassistant-api/` | Hosted endpoint for `prod`/`dev` |
| `serverBaseUrl` | `auto` | `local` endpoint; falls back to the emulator host |
| `assistantTranslationWebRtcDefaultUrl` | production translation endpoint | Default translation WebRTC service |
| `assistantTranslationWebRtcUsUrl` | default translation endpoint | US regional override |
| `assistantTranslationWebRtcJpUrl` | default translation endpoint | Japan regional override |
| `optionalIncallSdkAppKey` | public repository default | Client authorization parameter for the bundled CHAKEN trusted-call SDK |
| `optionalIncallSdkAppSecret` | public repository default | Client authorization parameter for the bundled CHAKEN trusted-call SDK |

Properties may be supplied with `-Pname=value` or local `local.properties`. Never inject model, SMS, SIP, map, or backend database credentials into an APK.

A controlled release environment may provide `signingStoreFile`, `signingStorePassword`, `signingKeyAlias`, and `signingKeyPassword`. Keep these values only in Git-ignored local configuration or CI secrets. Never commit a signing key or its passwords.

### SDK binaries

The company's own hardened CHAKEN trusted-call SDK is bundled under `app/libs/`. Client-scoped parameters authorized for public distribution are committed as Gradle defaults and may be overridden by a local or controlled release environment when rotated. Separately licensed binaries such as Alibaba Cloud financial-grade identity verification remain under `app/private-libs/`. SDK manifests can merge activities, services, receivers, or permissions into the app, so audit the final APK before distribution.

Anything written to `BuildConfig` is extractable from the APK. Use only revocable, least-privileged parameters that the vendor explicitly permits in a client application.
