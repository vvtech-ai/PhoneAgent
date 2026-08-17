# Third-Party Notices

This file is informational and does not replace the license text shipped by each dependency.

## Open-source dependencies

The Android build resolves libraries including AndroidX, Jetpack Compose, Kotlin Coroutines, Retrofit, OkHttp, Gson, Material Components, ML Kit, LiveKit, protobuf, TinyPinyin, Bouncy Castle, Glide, Fastjson, and Okio. Their copyright and license terms remain with their respective projects and are available from the dependency artifacts or upstream repositories.

## Hosted and vendor services

The client can interact with hosted model, SMS, map, SIP, translation, CDN, OTA, and storage services. Network access to a service does not make that service or its server software part of this repository's Apache-2.0 license.

## Bundled first-party SDK

`app/libs/chaken-incall-1.5.aar` and `app/libs/chaken-incall-ui-1.5.aar` are hardened CHAKEN trusted-call components owned by VVTech (Shenzhen) Network Technology Co., Ltd. The copyright holder has authorized their redistribution in this repository. Runtime service access remains subject to valid client authorization parameters and the applicable service terms.

## Excluded proprietary SDKs

The public repository does not redistribute Alibaba Cloud financial-grade identity verification binaries or related face, security, and risk-control components. Authorized integrators must obtain these files directly from the vendor and may place them in the Git-ignored `app/private-libs/`. Do not submit other AAR/JAR files unless redistribution rights are documented.

Android and related marks are trademarks of Google LLC. Other product names and trademarks belong to their respective owners.
