## Context

依据 v65 4c781e3ccfcd148c1f205921534907ee0c5aa864 的 QwenTaskAsrSocketClient、QwenTaskTtsApiClient 和后端 TaskVoiceAsr/TtsWebSocketHandler。后端按 provider 委托，App 只对接自有网关。Android ASR 为 16000/PCM16/mono、640 字节读取；TTS 声明 Pcm24k16BitMono。ASR stop 后允许一次非空 final，socket 空闲 90 秒关闭；正在录音时可以收到多个 final，不在基础门禁擅自合并或去重语句。

## Goals / Non-Goals

目标：可测试的协议、录音轮次、资源所有权、播放排空状态。非目标：完整 VoiceTurnCoordinator、语句拼接/发送策略、真实 WebSocket、原生采集/播放、页面、后台常听、登录或真实认证。

## Decisions

### 后端转写单次回退（2026-09-20）

固定v65 VoiceTaskAsrEventHandler/VoiceAsrWatchdogController/VoiceRuntimeLifecycleController及LiveSpeechTranscriptionSocketClient：主ASR错误或启动8秒未ready时，一次切到`/ws/assistant/realtime/transcription`；普通Closed不切，备用失败暂停，明确禁用平台SpeechRecognizer回退。DefaultUserId实际读取AccountIdentityProvider.accountId，不是demo-user。query携带当前账号、规范languageCode及可选旧voiceTaskId；Flutter新统一会话未持有该旧taskId时省略，不能拿sessionId冒充。后端BinaryWebSocketHandler在ready后接16k PCM16 mono，无start_capture/stop_capture/finish控制消息。iOS参考ddb996a的旧RTC→Dialog SDK不是同一协议，不迁移该架构；两端共享Dart回退，仅复用已有采集薄端口。

新增AsrRecognitionSession数据协议接口、RealtimeTranscriptionSession和FallbackVoiceInputSession。旧流先失效、旧采集cancel成功后才能创建备用会话；释放失败不抢占、不伪装空闲，仍能重试清理。按一次手势限制一次回退；取消/退出/切文字/账号改变/通话抑制和原生采集错误不重启。上层仍保持最多2秒收尾、60秒手势上限及单次提交；备用开始清未确认partial但保留已确认final，不重放旧PCM。普通TaskAsr独立协议10秒默认不变，生产工厂注入v65的8秒启动门限。回退切换使用本地类型事件，UI不透传远程错误正文。

微批≤3文件：协议接口与现有两类适配；备用会话/endpoint/测试；回退组合/事件/测试；工厂/输入控制器/接线测试；证据文档。仅共享Dart，不改原生、依赖、后端、SIP、数据库、TTS或真实账号。定向voice与直接页面调用测试、analyze、OpenSpec和回环WebSocket验证；不全量、不重复双端包、不自动开麦。真实备用服务启用、声音和路由列入集中人工验收，不因此归档4.3。

### 网络失败后的完整业务句恢复（2026-09-20）

固定v65 VoiceRecoverableTurnCoordinator、ConversationSubmitActionHandler与AgentStreamFailureRecoveryHandler：仅普通VOICE用户命令的传输失败冻结已提交文本/commandId，不把ASR partial、模型错误、文档、通话确认或活动单/多路失败变成可重放用户句。下一次用户显式输入（语音或同页键盘）先读取完整ledger；普通取消后更早/更晚的有效ASSISTANT_TURN_COMMITTED均算完成，但recovery_revision取消之后的旧回复不算。原命令已完成且重复原句只同步；新补充单独发送。未完成则按既有重叠规则合并并携带supersedesCommandId，用新的命令/幂等ID修订，临时用户气泡原位替换；不修改服务端事实。

新增domain/voice/conversation_turn_recovery.dart分离冻结/解析/计划，统一页Controller仅接异步门禁与提交；message store管理临时修订投影，submission复用已有wire字段。输入Controller按下时读恢复基句作为字幕前缀，取消不自动提交，关闭/历史恢复清理本页恢复状态。不新增自动重试、供应商或平台实现；iOS参考ddb996a仅找到supersedesCommandId模型字段，不据此猜测另一套恢复规则。

