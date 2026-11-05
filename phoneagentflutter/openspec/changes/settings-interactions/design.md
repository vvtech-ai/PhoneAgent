## Context

固定 Android 4c781e3 的 FinalSettingsHomePage、DomesticTranslationAudioSettingsCard、TranslationCallSettingsRepository、AssistantDeveloperToolsPage。静态设计 0cd58de9 的 settingsPage/translationOriginalAudioPage；原型缺少的日志入口与两个原音滑条以现有代码为准。

## Goals / Non-Goals

Goals：有效设置入口和可返回子页、真实本地原音偏好、退出确认、进程内解锁，平台危险操作的显式隔离演练。
Non-Goals：初始交互批次不真实上传/下载/安装；后续日志、手动更新子批已接真实端口，但自动验收不发送实际日志、不实际下载或安装。启动每日/持久强制门禁与正式旧数据升级仍独立待办。不配置真实外呼号码、不清后端列表，不实现媒体效果/国内 SIP/可信来电/新记忆功能。

## Decisions

### 用户范围纠正与普通Android恢复（2026-09-21，优先于下方历史批次）

日志仅保留既有上传，不新增匿名本地导出/分享页面；下方历史批次将匿名导出列作缺口的判断撤销，不再是开发或验收门禁。旧Android无账号/环境/时间的pending/recovered集合保留原文件但不导入、不重放，任务以服务端最新状态为准。现有Flutter账号队列不变，无需新增后台协议或业务代码。

普通main Dev包已重新构建，adb install -r返回Success，09-21 14:26:03更新，UID10496/首次安装时间不变；冷启动和截图确认普通登录页。此前“等待用户手动恢复”已解除，当前未登录不等于安装失败。本轮不卸载、不清存储、不发验证码、不重复全量。

### 确认卡独立设备阶段（2026-09-21）

新增confirmation分组，仅复用正式App/确认卡/任务恢复与现有内存工作台端口，验证普通卡换模型后历史计费不变、扩展卡联系人展开及同卡决策更新。先做375×667/393×820双平台样式预检，再在现有已解锁Mac会话构建运行iOS测试；附加式驱动必须keep-app-running，结束恢复当前普通main测试包。Android安装限制未解除前不绕过、不重发SMS。分组禁止真实安全存储、旧源、系统拨号与PCM；API为空且短信提交为0。六图单独输出，不覆盖此前52图，不重复全部设备用例。该证据仅为共享页面交互/布局，不代替真实后台、签名升级、历史持久化或视觉精校。

### 确认卡计费快照（2026-09-21，L04）

扩展卡续接：固定LargeTaskTimelineProjection以schema1/displayPayloadVersion1的confirmBatchTask TOOL_REQUESTED读取snapshotJson对象或JSON字符串，toolCallId为snapshotId，ordinal+1为version。结果只更新同卡决策、保留原位置/内容；BatchConfirmationTimelinePolicy抑制CONFIRMED之后首个makeBatchCalls重复确认。共享模型/投影独立文件，不在接近500行Controller加分支；现有timeline_committed与ASK_USER已提供正文回复及pendingToolCallId，继续使用既有输入。

共享卡包含任务分区、联系人三项统计/问题/默认4人及展开、规则及决策；不增加确认执行按钮。计费alias为batch-plus:snapshotId:version，Pending缺快照才捕获当前，非Pending缺快照不保存当前且不显示积分卡，已有新/旧快照仍显示。正式路由复用共享安全存储；MOCK增加完整App演练指令，不发真实外呼。微批依次：模型/投影/消息；merge/UI；存储捕获门禁及route；工作台/测试。定向覆盖对象/字符串、结果合并、重复执行抑制、未知schema/损坏、恢复pending续聊、窄屏展开及历史计费。未改原生不重复双端构建；阶段设备及真实升级仍单列。

已追到固定v65 SingleFlowNativeMainSection→SingleFlowPureVoiceContent→PureVoiceStage→PureVoiceStreamingStageContent→PureVoiceThreadList。有效统一页单/多路任务确认卡调用AgentCallConfirmBillingNotice，LargeTaskConfirmationCard也消费同一快照；不是FinalHomePage遗留入口。Flutter已有CallConfirmationCard但缺费率/余额提示，且没有快照存储；扩展batch-plus卡独立结构还需另批核对补齐，不能把普通makeBatchCalls确认当完整扩展卡。

先补现有CallConfirmation卡全链路：共享不可变BillingSnapshot/余额提示策略、账号/环境/会话/alias安全存储、同生产包只读旧哈希来源、正式Route注入只读计费子组件。旧scoped key优先，再查旧account+alias key；旧源只读，不传确认正文。新存储先于旧源，已有快照先于当前模型/余额；导入先落盘，失败不拿当前值冒充历史。以现有toolId及稳定alias匹配，不改呼叫准入、扣款、通知或旧确认执行按钮。

按最多3文件微批：模型/存储/旧源；原生通道/MainActivity；Provider/只读Route；确认原始身份元数据/页面回调；纯显示及测试/隔离Web。普通确认卡和扩展batch-plus分别记录验收，L04父项在两者完成前不勾。定向覆盖新旧优先、换模型不重写历史、错误/账号失效、费率阈值/单双路、窄屏与正式入口。Android桥接构建、Web连续演练，真实生产升级另验。

### 旧语音识别语言（2026-09-21，L01）

固定v65 VoiceLanguage/AssistantVoiceLanguageState保存设备级index9_native_screen.voice_language_code，主TaskASR和后端回退均读取。与国外翻译语言/模型无关，不增加初始化或设置入口。旧值按v65归一为zh-CN/en-US/ja-JP；未知字符串沿原默认，错误类型不能当缺失。

复用LegacyPreferencesChannel白名单及生产双门禁，DeviceLegacyPreferences只返回语言字段。新增SecureVoiceLanguageStore，按环境/API隔离安全key、同key跨实例串行；新值优先，新损坏不回退，命中旧值先保存再返回。无旧值才使用中文默认且不写入默认。原生无语音业务逻辑，iOS继续共享存储与默认语言。

语音工厂注入readLanguage，FallbackVoiceInputSession在start中有界等待3秒，每个手势只取一次；主/回退URI均使用此快照，保留userId等其余参数。读取失败不启动任何传输或默认回退；取消/失效的晚到读取不能启动麦克风。沿现有Controller错误/释放处理，不改提交、尾句、重试或TTS。测试含原生桥接合成响应、存储优先/并发/故障、正式工厂及双路径URI、取消/超时；analyze/相关定向/Android Debug，不真实采音或重复全量。

### 旧积分不足已提示标记（2026-09-21，L03）

