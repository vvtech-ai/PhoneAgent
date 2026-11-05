## Context

### 2026-10-16 实时字幕跟随

按用户指定核对旧Android origin/test/v66.0.3 a0bedb12 的 android/app/src/main/java/com/vvtech/aiassistant/features/assistant/FinalAiCallPage.kt:96：LaunchedEffect(transcriptCards) 在展示卡片变化时 animateScrollToItem(lastIndex)。Flutter沿用该触发与平滑归尾语义，实际显示行变化后启动短动画；可变高度懒列表继续核对最终滚动范围，用户拖动或页面销毁中止旧跟随。

CallTranscript.live 添加实时段落时保留 source（轮询快照原文）。页面以 source 作为 CallTranscriptViewport.revision，导致实时字幕虽已加入列表却不触发跟随；纯实时字幕时空 source 也被 viewport 明确跳过。页面改为以当前显示行的 speaker 与 text 构造修订值，不更改去重、段落归属或转写协议。新增字幕应滚动到底；用户回看期间无新字幕的计时刷新、相同内容轮询不夺走滚动位置。按Android/iOS、短屏大字体、重复话语和实时/轮询合并做实际页面回归；如发现可变高度懒列表的滚动范围估计不足，再修复viewport布局完成后的跟随，不扩大为其他页面滚动改造。

### 2026-10-16 单呼准备门禁与双端禁止返回

服务端 launchReady 来自唯一 START_CALL 指令；AgentCallStartGate 在两份同身份、同媒体 epoch 的 PHONE_PREPARED/MEDIA_READY 已投影且媒体活性核验后才创建该指令。客户端必须解码 launchReady，只有明确 true 且当前通话未结束/未关闭时显示页面；缺失、false 或非布尔真值都不得推导为就绪。REQUESTED 可继续只读轮询，不根据 callId 或 call_started 推断准备完成。

用户最新明确单呼通话页禁止返回，覆盖本变更历史中的返回会话描述。Android/iOS 共用 PopScope(canPop: !show)，通话覆盖层显示期间没有返回按钮，Android 系统返回和 iOS 边缘手势都不能退出或收起该页；状态观察保持，挂断和终态仍按既有明确动作退出。

验证覆盖：真实 HTTP DTO 缺失/false/true/错误类型；准备期间 callId 已存在仍停留会话，ready 后打开，准备失败不打开；两平台系统返回/边缘手势不可退出、持续观察和零 hangup。真实 iOS 设备效果与新 dev 外呼另行验收，不以 Widget 测试替代。

固定 v65 `4c781e3`：RealtimeAssistantModels、AssistantApiService、TaskCallSessionPollingController、TaskCallSessionStatusApplyController/Policy、TaskCallSessionTranscriptPolicy、TaskCallSessionUserCommandController/CommandUseCase。后端 RealtimeSessionService 确认 NOT_FOUND 返回空callId并回传请求taskId，挂断使用相同状态DTO。现有 Flutter AccountApi已隔离账号、无普通POST网络重试。

## Goals / Non-Goals

Goals：共享HTTP契约、逐次轮询、明确挂断、状态归属及晚到隔离、转写和结束等待语义；不依赖真机/人工即可验证的能力先完成。

Non-Goals（本实现批次）：不启用自动外呼、不新增人工接管入口、不播放监听音频、不修改SIP/ASR/TTS。完整通话页与统一对话接入仍是目标内后续任务，不能用独立接口替代。

## Decisions

### 正式单路监听装配（2026-09-19）

2.3沿固定v65 TaskCallMonitorController/CallMonitorAudioSocketClient/RouteManager：显式点击取票据，监听只接收PCM，不开麦、不发送声音、不触发外呼；Playing点击清空本地播放并Muted，恢复继续当前socket而不重取票。连接失败最多3次/800ms，新连接成功重置计数。终态、挂断前、离页、后台和账号改变停止本地监听，停止不等于挂断。音源只在Playing可选，可用蓝牙才展示；默认听筒，路由失败不假装切换。

复用既有VoiceSocket条件导出和DevicePcmOutput薄端口，不复制ASR/TTS。新增domain/call_monitor_media.dart、data/call_monitor_stream.dart与focused_call_monitor_media.dart、presentation/controller/call_monitor_controller.dart；PCM输出新增仅通信场景使用的清队列静音/路由方法，双端独立小型路由helper，不影响默认TTS输出。共享控制器固定目标和账号、generation隔离晚到、保护音频租约，关闭失败保留占用。原生只负责播放/路由/设备可用性。

app/call_monitor_providers.dart提供账号工厂，ConversationRoute/ConversationCallHost注入，既有通话页三按钮直接消费共享控制器；MOCK使用同一媒体协议/控制器和页面，只替换socket/输出/票据外部端口。每微批≤3文件，手写≤500行。验证包含真实loopback WS、合成PCM/系统通道、重连/静音/路由/关闭/账号/终态、同页三宽度及浏览器；三端构建，真实声音/蓝牙/权限与设备安装不以构建代替。没有SIP、数据库、提示词、后端协议或麦克风采集改动。

