# Phone Agent Android

[English](README_EN.md) | 简体中文

Phone Agent 是一款面向电话事务处理的 Android 语音智能体终端。用户可以通过语音或文字下达任务，由托管服务完成任务理解、通话准备、电话执行、实时翻译和结果回传。

![Phone Agent 首页](docs/images/home.png)

## 开源范围

本仓库只包含 Android 终端代码，不包含服务端实现。

| 已包含 | 未包含 |
| --- | --- |
| Kotlin / Jetpack Compose 客户端源码 | 后台源码、管理后台和数据库结构 |
| 客户端网络、语音、SIP 与界面逻辑 | 模型、短信、SIP、地图等服务端密钥 |
| Android 单元测试与协议测试样例 | 后台部署脚本、运行配置和生产数据 |
| 构建文档、权限说明和界面截图 | 未获公开再分发授权的商业 SDK 二进制 |

客户端默认连接已部署的 Phone Agent 托管服务：

```text
https://chaken-ai.vvtech.tech/aiassistant-api/
```

托管服务与本仓库的 Apache-2.0 软件许可相互独立。服务可用性、账号开通、短信额度、电话资费、并发量和区域能力以实际服务策略为准。

## 主要功能

- 手机号与短信验证码登录/注册。
- 首页电话任务入口和可用通话模型选择。
- 语音或文字创建电话任务，支持任务理解、确认和执行。
- 电话拨号、通话模型选择及实时翻译通话。
- 通话记录、转写、任务结果和录音回看。
- 身份资料、AI 音色、可信来电、版本更新和日志上报设置。
- 内置公司自有且已加固的 CHAKEN 可信通信 SDK；声音克隆身份认证 SDK 仍为可选集成。

更完整的产品说明见[中文项目介绍](docs/PROJECT_INTRODUCTION.zh-CN.md)和 [English Project Introduction](docs/PROJECT_INTRODUCTION.en.md)。

## 工作方式

```text
手机号登录
  -> 首页选择任务/模型
  -> 语音或文字描述电话事务
  -> 托管后台理解并确认任务
  -> 后台与终端协同执行通话/翻译
  -> 终端展示转写、结果和通话记录
```

模型 API Key、短信平台凭据、SIP 账号和地图 Key 只保存在托管后台，不应写入 Android 源码、`local.properties` 示例、APK 或日志。

## 快速开始

### 环境要求

- Android Studio 或 Android SDK Command-line Tools
- JDK 11
- Android SDK 33
- Android 8.0（API 26）及以上设备
- 可访问托管服务的网络环境

### 构建连接托管服务的调试包

Windows：

```powershell
Copy-Item local.properties.example local.properties
.\gradlew.bat :app:assembleProdDebug
```

macOS / Linux：

```bash
cp local.properties.example local.properties
./gradlew :app:assembleProdDebug
```

APK 输出到 `app/build/outputs/apk/prod/debug/`，同时会归档到 `app/apks/`。调试签名仅用于开发测试，正式发布必须配置自己的签名。

### 使用自定义兼容服务

```powershell
.\gradlew.bat :app:assembleLocalDebug -PserverBaseUrl=https://your-compatible-service.example/
```

服务地址必须以 `http://` 或 `https://` 开头；生产环境应使用 HTTPS。服务端 API 契约未作为服务端实现开源，第三方服务需要自行兼容客户端请求和事件协议。

详细配置见[构建与配置](docs/BUILD_AND_CONFIGURATION.md)。

## 构建变体

| 变体 | 默认服务 | 用途 |
| --- | --- | --- |
| `prod` | Phone Agent 托管服务 | 公开体验和正式构建 |
| `dev` | Phone Agent 托管服务 | 独立包名的开发调试 |
| `local` | 自动探测局域网或构建参数指定 | 授权集成方连接兼容服务 |

## SDK 边界

公开仓库随源码分发公司自有且已加固的 CHAKEN 可信通信 SDK，文件位于 `app/libs/`。SDK 的客户端 AppKey/Secret 不写入 Git，构建方仍须通过本机 `local.properties` 或 Gradle 参数注入获得授权的、可撤销且权限受限的客户端参数。

阿里云金融级实人认证 SDK 及其人脸、安全和风控组件未获得公开再分发授权，因此不随仓库提供。获得合法授权后，可把这些 AAR/JAR 放到被 Git 忽略的 `app/private-libs/`。缺少它们时，新建声音克隆的身份认证不可用，但不影响登录、任务、后台 AI 通话和记录等基础功能。详见[第三方组件说明](THIRD_PARTY_NOTICES.md)。

## 权限与数据

应用按功能申请麦克风、相机、联系人、电话、通话记录、定位、悬浮窗和安装更新等权限。拒绝非必要权限不应阻止应用启动，但会限制对应功能。请在测试真实外呼、录音、身份资料或声音克隆前取得必要授权并遵守所在地法律。

详见[隐私与权限](docs/PRIVACY_AND_PERMISSIONS.md)和[后台服务边界](docs/BACKEND_SERVICE.md)。

## 项目结构

```text
app/                         Android 应用模块
  libs/                      随源码分发的 CHAKEN 可信通信 SDK
  src/main/                  终端源码与资源
  src/test/                  单元测试和协议样例
  private-libs/              其他本地可选商业 SDK（Git 忽略）
docs/                        中英文介绍、架构与使用文档
gradle/                      Gradle Wrapper
README.md / README_EN.md     中英文入口
```

## 安全

不要提交真实手机号、验证码、Token、模型 Key、SIP 密码、签名文件或生产日志。安全问题请按 [SECURITY.md](SECURITY.md) 的方式私下报告。

## 参与贡献

提交代码前请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)，并至少执行：

```bash
./gradlew :app:compileProdDebugUnitTestKotlin :app:assembleProdDebug
```

公开边界烟雾测试和当前完整测试集状态见[已知问题](docs/KNOWN_ISSUES.md)。

## 许可证

本仓库中由著作权人提供的终端源码使用 [Apache License 2.0](LICENSE)。第三方库、图标、字体、服务和可选商业 SDK 适用各自许可与服务条款，参见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