固定v65 AssistantPageHost把根index9_native_screen偏好交给SharedPreferencesTaskCallPointsAdmissionNoticeStore；key为task_call_points_notice_加SHA256(account+NUL+conversation+NUL+confirmationIdentity)。TaskCallConfirmationIdentityAliasPolicy的toolId/stableAlias与Flutter CallLaunchRequest现有编码一致，后者已有分隔符/序号回归。不修改alias含义、不把余额或历史计费快照混入本项。

共享DeviceLegacyCallAdmissionSource只将旧key哈希列表传原生，原生同生产包、固定prefs/前缀、最多1024个64位十六进制哈希，只读布尔，不枚举或输出内容。Dart核对返回版本/精确哈希集合/布尔值后还原请求内alias集合。正式Provider仅非Web Android且精确prod API启用，捕获原账号和存活代次。SecureCallAdmissionNoticeStore新key优先，仅缺失项查旧标记，命中先安全保存1再返回；新读取/旧源/写入失败保留既有Service的persistenceFailed路径，不伪报导入成功。标记只从缺失到1，既有并发按alias独立写仍安全，不引入全局锁或新缓存。

本批不清旧文件、不新增通知POST，不自动打开/确认历史电话，不增加页面。微批为设计/spec/tasks；原生key校验/只读通道/MainActivity；共享source/store/Provider；定向协议、失败、新值优先、关闭/跨账号、并发和正式Service恢复分流测试及文档。analyze、相关定向、JVM与Android Debug验证；人工升级后再次不足流程集中验收，无真实外呼/验证码/安装。

### 旧国外翻译待归档记录兼容（2026-09-21）

固定v65 PendingRealtimeTranslationStore按账号SHA256前32位保存files/realtime-translation/pending/pending-<hash>.json；这不是可丢弃缓存。旧Coordinator在启动恢复CONNECTED/TERMINAL_DRAINING/READY_TO_ARCHIVE/ARCHIVING，沿clientCallId幂等PUT，不重拨。本批补正式生产Android首次读取兼容：原生只读当前账号固定路径，限定文件大小8MiB、禁止路径穿越/符号链接越界、不输出内容；Dart以白名单转换WORLD_CALL、核对每条账号/ID/阶段/时间/定位凭据。国内项和已完成/未接通项不进入新队列；未知/损坏的有效项显式失败，不当空队列覆盖。旧文件不删除、不写入，不复制国内录音路径或媒体票据。

沿既有精确prod API与Android生产包双门禁，Web/iOS/Dev不读取。SecureTranslationArchiveStore仅在新key缺失时调用旧源，在同key跨实例串行队列内先保存新格式再返回；新key包括空队列优先，成功同步后的空队列阻止再次导入。读/写失败可重试，账号失效不发布迟到结果。只接已有恢复Controller及API，不新建呼叫/计费/后台协议，不增加初始化步骤。新格式已存在不合并旧源；降级旧包不能宣称状态反向同步安全。

微批：settings-interactions设计/spec/tasks；原生文件读取器/通道/MainActivity；共享codec/device source/store；Provider及定向测试。测试用合成Gson形状数据和临时文件覆盖字段映射、排除、损坏/串号/有界读取、失败重试、新值优先、换账号/并发及Controller恢复至同一幂等ID；analyze、Android Debug构建和OpenSpec校验。无真机数据/SMS/外呼/安装。真实同签名升级与人工媒体仍保留单独验收。

### 真实键盘布局独立阶段（2026-09-21）

现有设备阶段enterText后主动隐藏键盘，不能证明真实IME安全区。本批仅新增keyboard分组：同源MOCK首页→统一页文字→点击输入框，设备等待真实viewInsets出现后核对输入/发送控件可见；输入合成文字、收起键盘、发送、关闭与任务恢复。共享函数在两尺寸/两平台预检注入显式键盘inset，不把注入当系统键盘；iOS使用真实平台键盘和截图，Android保持安装拒绝约束待恢复普通包后再验。无SMS/HTTP/真实音频或存储；保留原attach-only驱动和普通iOS包恢复，不重复前42图。视觉精校仍后置，不声称输入法候选、中文组合输入或用户输入准确性通过。

### 国外翻译媒体诊断（2026-09-21，2.1b7b）

沿现有LiveKitTranslationMedia/AppAudioTranslationMedia共享编排，仅增加强类型观察，不改双ready、create→media ready→merchant-call、静音/音源/DTMF和释放重试。组件为translationLivekit/translationAppAudio；连接阶段、权限取样、room初始化、后端ready、merchant ready、首帧采集/发送/播放、控制及关闭分别记录，PCM不逐帧记录。日志不存票据、URL、字幕、号码、DTMF数字、设备错误或音频。合法UUID sessionId可关联，非UUID后端ID丢弃，不伪装诊断trace为业务ID。

两正式工厂使用现有MediaDiagnosticScope绑定调用时Journal；TranslationDialRuntime在创建每路media前已有账号检查，旧实例回调保留原sink，诊断失败不影响业务。分≤3文件微批：诊断枚举/安全session绑定、两个共享适配器、两个工厂、定向测试和记录。无原生/依赖/界面/后台协议修改，不发真实电话；定向覆盖故障/取消/释放/隐私/正式工厂及原媒体回归，analyze/OpenSpec；真实设备音质与其他未纳入的媒体路径分别列验收，不把诊断成功当声音验证。

### 正式页面移除过期迁移状态（2026-09-21）

当前translationDialRuntimeProvider已读取原音偏好，TranslationDialRequest写入三个后端字段，双端translationDeviceMediaFactoryProvider已有正式实现。因此OriginalAudioPage不能继续显示“媒体尚未接入”的开发提示；移除该说明，保留保存失败/重试和下一通生效。TranslationDialerRoute仅在实际binding为空时提示当前环境无法发起翻译，不把整项能力误报为尚未开发，也不回退普通拨号。修改两页及既有定向断言，按真实装配测试和Web设置入口验证，不改变媒体/请求/平台行为。

### 共享语音传输与PCM诊断（2026-09-21，2.1b7a）

在现有TaskAsrSession、RealtimeTranscriptionSession、TaskTtsSession及VoiceWire追加纯观察，记录连接返回、协议ready/失败/合成complete、首个PCM和关闭；连接成功不等于ready，complete不等于播放完成。PCM装饰器只观察实际start/read/play/stop返回或失败，保持返回对象、异常和释放重试；不逐帧写日志。共享强类型media字段固定component/stage/reason，不存音频、文本、speaker、URL、异常原文。旧无media日志兼容，未知可选枚举归unknown。

