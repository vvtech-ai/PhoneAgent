# PhoneAgent · 电话智能体，你的语音分身

**面向真实电话任务的开源智能 Agent。**

用语音或文字描述预约、通知、事务协调或跨语言沟通需求。PhoneAgent 会协助补齐关键信息，在你确认后执行受支持的电话流程，并把通话状态、转写和任务结果带回终端。

[查看源码](.) · [快速构建](#快速开始) · [申请邀请码](https://chaken.ai)

> PhoneAgent 客户端源码公开，可自由查看、构建和参与贡献。App 当前处于受控测试阶段，需要使用邀请码激活。

![PhoneAgent 首页](docs/images/home.png)

## 用 AI 完成一项电话任务

```text
说出或输入需求
  → 补齐时间、地点、联系人等信息
  → 确认通话对象和任务内容
  → 执行受支持的电话流程
  → 回看状态、转写和任务结果
```

PhoneAgent 聚焦真实电话事务：

- 与普通聊天助手相比，它会把需求带入确认、通话和结果回传流程；
- 与通用 Agent 产品相比，它专注 AI 电话任务和实时翻译。

## 核心能力

- **语音或文字创建任务**：直接描述想要完成的电话事务。
- **关键信息补齐**：整理时间、地点、联系人、号码、人数和偏好。
- **执行前确认**：拨号前展示通话对象、关键内容和执行范围。
- **Agent 电话任务流程**：理解目标、补齐信息、请求确认，并与托管服务协同完成受支持的电话任务。
- **可切换语音模型**：根据电话场景和使用偏好，选择托管服务当前开放的语音模型，发挥不同模型在实时语音对话、表达和跨语言沟通中的能力。
- **实时翻译**：在支持的模型和地区展示双方转写与译文。
- **联系人辅助**：获得授权后读取联系人，也可以手工输入号码。
- **结果回看**：查看任务状态、通话记录、转写和任务结果。

## 典型场景

| 场景 | PhoneAgent 如何协助 | 当前状态 |
| --- | --- | --- |
| 餐厅预订 | 整理时间、人数、地点和偏好，确认后进入电话流程 | 已内置入口 |
| 会议邀请 | 整理联系人和通知内容，回收通话结果 | 已内置入口 |
| 实时翻译 | 发起翻译电话，显示双方转写和译文 | 已支持 |
| 通用电话任务 | 用语音或文字描述事务，补齐信息后执行 | App 内未开放 |
| 社区 Call Skill | 为预约、售后、物流等场景设计可复用流程 | 规划中，SDK 尚未发布 |

具体可用能力受账号、模型、线路、地区和托管服务运行状态影响。

### Agent 与语音模型分工

PhoneAgent 将电话任务能力与语音模型分开：Agent 负责理解和完成任务，语音模型负责通话中的实时语音理解与表达。用户可以切换托管服务当前开放的语音模型，发挥不同模型的能力；模型切换将在下次通话时生效。

| Agent | 语音模型 |
| --- | --- |
| 理解用户要完成什么任务 | 处理通话中的语音理解与生成 |
| 补齐时间、地点等任务必要信息 | 影响语音交互、响应和表达效果 |
| 请求用户确认任务 | 支撑实时对话或翻译 |
| 编排电话流程并处理异常 | 提供音色、声音克隆能力 |
| 汇总状态、转写和任务回执 | 执行 Agent 确定的任务目标和通话要求 |

## 产品体验

| 创建任务 | AI 通话 |
| --- | --- |
| ![创建任务](docs/images/task-text.png) | ![AI 通话](docs/images/dialer.png) |

| 任务回执 | 可切换语音模型 |
| --- | --- |
| ![任务回执](docs/images/call-history.png) | ![可切换语音模型](docs/images/voice-settings.png) |

[查看完整产品导览](docs/PROJECT_INTRODUCTION.zh-CN.md)

## 快速开始

### 环境要求

- JDK 11
- Android Studio 或 Android SDK Command-line Tools
- Android SDK 33
- Android 8.0（API 26）及以上真机

### 构建调试 APK

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

请先在 `local.properties` 中填写 Android SDK 路径。构建产物位于：

```text
app/build/outputs/apk/prod/debug/
```

详细配置请查看[构建与配置](docs/BUILD_AND_CONFIGURATION.md)。

## 申请邀请码

App 当前需要邀请码激活。邀请码可用于体验已经接入的语音模型、SIP 通信及 PhoneAgent 电话任务流程。前往 PhoneAgent 官网，只需填写邮箱即可加入申请名单：

[填写邮箱，申请邀请码](https://chaken.ai)

我们会根据服务承载能力分批发送邀请码。请留意申请邮箱中的通知。

> 官方不会出售邀请码，请勿通过第三方购买。

## 一起验证真实电话场景

除邀请码申请外，PhoneAgent 的场景征集、活动、讨论和成果均在开源社区进行。

### 电话场景征集：提交 Call Skill 设计

PhoneAgent 希望把预约、通知、售后、物流和跨语言沟通等场景组织成可复用的 Call Skill。欢迎把你最想交给 AI 的一通电话整理成 Call Skill 设计，发送到指定邮箱。优秀提案有机会获得 PhoneAgent 邀请码。

一个 Call Skill 计划描述：

- 匹配哪些用户需求；
- 需要收集和确认哪些信息；
- 通话中遵循什么策略；
- 可以调用哪些工具；
- 如何处理拒绝、无应答和异常；
- 如何判断任务是否完成；
- 返回什么结构化结果；
- 需要哪些权限和安全约束。

投稿建议包含：场景与目标用户、必要输入、用户确认点、通话策略、拒绝与无应答处理、完成标准、结果格式、权限与合规风险，以及测试用例。

> **Call Skill SDK、运行时和分发平台尚未发布。** 当前征集的是场景设计提案，不是可运行的 Skill 包。

投稿邮箱待公布 · [了解 Call Skill 愿景](docs/CALL_SKILLS.zh-CN.md) · [查看路线图](docs/ROADMAP.zh-CN.md)

## 开源范围

| 本仓库包含 | 本仓库不包含 |
| --- | --- |
| Kotlin / Jetpack Compose Android 客户端源码 | 后台源码、管理后台和数据库结构 |
| 任务、网络、语音、SIP、WebRTC 和界面逻辑 | 后台部署脚本、生产配置和生产数据 |
| Android 测试样例及项目文档 | 模型、短信、SIP、地图等服务端凭据 |
| 获授权公开分发的 CHAKEN 可信通信 SDK | 未获公开再分发授权的商业 SDK |
| Call Skill 愿景和社区提案入口 | Call Skill SDK、运行时和分发平台 |

客户端默认连接 PhoneAgent 托管服务。开发者可以接入自行实现的兼容服务，但需要独立实现客户端使用的认证、任务、通话、事件和记录契约。

[了解后台服务边界](docs/BACKEND_SERVICE.md) · [查看终端架构](docs/ARCHITECTURE.html)

![PhoneAgent 客户端与托管服务架构](docs/images/architecture.png)

## 负责任地使用与参与贡献

真实外呼、录音和翻译应遵守所在地法律、运营商规则及服务条款。请勿在 Issue、日志或测试材料中提交真实号码、验证码、Token、录音、转写或身份材料，也不得将 PhoneAgent 用于骚扰、垃圾营销、欺骗或未经授权的身份模拟。

欢迎贡献客户端改进、Bug 修复、测试、文档和 Call Skill 场景提案。开始前请阅读[贡献指南](CONTRIBUTING.md)，并关注后续公开的 Good First Issues。

[隐私与权限](docs/PRIVACY_AND_PERMISSIONS.md) · [安全策略](SECURITY.md) · [已知问题](docs/KNOWN_ISSUES.md)

## 许可证

本仓库中由著作权人提供的终端源码采用 [Apache License 2.0](LICENSE)。第三方组件、托管服务和可选商业 SDK 适用各自许可与服务条款，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