### 恢复当前确认的发送前门禁（2026-09-17）

固定v65 RestoreSnapshotMapper只恢复可恢复的pending makeCall spec；ConfirmCallHandler只有RepeatedInsufficient拦截用户提交。因此共享协调器增加静默restored上下文：不计时、不确认、不弹框、不读余额。用户输入后用账号/会话隔离的通知alias及当前余额重新判定；仅已通知且当前不足才刷新，刷新仍不足弹框，充足/未知则转发原输入一次。首次不足不在这一恢复发送门禁生成通知，继续原输入由既有Agent/准入处理。已解决、CLOSED、不允许恢复pending、非makeCall工具不恢复此上下文；不因此禁止普通输入。不得解析提示文案猜测标记或重发历史confirm_call。

### 结构化失败接入（2026-09-17）

按固定v65 AgentStreamEvent.Err / AgentStreamConfirmCallHandler / UserFacingErrorSanitizer，category=NETWORK或errorCode=NETWORK_TRANSPORT才是结构化网络错误；存在结构化字段时不根据文案猜测，模型超时/限流不等于设备断网。旧错误文本使用源TransportNetworkErrorPatterns兼容规则，不扩大为所有timeout/5xx。retryable只保留为提示信息，不启用自动业务重试。

AgentFailure为纯Dart协议模型；ConversationFailurePresentation单独映射安全提示和可继续状态；确认错误交给现有通话协调器，已登记callId继续观察，无callId的明确非网络失败关闭本地观察，网络失败保留核实。普通非网络失败允许调整输入，网络或无法核验的传输异常要求同步历史；错误不生成成功回执。批量失败结果仍按后端task_completed协议，不擅自扩展task_failed的含义。

实时结果直接协调：final中的终态单路回执必须归属当前confirm命令，已登记callId时还要匹配；持久回执必须匹配已登记callId并包含agentOutcome。仅物理CALL_COMPLETED不能收起观察，普通final文本、RUNNING及旧命令/其他通话回执均不能代替当前Agent结果。已有消息包含匹配结果时不再等待REST；否则仍保留物理结束后的只读同步。所有收起均为本地清理，不隐式hangup。

### 正式入口装配（2026-09-17）

ConversationController注入账号绑定准入/通话仓库；抽离ConversationEventStream订阅生命周期，独立ConversationCallController拥有自动确认、单路观察、计时与物理结束后的只读ledger同步。普通对话流仍是消息唯一入口，confirm_call沿用同session、voice和独立命令身份，无用户消息重放。实时请求触发，历史只补identity上下文，不自动执行。单路覆盖既有共享页面，多路不覆盖；返回只停止观察，不挂断。监听未接媒体时明确提示，不模拟播放。Web演练注入合成Agent/余额/提示/通话仓库，完整执行同一控制器与页面而不访问真实账号。

验证覆盖延时到页面、单/多路分支、积分不足、恢复无执行、确认网络错误不重发、终态ledger等待与挂断返回、关闭晚到。正式外呼/媒体/双端仍留集中验收，不能将合成端到端等同真实外呼完成。

v65发送前拦截也接入共享协调器：当前确认已提示积分不足时，新输入先刷新余额，不足仅弹框，不向Agent再提交；刷新允许才发送原输入一次，关闭/恢复使回调失效。重复弹框关闭后可以再次显示，不被同tool身份永久吞掉。typed已知拒绝且无callId时关闭观察，有callId或网络不确定时保留核实。

REST与SSE结果合并容忍仅时间戳精度的差异，持久副本权威；正文、归属、序号和其他metadata严格一致，较新SSE保留，整次合并失败不得部分修改。结构化失败与实时结果已由本页增量接入；恢复当前确认门禁、钱包缓存/结算和多路活动流例外仍未全部完成，单路入口完成不代替这些后续验收。

### 自动确认与积分准入增量（2026-09-17）

依据固定v65 AgentStreamConfirmCallHandler、TaskCallPointsAdmissionPolicy/RetryPolicy、TaskCallConfirmationIdentityAliasPolicy、TaskCallPointsNoticeCommitter：实时MAKE_CALL_REQUEST延迟1500ms确认；同一个待处理tool不能重复执行；新输入/恢复/关闭取消未提交调度。单路进入通话观察，多路留统一页，历史恢复本身绝不发confirm_call。

先实现独立CallLaunchRequest/CallAdmissionPolicy和CallLaunchCoordinator，字段身份、计价/人数、首次不足消息/再次不足刷新与弹框决定都用纯Dart。余额未知允许后端原子校验，不虚构余额0或本地扣费。确认后网络结果不明不重发；一个pending身份至多提交一次。协议/生命周期分别测试，再接ConversationController和正式Route，未接线的阶段明确记为基础而非端到端完成。