一次输入/回复/试听工厂调用固定Journal及UUID trace，延迟创建fallback/后续句子仍使用原归属。Provider不watchJournal重建音频工厂。分≤3文件微批：诊断模型/观察器、PCM装饰器、voice wire、三种协议session、三个正式工厂及定向测试。无原生/依赖/业务状态变更，不开硬件/发短信/上传，不重复打双端；analyze与相关语音/日志/工厂定向验证。翻译LiveKit/AppAudio专属传输诊断、匿名导出和真实声音仍是独立未完成项，不将本批扩称全部媒体诊断完成。

### Android 未捕获异常摘要（2026-09-21，2.1b6）

固定v65 AppCrashHandler安装Java/Kotlin默认未捕获异常处理器；指定iOS ddb996a自有源码检索未发现同类处理器，第三方二进制符号不是业务证据。本批只迁移Android managed异常，不声明NDK信号、ANR、系统强杀或iOS崩溃捕获。Application启动安装，始终转交原处理器；采集/密钥/磁盘失败不能替换原异常。

原生diagnostics目录分CrashSummary、CrashSummaryStore、NativeCrashRecorder、NativeCrashChannel与Application接线。摘要仅UUID、时间、主/后台线程布尔和固定异常分类，不读取message、stack、任意类名或线程名。AndroidKeyStore独立AES-GCM密钥，noBackupFilesDir内单摘要加密原子替换；AAD绑定scope和文件名，严格文件名白名单，暂存含当天15天、全局最多32条。此暂存不替代正式Dart15天日志归档；OOM/磁盘故障仅尽力保存。

Dart负责环境/API/账号作用域SHA256、NativeCrashImporter、DeviceNativeCrashPort和正式宿主接线；原生内存scope只采用最近收到的显式绑定，不跨进程恢复上次账号。启动未绑定记录归unassigned，不能猜测交给随后账号；匿名导出仍独立待办。桥接是异步边界，绑定送达前的极短窗口仍按上次已确认scope记录，不宣称异常发生瞬间的业务身份。读取/确认均带原scope，异步结果固定原Journal，换账号绝不重定向。成功flush后按精确UUID删除原生摘要，清理失败可重试；进程在两次提交间终止允许同UUID重复，不声称exactly-once。

微批≤3文件，新增定向JVM真实AES-GCM/临时目录/原处理器故障注入，Dart通道/恶意字段/账号换代/持久化/ZIP测试及analyze、Android Debug构建。不在真机制造崩溃、不安装、不清登录、不上传，iOS/Web不调用新增通道。

### 共享音频占用诊断（2026-09-21，2.1b5）

在既有AudioPlaybackFocus追加纯观察诊断：申请、释放、实际stop回调及等待超时；固定8类owner白名单，未知归unknown，不存任意owner/异常文本/PCM/转写/URL。申请时固定Journal，成功后租约保留同一sink，账号切换后的迟到停止仍归原账号；Provider不因Journal变化重建仲裁器。申请编号和租约代次仅为本进程关联数字，不代表后端session或call。

超时只记录等待超时，仍保留原租约并复用在途停止；stop回调失败不虚报释放，诊断获取/写入失败不改变原业务异常和串行顺序。共享模型/audio_focus_diagnostics.dart、audio_playback_focus.dart及app/audio_focus_providers.dart分≤3文件微批，新增定向覆盖白名单、失败/超时、跨账号、Journal重建和ZIP。无UI/协议/原生变动，不开硬件、不重复平台构建。此子批不等于原生crash、PCM/媒体底层错误或真实声音效果已验收。

### 登录请求脱敏诊断（2026-09-21，2.1b4）

共享DioAuthGateway在send-code/login完整响应解析后记录一条结果，包含固定operation、HTTP状态、耗时及auth.outcome；邀请码待补充与凭据返回分别分类，HTTP200不等于登录成功，凭据返回也不等于SessionStore已保存。沿原AuthFailure映射，不改变请求、重试或业务异常；不记录手机/验证码/邀请码/challenge/token/账号/响应原文/URL。诊断获取和写入失败均不得影响业务结果。

authGatewayProvider使用延迟sink工厂，在每个请求开始时读取并固定当前Journal，而不是watch账号Journal导致登录过程中关闭客户端；请求晚到不重新选择账号。新增可选强类型auth字段，旧无字段日志可读，未知分类归unknown。每请求独立状态，最终事件无需将并发started/finished配对；未完成或强杀请求没有完成事件，不声称请求起始已持久化。

沿现有环境/API/账号隔离，登录前存signed-out槽位，不把匿名历史自动转交给下一个账号。当前设置ZIP只导出当前账号，所以登录前日志的用户导出入口仍是明确开发缺口（2.1b4b）；本批2.1b4a仅完成正式采集/持久化及合成ZIP验证，不能据此勾选完整日志父项。微批≤3文件；定向HTTP/解析/隐私/并发/sink失败、正式Provider换账号及实际Journal重建/ZIP、analyze。不触发SMS、不改变UI/平台/依赖，不重复设备构建。

### Agent工具事件诊断（2026-09-20，2.1b3）

固定v65 AgentService信号工具、AgentRealToolDispatcher同步工具、ConversationEventType持久事件为白名单来源。新增core/diagnostics/diagnostic_agent_details.dart保存强类型frame/signal/tool/ledger与安全整数sequence；diagnostic_event.dart追加可选agent字段及agentEvent/received，缺字段的旧日志保持可读，未知可选枚举归unknown，不接受任意字符串透传。conversation/data/stream/agent_stream_diagnostics.dart负责纯映射，DioAgentGateway在取消/账号/会话校验后调用；替换原assert中的任意type/payloadKeys打印。非error结构事件结果为received，只证明接收，不推断执行成功或通话终态；Agent流原有终止语义不变。

记录工具开始/完成/卡片、signal/final/error/status及timeline_committed；text/thinking/heartbeat/done不逐帧记，避免token流占满缓冲。合法sessionId/traceId继续来自当前命令；原始toolCallId不保证UUID所以不记录，以会话/轮次trace和ledger序号关联。未知事件类型不透传原文。只追加日志，不参与Reducer，不新增API/数据库/音频/原生或自动上传。微批≤3文件：模型/映射，Gateway与定向测试，文档；验证SSE→真实Journal重建→实际ZIP、16工具/16持久事件/信号白名单、恶意字段与旧日志、错会话/取消/诊断失败。没有UI变化，不重复页面演练、全量测试或双端构建。

### 正式加密归档接线（2026-09-20，2.1b2b）

