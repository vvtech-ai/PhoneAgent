# 终端架构 / Client Architecture

## 系统边界 / System boundary

```text
┌──────────────────────────────────────────┐
│ Open-source Android client               │
│ UI → ViewModel/State → Domain → Data     │
│ Android APIs · SIP · WebRTC · Audio      │
│ CHAKEN trusted-call integration          │
└─────────────────────┬────────────────────┘
                      │ HTTPS / SSE / WebSocket / media
┌─────────────────────▼────────────────────┐
│ Phone Agent hosted service               │
│ Authentication · task orchestration      │
│ call events · history · OTA metadata     │
└─────────────────────┬────────────────────┘
                      │ provider APIs
┌─────────────────────▼────────────────────┐
│ Model · SMS · map · SIP · storage        │
└──────────────────────────────────────────┘

Future Call Skill layer (planned, not released):
matching · input schema · confirmation · dialogue policy · tools · result schema
```

服务端源码及供应商凭据不属于终端开源边界。客户端只保存用户会话、界面偏好和完成功能所需的本地缓存。Call Skill 层是规划方向，当前仓库没有可执行的 Skill 运行时或 SDK。

Backend source and provider credentials are outside the open client boundary. The app stores only user session data, UI preferences, and local cache required for client features. The Call Skill layer is planned; this repository does not currently contain an executable Skill runtime or SDK.

## Android 分层 / Android layers

- **UI Layer**：Compose 页面、组件、导航、`UiState`、`UiAction`、`UiEffect`。
- **Domain Layer**：任务、号码、联系人、语音、通话、翻译和回执策略。
- **Data Layer**：Retrofit、SSE、WebSocket、Repository、本地缓存、联系人和文件日志。
- **Integration Layer**：Android 平台 API、SIP、WebRTC、音频、内置 CHAKEN 可信通信 SDK，以及通过反射隔离的可选商业身份认证 SDK。

- **UI Layer**: Compose screens, components, navigation, `UiState`, `UiAction`, and `UiEffect`.
- **Domain Layer**: task, number, contact, voice, call, translation, and receipt policies.
- **Data Layer**: Retrofit, SSE, WebSocket, repositories, local cache, contacts, and file logging.
- **Integration Layer**: Android APIs, SIP, WebRTC, audio, the bundled CHAKEN trusted-call SDK, and reflection-isolated optional commercial identity SDKs.

## 状态与协议 / State and protocols

跨层状态应由单一事实源驱动。长连接和通话状态必须能够通过 `sessionId`、`taskId` 或 `callId` 关联。客户端与托管服务之间的能力以运行时响应为准，界面不应假定所有账号、模型、区域或线路都支持相同功能。

Cross-layer state should have one source of truth. Long-lived connection and call state must be correlatable through `sessionId`, `taskId`, or `callId`. Hosted capabilities are determined at runtime; the UI must not assume identical model, region, account, or telephony support.

## 安全约束 / Security constraints

- 模型 Key、短信凭据、SIP 密码、地图 Key 和数据库凭据不得进入客户端。
- 日志不得包含 Token、密码、完整号码、录音或不必要的敏感内容。
- 真实外呼、录音、批量或多路通话需要明确的用户确认、权限和合规控制。
- 任何未来 Call Skill 都必须声明权限、限制工具范围，并提供可验证的输入和结果。

- Model keys, SMS credentials, SIP passwords, map keys, and database credentials must remain server-side.
- Logs must exclude tokens, passwords, full phone numbers, recordings, and unnecessary sensitive content.
- Real calls, recordings, bulk calls, and concurrent calls require explicit confirmation, permissions, and compliance controls.
- Future Call Skills must declare permissions, constrain tools, and provide verifiable inputs and results.
