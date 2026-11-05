# ASR/TTS 网关传输：实现与集中验收

日期：2026-09-18。此批接通真实网络端口和共享会话逻辑，**不是完整按住说话或播报功能**。没有请求线上ASR/TTS、录音、播放或重发验证码。

后续输出增量（2026-09-19）：双端PCM薄输出、共享有界播放/实际排空/抢占及TaskTtsPlayback组合已实现，见[PCM_OUTPUT_VALIDATION.md](PCM_OUTPUT_VALIDATION.md)。当前生产分句桥和完整播报交互仍待接；下方“PCM输出待实施”仅为原传输批次历史状态。

后续输入接线与纠偏：[VOICE_INPUT_VALIDATION.md](VOICE_INPUT_VALIDATION.md)记录正式统一页的按下/上滑/收尾/切文字与合成验证。本文底层“松手”应理解为显式release/stop，不代表v65手势立即关闭采集；正式手势最多2秒继续收尾，TTS/设备验收仍未完成。

后续 PCM 增量：双端采集薄端口及共享 ready/读取/松手/取消/音频占用已实现并编译验证，Web 演练现在同时替换采集源和 socket，复用正式采集编排。22 新增、1819 全量和三端构建通过，见 [PCM_CAPTURE_VALIDATION.md](PCM_CAPTURE_VALIDATION.md)。下文原传输批次的“采集待实施”由该增量更新；生产页面提交、PCM 输出和真实声音仍未完成/验收。

## 固定来源

- v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864`：`QwenTaskAsrSocketClient.kt`、`QwenTaskTtsApiClient.kt`、`VoiceLanguage.kt`。后端TaskVoiceAsr/TtsWebSocketHandler按配置委托Qwen/Doubao，App只接自有网关。
- iOS `ddb996a28f98559ea7d8b76ca9d7712703dedbc1`：`Core/Voice/AIAssistantSpeechPlayer.m`，核对网关路径、取消/首音和合成完成与播放队列分离；不复制其原生业务架构。
- 前一协议批已明确：线协议没有可靠客户端轮次回显，Flutter先以独立连接隔离每次capture/synthesis，不把旧socket回调标成新轮。连接延迟须真机实测，不宣称独立连接性能与旧复用相同。

## 实现位置

| 文件（lib/features/conversation下） | 职责 |
| --- | --- |
| data/voice/task_voice_endpoint.dart | 从可信HTTP API base转换WS/WSS，保留context path；语言归一zh-CN/en-US/ja-JP，拒绝userInfo/query/fragment |
| data/voice/voice_socket.dart、voice_socket_io.dart及conditional factory | 同一Dart IO实现供Android/iOS使用，Web真实端口明确不可用；没有新依赖、原生插件或供应商直连 |
| data/voice/voice_wire.dart | 一次连接、连接晚到关闭、先作废再并行取消订阅/关socket；错误只保留本地类别，不记录地址、文本、PCM或服务原文 |
| data/voice/task_asr_session.dart | ready后start_capture/open_listening，16k PCM16单声道帧门禁，松手stop_capture、单次late final、90秒空闲finish关闭 |
| data/voice/task_tts_session.dart | ready后synthesize，24k PCM、首音5秒、完成字数×350ms夹15–60秒、24000首缓存/5760后续块/尾块、cancel |
| domain/voice/voice_gateway_event.dart | 音频块、合成完成（含softTimeout）、清洗后的错误和关闭原因；不等于播放状态 |

ASR支持AudioRecord不足640字节的短帧，但必须是完整PCM16样本；ready前/松手后/关闭后拒绝发送。录音期间允许多个final，松手后最多一次非空final；不在transport拼接文本或自动提交Agent请求。连接/ready采用可注入10秒技术等待边界（不是v65既有ASR业务时限），失败不自动重连重放。IO关闭最多等待2秒后关闭本次HttpClient；旧事件始终已被作废。

TTS先收到少量音频但未达首缓存时不提前输出；complete输出尾块后封口。有字节的完成超时保留v65软完成，事件显式标记；无首音失败，不能伪造播放完成。单帧最多1MiB（二进制字节/文本字符检查），单轮TTS最多16MiB，超限失败；这些是客户端资源保护上限，不是服务端能力声明。

**背压与播放边界**：socket.send成功只表示已交给本地WebSocket，不是服务端确认。输出stream不是原生播放队列；后续PCM输出必须用已有PlaybackLedger限制待播放字节、处理背压并等实际消费回调，不得把stream收到块或complete当drained。此批未验证弱网下原生socket内部发送缓冲，也不声称已经完成设备层背压。

## 自动与浏览器证据

- 新增22项：ASR/地址9、TTS6、真实回环3、页面/并发启动4；全量1797项通过，analyze无问题，832个Dart文件格式检查无修改。
- 回环测试实际启动127.0.0.1随机端口HttpServer并升级WebSocket，验证握手/路径/语言、控制消息、PCM二进制、松手final、finish、TTS speaker/尾块和拒绝连接映射。没有将fake socket单测冒充真实网络。
- Web、Android Debug、Mac iOS Debug无签名构建通过；没有新安装、权限请求或修改Mac保留解锁会话。
- 开发者入口“打开语音网关链路演练（MOCK）”；独立启动：`flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8109 -t tool/previews/voice_transport_preview.dart`。
- 演练使用正式TaskAsrSession/TaskTtsSession，只有socket在内存里响应；页面明确MOCK。浏览器确认ready前累计0字节→ready后640→松手final→取消finish；TTS输出24000+2字节，显示“合成完成，不代表播放排空”。320/390/430三宽Widget连续操作通过。

## 未完成与后续集中人工步骤

1. **仍须实施**：PCM输出双端薄端口，生产会话provider、按住/取消/切文字/ASR分段提交策略、TTS Markdown清理及音色选择、实际播放排空、单路监听/实时翻译。PCM采集及其共享占用已由后续4.3a实现，见页首增量，但尚未接生产统一页。现有文字主流程未改，语音占位不能视为已交付。
2. 正式接线后以现有登录测试账号分别在Android/iOS按住说话、松手、滑动取消、快速新轮、切文字、退出/任务恢复。预期旧轮不迟到提交，取消不自动重录/重连；录音期间多段和松手final均按v65业务编排处理。
3. 同意麦克风后测试中文/英语/日语、短按未ready、网络拒绝/ready超时/断网。记录平台、操作时间、连接本地标识及错误类别；不记录识别正文、PCM、供应商响应或凭据。没有录音授权前不要自动触发。
4. TTS测试短句尾块、长句/完成超时、首音超时、用户打断及音色；核实实际24k格式、声音无截尾、complete后剩余队列排空再退播放状态。独立连接首音延迟需量测。
5. 接后台/系统通话/耳机/蓝牙、与克隆/录音/翻译交叉占用；需观察实际声音/麦克风指示器，不能由本批回环或无签名构建证明。所有人工步骤待真实端口装配后集中执行。