继续复用固定path_provider 2.1.5（此前已为传递依赖）取得App Support私有目录，显式依赖；新增固定纯Dart cryptography 2.7.0，使用库AES-256-GCM随机nonce/认证标签，AAD绑定scope摘要+文件名+格式版本，不自造加密算法。每scope随机32字节密钥只放现有FlutterSecureStorage，不写文件；解密失败/密钥缺失但已有归档必须失败，不自动换密钥覆盖。文件与索引均加密；密文编码开销纳入5MiB文件上限。IO加解密放独立isolate，平台仅目录/安全存储插件，Web保留原有安全存储journal，独立MOCK继续纯内存。

微批：pubspec.yaml/lock机械依赖；`data/diagnostic_archive_cipher.dart`、`secure_diagnostic_key.dart`、`encrypted_diagnostic_files.dart`及测试；`data/diagnostic_journal_factory.dart`、条件`diagnostic_journal_factory_io.dart`与`diagnostic_journal_factory_web.dart`；core归档追加一次导入标记及有界快照，`diagnostic_journal.dart`增加归档构造与串行在途批保留；`diagnostics_providers.dart`正式装配。旧v1结构日志只读解码白名单后一次导入，导入标记与分片同一索引提交；成功后才清旧安全存储，清理失败可重试但不重复导入。旧任意Android文本文件仍不导入。导入日为归档写入日，原事件UTC时间不变。

固定v65后端配置允许单文件300MB/请求320MB，但不能据此把真实服务器现配置当作已验证；当前客户端512KiB也不是后端限制。为避免手机把15天全部事件读入内存，正式ZIP按至多4MiB原始事件分批准备，单ZIP最多5MiB，明确提示尚有剩余。每次用户上传只POST当前明确快照；成功后显式继续准备/上传下一批，不自动循环POST。快照watermark为本批最后序号，不能用归档总序号清掉未上传余量。小日志交互不变，上传失败/清理失败仍保留原语义，不重试已收件批次。

平台实现补充：Android复用path_provider和既有禁止备份配置；iOS用45行DiagnosticDirectoryChannel创建固定App Support目录、设置并读回completeUntilFirstUserAuthentication与排除备份属性，Dart检查失败则拒绝启用。业务规则/加密仍共享，Keychain unlocked_this_device未放宽。独立diagnostic_storage_probe只用随机合成scope调用正式工厂和真实安全存储，不接业务HTTP，结束仅清自身文件和密钥；它不是零存储MOCK。

验证：旧结构事件/在途写失败/边界/分批不丢记录/跨账号/密钥丢失/篡改/AAD错文件/随机nonce、正式provider取样和MOCK零存储；91条定向及analyze通过，依赖变化完成Web/Android/Mac iOS构建，两端存储探针400条重建、分批确认后367条通过。iOS普通包已恢复；Android恢复被执行策略拒绝，已请求手动覆盖，未绕过。额外Chrome widget测试卡loading后结束，不重复启动耗时循环；改用独立tool/previews/log_batch_preview.dart内存仓库+真实合成ZIP，8123浏览器实测两批显式准备/上传和最终入口消失通过。真实日志HTTP收件、锁屏和突然断电集中待人工，原生crash/音频仍待开发。详见LOG_REPORT_VALIDATION。

### 15天轮转归档底层（2026-09-20）

固定v65 AppFileLogger为本地自然日含当天15天、5MiB单文件轮转，不是256条或整机logcat。先实现共享Dart `core/diagnostics/diagnostic_archive.dart`（事务/保留/水位）、`diagnostic_archive_files.dart`（最小文件端口）及 `app_logs/data/directory_diagnostic_files.dart`（私有目录文件适配），另加定向真实临时目录/故障注入测试。单个事件仍经DiagnosticEvent白名单，不导入旧任意文本；事件UTC时间与写入本地归档日期分开，跨夏令时按日期而非24小时相减。

每次写入先生成不超过5MiB的不可变分片，再原子替换索引提交；单批超过上限先失败，不静默丢弃。满片或跨日新开分片，未满同日片copy-on-write替换，最多重写一片。索引持久sequence与acknowledged，清空/过期/重启也不复用序号；上传期间新事件通过watermark保留。失败发生在索引提交前时旧快照仍有效，孤立分片下次清理；索引提交后不因回收失败把append报告为未写入而诱发重放。快照/确认可显式报告清理失败，确认重试不重新上传。损坏索引/分片拒绝覆盖、不当作空日志。

目录由调用方提供App私有根目录，适配器仅进入SHA256(scope)子目录，不接受动态相对路径、不遍历其他账号；只回收严格匹配归档命名的文件，不递归删除、不碰未知文件。相同规范路径的实例在当前isolate串行；不声称跨进程/isolate并发安全。记录白名单脱敏不等于加密，正式装配前须确定平台私有存储保护与旧安全存储衔接。

本子批不修改正式provider、Journal、ZIP或平台依赖；正式App仍为256条。后续2.1b2b必须完成正式私有目录/保护、旧结构日志衔接、Journal队列与ZIP上限适配、双端构建及设备检查，之后才能宣称15天能力生效。原生崩溃/音频诊断仍是独立开发缺口。自动测试只使用本机新建临时目录和合成事件，不读写真机日志、不真实上传。

### 共享运行时异常诊断（2026-09-20）

正式main入口ProviderScope内挂RuntimeDiagnosticsHost，安装独立RuntimeDiagnosticHooks包装FlutterError.onError及PlatformDispatcher.onError；不改变原回调的异常传播/handled返回值，无原平台回调时返回false。诊断自身同步/异步失败隔离；取消宿主只恢复仍由自己拥有的回调，不覆盖后来接入的处理器，已释放回调不再记录。独立演练入口不自动接入全局钩子。

仅新增flutterFramework/dartUnhandled operation和固定failureKind枚举，禁止调用异常toString、读取PlatformException details或保存堆栈/消息。每次事件发生时同步选择当前账号journal，不缓存旧账号sink；记录后立即请求串行flush，不等待500ms定时器。异步安全存储仍不保证进程被系统立即终止时落盘，不冒充原生crash捕获；现有256条容量和ZIP上传/水位清理不改。旧无failureKind事件继续读取。

微批文件：diagnostic_event.dart、diagnostic_journal.dart、runtime_diagnostic_hooks.dart；runtime_diagnostics_host.dart、main.dart及定向测试。用合成异常/内存存储和实际Flutter错误回调验证类型白名单、原回调/返回值/抛错、重入/销毁/第三方接管、账号换代及真实ZIP准备，不触发线上上传或真机崩溃。只跑受影响日志、启动/登录和共享主流程测试+analyze。15天文件归档、原生crash及音频诊断仍是开发缺口，不转为仅待人工验证。

### Android v65旧登录升级导入（2026-09-20）

