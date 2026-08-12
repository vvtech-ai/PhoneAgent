# 构建与配置 / Build and Configuration

## 中文

### 构建环境

- JDK 11
- Android SDK 33
- Gradle Wrapper 7.5.1
- Android Gradle Plugin 7.4.2
- Android 8.0（API 26）及以上

将示例复制为本机配置，并填写 Android SDK 路径：

```powershell
Copy-Item local.properties.example local.properties
```

`local.properties` 已被 Git 忽略。不得把真实客户端参数、签名口令或任何后台密钥复制到示例文件。

### 常用命令

```powershell
# 托管服务调试包
.\gradlew.bat :app:assembleProdDebug

# 托管服务单元测试
.\gradlew.bat :app:testProdDebugUnitTest

# 自定义兼容服务
.\gradlew.bat :app:assembleLocalDebug -PserverBaseUrl=https://service.example/
```

macOS/Linux 将 `gradlew.bat` 替换为 `./gradlew`。

### 可配置属性

| 属性 | 默认值 | 说明 |
| --- | --- | --- |
| `hostedServerBaseUrl` | `https://chaken-ai.vvtech.tech/aiassistant-api/` | `prod`/`dev` 使用的托管服务 |
| `serverBaseUrl` | `auto` | `local` 服务地址；自动探测失败回退模拟器地址 |
| `assistantTranslationWebRtcDefaultUrl` | 生产翻译入口 | 默认翻译 WebRTC 服务 |
| `assistantTranslationWebRtcUsUrl` | 默认翻译入口 | 美国区域覆盖值 |
| `assistantTranslationWebRtcJpUrl` | 默认翻译入口 | 日本区域覆盖值 |
| `optionalIncallSdkAppKey` | 仓库内公开客户端默认值 | 内置 CHAKEN 可信通信 SDK 的客户端授权参数 |
| `optionalIncallSdkAppSecret` | 仓库内公开客户端默认值 | 内置 CHAKEN 可信通信 SDK 的客户端授权参数 |

构建参数可通过 `-Pname=value` 或本机 `local.properties` 提供。不要把模型、短信、SIP、地图或后台数据库凭据注入 APK。

### SDK 二进制

公司自有且已加固的 CHAKEN 可信通信 SDK 位于 `app/libs/` 并随源码构建。经授权可公开分发的客户端授权参数已作为 Gradle 默认值提交到 Git，直接构建即可使用；参数轮换时可由本机或受控发布环境覆盖。阿里云金融级实人认证等未获公开再分发授权的二进制仍应放入 `app/private-libs/`。SDK 会通过自己的 Manifest 合并 Activity、Service、Receiver 或权限，发布前必须审计最终 APK。

任何写入 `BuildConfig` 的值都能从 APK 中提取，因此只能使用供应商明确允许放在客户端、可撤销且权限受限的参数。

## English

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

### Common commands

```bash
# Hosted-service debug APK
./gradlew :app:assembleProdDebug

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

### SDK binaries

The company's own hardened CHAKEN trusted-call SDK is bundled under `app/libs/`. Client-scoped parameters authorized for public distribution are committed as Gradle defaults and may be overridden by a local or controlled release environment when rotated. Separately licensed binaries such as Alibaba Cloud financial-grade identity verification remain under `app/private-libs/`. SDK manifests can merge activities, services, receivers, or permissions into the app, so audit the final APK before distribution.

Anything written to `BuildConfig` is extractable from the APK. Use only revocable, least-privileged parameters that the vendor explicitly permits in a client application.
