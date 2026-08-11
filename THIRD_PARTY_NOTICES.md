# Third-Party Notices / 第三方组件说明

This file is informational and does not replace the license text shipped by each dependency.

本文仅用于说明边界，不能替代各依赖随附的正式许可证或服务条款。

## Open-source dependencies / 开源依赖

The Android build resolves libraries including AndroidX, Jetpack Compose, Kotlin Coroutines, Retrofit, OkHttp, Gson, Material Components, ML Kit, LiveKit, protobuf, TinyPinyin, Bouncy Castle, Glide, Fastjson, and Okio. Their copyright and license terms remain with their respective projects and are available from the dependency artifacts or upstream repositories.

Android 构建会解析 AndroidX、Jetpack Compose、Kotlin Coroutines、Retrofit、OkHttp、Gson、Material Components、ML Kit、LiveKit、protobuf、TinyPinyin、Bouncy Castle、Glide、Fastjson 和 Okio 等组件。相关著作权和许可仍归各项目所有，请以依赖包或上游仓库随附文本为准。

## Hosted and vendor services / 托管及供应商服务

The client can interact with hosted model, SMS, map, SIP, translation, CDN, OTA, and storage services. Network access to a service does not make that service or its server software part of this repository's Apache-2.0 license.

客户端可能访问模型、短信、地图、SIP、翻译、CDN、OTA 和对象存储服务。通过网络访问这些服务，不表示其服务端软件或额度属于本仓库 Apache-2.0 许可范围。

## Bundled first-party SDK / 随源码分发的自有 SDK

`app/libs/chaken-incall-1.5.aar` and `app/libs/chaken-incall-ui-1.5.aar` are hardened CHAKEN trusted-call components owned by 微位（深圳）网络科技有限公司. The copyright holder has authorized their redistribution in this repository. Runtime service access remains subject to valid client authorization parameters and the applicable service terms.

`app/libs/chaken-incall-1.5.aar` 和 `app/libs/chaken-incall-ui-1.5.aar` 是微位（深圳）网络科技有限公司自有并已加固的 CHAKEN 可信通信组件，著作权人已授权随本仓库公开分发。运行时服务访问仍须使用有效的客户端授权参数并遵守相应服务条款。

## Excluded proprietary SDKs / 未分发的商业 SDK

The public repository does not redistribute Alibaba Cloud financial-grade identity verification binaries or related face, security, and risk-control components. Authorized integrators must obtain these files directly from the vendor and may place them in the Git-ignored `app/private-libs/`. Do not submit other AAR/JAR files unless redistribution rights are documented.

公开仓库不分发阿里云金融级实人认证 SDK 及其人脸、安全和风控组件。获得授权的集成方必须从供应商合法取得这些文件，可将其放入已被 Git 忽略的 `app/private-libs/`。除非已记录公开再分发授权，否则不得提交其他 AAR/JAR。

Android and related marks are trademarks of Google LLC. Other product names and trademarks belong to their respective owners.