同一SecureSessionStore.keyFor作用域跨provider实例共用进程内串行尾队列，完成后删除尾引用，不保存凭据结果；不同作用域独立。最小失败回归证明重建实例退出会被迟到旧读取覆盖，修复后恢复先落盘再退出清理。当前单isolate装配有效，不扩展为跨进程锁。旧文件保留意味着降级旧包仍可能读取旧凭据，不能称自动回滚安全，正式发布专项必须覆盖此边界。

固定AccountIdentityProvider使用account_identity的phone、voice_clone_access_token，账号为phone-加归一中国手机号；expired_login_phone_hint不构成登录。旧prod包com.vvtech.aiassistant指向chaken.ai，旧local是.dev，旧dev是.test，不能按当前Flutter.dev名称映射旧测试凭据。

本子批只自动迁移同生产包、精确prod API作用域的旧登录。新增domain/legacy_session_source.dart契约、data/migrating_session_store.dart串行装饰现有安全存储：新存储优先，读取失败不得回退；导入先写安全存储再持久标记消费，失败保持可重试。新登录或退出先消费标记，再写/清新存储，避免退出后复活旧凭据；旧account_identity不修改，保留回滚依据。Android LegacySessionChannel只允许固定同包文件/字段，非生产包返回无来源；在独立串行executor读写标记，原文不进日志。不调用HTTP/短信、不推断token在线有效，不创建登录赠送事件。

Web/iOS和非精确prod API继续使用现有SessionStore，不调用旧数据通道；不跨包读取、不更改沙箱/证书。测试通过合成源、内存目标和MethodChannel核验顺序/失败/并发/退出/环境；Android Debug编译核对注册，不将其当同签名升级成功。旧偏好、认证录音、本机记录、评分草稿及实际生产签名/versionCode仍为2.1d2后续范围，本批不把整个OTA或迁移标完成。

### 拨号权限顺序与开发者重置（2026-09-18）

固定v65 DialerLocationPermissionGate/DialerCallLogPermissionGate/DialerPermissionSequencePolicy：进入拨号先检查位置，已授权刷新可信地区；未授权且从未提示先显示用途说明。取消/拒绝关闭翻译但保留普通拨号；再次打开翻译按真实状态走申请或系统设置。位置决定完成才允许Android申请一次CallLog；iOS永不请求系统记录。开发者重置沿AssistantRootHostArgsShell只清locationPromptShown/systemRequested后打开翻译拨号，不清callLogRequested、不清位置缓存、不撤销OS权限。旧iOS resetPermissionsTapped只有提示，不复制其空实现。旧四类模拟granted变量不能覆盖Flutter已有实时OS权限来源，也不复活旧语音/存储流程。

共享domain/dial_permission.dart保存本进程提示标记和端口契约；controller/dial_permission_controller.dart管理检查→说明→授权/设置返回→CallLog→ready，单飞和离页/重置代次隔离。widgets/dial_permission_host.dart负责共享说明、阻塞与设置返回生命周期，不直接访问原生；app/dial_permission_providers.dart装配来源。data/device_dial_permission_port.dart复用现有权限和位置设置通道；Android PermissionChannel只扩展locationStatus/CallLog权限，iOS只增加位置状态，无系统记录端口。已有位置缓存与设置控制器继续唯一持久事实源。

普通与翻译拨号共享Host，正式Web不申请权限且不改OS状态；独立显式MOCK覆盖同一Host、控制器和端口，可连续验证重置→位置拒绝→CallLog→再次开启→永久拒绝/设置返回。DeveloperToolsRoute接真实reset入口，无权限授权伪造、后台操作或自动电话。每批最多3手写文件，新增测试+analyze/fulltest/格式/OpenSpec/Web/Android/iOS无签名构建，真实系统授权/设置返回集中留设备验收。

### 列表调试真实本地消费者（2026-09-18）

依据AssistantDeveloperDataModeActions，两种模式都清当前账号本机CallRecord持久数据；Filled另刷新真实任务、已授权联系人，Empty只清联系人内存及选择，不删OS通讯录、后端任务或备注。废弃ContactMethods不迁移。模式只作为本进程操作标签，不引入永久过滤后台任务/联系人规则，后续正常刷新可重新读联系人。

新增controller/developer_list_controller.dart和widgets/developer_list_controls.dart，app/developer_list_providers.dart装配共享本机记录仓库、任务refresh及ContactsController现有读取；contactsController账号范围保活至账号失效，Empty清选择并废弃在途设备读取，Filled静默刷新（不申请权限）。真实DeveloperToolsRoute替换列表未接入提示，提供本机持久清理失败和重试反馈，不自动执行清理；本地失败不报告成功。清理只影响当前槽位，不调用DELETE接口。

按每批≤3文件接线，Web独立Preview容器替换存储、任务、系统来源，演练复用正式控件/控制器与最近列表，可核对本机清空但系统记录/后台任务不被删除。自动验证不清真实数据、不拨电话，不改变OS权限。对应contacts-migration 2.9a提供共享存储，2.2d4仅覆盖列表消费者，权限重置/完整翻译归档和双端安装仍未完成。

### 对话时间、权限快照与上下文组装（2026-09-18）

2.2d3沿固定v65 AssistantUserContextHolder.currentPermissionStatusSnapshot/currentTimePayload，后端AgentService按ISO_OFFSET_DATE_TIME解析本地日期，允许OK/NOT_GRANTED/UNAVAILABLE等状态，不能发自造UNKNOWN。iOS ddb996a自有代码未发现对应上下文实现，因此共用Dart而不是复制播放器currentTime。

domain/context/agent_clock.dart负责时间/偏移/时区验证与ISO编码；data/context/device_agent_clock.dart及条件browser_agent_clock_web.dart读取设备或浏览器时钟。Android/iOS DeviceClockChannel只回传当前epochMillis/offsetSeconds/timezone，无权限/数据采集。浏览器Intl时区来自运行环境，失败用明确数字偏移，不把timeZoneName缩写伪装成IANA。禁止硬编码Asia/Shanghai或服务器时区。

domain/context/agent_context_builder.dart独立组装：先等待已有有界位置，再并发读取新时钟及各权限（request=false），每项最多2秒；不缓存上一轮权限/时间。失败的权限标UNAVAILABLE不冒充用户拒绝或已授权；时间源失败按Dart当前系统时钟与明确偏移降级，不伪造IANA。每轮独立，dispose后不输出旧账号上下文。app/agent_context_providers.dart依赖loginEpoch并复用DevicePermissionChannel，与正式权限工具共用一个source provider。

