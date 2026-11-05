## Context

行为证据：FinalTasksPageV3 无 session 分支 onOpenResult → openAssistantTaskResult → onEnterConversationWithPermission(null)。翻译专门 onOpenRealtimeTranslation(callId)。PhoneAgentRealtimeTranslationApi/DTO/Repository 定义详情与录音容错。不从设计 resultPage 推导新入口。

## Goals / Non-Goals

目标：准确读取翻译历史并从任务卡打开；错误重试、晚到隔离；普通记录入口符合 v65。非目标：新翻译拨号、归档、录音上传/播放、旧独立结果页、支付、评价提交。

## Decisions

### SDK采集占用接续（2026-09-18）

2.10b2d将正式身份采集接入同一个AudioPlaybackFocus，prepare仅准备元信息，capture前取得不可被试听抢占的租约。FocusedIdentityCapturePort装饰现有采集端口，等待旧播放停止后才调用SDK；退出和账号变化使等待失效。采集返回不直接证明硬件释放，新增waitForRelease通道，成功/异常/取消均在实际释放确认后归还租约。

Android release失败保留原句柄和占用，abort可重试；准备中取消也等待后台准备结束。iOS没有公开abort API，取消可先结束业务等待，但waitForRelease必须等供应商完成及自身容器关闭，不以超时解锁。超时只使停止请求失败，不允许新播放；供应商永不回调的风险留集中人工验证。新账号仍共用旧focus，不能绕过占用。

≤3文件微批：本设计/spec/tasks；DeviceIdentityCapturePort与双端通道；共享FocusedIdentityCapturePort与测试、生产provider；Web合成端口/控制器/页面及测试；文档。无实际身份采集、权限或短信/电话；单测模拟延迟释放、失败保留、取消和旧请求，三端构建及隔离Web操作，不把MOCK当真实SDK验收。

### 跨模块播放占用（2026-09-18）

先接通已存在的普通回执录音、翻译历史录音与克隆试听，不能把尚未实现的TTS/监听/翻译实时媒体标成接通。core/audio新增共享异步AudioPlaybackFocus，以现有AudioResourceCoordinator为唯一租约事实；用户新播放可请求停止可中断旧播放，必须等待真实stop/pause完成后换租约。停止失败/超时保留旧占用且阻止第二播放器，支持显式重试；新请求/账号切换失效旧排队请求，迟到释放不能释放别人。未来录音/实时媒体使用同一租约且可声明不可由普通试听抢占。

生产app只提供一个进程级focus实例，账号变化停止旧播放但不提前换实例绕过尚未完成释放；每个播放器还检查自身账号/页面归属。普通/翻译以FocusedRecordingPlayer装饰PluginRecordingPlayer，只在play/resume时申请，prepare不自动播放；被打断后发paused事实，不自动恢复。克隆以FocusedClonePreviewPlayer包裹既有PluginClonePreviewPlayer，先申请再播放，停止和自然完成均等待真实关闭后释放。底层两个插件适配器保留dispose失败句柄供重试。业务状态仍由原Controller消费，UI不触碰原生端口。失败提示复用已有清洗后的音频错误，不记录URL/文件/音频内容。

微批不超过3文件：先本设计/spec/tasks；core focus+测试+provider；录音播放器及测试；克隆装饰器及测试；三个正式provider；共享合成演练及记录。自动验证并发/迟到/暂停/失败/换账号，不真实录音/播放/安装；全局媒体父项仍包含未来TTS/实时链路和双端人工验收，不整项勾选。

### 活动批量进度与退出接收（2026-09-18）

固定v65 AgentStreamBatchCallActiveStateHolder/TaskBatchCallProgressPolicy按命令步骤、batchId和正itemIndex聚合，total取最大提示，按序号展示；makeBatchCalls tool start立即标活动，无非空状态文案不造进度。最终快照替换临时结果，失败只把仍运行项标为结果未完整返回，不把断流当成功。Done无最终结果保留快照、提示同步，不伪造已持久终态。

AgentStreamHandler.interruptCurrentStream保留活动批量流；EventSessionGate在退出后忽略旧会话事件，只释放终态标记；TurnRunner活动批量期间拒绝新轮。本项目不复制旧巨型ViewModel：domain/receipts/batch_progress_tracker.dart负责纯聚合，ConversationMessageStore集中事实视图/临时消息投影，ConversationEventStream可脱离UI接收；账号级DetachedBatchStreams保留该订阅直到Done/关闭/错误、阻止活动期重复新轮，账号代次替换关闭。脱离后不执行工具/权限/确认，不更新其他页面，只在结束时使任务列表下次读取失效；重新进入仍用历史权威恢复，不自动重拨。

