# Third-Party Notices / 第三方组件说明

This file is informational and does not replace the license text shipped by each dependency.

本文仅用于说明边界，不能替代各依赖随附的正式许可证或服务条款。

## Open-source dependencies / 开源依赖

The Android build resolves libraries including AndroidX, Jetpack Compose, Kotlin Coroutines, Retrofit, OkHttp, Gson, Material Components, ML Kit, LiveKit, protobuf, TinyPinyin, Bouncy Castle, Glide, Fastjson, and Okio. Their copyright and license terms remain with their respective projects and are available from the dependency artifacts or upstream repositories.

Android 构建会解析 AndroidX、Jetpack Compose、Kotlin Coroutines、Retrofit、OkHttp、Gson、Material Components、ML Kit、LiveKit、protobuf、TinyPinyin、Bouncy Castle、Glide、Fastjson 和 Okio 等组件。相关著作权和许可仍归各项目所有，请以依赖包或上游仓库随附文本为准。

## Hosted and vendor services / 托管及供应商服务

The client can interact with hosted model, SMS, map, SIP, translation, CDN, OTA, and storage services. Network access to a service does not make that service or its server software part of this repository's Apache-2.0 license.

客户端可能访问模型、短信、地图、SIP、翻译、CDN、OTA 和对象存储服务。通过网络访问这些服务，不表示其服务端软件或额度属于本仓库 Apache-2.0 许可范围。

## Optional proprietary SDKs / 可选商业 SDK

The public repository intentionally excludes proprietary binaries, including:

- CHAKEN trusted-call / in-call SDK binaries;
- Alibaba Cloud financial-grade identity verification binaries;
- related face, protection, or application-hardening components.

公开仓库明确不分发以下商业二进制：

- CHAKEN 可信来电/通话 SDK；
- 阿里云金融级实人认证 SDK；
- 相关人脸、保护或应用加固组件。

Authorized integrators must obtain these files directly from the vendor and comply with the vendor's terms. Vendor binaries may be placed locally in `app/private-libs/`, which is excluded from Git. Do not open a pull request containing an AAR/JAR unless redistribution rights are documented.

获得授权的集成方必须从供应商合法取得文件并遵守供应商条款。二进制可在本机放入已被 Git 忽略的 `app/private-libs/`。除非提供公开再分发授权证明，否则不得在 Pull Request 中提交 AAR/JAR。

Android and related marks are trademarks of Google LLC. Other product names and trademarks belong to their respective owners.