将DioAgentGateway.locationContext准确改名为userContextProvider，保留原提交后登录/取消校验以及OCR/首轮/工具幂等字段；正式provider注入builder。新时钟native文件及MainActivity/AppDelegate/pbxproj注册分3文件微批；独立Web合成上下文演练复用builder与只读显示，位置/时钟/权限源全部注入，不产生真实HTTP或权限请求。测试覆盖跨日/非整点/负偏移、每轮刷新、单项失败/超时/销毁、实际Dio序列化、Web条件分支和原权限续接；全量/analyze/格式/OpenSpec/三端构建及浏览器。原有列表与模拟权限重置不是这份真实权限快照，仍待完成。

### 对话位置与开发者只读摘要（2026-09-18）

核对固定v65 AssistantUserContextHolder、FusedLocationProvider和iOS ddb996a AILocationService：开发者位置来自Agent坐标/地址，不是翻译国家码。Android已授权才取样，当前定位8秒、最大年龄2分钟/精确1500米或近似3000米，失败可选5分钟内最近定位（GPS500米、其他1000米）；共享刷新缓存2分钟、每轮最多等待10秒。iOS用CoreLocation一次请求和可选逆地理编码，但沿已批准Android行为不在发送文本时主动申请权限。显示地址优先、否则四位小数坐标，不将国家选择器冒充设备位置。

新增conversation/domain/context/agent_location.dart、controller/agent_location_controller.dart、data/context/device_agent_location.dart；原生AgentLocationChannel.kt/swift只提供已授权坐标、可选地址、取消和有界释放，不记录精确位置、不落盘、不新增App自有HTTP定位接口；系统逆地理编码可能使用系统厂商服务。Android/MainActivity、iOS/AppDelegate/pbxproj分批注册。app/agent_location_providers.dart按登录代次隔离内存，开发者摘要只观察，不因进入设置触发定位。

在DioAgentGateway真正提交前通过注入回调读取位置并合并userContext，保留OCR/首轮/工具/幂等字段。回调结束后再次验证账号和取消，不允许退出时排队的HTTP晚发；定位失败继续原对话，不伪造坐标。平台取样有界，关闭账号取消；普通路由取消阻止本轮HTTP，正在取样最多有界结束并只更新同账号缓存。不向500行ConversationController添加职责。时间/权限快照等非位置上下文独立跟踪，不能把本批当完整UserContext迁移。

微批≤3文件；测试覆盖缓存/失败/取消/账号、真实HTTP适配合并、通道无主动请求权限、开发者只读及显式MOCK共享控制器；Web不调用原生，合成页面不发真实API。验证全量/analyze/OpenSpec/Web/Android/iOS无签名构建，真实定位/权限和双端安装集中验收。列表持久本地记录语义及权限重置仍在2.2d，不用空实现勾选。

### 真实系统网络状态输入（2026-09-18）

固定v65 network/ValidatedInternetAvailability.kt要求activeNetwork具备INTERNET和VALIDATED；Android已有ACCESS_NETWORK_STATE普通权限，无运行时弹窗。iOS参考ddb996a的AIDeveloperToolsViewController仅存网络选项，未发现业务侧reachability消费者，不搬旧NSUserDefaults假状态。iOS新增NWPathMonitor一次取样，必须等首次回调，明确unsatisfied判不可用；requiresConnection及超时为unknown，允许原业务尝试。Web不把不可靠navigator.onLine当硬门禁，返回unknown保留真实HTTP错误处理。路径可用/VALIDATED不等于目标API可达，不能用于宣称业务成功。

共享domain/network_availability.dart、presentation/controller/online_entry_controller.dart负责入口租约、重复点击抑制、检测单飞/有界等待、模式优先及晚到保护；source返回available/unavailable/unknown，异常或3秒超时为unknown，禁止假造available。未知允许真实业务尝试，正常错误仍走原有处理。UI只调用控制器，弹窗初始明确离线或模拟离线，重试重新检测且不自动重放；关闭/离页释放本次租约。原生仅只读OS状态，不发探测HTTP，不读取SSID/IP/设备身份，不新增日志敏感字段。

微批：domain/network_availability.dart、controller/online_entry_controller.dart、data/device_network_availability.dart；Android NetworkAvailabilityChannel.kt/MainActivity.kt；iOS NetworkAvailabilityChannel.swift/AppDelegate.swift/project.pbxproj；app/online_entry_providers.dart和widgets/online_entry_guard.dart替换原模拟专用命名；既有三入口/预览和测试分批更新。NWPathMonitor每次请求完成/2秒超时/engine detach均停止，同一结果只交付一次。Flutter provider变化关闭旧控制器，弹窗继承同一容器；MOCK覆盖模式及source，增加系统在线/离线/检测失败切换，不能调用原生。无需更新依赖。

验证纯Dart租约/超时/模式切换/关闭、通道畸形/插件缺失、正式入口与隔离作用域、全量test/analyze/OpenSpec、Web/Android/iOS无签名构建和浏览器恢复路径。双端飞行模式/无互联网Wi-Fi/VPN切换保留集中人工验收；不安装未经重新授权的设备包。2.2d1只完成联网输入，列表/定位摘要/模拟权限和父任务继续未完成。

### 开发者网络模拟正式消费者（2026-09-18）

依据固定v65 AssistantOnlineEntryNetworkGuard、AssistantRootActionGraph、AssistantRootCallEntryActions、AssistantOverlayPermissionActions及V88NetworkStatusLayer：正常/弱网/断网是进程内状态，弱网只提示，不注入延时或拦截所有HTTP。断网阻止首页在线入口、进入统一会话/任务恢复、联系人需求和翻译呼叫；普通系统拨号不受影响。重试在仍为断网时保留提示，否则只关闭提示，不自动执行原操作。外部点击/返回可关闭提示。实际系统validated internet检测是另一输入，本子批不伪装已实现，保留2.2d。

微批文件：domain/developer_network_mode.dart、app/developer_network_providers.dart、widgets/developer_network_controls.dart；widgets/developer_network_guard.dart、pages/developer_tools_route.dart、pages/developer_network_preview_page.dart；shell_route.dart、contact_actions.dart、translation_dialer_route.dart；演练入口/测试和记录。共享Dart状态与控件；弹窗/新路由显式继承Provider容器，隔离演练新建模式作用域，禁止父子污染。普通真实入口仅读取模拟模式，不触发系统权限/电话；切换不会取消已有会话、请求或媒体，也不删除真实列表。测试包含正式路由拦截及MOCK计数，不用仅有按钮切换证明消费者完成。每批≤3文件，视觉后置。

列表动作已追到AssistantDeveloperDataModeActions，清空只作用本地通话/联系人，不删除后台任务；权限重置还会重开翻译拨号和重置本地定位提示，不能直接改成撤销OS授权。本子批不迁移这些行为，2.2父任务保持未完成。

