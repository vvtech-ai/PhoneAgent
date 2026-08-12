# Phone Agent · 电话智能体

[English](README_EN.md) | 简体中文

> **让 AI 替你完成一通电话，也让开发者为每一种电话场景创造 Skill。**

Phone Agent 是一个开源的 Android 电话智能体终端。你可以用语音或文字描述订餐、会议通知、事务协调或跨语言沟通需求；终端与托管服务协同完成任务理解、信息确认、真实通话和结果回传。

未来，Phone Agent 将开放 **Call Skill（通话技能）** 开发能力，让开发者把行业知识、对话策略、工具调用和结构化结果封装成可复用的电话场景。

[快速构建](#快速开始) · [产品导览](docs/PROJECT_INTRODUCTION.zh-CN.md) · [Call Skill 路线](docs/CALL_SKILLS.zh-CN.md) · [参与贡献](CONTRIBUTING.md)

![Phone Agent 首页](docs/images/home.png)

## 不只是聊天，而是完成一通电话

```text
说出或输入需求
  → 补齐时间、号码、人数等关键信息
  → 用户确认任务与通话范围
  → 终端与托管服务协同执行
  → 回看状态、转写、录音和任务结果
```

| 场景 | Phone Agent 如何协助 | 当前状态 |
| --- | --- | --- |
| 餐厅预订 | 理解时间、人数、位置和偏好，进入电话任务流程 | 已内置入口，实际能力取决于托管服务 |
| 会议邀请 | 整理联系人、通知信息并回收通话结果 | 已内置入口，实际能力取决于托管服务与线路 |
| 实时翻译 | 发起翻译电话并展示双方转写与译文 | 已支持，模型和区域能力以服务为准 |
| 通用电话任务 | 用语音或文字描述事务，在确认后执行 | 已支持 |
| 社区 Call Skill | 由开发者封装预约、售后、物流等新场景 | 规划中，SDK 尚未发布 |

## 为什么选择 Phone Agent

- **面向真实电话任务**：从自然语言输入走到任务确认、通话和结果，不止停留在聊天窗口。
- **移动端完整体验**：Android 原生界面覆盖登录、任务、拨号、翻译、记录、音色和设置。
- **过程可确认，结果可回看**：执行前确认关键内容，执行后查看任务状态、通话记录、转写和回执。
- **可组合的通信能力**：终端集成 HTTP、SSE、WebSocket、SIP、WebRTC 和音频链路，并支持可信通信组件。
- **面向开发者生态演进**：Call Skill 将把电话任务抽象为可描述、可测试、可共享的扩展单元。

## 产品一览

| 语音创建任务 | 文字补充信息 | 拨号与模型选择 |
| --- | --- | --- |
| ![语音任务](docs/images/task-voice.png) | ![文字任务](docs/images/task-text.png) | ![拨号准备](docs/images/dialer.png) |

| 通话记录 | 设置中心 | AI 音色 |
| --- | --- | --- |
| ![通话记录](docs/images/call-history.png) | ![设置中心](docs/images/settings.png) | ![AI 音色](docs/images/voice-settings.png) |

更完整的操作流程见[中文项目介绍](docs/PROJECT_INTRODUCTION.zh-CN.md)。

## Call Skill：让每一种电话场景都可开发

我们把 Call Skill 设想为一个可复用的电话任务能力包。它描述：

- 什么情况下匹配该 Skill；
- 需要向用户收集和确认哪些信息；
- 通话中遵循什么对话策略、可以调用哪些工具；
- 什么情况下算任务完成；
- 最终向用户返回什么结构化结果；
- 需要哪些权限、合规约束和安全边界。

餐厅预订、服务预约、会议邀请、酒店确认、售后协调、物流沟通、跨语言电话和无障碍辅助，都可以成为独立的 Call Skill。

> Call Skill 目前是公开路线方向，不是已经发布的 SDK。概念模型、阶段规划和示例目录见 [Call Skill 愿景](docs/CALL_SKILLS.zh-CN.md)与[项目路线图](docs/ROADMAP.zh-CN.md)。

## 架构概览

```text
Android UI / 用户确认
        ↓
任务、联系人、通话与结果状态
        ↓
HTTP · SSE · WebSocket · SIP · WebRTC
        ↓
Phone Agent 托管服务
        ↓
模型 · 短信 · 地图 · 电话线路 · 存储

未来 Call Skill 层：场景匹配 · 输入规范 · 对话策略 · 工具与结果规范
```

客户端采用 Kotlin、Jetpack Compose、AndroidX、MVVM、Coroutines 和 Flow。详细分层与边界见[终端架构](docs/ARCHITECTURE.md)。

## 快速开始

### 环境要求

- JDK 11
- Android Studio 或 Android SDK Command-line Tools
- Android SDK 33
- Android 8.0（API 26）及以上真机
- 可访问托管服务的网络环境

### 构建连接托管服务的调试 APK

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

APK 输出到 `app/build/outputs/apk/prod/debug/`，并归档到 `app/apks/`。调试签名仅适合开发测试，正式分发请配置自己的签名。

默认托管服务地址：

```text
https://chaken-ai.vvtech.tech/aiassistant-api/
```

详细配置和自定义兼容服务构建方式见[构建与配置](docs/BUILD_AND_CONFIGURATION.md)。

## 当前能力边界

| 已包含在开源仓库 | 不包含在开源仓库 |
| --- | --- |
| Kotlin / Jetpack Compose Android 客户端源码 | 后台源码、管理后台和数据库结构 |
| 客户端网络、任务、语音、SIP、WebRTC 与界面逻辑 | 后台部署脚本、生产配置和生产数据 |
| Android 单元测试和协议测试样例 | 模型、短信、SIP、地图、存储等服务端凭据 |
| 公司自有且已加固的 CHAKEN 可信通信 SDK | 未获公开再分发授权的商业 SDK 二进制 |
| 构建、架构、隐私和扩展路线文档 | 尚在规划中的 Call Skill SDK 与分发平台 |

托管服务与本仓库的 Apache-2.0 许可相互独立。服务可用性、账号开通、短信额度、电话资费、并发量、模型和区域能力以实际服务策略为准。更多说明见[后台服务边界](docs/BACKEND_SERVICE.md)和[常见问题](docs/FAQ.zh-CN.md)。

## SDK、权限与安全

- `app/libs/` 随源码提供公司自有且已加固的 CHAKEN 可信通信 SDK，以及经授权可公开分发的客户端参数。
- 未获公开再分发授权的身份认证等商业组件不随仓库提供；缺少这些组件不会阻止基础登录、任务、托管 AI 通话和记录功能。
- 应用会按功能申请麦克风、相机、联系人、电话、通话记录、定位、悬浮窗和安装更新等权限。
- 不要提交真实手机号、验证码、Token、模型 Key、SIP 密码、签名文件、生产日志、录音或身份材料。

详见[第三方组件说明](THIRD_PARTY_NOTICES.md)、[隐私与权限](docs/PRIVACY_AND_PERMISSIONS.md)和[安全策略](SECURITY.md)。

## 路线图

- **现在**：持续完善 Android 电话智能体终端、内置场景、实时翻译、记录和可信通信体验。
- **设计阶段**：Call Skill 生命周期、Manifest、输入槽位、结果协议、权限声明和兼容规则。
- **后续规划**：开发者 SDK、本地调试、模拟测试、示例 Skill 和社区分发机制。

路线图表示方向，不构成版本或日期承诺。查看[完整路线图](docs/ROADMAP.zh-CN.md)。

## 参与贡献

欢迎贡献 Android 功能、稳定性修复、测试、文档、翻译、场景建议，以及未来的 Call Skill 设计提案。提交前请阅读[贡献指南](CONTRIBUTING.md)，并至少执行：

```bash
./gradlew :app:compileProdDebugUnitTestKotlin :app:assembleProdDebug
```

问题定位前可先查看[已知问题](docs/KNOWN_ISSUES.md)。

## 许可证

本仓库中由著作权人提供的终端源码使用 [Apache License 2.0](LICENSE)。第三方库、图标、字体、托管服务和可选商业 SDK 适用各自许可与服务条款，参见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