积分不足提示以环境/账号/会话隔离的安全存储记alias哈希，稳定alias严格保留v65 ordinal/scene/name/phone/goal/explicitCount/summary结构；重建请求时可检查历史同任务及已提示alias。首提示POST既有task-call-points-notices接口，仅该已确认幂等接口按v65最多3次/300ms尝试，不将重试扩展到confirm_call。异常不记录号码、正文、token。读写失败不能绕过积分不足；通知持久化失败单独报告，后续以服务端ledger为准。

实现微批（每批至多3文件）：domain请求/政策/端口；data API/安全存储及测试；协调器/虚拟时钟测试；生产会话及页面接线独立验收。共享代码不新增原生/后端/数据库/SIP/ASR/TTS；既有锁定crypto 3.0.7显式声明为直接依赖，用于标准SHA-256，不升级版本。沿用既有通话UI及静态优先授权。

积分不足首次先发布本地消息决定再尽力持久化；再次只返回弹框决定并保存alias，不重复POST提示。仅网络/服务端暂不可用重试，已知账号失效、归属变化、404/409/422或响应结构异常立即终止。close/new input/restore在每个异步边界检查generation。该核心不选择路由、不直接调用Agent，不把HTTP提交成功等同电话接通。

- domain：CallSessionTarget（taskId/callId）、CallSessionSnapshot、CallMonitorTicket、纯转写合并。data：AccountApi调用与严格DTO验证。controller：单个会话生命周期；独立于大ConversationController，不新增原生重复实现。
- 状态查询POST与挂断POST只发一次；轮询在本次完成后1500ms安排下一次，同一controller无重叠查询，失败保留已知状态并继续读。空taskId+callId拒绝请求，不让后端隐式选择其他电话。
- 取得callId前忽略NOT_FOUND；已知callId时允许后端NOT_FOUND空callId响应。非空task/call冲突拒绝，取得具体callId后继续用它定位。严格检查updatedAt，旧快照不得改转写或状态；终态不被同电话迟到运行态降级。
- 终态为ENDED/FAILED/NOT_FOUND，不把HTTP200或ENDED解释为任务成功。taskId等于Agent session、尚无Agent结果、ENDED+COMPLETED或FAILED+FAILED、resultCode非AGENT_时进入awaitingOutcome。结束通知只发一次，后续由编排器同步ledger；本controller不写伪持久回执。
- 转写按原单路状态规则识别assistant/callee/merchant/remote英文冒号；保留种子行和重复发言。完整快照更新/前缀续接遵循v65，不与结果回执的其他格式解析混淆。
- 挂断单飞，明确成功后请求收起通话页；失败不假装结束、不自动重发。挂断期间旧查询响应失效，失败后恢复查询。关闭/销毁只停本地轮询，绝不发送hangup。
- 监听票据按原接口获取，凭证不进入日志/页面；音频格式缺字段沿用DTO默认16k/mono/PCM_S16LE，有字段必须有效。票据不证明媒体已连通，不主动刷新或播放。
- 日志只有事件名、session/task/call关联ID、状态/原因分类；不输出用户正文、号码、转写、票据或异常原文。

## Risks / Trade-offs

- 查询与挂断并发、页面销毁 -> generation与命令版本隔离；AccountApi额外处理账号变化。
- DTO含历史接管RTC凭证 -> 当前入口不用，不导入凭证到UI状态，也不接旧接管操作。
- 2026-09-17用户已允许静态HTML/CSS/组件先行：使用pvCallScreen及v63-0-1/0-4增量样式，排除旧callPage静音/接管和波形；视觉后续校准。

## 页面交互批次（2026-09-17）

- 新增共享CallSessionPage（只接收状态和回调）、CallControls/CallAudioSourceSheet、具名SVG图标和展示映射，监听/挂断/音源三项保持v65；只在Playing允许音源，蓝牙按可用性显示。
- 隔离CallPreviewController组合既有CallSessionController和纯内存Repository，演练呼叫/接通/转写/物理终态等待Agent结果、状态读取错误、挂断失败重试、监听连接/失败/重连/静音和音源弹层。不联网、不调用票据、系统权限或音频。
- 从现有开发者演练进入场景入口，不给正式确认卡新增执行按钮。页面采用同一Flutter控件树；未来真实编排注入真实状态和媒体回调，不再复制页面。
- 本批页面可演练不代表自动确认/积分/ledger编排已接入；2.1、2.2正式执行入口和2.3真实媒体继续待办，不能用MOCK假装完整外呼。
- 页面销毁停止本地timer/controller；挂断成功关闭页面，失败留页；外部返回不调用hangup。终态不能显示业务成功。

## Migration Plan

三个微批：domain/API/契约测试；状态controller/轮询与并发测试；provider/集中验收文档。每批不超过3个手写文件。analyze、全量test、Web build、OpenSpec通过后提交推送。无依赖与原生变更，本批不重装设备。后续独立完成自动确认/积分、页面、媒体及双端验收后才可归档。