### 固定外呼号码正式接线（2026-09-18）

固定v65 AssistantOutboundNumberRuntimeController/FinalOutboundNumberPageV3/normalizeOutboundDialNumber及TaskApiService、AccountSettingsController：账号级GET/POST/DELETE api/account/settings/outbound-number，POST仅outboundNumber。沿AccountApi账号头和代次隔离；响应accountId必须匹配，configured保留服务端值，成功才更新快照并返回开发者页。号码按v65全角/分隔符/中国国家码规则，不沿用演练3–15位限制、不添加App侧拨号目标覆盖。iOS指定参考提交未找到此配置实现，直接复用Dart，不新增原生接口。

微批：domain/outbound_number.dart、data/api_outbound_number_repository.dart、controller/outbound_number_controller.dart；app/outbound_number_providers.dart、正式page、正式route；开发者入口/内存演练适配及测试。Controller读取/编辑/保存/删除单飞，空输入只本地提示，失败保留草稿、不自动重复写；显式重试前可重新读取权威状态。关闭和账号切换丢弃旧回调，不在日志中记录号码或响应。页面复用既有控件，键盘小屏可滚动，按用户要求视觉后校准。

自动验证使用严格隔离合成仓库/HTTP；不访问真实固定号码、不发送真实POST/DELETE，不拨打电话。Web演练改为正式页面注入内存仓库，支持读/写失败和重开恢复。新增真实消费者只限固定号码；列表/网络/模拟权限仍未完成，不提前勾选2.2。验证analyze/full tests/OpenSpec/Web/Android/iOS构建及浏览器合成保存/删除/返回。

### 开发者翻译配置真实接线（2026-09-18）

替换设置中开发者总占位页为DeveloperToolsRoute：必须已进程解锁，实时翻译子区使用既有TranslationSetupController/安全存储，持久强制海外布尔、US/JP与OPENAI/GEMINI；构建开关关闭时隐藏整个调试区且策略不消费持久force值，不新增仅debug或仅测试环境限制。普通拨号模型消费者共用TranslationAccess策略；定位未知时可强制选择但不允许实际call准入。强制不会改服务节点，按v65策略而非已过时“固定US”文案。未迁移的固定号码/列表/网络/模拟权限仍进入明确MOCK页，本批不得勾选整个2.2。不会开启实际电话/媒体。

### 启动检查与强制响应续接（2026-09-18）

重新核对固定v65 AssistantOtaRuntimeController/FinalScreenContract：先恢复活动下载，有记录直接恢复且不先请求版本；否则forceRequired或lastSuccessDate不是本地当天才检查。成功（含手动检查）保存当天与hasUpdate&&forceUpdate；失败不写日期，不清force标记。普通启动失败静默，既有force失败提示；原实现没有缓存标记驱动的离线封锁，旧文档“持久强制门禁”应解释为持久标记驱动复查+有效强制响应不可关闭，不能新增离线锁死。

实施2.1d1：domain/startup_update.dart定义日期/标记和恢复端口，data/secure_startup_update_store.dart按环境/API/包隔离设备偏好，controller/startup_update_controller.dart单飞/账号/关闭保护、恢复优先与手动结果共享。native UpdateDownloadStore/UpdateInstallChannel增加当前scope记录只读peek（无URL/请求头），保留force/notes；已安装目标版本的自有旧job清理，不处理别的scope。恢复无URL且失败要重查授权信息，不能向空地址下载。

装配现有app/app_update_providers.dart、startup_update_host.dart、startup_update_dialog.dart；AuthRoute仅Android已登录挂载，dialog禁止外部点击关闭、强制响应禁止返回/稍后，接已有安装页；Web/iOS不触发正式检查，开发者新增独立合成启动/强制/恢复演练。手动AppUpdateController通过已验证结果回调复用同一持久状态；SharedAppUpdateRepository只合并同包版本进行中的请求，不缓存历史结果。所有下载仍由用户选择或旧系统任务继续，不静默创建新任务、不安装真机、不改Release门禁。

弹窗和安装路由显式继承Host的ProviderContainer，避免Navigator位于嵌套ProviderScope上方时，MOCK跨路由落回正式Provider。自动测试把根正式Provider设置为抛错，证明强制弹窗、安装页、解除提示和恢复刷新均未逃出合成容器；预览仍复用正式状态和页面，不使用真实账号/网络/下载。

每手写微批≤3文件、每文件≤500；新页面复用现有ShellTokens，视觉后置。自动验证覆盖本地日期/失败不记成功/force复查/手动解除/旧账号晚到/持久失败/已有下载恢复/错包版本/两端显隐与取消、浏览器合成完整导航；全量test/analyze/OpenSpec/Web/Android构建。正式同签名旧登录/数据导入与双端安装为2.1d2，必须保留未完成。

### 手动更新安装链路（2026-09-18）

按固定v65 FinalOtaUpdateInstaller/AssistantOtaRuntimeController接续手动版本检查。共享Dart负责Idle→Downloading/Paused→Verifying→Ready→Permission/Installing→返回待安装或失败；系统安装器返回不等于升级成功。Android薄端口使用DownloadManager保留后台任务，记录环境/API/账号/包范围的opaque job及不含URL/下载头的版本元数据，进程重建可重新附着。只有显式用户开始更新才enqueue，恢复只query；显式关闭取消本任务，普通dispose停止观察但不删除后台任务。iOS不注册/显示入口，Web只能独立MOCK。

原生仅提供系统下载、文件/包证据和系统Intent。下载文件进入自有私有目录后校验SHA256/大小、实际包名与版本和已安装证书；系统PackageInstaller仍是最终签名/安装权威，不把Intent成功当升级成功。安装前再次验证，FileProvider只暴露专用APK目录，不接受Dart任意文件路径。账号Bearer不附加到外部APK地址，只使用服务端下载契约给出的头且不记录其值。实际下载URL可能为对象存储签名URL，不能强行改为API同源。

微批：domain/update_install.dart + controller/update_install_controller.dart + data/device_update_install_port.dart；Android ota目录按download store/package inspection/channel拆分，Manifest/FileProvider/MainActivity机械接线另批；共享安装页/预览/入口三文件批；unit/widget/channel与Android构建。必须保留系统下载恢复及强制升级最终待办，不能用前台下载或UI模拟替代完整迁移。启动每日检查、全App持久强制门禁与正式升级兼容独立由2.1d完成，本批不解开release保护、不安装设备。

### 结构化诊断日志真实上报（2026-09-17）