修改按≤3文件微批实施，控制器接近500行先提取临时消息操作。合成SSE/状态/生命周期/页面回归及Web浏览器验证，三端编译；不触发真实电话/费用/短信、不改后端、数据库、提示词、SIP、ASR/TTS。跨进程后台存活和真实服务持久结果需集中验收，不承诺OS杀进程后仍有客户端订阅。

### 普通录音正式保存与页面装配（2026-09-18）

2.10b2继续实现普通单路保存及正式回执接线。共享domain/call_recording_save.dart定义保存目的地、下载与用例；data/call_recording_file_download.dart以独立无凭据Dio流下载到本次私有临时文件，校验可选服务端长度/HTTP长度，计算本地SHA256供平台复制时完整性检查（不是远端真实性证明），成功/失败/退出清本次文件，不复用翻译远端摘要缓存。下载设置512MiB资源保护上限，无整段内存缓存、不跟随重定向。使用v65 call-recording-<callId安全后48位>.m4a命名，不做转码。

Android新增薄RecordingDestinationChannel与MainActivity注册：choose只返回本次是否选择、URI留原生；write只接受本次ID及现有缓存根内本地资产，复核长度/hash，失败或取消仅清本次新建文档。iOS复用RecordingExportChannel导出副本，不修改其已有文件校验。Dart DeviceCallRecordingDestination统一reserve/write/abort语义，按平台决定选择在下载前或导出时发生；独立save controller，不用播放缓存代替新token，不因保存失败关闭播放。

app/call_recording_providers.dart注入真实repo/player/saver；ConversationRecordingsController由会话宿主持有按callId的条目，离屏只停metadata，不销毁播放；账号/退出关闭全部。ConversationRecordingHost处理生命周期与切语音/显示通话页的停止，CallRecordingRoute只消费条目状态和回调。Web生产仅给明确能力提示；隔离演练复用同一核心，正式provider不注入MOCK。微批≤3文件，500行上限；无后端/数据库/提示词/SIP/ASR/TTS修改。合成HTTP/临时字节/平台通道、宿主Widget与三端构建验证，真实声音/系统保存和跨TTS/克隆/翻译仲裁仍集中验收，不以测试替代。

### 普通录音真实协议与播放接续（2026-09-18）

补充后端证据：固定v65 AgentCallRecordingController.PlaybackView实际包含可选sizeBytes/expiresAt；安卓DTO未消费这两项，并非服务端没有。没有SHA256/cacheKey，不伪造远端摘要。RecordingAccountPrincipalResolver沿AccountIdentityService读取已有X-Account-Id，不新增登录或短信流程。播放地址只允许当前API上下文下recording-content的令牌路径；不把账号头送给播放器。

2.10b分为协议/共享播放核心与正式装配/保存/集中验收，父任务保持未完成。依次微批：domain/call_recording.dart、data/api_call_recording_repository.dart、合成协议测试；共享RecordingAudioAsset增加明确远程源、PluginRecordingPlayer按源选URL/文件、对应播放器测试；普通metadata观察器和播放互斥协调器及回归。metadata不自动获取播放token，RECORDING/PROCESSING每2秒观察、最长60秒；错误保留已有数据，播放/重播/重试才取新token。复用翻译控制器但不改变翻译缓存/预加载/导出校验。每批≤3文件；不请求真实录音，不把协议测试当作系统播放或完整普通录音已交付。

普通保存后续必须先Android选择目标再取新源；iOS走系统export-as-copy，不强行假装平台顺序一致。全局TTS/翻译/克隆媒体仲裁、正式页面接线和双端设备仍须完整验证。原生URL播放的重定向策略属于插件，不宣称Dart控制了原生HTTP；初始源严格同源且不附加账号凭据。

### 普通单路与批量录音交互接续（2026-09-18）

固定v65 PureVoiceThreadList仅在有可见双方转写且metadata.callId存在时在单路结果前显示完整录音卡；BatchPlusCallResultItem使用item.callId，若有最后一条billingSummary则connectedDurationMs必须大于0，无结算时允许已有callId；批量仅紧凑播放键，不新增保存/完整录音卡。不能拿displayDurationSeconds或较早结算替代最后接通时长。

