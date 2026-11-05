# B1 第一批：语音协议与生命周期基础

## 最新接续：2026-09-18

真实网关传输已实现：独立连接ASR/TTS、取消晚到隔离、ready/首音/完成超时、TTS预缓冲及软完成、IO WebSocket与Web隔离工厂；22新增/1797全量和三端构建、8109浏览器通过。见[VOICE_TRANSPORT_VALIDATION.md](VOICE_TRANSPORT_VALIDATION.md)。下方第一批的“真实WebSocket尚未实现”由本接续更新；PCM采集/输出、生产语音编排与真机仍未完成，不能据此关闭B1。

日期：2026-09-16。OpenSpec：voice-protocol-foundation。此批是可复用的纯 Dart 基础，不是完整语音功能；UI 仍为 B0 工程页。

## 来源与实现映射

行为源码固定为 AIAssistant 的 4c781e3ccfcd148c1f205921534907ee0c5aa864，不参考当前重构分支行为。

| 依据/约束 | 本批实现 | 验证 |
| --- | --- | --- |
| QwenTaskAsrSocketClient 的 ready、start_capture/open_listening、stop_capture、finish、partial/final | TaskVoiceCodec、VoiceGatewayEvent | 8 项协议测试（包含 TTS） |
| Android ASR 16000/PCM16/mono、FRAME_BYTES=640；QwenTaskTtsApiClient 声明 Pcm24k16BitMono | 独立格式常量 | 不用 ASR 采样率推断 TTS；真实部署格式仍需验证 |
| stop 后一次非空 late final、取消后失效、ready 前不录音 | CaptureTurnGate | 8 项时序测试 |
| 新架构的 App 级独占音频租约 | AudioResourceCoordinator | 3 项所有权测试 |
| 合成结束不等于播放排空，有界缓冲 | PlaybackLedger | 9 项记账与取消测试 |
| 领域逻辑不依赖 Flutter/设备/网络 | architecture_test | 新增依赖边界检查 |

旧客户端路径：android/app/src/main/java/com/vvtech/aiassistant/features/assistant/speech/qwen/。后端路径：backend/src/main/java/com/example/aiassistant/backend/assistant/ws/TaskVoiceAsrWebSocketHandler.java、TaskVoiceTtsWebSocketHandler.java；两者按配置委托 Qwen/Doubao，不在 Flutter 新增供应商直连。

## 状态边界

- CaptureTurnGate 是事件准入策略，不是最终 VoiceTurnCoordinator。录音期间多个 final 仍可通过；语句拼接、修订和发送规则留到统一页编排，不能擅自变成“一次按住只接一次 final”。
- release 前未 ready：结束该轮，晚到 ready 不再启动采集。release 后停止 PCM/partial，接受一次非空本轮 final；cancel/expire/新轮使旧结果无效。
- 轮次 token 按对象身份校验，即使数值 generation 相同，不同实例的 token 也不互通。
- PlaybackLedger 不保存音频，只持有块消费凭据和字节计数。重复、外来、旧轮消费回调无效。容量不足返回 backpressure；超大块必须拆分，不能无限等待或静默丢帧。
- complete 封口，有剩余数据则 draining，实际消费完才 drained；临时空缓冲不等于 complete。取消清理记账，但调用方还必须停止原生播放器后才能交接资源。

## 已执行验证

Windows，Flutter 3.32.0 / Dart 3.8.0，执行 scripts/verify.ps1：

- OpenSpec 6/6 通过。
- 依赖锁校验通过，无新依赖或升级。
- 16 个 Dart 文件格式检查通过。
- flutter analyze：No issues found。
- flutter test：43/43 通过（原 14 项 + 新增 28 项语音/音频测试 + 1 项架构检查）。
- flutter build apk --debug：成功。
- 新增运行源码最大 96 行；没有放宽或触发 500 行例外。

所有输入均为根据源码编写的 synthetic fixtures；没有录音、真实接口访问、账号数据或生产凭据。本批未修改平台宿主/依赖/UI，未重新安装 Android/iOS，也未重复 iOS 构建，不将 B0 真机证据冒充 B1 媒体验证。

## 下一批必须解决的技术项

1. WebSocket transport、连接 ready、首音/完成超时、取消清理与错误映射。
2. 当前线协议没有可靠的客户端轮次回显。后续 transport 必须将独立连接上下文绑定 token，不能把复用 socket 的所有事件重标当前轮。基础单测不会掩盖这一缺口；独立连接的延迟也须实测。
3. PcmCapturePort/PcmOutputPort 真正平台实现及异步编排；AudioSession/焦点、路由、中断、前后台、蓝牙验证。
4. 原生 playback 回调必须证明实际消费，不以入队完成充当 drain。容量、分块、预缓冲参数需设备试验。
5. 录音期间 ASR 分段、松手提交、TTS 打断的完整业务规则，仍以统一页现有代码为准。
6. Android 和 iOS 的真实媒体测试通过后才能关闭 B1；登录/首页另按固定 HTML 设计契约实现。

## 交付范围

本批仅提交协议/策略/测试/OpenSpec 与记录。沿 codex/flutter-foundation 推送到已配置 origin；提交与远端结果见 Git 历史。未取得用户验收，不归档 change。不关闭或重建已解锁的 Mac 共享会话。