微批≤3手写文件：规格→规则/测试→提交/投影/Controller→输入provider/同页演练→集中验收。验证纯规则、正式Controller、输入和三宽页面、全量/analyze/OpenSpec/Web/Android构建。Mac SSH超时，本批无iOS新构建或设备授权操作。Controller原497行，新增恢复接线时将用户提交/恢复编排抽到ConversationSubmissionFlow，展示映射复用已有Projection/FailurePresentation，继续保持500行以内，不申请例外或削弱检查；不进行无关架构重构。

### 通话结果持久回复播报接续（2026-09-19）

固定v65 AgentStreamCommittedReplyNarrationCoordinator与TimelineSnapshotUiProjection：终态标记、持久ASSISTANT_TURN_COMMITTED及已应用消息投影关联，正文取白色消息同源；不朗读final.text代替。普通/批量按finishReason区分，身份优先attemptId/callId/batchId，事件和终态各保留128条去重。当前轮重置等待关系但保留去重；恢复历史/离页/后台取消不重播。缺失实时commit时允许已同步投影中对应终态锚点之后的最新结果回复。

新增domain/voice/committed_reply_narration.dart承担关联；ConversationSpeechController承接晚到结果与当前播放队列；ConversationController只转发已验证commit、已应用投影和deferred callId。单路通话暂停输出但保留本轮结果关系，正式provider在通话退出后触发检查；用户/后台取消则永久作废该轮。已有封口队列先实际排空再播晚到结果，不抢占前句。每微批≤3文件、手写≤500行；专项乱序/重复/恢复/晚到/失败与正式controller、Web同页合成回归，再全量/analyze/OpenSpec/三端构建。无真实外呼/声音/设备安装，不改变任务或接口契约，视觉后置。

### 普通回复正式播报接续（2026-09-19）

固定v65 AgentTtsBridge、VoiceDuplexPlaybackController、AgentStreamEventHandler/InteractiveResponsePolicy和MarkdownText：标点分句、超过80字符时按逗号分句、空闲首片800ms按delta重置；signal整段入队，final TEXT_REPLY整段+flush，保留原事件语义不新增文本相同去重。音色是AgentTtsBridge默认zh_male_taocheng_uranus_bigtts，不是外呼音色。清理发生在分句之后、请求之前；无正文日志。

新增纯规则speech_text_policy/speech_prompt_policy、领域ReplySpeechPlayback端口、data ConversationTtsStream（串行合成接同一PCM队列、不等上一句播放完才合成）、独立ConversationSpeechController。ConversationController仅转发当前已接收事件和生命周期；生产provider注入设备/网关，Web禁真实TTS。统一页宿主绑定状态、按下/后台/关闭及单路通话抑制，不更改任务状态或自动开启ASR。恢复历史不播报；通话结果需要持久事件/终态/投影三方关联，独立后续任务，不用final.text代替。

补充定点纠偏：SingleFlowNativeDemoScreen的onInputModeChange只设置本地SfInputMode；业务仍VOICE，不能把Flutter voiceMode（输入控件模式）当作播报开关。切键盘不取消已有TTS，键盘提交后的回复同样播报。VoiceManualControlHandler允许ttsPlaying期间按住并interruptCurrentStream，因此新共享输入打断入口在当前确有播报且非批量/通话时取消旧Agent流，恢复ready后才开始手势采集；单纯thinking仍不能强行发送新请求。初始方案中“切文字即停播”的推断已撤回，不作为规格或完成行为。

每个微批≤3文件、500行。新代码及既有conversation provider/voice host/preview按职责修改；分句、流式先合成后排空、取消晚到/失败、controller正式事件及三宽同页测试，analyze/全量/Web/Android/iOS构建。无真实网络TTS、声音、授权或设备安装。

### PCM输出与TTS播放接续（2026-09-19）

固定v65 AudioPlayer/PcmPlaybackPolicy/TtsAudioAttributes及iOS参考AIAssistantSpeechPlayer确认：TTS为24k PCM16 mono媒体播放，不使用翻译的通信音量。共享PcmOutput提供start/play/stop，play仅在实际消费后完成；DevicePcmOutput用独立outputId方法通道。Android独立队列非阻塞AudioTrack写入并轮询播放头确认，iOS AVAudioEngine/Float32转换及dataPlayedBack回调；停止/后台/中断先作废回调，再释放/恢复会话，不自动恢复，无权限申请。