普通CallRecordingApi为agent-calls/{callId}/recording及recording/play-token，播放token DTO只有url/contentType，没有翻译录音的cacheKey/size/SHA256。普通点击播放才取播放源，不应照搬翻译页自动预下载。本子批2.10a只交付共享按需控件、显隐和隔离回执演练，真实网络/保存协议单列2.10b，不能伪造服务器摘要以强行复用。已有RecordingAudioController增加可选按操作加载策略，默认翻译预加载语义不变；播放器、状态与保存演练复用现有端口，正式回执尚不注入模拟组件。

微批：call_receipt.dart、batch_receipt.dart补接通时长/显隐领域；RecordingAudioController、RecordingAudioCard增加可选按需行为，独立CallRecordingControl处理紧凑外观；CallReceiptCard/BatchReceiptCard/ConversationMessageTile纯builder插槽，ConversationPage传递；ReceiptPreviewPage注入独立合成端口。每批≤3文件，默认≤500行；不改SIP/ASR/TTS、数据库、服务接口，不发真实录音请求。自动测试覆盖来源锚点、最后结算、无转写、懒加载/重试/取消保存/相互切换及320/390/430布局，完整test/analyze/Web/Android构建。视觉统一后置。

### 翻译历史录音接续（2026-09-18）

2.9b实施：新增data/recording_file_downloader.dart（私有目录SHA256命名、跨实例串行、大小/hash/Range/206/416校验）、io_recording_repository.dart（源解析与缓存组合）、plugin_recording_player.dart（现有audioplayers串行生命周期）、device_recording_exporter.dart（指定资产导出/取消）；conditional factory隔离Web无IO。文件名不作为磁盘路径；cache key加入环境/API/账号/call、服务端cacheKey/size/hash，不持久化URL/请求头。系统目录由同一导出通道提供，仅缓存已校验文件，失败半文件可在非强制重试重入续传，明确重试清缓存。

原生微批：Android RecordingExportChannel.kt / MainActivity.kt；iOS RecordingExportChannel.swift / AppDelegate.swift / project.pbxproj。仅私有缓存根目录和系统创建/导出文档，校验源文件归属、长度、SHA256；不请求广泛存储权限。取消/关页按导出操作ID撤销本次等待，不能删除用户其他文件或误报成功。随后app/recording_providers.dart、pages/recording_audio_route.dart和TranslationHistoryRoute接正式插槽；带字幕读取失败仍不被音频影响。

验证使用临时合成字节/HTTP/平台通道，覆盖缓存命中/篡改、断流、Range忽略/错误/416、单飞、账号/关闭、播放器重播与释放、导出取消和页面挂载。Web/Android/iOS无签名构建；不下载安装真机、不请求真实录音。普通单路/批量复用与跨模块媒体互斥仍独立2.10，不能由本批代替。

执行顺序细化：2.9a先交付共享状态、完整页面控件和Web演练，协议解析仅以合成HTTP验证，不在正式历史页装配真实下载/播放。2.9b再接入缓存、播放器和系统保存，以保持用户要求的交互优先顺序。2.9a不触及平台媒体或原生工程，正式页尚未接入时保留真实能力边界提示。

按v65 RealtimeTranslationHistoryRoute/ViewModel、RecordingPresentation/SaveCoordinator、WorldCallRecordingRepository和RecordingDownloadRepository实现。详情有录音时预加载而不自动播放；Failed重试须刷新详情/grant并失效旧缓存；WORLD_CALL固定US/JP端点POST play-token，只有RECORDING_NOT_READY按retryAfter累计最多120秒等待。签名下载URL只能HTTPS，不带账号或grant；PHONE_AGENT仅同源当前call录音路径加X-Account-Id，不把账号凭据传任意URL。保持文件大小/SHA256、缓存复核、Range续传与416一次全量重试。不迁移国内SIP拨号，但原国内历史保持可读。

共享Dart负责协议、缓存流、状态和UI；audioplayers6.4.0复用已有平台实现；仅Android CreateDocument/iOS export document picker为新薄端口。历史资料与下载凭据不进入录音UI状态/日志。播放/暂停/剩余时长/保存/重试是当前功能，没有seek拖动。iOS参考固定ddb996a的AVAudioPlayer文件播放和退出释放；其Calls历史未找到同等录音卡，不据此删掉Android既有功能。