v65 TaskApiService/TaskRepository/AssistantLogUploadRuntimeController：POST api/logs/upload multipart(file/accountId/deviceInfo)，只有成功才清日志。Flutter不复制旧任意文本/对话正文日志，新增core/diagnostics结构化白名单事件与有界快照；只存固定枚举、时间、状态码、耗时、UUID关联，不存请求/响应正文、URL、令牌、号码或异常全文。按环境/API/账号隔离，现有安全存储限量256条，500ms批量写入，上传前flush；读取失败禁止默认覆盖，写失败保留内存。成功仅移除已上传序号范围，上传过程新事件保留。

微批1：diagnostic_event.dart、diagnostic_journal.dart、secure_diagnostic_store.dart；微批2：app_log_report.dart、zip_log_repository.dart、pubspec archive固定3.6.1；微批3：log_report_controller.dart、log_report_page.dart、diagnostics_providers.dart；后续小批接AccountApi与AgentGateway结构事件、settings入口和测试。UI不直接网络/存储，生成ZIP及transport注入；真实发送由页面明确按钮触发，不自动上传。本轮自动验收只用合成仓库与HTTP adapter，不上传真实日志。

与旧版差异：固定v65导出自身15天轮转文本文件，不是整机logcat；当前不导入旧日志，保留账号范围最近256条结构事件，15天归档及完整native crash/音频日志仍待补齐。日志ZIP使用纯Dart archive.dart（Android/iOS/Web共享），无原生压缩插件。真实设备信息暂为Flutter平台及编译版本，不伪造硬件型号；旧接口deviceInfo是可选说明。网络未知失败不自动重传；上传成功后清理失败显示“已上传，本地清理失败”，仅重试清理，不再次POST。

### 真实版本检查子批（2026-09-17）

新增app_update feature：实际安装包身份由Android PackageManager薄通道提供，不硬编码v65或pubspec版本；共享repository经AccountApi调用POST api/ota/check，字段遵循v65 TaskRepository/OtaDtos，deviceId沿账号ID语义，不读取硬件标识。校验响应包名、布尔与版本元数据，不把错误当“最新”。页面共享检查/新版本/无更新/失败重试和晚到保护；Android设置接正式查询，Web debug注入隔离合成源，同一页面再链接原下载/安装演练。iOS继续隐藏且端口不调用。

本子批只检查：不下载APK，不申请未知来源，不发布新版，不启用启动检查/强制门禁，forceUpdate只如实显示重要更新及尚未启用说明，避免无安装出口锁死。Flutter当前1.0.0+1/.dev不能证明覆盖v65；正式release构建现有门禁保持，必须后续验签、版本递增、旧数据迁移和回滚。版本查询不等于2.1整体完成。

- ShellRoute 仅挂 SettingsRoute，不继续聚合业务；新增 settings/domain/original_audio_settings.dart、data/secure_original_audio_store.dart、presentation/controller/original_audio_controller.dart、pages/settings_route.dart、settings_page.dart、original_audio_page.dart、developer_preview_page.dart、service_preview_page.dart、widgets/logout_dialog.dart、app/settings_providers.dart。
- 原音默认 false/50/100；增益0–50、音量0–100四舍五入10步进。沿 v65 为设备偏好而非账号身份；存储命名空间隔离环境。单控制器串行持久化最新快照，失败保留草稿/重试，不显示已保存。关闭不清参数。
- 开发者解锁保持20142014*#，进程内布尔不写磁盘，无仅Debug限制；MOCK拨号不解锁正式状态。设置页只有已解锁时显示开发者入口，子工具明确为MOCK，后续用真实端口替换。
- 初始日志和OTA普通入口说明未接入，后续按上方真实子批替换：日志正式准备/手动上传，Android正式版本检查。独立演练仍不含真实文件/账号/网络，Web可演练Android OTA，不给iOS生产入口。退出演练丢弃内存。
- 退出使用既有SessionController.signOut，只在确认后调用；保存中防重复和返回，失败留弹层并重试。自动验收不退出真实账号。
- 每批≤3文件；UI用真实控件、Navigator/PopScope和SafeArea；复用ShellTokens/已有SVG，不生成设计播放器。原音滑条依据v65补足原型差异。

## Risks / Trade-offs

### 迁移演练发布边界（2026-09-20）

2026-09-21增量：正式main Web Release产物复核发现附件菜单虽隐藏演练项，结果处理器仍编译合成文档/OCR分支。仅在`conversation_attachments.dart`的两个演练结果分支增加同一编译常量短路；关闭时直接返回，不能落入真实文档选择。新增正式App弹层结果回归（开启/关闭两次定向），以及编译产物标记核验脚本：同时检查已知演练入口/附件合成标记不存在、原有开发者/身份/文档入口存在，避免空产物假通过。产物文本检查不等于全部路由或原生Release验收；不笼统禁止所有MOCK字样，因为部分正式控件复用可选预览参数，且真实声音试听也叫preview。独立输出目录构建，不覆盖8080/8122；不发SMS、认证、电话或安装，不改变后台/权限/媒体协议。

入口漏检修复：日志页onPreview、音色页克隆演练沿同一Debug+ENABLE_MIGRATION_PREVIEWS边界隐藏；把现有常量提取到core/config/migration_previews.dart，已有联系人/拨号/翻译/附件/设置Web入口使用同一开关。正式上传/创建克隆、原开发者工具及独立tool/previews目标不改变。不以文件名含preview判定演练（真实克隆试听也称preview）。仅导航显隐，无状态/API/原生/日志字段变化，按settings-interactions已有隔离要求补漏，不增加产品功能。

DeveloperToolsRoute 的4个新增MOCK入口及演练说明仅在 `kDebugMode && bool.fromEnvironment('ENABLE_MIGRATION_PREVIEWS', defaultValue: true)` 时显示。Debug可通过编译参数关闭，Profile/Release不能通过该参数开启；不改变进程内开发者解锁，也不隐藏v65原有翻译配置、网络模拟、列表、定位、固定号码和权限提示重置。此处是导航可见性门禁，不是鉴权，不声称完成全项目发布入口审计。

同一专项测试分别在默认Debug和关闭参数下检查完整列表与原有控件交互，另编译Web Release验证常量路径。独立Web演练目标及集中真机、视觉验收仍保留各自范围。

- MOCK混真实 -> 不注入AccountApi或原生权限端口，持续标识，不把模拟输出写正式偏好。
- 偏好并发覆盖 -> 串行写与版本门禁，初始化失败禁止默认覆盖旧存储。
- 仅UI成功误报完整迁移 -> 文档分开已接入/未接入，媒体和OTA升级兼容仍待办。
- 未验收 -> 不同步主规范/不归档，遵循项目规则。