共享PcmPlaybackQueue使用既有PlaybackLedger记账，限制待播字节和最多2秒原生在途，分块但不逐块创建播放器。complete只封口，全部实际消费后再stop并报告drained；取消/失败清空未提交队列，旧消费不得恢复，关闭失败不能归还租约。FocusedPcmOutput复用全局占用，TTS可被新录音中断，但不得抢占克隆/翻译等受保护采集。

TaskTtsPlayback组合现有TaskTtsSession与共享队列，收到音频才开始输出；保留v65 24k起始320ms静音保护与结束60ms填充。独立Web演练替换socket/output，不播放声音，验证complete与实际排空分离、取消和错误；最终生产对话分句桥、SDK回退和实际设备另列，不以本输出子项勾选完整4.3。AppAudio后续复用PCM端口时需独立通信会话/路由与merchant_audio_ready规则，不复用TTS媒体配置假装双工完成。

文件微批（每次≤3手写文件）：core/audio/pcm_output.dart、pcm_playback_queue.dart、focused_pcm_output.dart；conversation/data/voice/device_pcm_output.dart、task_tts_playback.dart；android的PcmOutputChannel.kt/MainActivity.kt；ios的PcmOutputChannel.swift/AppDelegate.swift/project.pbxproj；专项测试、voice_transport_preview及provider按职责分批。手写上限500行，新增无依赖；全量test/analyze/格式/OpenSpec及Web/Android/iOS构建，集中人工验证真实声音/尾音/中断/设备效果。此方案参考原实现但不复制其未区分实际播放的旧iOS默认completion语义。

### 正式按住输入接续与源代码纠偏（2026-09-18）

固定v65 VoiceManualControlHandler.onManualAsrRelease并不立即stop：manualAsrFinalizing最多2000ms继续采集，第一条有效final立即closeNow并提交；到期按ManualAsrTranscriptPolicy合并缓冲final/最新partial，再关闭并提交。VoiceAsrWatchdogController按住60000ms到期选择缓冲或更完整partial提交。PureVoiceStageVisuals按pointer down即触发、向上58dp取消，没有新增500ms长按或最小时长门禁。此前文档把底层release/stop等同手势松手不准确；本节和对应delta纠正，上层手势收尾不立即调用底层release。

新增ManualVoiceTranscript纯规则、VoiceInputSession端口、独立VoiceInputController（权限/计时/轮次/提交），通过conversation_voice_providers装配已有AsrCaptureSession与FocusedPcmCapture。正式Route/Composer复用VoiceHoldButton和状态绑定，切文字/关闭/后台作废当前轮，历史不自动录音；提交沿ConversationController.send且source=asr，不改既有voice业务channel/准入/联系人续接。权限只由用户按下后显式请求，上层请求期间若松手/取消则晚到授权不启动；Web普通入口明确不可用，合成演练替换端口复用同一控制器与页面。

本子批不以输入接线冒充完整语音：TTS输出与打断、旧SDK回退、网络恢复文本策略及双端真实设备仍后续，异常不自动提交不可信partial或假报识别成功。保留人工验收边界。每微批最多3文件、手写500行，测试覆盖虚拟时钟、指针取消、权限/关闭晚到与共享页面。

### PCM采集接续（2026-09-18）

新增纯Dart PcmCapture（start/read/stop）和DevicePcmCapture方法通道，每个实例只用一次、携带独立captureId。按需读取最多640字节16k/PCM16/mono，最多一个在途read；停止必须等待原生释放，旧id的stop不得停止新采集。Web明确不可用，自动验证注入合成端口，不主动请求权限。

Android独立PcmCaptureChannel用AudioRecord，沿固定v65优先VOICE_RECOGNITION、回退MIC、可用AEC/NS、不启用AGC；单工作队列用非阻塞read与短等待响应停止，不在UI线程等待录音read。iOS独立PcmCaptureChannel用AVAudioEngine/AVAudioConverter，参考固定ios_newUI2的转换实现，转16k PCM16 mono；缓冲有界且溢出明确失败。两端只检查已有麦克风授权，离开前台/系统中断停止，不自动恢复。

AsrCaptureSession组合现有TaskAsrSession、采集端口及共享AudioPlaybackFocus：收到ready后申请受保护租约、开始采集与顺序上行；松手先关上行/发送stop_capture，再等待硬件释放；final保留原协议。取消/失败关闭传输并停止硬件，停止失败保留租约供重试，不能假报空闲。生产统一页的语句合并/提交与TTS输出仍独立跟踪，不能以本子批完成替代完整语音。新增文件均不超过500行，微批≤3文件。