实现微批：domain/recording_audio.dart、controller/recording_audio_controller.dart、data/recording_source_resolver.dart；IO校验缓存/适配工厂/播放器；双端导出通道与宿主接线；共享录音卡/页面插槽/provider；明确MOCK场景/入口和测试。手写文件≤500，每批≤3文件。Web不能使用原生文件缓存，正式页面明确平台能力边界，隔离演练复用完整页面/控制器且无真实录音请求。视觉复用已治理录音保存SVG/现有CSS参数，统一校准后置。

自动验证不读取、播放或导出真实通话录音；仅合成HTTP/文件/播放器/保存结果。后续集中验收须验证真实声音、系统文件选择、失败清理与跨模块音频互斥，不能用构建成功代表通过。

### 共享回执卡展示批次（2026-09-17）

用户已允许静态HTML/CSS与组件先行，以下历史运行态视觉门禁不再阻止实现，但不宣称视觉验收。本批按v65 PureVoiceCallCards/PureVoiceCallResultPresentation、BatchPlusCallCard/BatchPlusCallResultItem/LargeTaskCardShell实现有效结构；不迁移旧固定餐厅回执弹窗或AgentCallResultCard原始metadata表。静态样式来自0cd58de style.css的pv-summary-card/pv-static-transcript-label和v65批量卡参数，记录到design/receipts。

新增core/design/receipt_tokens.dart、conversation/widgets/receipts/{call_receipt_card,batch_receipt_card,receipt_sections}.dart，修改conversation_message_tile.dart按类型分派，保留已有反馈builder。单路独立转写和结果卡；批量进度不是成功率，逐项转写默认折叠并在item身份/status/transcript变化后重置。合成演练从正式App开发者入口可达，使用同一ConversationPage/组件、不读真实账号或发API。新增卡片回归/连续导航；完整测试/analyze/Web/Android构建。无接口/数据库/提示词/日志正文/SIP/ASR/TTS修改，录音真实能力、活动批量流退出例外及精细视觉仍单列。

- domain 类型化 route/transcript/recording metadata，data 负责严格 DTO 映射；controller 负责 loading/content/error，UI只接状态/回调。
- API 返回 callId 必须与请求相同；顶层异常失败，录音元数据异常仅丢弃录音不丢字幕。WORLD_CALL 定位需要 clusterId+callSessionId+grant，PHONE_AGENT 元数据按旧规则检查。授权只留 data/domain，不写 UI/日志。
- 不过滤 final=false 字幕；仅展示双方非空文本。只读加载不触发世界集群媒体访问。
- 旧国内历史可查看不等于新增国内 SIP 功能。
- 设计用现有 translationHistory 节点，按实际 HTML 查明路由；SafeArea/竖屏/平台字体允许差异。

## Validation

合成 API 字段、错 callId/route/录音异常、字幕保留、账号切换、controller 退出晚到；widget 小屏/错误重试；设备 task → translation → back 与 ordinary record → unified；完整 analyze/test/Android/OpenSpec。无真实录音或通话请求。

## Risks / Trade-offs

只读批次不声明完整翻译模块。音频按钮明确后置，不伪装可播放。统一回执仍独立后续实现，不能把旧 resultPage 接入代替它。

## 统一确认卡增量（2026-09-16）

先实施现有 2.1 的确认展示子项，随后继续单路/批量回执。源依据 v65 ConversationLedgerTimelineMapper.callConfirmation/rejectedCallConfirmationRemoval、CallConfirmationPresentationPolicy、PureVoiceCallConfirmSummaryCard、AgentStreamClientPayloadMappers。

- 纯 Dart CallConfirmation 读取 targetName/phoneNumber/primaryGoal/summaryLines/recipientCount，嵌入数组和 JSON 字符串严格按已知字段解析。makeBatchCalls 从 recipientsJson 的有效 targetName 形成摘要，未返回电话不补造。
- TOOL_REQUESTED 的 makeCall/makeBatchCalls 生成只读确认卡，不要求 displayPayloadVersion（此两类并无该字段）。同工具 ID 更新；后续 policy_rejected/rejected 移除该确认，不移除其他轮次。
- call_ready 和旧 MAKE_CALL_REQUEST 走同一模型，持久副本替换临时卡；普通 AI 文本不能覆盖卡，卡不能吞掉回答。恢复只展示，不触发 confirm_call 或后台电话。
- 本子项不改变自动执行策略；当前未接入调用仍明确提示未执行。后续单路自动确认/积分门禁/通话页面、批量编排继续待办。
- 确认卡按固定设计 .pv-summary-card 样式，源代码业务字段优先。无新增确认执行按钮；批量“大任务快照确认”是另外一种卡，不能合并到此模型。
- 三文件领域/投影/测试 → 消息/控制器/回归 → 展示/布局测试。无后端、数据库、提示词、媒体或真实外呼修改。主规格在验收后合并，不提前归档。
- tool/previews/conversation_preview.dart 是独立 debug-only 离线验收入口，复用正式组件并固定显示 MOCK 标识，不导入认证/网络装配、不保存账号、不发起通话，不是正式导航替代品。浏览器可以无人工触发查看单路/多路确认样例，完成后关闭该预览服务；普通 App 主入口不变。

