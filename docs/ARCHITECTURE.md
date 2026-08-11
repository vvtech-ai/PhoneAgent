# 终端架构 / Client Architecture

## 边界 / Boundary

```text
Android UI
  -> ViewModel / State / Coordinator
  -> Repository / API / SSE / WebSocket
  -> Hosted Phone Agent backend
  -> Model, SMS, map, SIP and storage providers
```

服务端及供应商凭据不属于终端代码。客户端只保存用户会话、界面偏好和完成功能所需的本地缓存。

Backend and provider credentials are outside the client boundary. The app stores only user session data, UI preferences, and local cache required for client features.

## Android 分层 / Android layers

- UI Layer：Compose 页面、组件、导航、`UiState`、`UiAction`、`UiEffect`。
- Domain Layer：任务、号码、联系人、语音、通话和回执策略。
- Data Layer：Retrofit、SSE、WebSocket、Repository、本地缓存、联系人和文件日志。
- Integration Layer：Android 平台 API、SIP/WebRTC/音频，以及通过反射隔离的可选商业 SDK。

- UI Layer: Compose screens, components, navigation, `UiState`, `UiAction`, and `UiEffect`.
- Domain Layer: task, number, contact, voice, call, and receipt policies.
- Data Layer: Retrofit, SSE, WebSocket, repositories, local cache, contacts, and file logging.
- Integration Layer: Android APIs, SIP/WebRTC/audio, and reflection-isolated optional commercial SDKs.

跨层状态应由单一事实源驱动。长连接和通话状态必须能通过 `sessionId`、`taskId` 或 `callId` 关联，日志不得包含 Token、密码或完整敏感内容。

Cross-layer state should have one source of truth. Long-lived connection and call state must be correlatable through `sessionId`, `taskId`, or `callId`, while logs must exclude tokens, passwords, and full sensitive content.