### 真实网关传输接续（2026-09-18）

新增data/voice下voice_socket.dart（连接契约）、voice_socket_io.dart（dart:io WebSocket）、voice_wire.dart（有界连接/取消与错误清洗）、task_voice_endpoint.dart、task_asr_session.dart、task_tts_session.dart。平台工厂以conditional import隔离Web；Web演练使用合成socket，不偷偷连接供应商。无需新依赖或原生平台代码。网关地址从可信API base保留context path拼接，HTTP→WS、HTTPS→WSS，不接受凭据/query/fragment，不添加v65未发送的账号header。

每次ASR捕获或TTS合成使用独立连接，不将旧socket事件重标新轮。ASR ready后发送start_capture/open_listening，放行PCM16/16k单声道数据，松手发送stop_capture并允许一次late final；取消/结束发送finish并关闭，松手90秒空闲关闭。传输握手/ready增加可注入10秒技术边界防永久等待，不改变业务重试或新增自动重连。关闭期间及连接晚到不得发新控制消息/音频。

TTS保留v65 ready后synthesize、24k PCM、首音5秒、完成trim(text).length×350ms且夹在15–60秒；24000字节首缓存/5760后续块，complete清空尾块但不宣称设备drained。有音频的完成超时按v65软完成并显式标记，首音超时失败。取消发送cancel，旧帧/重复ready/complete无效。限制单条网关帧与单轮字节资源上限，超限明确失败，不静默丢音频；后续设备消费必须继续使用PlaybackLedger，stream送出不代表播放完成。

每微批≤3文件，保持500行。先实现共享端口/两个session与fake-time测试，再用回环HttpServer/WebSocket验证真实原生握手/控制/二进制/关闭；隔离Web演练复用正式会话类。无线上ASR/TTS、身份、录音、账号操作或短信；生产PCM端口、音频保护/排空与统一页装配、真实设备延迟及路由仍另列，不能因本批编译完成而勾选全部语音。

- codec 只编解码现有控制字段；未知类型忽略，损坏消息显式抛 FormatException；错误不回显原始 payload。原始二进制音频不经 JSON/base64。
- CaptureTurnGate 使用不可伪造对象身份作为轮次 token。ready 前不放行 PCM；release 后仅放行一次非空 final；cancel、过期或新轮令旧 token 失效。release 前收到的 final 不推断用户已松手。
- 线协议没有可靠的客户端轮次回显，不能把复用 socket 的每条消息简单标成“当前轮”。后续 transport 必须为新轮提供独立连接上下文，或先证明能可靠归属；本批只验证绑定正确 token 的门禁，不声称已经解决传输层串轮。
- AudioResourceCoordinator 独占租约，旧 token 不可释放新 owner；不自动抢占，交接必须等原适配器实际停止才释放。
- PlaybackLedger 只记已入队尚未播放的字节数，不持有音频。有界容量由适配器注入，满了 backpressure、不丢音频；complete 封口后等待逐块消费至零才 drained。设备回调不能用“已复制到原生缓冲”冒充实际播放。
- 状态对象均同步纯 Dart，无插件、时钟、网络、日志正文。UI 尚未接入，不改变 B0 页面。

## Risks / Trade-offs

- 离线正确不等于硬件正确 → 后续 B1 必须双端采集、播放、路由、中断验证。
- socket 复用存在归属歧义 → 后续 transport 先采用独立连接边界再评估延迟；不要求后端增字段。
- 本批不设置 late-final 新时限 → expire 由后续生命周期按 v65 空闲关闭/退出规则调用。
- 缓冲容量不是随意“最优参数” → 测试注入小容量，真实容量由平台试验确定。

## Migration Plan

新增未接入 UI 的基础类，回滚本次提交即可。无数据、API 或依赖迁移。按每批最多三个文件：协议事件/codec/测试；CaptureTurnGate/测试；音频租约/测试；PlaybackLedger/测试；最后架构断言和记录。500 行上限。

## Open Questions

技术待验证：双端原生 PCM、真实 provider 格式、首音/完成超时接入、WebSocket 归属和连接延迟。无需重新向产品询问已确认的按住说话交互。