## 单路回执增量

按 v65 CallAttemptTimelineProjector 聚合同 session + callAttemptId 的事实。首个 CALL_REQUESTED 决定展示位置，后续 STARTED/终态/OUTCOME 更新同一个回执；不同 attempt 不按 taskId 混合。OUTCOME 的 SUCCESS/COMPLETED、CANCELLED/USER_CANCELLED、UNCLEAR、FAILED/NEEDS_RECALL 按原 transport policy 映射；没有语义 outcome 时保留物理状态，不凭 SSE done 推导业务成功。

callReceipt 优先终态再 started；目标、摘要、原因、逐字稿按原源代码回退顺序读取。保留有效 receiptFields 与计费摘要；缺字段不补造收费/余额。无 callAttemptId 的旧终态只能按 eventId 单独呈现，不合并到其他尝试。未知事件/schema 不造回执。领域聚合不访问网络，UI 只展示和展开，不追加拨号/挂断/评价请求。

本批先领域模型/聚合/合成测试，再 ledger 与实时 final 接入、共享 UI 与浏览器预览；随后继续批量回执/评分等剩余任务。完整状态条依赖单路/批量状态事实，不以本批替代完整通话编排。

视觉门禁：现有运行态设计快照没有动态结果卡，浏览器拒绝本地 file 访问；已询问可访问设计地址，不绕过限制。新增专用转写/结果卡暂停生成。期间仅复用已有普通消息布局输出可读结果文本（presentation 的 CallReceiptText），明确不是最终卡片设计。领域/实时/历史接入与该临时可读性作为独立 2.6 子项验收，不勾选 2.5 完整视觉。

补充 v65 TaskCallResultDisplayPolicy：物理 COMPLETED 不证明业务成功；agentOutcome 与 resultCode 优先，未确认、业务失败、技术异常保持区分。模型保留 metadata 仅供解析，不展示原始 metadata 表；转写按 AgentStreamCallTranscriptPolicy 识别双方角色、保留重复发言，不把总结行当通话。费率/时长/积分仅展示实际返回的有效字段。显式 attempt 不同不能因 callId 相同合并。

## 批量结果快照增量

- 固定 v65 ConversationLedgerTimelineMapper、ConversationTimelineReducer、TaskReceiptOutcome、BatchPlusCallCard 为依据；直接 batchCallResult 或 result.batchCallResult 两种持久位置都读取。ASSISTANT_TURN_COMMITTED 的普通文字与批量结果同时保留。
- 以 session + batchId 更新首个快照位置；无 batchId 的历史结果只按事件 ID 隔离。快照是替换，不凭空把已被后端移除的旧 item 并回去。items 的 attempts、recalled/abnormal、各次 billingSummaries 和 callId 不丢失。
- 批量 item 的 transport outcome 与单路语义判定不同：COMPLETED 可作为 item 成功，未知/PENDING/NEEDS_RECALL 视为待确认；总进度按 max(totalCount, items.length)，不得因父状态结束就把仍运行的项算完成。
- 所有 item 尝试次数为 0 且积分不足时不造“已外呼”的结果卡；保留服务端说明，历史多路说明沿用现有前缀。后端 ToolEventNormalizer.batchCallResultEvents 对失败批次也发 task_completed，保留该真实路径的失败明细；不扩展 task_failed 的旧客户端行为。实时终态遇到同身份的旧运行中快照时原位保留终态；持久终态到达后再取持久结果，依据 TimelineSnapshotUiProjector.promoteCurrentTerminalPresentation。
- 本子项先完成类型、快照投影、SSE 结果读取与测试；专用批量卡设计仍受动态运行态门禁约束，暂复用现有消息文本。逐项 batch progress、活动流退出例外、录音/下载/赞踩/评分及真实外呼编排另列，不能以结果读取代替执行实现。
