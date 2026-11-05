# 当前手机任务播报与服务路由排查

## 核验范围

2026-10-10手机已装实现提交114f8065对应的v45/1.0.51-foundation云端包。用户反馈播报失败，随后反馈任务回答时又恢复。读取当前进程logcat及220开发服务器09时段Agent/SDK/Runtime日志；没有自动进入任务、发消息、拨号、重启或改后端/数据库。普通logcat没有本次TTS阶段诊断，不能用没有异常输出证明客户端正常。

## 当前接口分工

全部使用chakenai-dev.vvtech.tech，HTTP为HTTPS、语音为WSS。以下路径包括网关前缀；sessionId/callId等只是占位符。

| 功能 | 方法及实际路径 | 服务与依据 |
| --- | --- | --- |
| 开场/回复/结果播报 | WSS /aiassistant-runtime/ws/assistant/task-voice/tts | Runtime；conversation_speech_providers、TaskVoiceEndpoint、TaskTtsSession |
| 按住说话识别 | WSS /aiassistant-runtime/ws/assistant/task-voice/asr?languageCode=zh-CN | Runtime；conversation_voice_providers、TaskAsrSession |
| 识别兼容回退 | WSS /aiassistant-runtime/ws/assistant/realtime/transcription?userId={accountId}&languageCode=zh-CN | Runtime；FallbackVoiceInputSession，仅主识别失败时使用 |
| 任务对话与编排 | POST /aiassistant-api/api/agent/chat/stream，SSE响应 | Agent；AccountApi.openAgentStream，DioAgentGateway |
| 确认回答分类 | POST /aiassistant-api/api/agent/call-confirmation/reply | Agent；ApiCallConfirmationReplyRepository；有效部署是否齐全仍按既有后端交接待验 |
| 确认后补充记录 | POST /aiassistant-api/api/agent/conversations/{sessionId}/call-confirmation-supplements | Agent；ApiConfirmationSupplementRepository |
| 历史与恢复 | GET /aiassistant-api/api/agent/conversations/{sessionId}及其/timeline | Agent；现有history/timeline Repository |
| 停止编排/批量停止 | POST /aiassistant-api/api/agent/conversations/{sessionId}/stop或/batch/stop | Agent；ApiConversationStopRepository |
| 通话状态/挂断 | POST /aiassistant-api/api/assistant/realtime/call/session/status或/hangup | Agent；ApiCallSessionRepository |
| 任务列表 | GET /aiassistant-sdk-api/api/assistant/task-list/page | SDK；offset/limit/userId，默认15条 |
| 普通任务详情 | GET /aiassistant-sdk-api/api/task/detail/{taskId} | SDK；对话类详情另读Agent会话/timeline |
| 监听票据 | POST /aiassistant-sdk-api/api/agent-calls/monitor/token | SDK；最新独立App契约，部署差异另见BACKEND_TASK_OUTBOUND_CONTRACTS_20261010.md |
| 监听音频 | WSS /aiassistant-runtime/ws/assistant/call/monitor?ticket={ticket} | Runtime；CallMonitorStream，不与任务TTS共用音频会话 |
| 单路/批次模型评价 | GET /aiassistant-sdk-api/api/agent-calls/{callId}/evaluation或/batches/{batchId}/evaluation | SDK；ApiCallEvaluationRepository |

ServiceRoutes按api/agent/、api/agent-artifacts/、api/assistant/realtime/call/等归Agent，其余现有HTTP接口归SDK。Runtime基地址由独立RUNTIME_API_BASE_URL配置，不经过上述HTTP分类器。任务语音WebSocket通过SignedVoiceSocket携带C1握手头、Bearer与X-Account-Id，账号切换隔离；普通HTTP由AccountApi统一路由/签名/受保护接口鉴权，SSE复用同一路径。

TTS连接等待ready后发synthesize文本帧，收24kHz/16bit/单声道PCM并在设备播放，complete结束；ASR上行16kHz/16bit/单声道PCM，partial/final文字进入既有输入规则，用户提交文字后才发编排SSE。手机不直连Qwen/Doubao或编排大模型。普通播报不带preview用途，Runtime读取TASK_TTS及账号音色选择，客户端兼容speaker字段不应覆盖服务端有效选择。

## 已确认日志与结论边界

- Agent在09:17–09:19收到多轮chat/stream，保存了询问、候选/确认等事件；09:20:23记录semantic_outcome_persisted、call_finished、task_completed。这里只核对事件类型，没有输出正文、联系人或会话标识。Agent结果存在不等于TTS播放成功。
- Runtime09:16–09:19多数Upgrade记录HTTP101/securityResult1。09:19:49.044、09:19:50.668、09:19:51.858、09:19:53.001为HTTP503，拒绝原因sdk_admission_unavailable；09:20:24.844恢复101。
- Runtime公开日志route统一脱敏为/ws/assistant/{channel}，不能据此区分TTS、ASR、监听，也不能把四次503直接归到当前手机的播报失败。
- 对照Java origin/v71的TaskVoiceSdkAdmissionClient及RuntimeWebSocketUpgradeAuthHandler，此原因来自Runtime向SDK内部POST /internal/v1/task-voice/admission的准入链：非200/响应校验失败、内部调用异常或SDK准入存储不可用均可能归为此原因。需后端按原始reqid/traceId进一步核对SDK私有控制口、TLS/实例及Redis证据；本轮没有证据将其具体归为重启或Redis故障。
- 同时段SDK另有INBOX/IllegalStateException及一条app_key_invalid，但没有与本次TTS逐次关联，不能拿这些独立异常替代根因。
- HTTP101只证明WebSocket升级，不证明供应商首PCM或设备播放成功。本次没有读到逐次TTS诊断，因此尚未确认用户这次播报失败属于客户端还是后端。

## 最小后续核验

现有TaskTtsSession首音频计时5秒、连接器超时10秒；这是源码规则，不是已确认超时原因。应以手机voiceMedia诊断区分connectFailed、firstAudioTimeout、providerError和pcmOutput/deviceFailure，再关联服务端时间和请求标识。连接失败检查握手与准入；ready后首音频超时检查供应商/首包耗时；已收PCM而播放失败再检查平台输出。没有证据前不放宽超时、添加重试或修改音色。

手机诊断按账号加密存储，logcat没有结构化TTS事件；Android/proc网络读取被权限限制，开发VM接口要求认证，未绕过。当前没有本地导出按钮，前次导出说明已纠正；用户明确选择暂不上传、先看接口及已有服务器证据，因此停止上传相关调查，不代用户点击或传输。本次只报告已证实的准入故障及接口分工，TTS个案根因保留未确认，不宣称修复或重新打包。
