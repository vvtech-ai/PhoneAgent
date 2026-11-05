## Context

### 2026-10-10 合入最新 codex/dev

用户明确授权切换开发目标到 codex/dev。本次三方合并保留 origin/codex/dev c75511de 的可信来电生命周期、iOS 16.1/身份事件、翻译音频和依赖版本，以及任务分支 b005131b 的首页、对话、列表、详情和会议修复。现有隔离工作树切换到本地 codex/dev，原 foundation 工作区不动；不改后端或数据库，不重建任务状态机。

自动 Git 合并作为机械批次记录，手写冲突/文档仍按每批至多三个文件。AndroidManifest 冲突采用最新 dev 的供应商组件所有权，额外保留任务分支圆形图标；不能恢复已经移除的旧 Flutter 可信来电适配组件。tasks.md 和问题日志保留双方历史。依赖锁保留 dev 新版本及任务新增的直接依赖；固定 Flutter 3.32 验证，不隐式升级工具链。跨模块集成触发一次全量 Dart 回归、静态分析、OpenSpec 和 Android 编译/可信来电 APK 类定义检查；Windows 无 iOS 编译环境，实际媒体/电话/生产升级另列待验。非强制推送前核对双方父提交祖先关系及最新远端。

2026-10-10 当前会议反馈补充：实时 confirmBatchTask 被兼容为固定提示的 ASK_USER，快照通过现有 timeline 读取。ConversationSignalFlow 仅针对该确认提示补齐快照，失败进入原 recoveryRequired；不新增接口或任务状态机。TimelineApiMapper 对 askUser 去除内部问题 id，展示合并按同轮工具身份和相同文案替换实时补问。单路收尾读取 CallSessionPhase.awaitingOutcome；多路收尾读取当前发送中的临时批量进度全部结束条件，使用原思考卡，仅影响展示。评分数据关联交接见 docs/engineering/MEETING_TASK_DIAGNOSIS_20261010.md，后端与数据库不修改。

### 2026-10-10 录音与外呼UI纠偏
用户追加100%比例无任务评分卡。当前ApiTaskRatingRepository与App origin/v71 6309bc55的SDK routes及anchor校验一致，但taskRatingClientVersionProvider写死1.0.0；v66策略最低支持1.0.45。复用homeInstalledVersionProvider读取双端实际包版本，Controller异步等待并检查代际，失败不伪造版本/资格；单路callId和批量batchId仍使用现有评分端口，服务端资格/频控/发布时间规则权威。后端若仍不返回资格，脱敏交接待确认，不改库或策略。
来源为v66.0.3 a0bedb12的PureVoiceCallRecordingRoute、assistant-call-recording-card、FinalAiCallPage、AiCallAudioSourceSheet和VoiceGuidePolicy。保存完成/失败通过现有短暂通知显示，不在录音卡下持久展示；关闭按钮去掉Material长按tooltip但保留Semantics；外呼页不渲染额外monitor.label。音源恢复#191D25面板、26圆角、radio和取消，不修改监听或路由生命周期。

现有audioplayers端口没有当前播放实例的PCM或session采样。普通任务录音新增独立平台播放器适配，替换该录音端口的实例，不并行创建第二播放器；Android采样MediaPlayer的Visualizer，iOS用AVPlayer音频处理tap，共享Dart投影波形与失效帧降级规则。翻译的播放器及录音请求、play-token刷新、保存、账号隔离和播放互斥保持原边界。采样不可用仅影响声纹，不让播放失败。新增平台文件承担播放/采样适配，UI不发网络或持有原生播放器。

首次引导保留设备级完成规则，不清空已有偏好：未完成时环境检测和欢迎播报结束后显示“按住说话”及向下尖角；有效输入后不再自动出现，短按仍按原规则提醒。修复无活动录音时异步状态变化误取消尚未使用引导的接线。开发包继续com.vvtech.aiassistant.dev、开发域名三前缀和完整C1配置，install -r保留数据。Android构建/安装与真实媒体、iOS编译分别记录；不修改后端。

### 2026-10-09 全量外呼需求复核续批

UI裁决采用v66.0.3最终正式PureVoice调用链，接口/功能采用fetch后的App v71 146152a；归档的旧规则不得覆盖后续正式代码。ApiCallModelRepository只映射modelId/activeModelId、服务端displayName与appSubtitle（兼容旧description）；无modelId的旧目录继续provider兼容，不再合成推荐标签。ReceiptOverlay仅补同一次通话终态回执的缺失metadata/媒体身份/字段/账单，不替换持久终态、正文或序列；源事件仍保留原对象，不建立另一套事实源。Timeline的所有5xx按暂不可用保留重试，不照搬App无ledger兼容fallback。

监听仍由CallMonitorController拥有生命周期和重试，媒体适配器通过首PCM就绪契约报告真实播放；票据等待CONNECTED、8秒请求超时、首PCM10秒超时、最多三次800ms重试。旧账号/页面/call释放等待与媒体，音源预选只改变本地路由偏好，不启动监听或外呼。票据对齐SdkCallMonitorApi的api/agent-calls/monitor/token，socket及C1作用域对齐Runtime基地址。既有Android/iOS输出适配器不另建播放栈。Java v71提供的旧Agent监听与新App SDK接口存在冲突，后端确认文档单列，不修改Java/数据库/部署，也不静默回退旧接口。

候选卡保持原284外宽和有效Compact布局，仅限制餐厅名称/第二行单行省略、第三行最多两行；原版源码CLOSED为“未营业”，优先源码，不按早期spec改为“不营业”。设置/翻译/声音克隆业务不扩展。未来模型目录和监听能力继续通过现有Repository/媒体端口接入。

2026-10-09外呼反馈续批：请求优先对照独立App origin/v71@257f512的AssistantApiService、NetworkModule和BackendEndpoints；Java v71 AssistantRealtimeController核对服务归属。call/session/status、call/hangup、call/monitor/token属于Agent，Flutter ServiceRoutes此前将这三条误入SDK；AccountApi也漏保护call和agent-calls路径，严格账号契约要求Bearer。独立App CallRecordingRepository使用sdkApiBaseUrl，Flutter录音提供器此前却使用Agent基地址校验SDK内容URL，现改为SDK基地址，兼容无独立SDK配置的原回退。修复既有网络路由/账号传输/提供器，不新增请求栈、后端接口或数据库变更。监听WSS已使用Agent配置，听筒适配保持现有实现。

分页使用既有ScrollController，以小型展示宿主监听底部可见及尺寸变化；失败仅点击重试，原分页Controller负责代际与防重。结构化回执按v66任务完成/失败/确认中展示，普通回执使用服务端headline作为标题，未识别为对话的detail保留正文，不能因转写回退字段相同而丢弃正文。转写/录音/积分/评价/评分复用已有组件及服务端显隐规则。确认卡正式源码320上限；系统返回关闭本地观察，不添加原版没有的按钮。验证分离服务路由和Bearer、分页/刷新/失败、单路多路宽度、结果及返回；真实媒体和iOS运行单列待验。

2026-10-09外呼反馈：用户确认人数、时间后尚未确认预订联系人却出现确认卡。v66餐厅确认规范及当前缓存v71餐厅skill要求姓名、手机号先收齐；当前Java CallSpecValidator在生成MAKE_CALL_REQUEST前校验，但Flutter的TOOL_REQUESTED投影与服务端call_ready需分别核对。VPN恢复后fetch仍403，不能把缓存称为已核验最新部署。展示批次仅修改现有ConfirmationBillingNotice（单路/多路复用）和CallConfirmationCard，使用v66 AgentCallConfirmBillingNotice/AgentCallConfirmCard的胶囊、文字、320宽度和头部，不更改价格规则、快照或通话协调器。后端问题必须先取得运行契约证据，不自行生成假ASK_USER或客户端联系人状态机。

用户随后明确contactPhone属于此前逻辑，暂不调整。已撤回本轮摘要本地化及补充行改动，CallConfirmation解析/摘要显示/提交源规格保持原实现；本批只调整确认卡与共用计费展示。

后续用户反馈卡片后缺少AI确认回复。v66 CallConfirmationPresentationPolicy固定返回“请确认以上任务内容，是否现在拨打？”，实时StepReducer和持久投影共用；当前Java buildCallSummary也使用同一句。Flutter CallConfirmationCard仅绘卡，SpeechPromptPolicy没有MAKE_CALL_REQUEST分支，形成明确遗漏。新增纯Dart确认提示常量，由原卡片后的NativeConversationTextBubble及原语音提示策略共享，所有实时/历史卡片入口一致；ConversationSpeechController仅在当前播报轮次按工具身份去重，不修改大ConversationController或拨打协调器。历史渲染不触发播报，账号/页面代际沿用既有隔离；明确确认、显示前拒绝和重复确认提交门禁不变。此客户端补丁需重新构建正式main并保留数据安装，不依赖后端提示补丁部署。

20:00后VPN恢复，Java远端v71重新fetch仍8ebd7db4，Android远端v71更新257f512，Flutter codex/dev仍9a8d4e64。220开发Agent当前为release 144；对手机卡片与19:11:58模型makeCall事件仅做脱敏相等比较，确认姓名/电话来自system的user_memories，三条当前用户消息均未提供，先前askUser只问时间/人数。必填校验只验证有值，不能证明本任务已确认。最小后端修正限定现有餐厅联系人记忆提示策略和restaurant-booking规则，明确建议联系人须先经当前任务明确选择/同意，已明确提供则不重复问；已询问标记仅抑制是否保存询问，不能当作使用联系人授权。HTTP/DTO/ledger/表/余额/拨打状态不变，不修改只读aiassistant-backend；Java另开codex/fix-restaurant-memory-confirmation隔离分支。release 144提示词与当前v71快照有差异，尚未核验部署源提交，禁止直接替换云端JAR；补丁通过后再确认部署版本及最小更新方式。

2026-10-09再次读取v66列表基线与complete-v67、fix-task-list-and-restaurant-memory、fix-task-unread-and-pinned-r31：后一个修正恢复折叠时未读置顶可见并要求即时清未读、置顶定位目标；较早“全部折叠”和整页重载是历史，不覆盖当前规则。当前SDK AssistantTaskListController.pin返回AssistantTaskListItem，可通过现有Repository扩展单项返回端口接入原Controller；页投影仅增加纯函数调整，不建立第二套列表状态。展示拆为小组件，长按覆盖层复用原行；会话标题元数据通过既有Agent列表按session关联，最终可见回执通过原read端口，账号所有者和页面可见性隔离。无后端/数据库/提示词/SIP变更。

语音提示以origin/test/v66.0.3@a0bedb12的docs/product/1868_V68语音体验首页卡片与界面优化_PDR.md最后一次R3修正为准：无欢迎语立即显示，有欢迎语待结束/失败，不沿用历史固定3秒。短按提醒仍3秒；对照PureVoiceBottomControlHint.kt使用14×7底边尖角，140ms透明度退场保留文案和颜色。计时留在TaskVoiceGuideController，气泡独立展示组件。模型Sheet打开只由入口点击触发；自动刷新仅发生在已打开的Sheet内部。

### 2026-10-09 任务模型弹窗纠偏
只读来源v66.0.3 a0bedb12的V88VoiceModelSheet、ModelLatencyPill及AssistantProviderRuntimeController：按内容撑高、宽度上限420、上圆角20、顶部24/底部32，入场与刷新读取真实毫秒值，缺失或失败显示原不可用，不伪造测量。当前对话Route固定68%且未接quality，新增独立CallModelSheet负责弹窗加载/刷新生命周期，复用现有CallModelController/CallModelQualityController；Route只导航和展示所选模型名/倍率，既有首页不扩展业务。
当前Java纯v71 AssistantRealtimeController的GET /api/assistant/realtime/call-models/latency?refresh=true属于Agent28080；AccountRequestPolicy对C1版本1要求Bearer。ServiceRoutes和AccountApi只补这一精确端点，保留SDK目录端点、账号隔离、刷新重签；不改Java、数据库、翻译或声音克隆。两端共享Dart；以双平台主题/小屏大字/关闭迟到响应测试及Android保留数据真机分别验证，iOS实机继续待验。
用户进一步要求TTS期间隐藏录音、保留原暂停控件。v66 PureVoiceStageVisuals实际为方形Stop控件；复用NativeTaskSubmitButton和现有speech.interrupt，仅停止播报不启动ASR，不新增暂停状态机。VoiceComposerBinding提供薄回调，Host在播报结束后重新计算原VoiceGuidePolicy.ready；首次文字及底边尖角按v66最新1868需求，录音中的原版提示不变。

状态展示以v66有效V67SpeechStatusPresentation为准：实际错误优先，其后为AI回复、聆听、思考、待命，文案固定为「AI 回复中...」「正在聆听...」「AI 思考中...」「语音待命中...」，paused参数在来源正式实现中未生成额外标签。连接/识别内部事件只更新既有输入状态，不增加提示行。VoiceGuidePolicy已有的首次/短按文案由NativeVoicePressFeedback显示在麦克风旁，不放到喇叭下面；所有者离开时移除所属展开编辑路由，避免跨账号浮层残留。

2026-10-09纠偏：v66.0.3 a0bedb12的需求#1860 R1–R3/R23–R25及正式SingleFlowConversationContent、TaskComposerTextInput、TaskSpeechWaveIndicator确定同一行状态/七段声纹/44dp无底色喇叭，52dp透明关闭按钮与喇叭中心对齐。正式声纹为蓝色待机/识别、绿色播报，采用有效源码，不复制旧Demo渐变。编辑层与TaskDraftController共享文本/选区，允许AI输出期间编辑，发送沿用既有门禁。

当前Java v71 8ebd7db4把task-voice ASR/TTS交给runtime-netty；Flutter补独立环境地址，默认兼容同域网关，保持Bearer/C1/PCM/轮次隔离。新任务有效开场在偏好加载且可见时通过原播报协调器播放一次，恢复不重放。本机只启动既有runtime-netty，读取已批准202配置，不执行DDL或配置写入。

2026-10-09再次按v66.0.3正式入口复核：SingleFlowNativeContentShell调用SingleFlowHeader，已无旧四阶段栏；FinalTaskPageItem的会话行直接onOpenConversation，Result在AssistantNavigationPolicy重定向。因此Flutter删除旧阶段栏，会话列表直达原统一会话，不插入独立“任务详情”页。无session的历史详情和翻译详情保留现有入口。进一步补齐MessageCopyPolicy规定的普通完整文字复制，以及正式Agent问卷items控件；当前JavaAskQuestionsPayload已经定义answer_questions/actionPayload.answers，沿用原命令和pending身份，无需增加后端接口。详细复核表见docs/engineering/V66_TASK_PARITY_RECHECK_20261009.md。

本节下方记录首批实现的历史基线；2026-10-08 后续功能决策以文末「v66.0.3 功能补齐」为准。探索阶段已完成；用户于2026-10-08批准进入实施及下述必要的最小后端补齐。新增任务按实际验证更新。

- Flutter 起点 origin/codex/dev `9a8d4e642ec1e892df4128992b84e8686233e732`，隔离工作树开发分支 codex/refactor-conversation-task-flow；按用户最新要求，origin/codex/dev保留开发前提交。原 foundation 保持不动，禁止合入 dev_zys。
- Android fetch 后 origin/v71 `98fe930638a452cdec74fce828ee0312142f98eb`；相比规划时 `2c07940` 的新增仅翻译诊断/归档刷新，本次不迁移翻译实现，统一列表由服务端反映归档变化。
- Java origin/feat/v70-parity `4df226b8578cefdbfd5adc53ae4914a9ab226b77`，只读对应 sdk-api/tasklist 和 agent-sse/history 源码，保护 v3 未提交改动。
- 旧 Android origin/test/v65.0.1 `0f8879e4`，iOS origin/iOS/v1.0.46/dev `bb9ff349` 仅用于追溯。旧 Android 允许网络故障历史降级，当前 Android 只允许明确无 ledger；旧 iOS 的兼容只读策略不覆盖已明确的 Flutter 恢复/输入边界。

## Goals / Non-Goals

2026-10-10追加Skill入口核对：HomeCard及HomeConfigMapper只扩展selectedContactOpening契约，原联系人开场策略负责模板替换，入口复用ConversationEntry与已有首轮消费，不把Skill提示词或必填收集放入Flutter。外呼展示时钟复用当前Stopwatch，首次物理CONNECTED重置、重复状态不重置；只展示、不计费，不增加第二套任务状态机。

2026-10-09结果卡UI与积分续批：确认正式PureVoiceCallCards/PureVoiceCallResultPresentation和TaskCallBillingSummarySection，结果字段/账单均使用PureVoiceSummaryRow，单路账单无额外标题。Flutter现有ReceiptFieldRow的比例列、颜色及账单整句小字不一致；仅修正共享展示行和账单组件，复制文本沿用原格式。新增纯展示映射负责标题和失败原因，复用CallReceiptStatus业务判断，不新建任务状态机。CallReceiptProjector修复同session/attempt内工具结果账单/字段被丢弃的问题，按事件顺序取有效返回账单；不存在返回账单时不伪造积分。Android/iOS主题覆盖完成/失败/异常、窄屏大字及恢复与零扣费，录音/任务详情等直接调用方定向回归；Android继续云域名保留数据安装，真实账单及iOS原生仍独立待验。

2026-10-09确认宽度纠正与监听接线：v66的FinalDefaultPureVoiceMode=true，经正式SingleFlowNativeContentShell/SingleFlowPureVoiceContent到PureVoiceThreadList/PureVoiceCallConfirmSummaryCard，实际卡片上限280、任务确认纯标题、EDFAF0/D6F5DC渐变。此前对照非默认AgentCallConfirmCard的320及可执行标记不适用于当前任务界面，已按用户反馈改正。仅改现有展示组件，contactPhone、计费快照和明确确认门禁不变。

独立App CallMonitorAudioSocketClient的升级握手使用SdkWebSocketHandshakeSigner和accountAuthInterceptor；Flutter监听提供器改用既有SignedVoiceSocket.open，沿用账号/C1/401/生命周期端口，不新建监听请求层或平台状态机。当前SDK录音地址校验/保存作用域使用SDK配置，Agent通话三端点与SDK评价补既有账号鉴权。

用户要求后端问题交接：21:38云端票据拒绝“通话不存在”，SDK通话事件入箱失败、Runtime转写初始化和事件Redis异常按脱敏日志单独记录。没有完整结果响应的转写/录音/评分/账单字段保持待确认，不以事件出现或自动测试通过证明真实数据齐全。交接见docs/engineering/BACKEND_CALL_VOICE_HANDOFF_20261009.md；不修改后端、库或部署。

首页→统一对话→任务列表→详情→恢复连续一致，终态仍可恢复，迟到事件和账号变化不产生串线或重复动作。非目标为翻译/克隆/积分/设置重构、后端改造、生产发布、真实电话与媒体验收。

## Decisions

2026-10-09最新App回执复核：fetch确认origin/v71为fd2d5bee，CallAttemptTimelineProjector优先读取CALL_OUTCOME_REPORTED.callReceipt；适配器将有效callId写入结果metadata，录音/模型评价/任务评分以此锚点请求。Flutter遗漏reported回执和ledger录音锚点，且额外以可见转写限制录音入口。仅修正既有纯投影与录音可见规则，复用现有SDK接口及共享页面。v66.0.3录音仅依赖有效metadata.callId；保留当前App明确未接通时隐藏的细节，但转写缺失不再阻止录音查询。账号/session/attempt隔离与物理/业务状态分离不变，不改服务端、数据库或电话能力。以reported-only、旧终态后补reported、跨attempt/账号隔离和双主题组件测试验证，不冒充真实音频生成或评分响应验收。

- 扩展现有 TaskRecord/TaskRepository/TaskController；新增纯 Dart TaskRef/TaskPage 与统一 DTO 映射，API 适配负责请求和解码，Controller 负责列表请求代际和操作状态，widgets 负责渲染和事件。使用 `/api/assistant/task-list/page`，offset=0、limit=15，保留服务端顺序和置顶分组，按 type/id 去重。旧三源适配仅保留显式旧预览/fixtures，正式入口不再调用；不建立第二个列表 Controller。
- pin/read/hide/clear 使用现有统一接口与身份隔离。操作中单项防重，成功后刷新；失败保留原数据并显示可重试错误，删除尊重 canDelete 和服务端409业务错误。刷新使旧分页失效，游标不前进时停止并显示失败。
- 新增 TaskDetailPage/Route 只负责呈现和导航，复用既有任务记录、ConversationHistoryRepository、回执及录音能力。会话详情恢复同 session；翻译继续已有详情入口，legacy 无可恢复 session 不伪造身份。详情不是新的状态机。
- ConversationController 保留生命周期与代际所有权，提取独立 ConversationEventFlow 处理事件分发，复用现有 action/tool/call/batch/ledger 服务；新增能力通过处理器或既有端口接入。保持手写文件默认500行，任何超限说明记录到 file_exceptions。
- status 事件保留具体事件名与 attempt/outcomePush/progressOnly，只接受当前 session/attempt；ledger sequence/eventId 去重。物理终态关闭通话展示并释放输入，结果处理中不伪装成功；任务终态来自服务端投影/业务回执，不由 done 或文案推断。
- timeline 503/网络错误作为恢复失败，可显式重试；legacyNoLedger 才进入无执行能力兼容展示；401/403不降级，游标冲突至多一次完整重同步，错误契约保留 retryable/recoveryAction。
- 首页入口防重复导航、检查可用状态与网络；配置失败有提示与重试。首页横幅消隐与任务服务端已读维持各自现有语义，共用列表事实；返回详情/对话刷新。账号变化销毁旧控制器/订阅，pending error 队列继续按环境和账号隔离。
- 普通退出只停止本地流、媒体和观察，不发送 hangup/interrupt；批量 detached 流沿用现有保护。历史恢复只水合事实，不重放权限、上传或外呼。

## Validation

用户本轮最终澄清：单路和多路任务界面仍以v66.0.3为准，功能、接口及后端AI语音选择以fetch后的最新独立App origin/v71为准。TaskTtsClientFactory普通请求无preview；当前Runtime普通任务采用受信账号的TASK_TTS配置/selectedVoice，Flutter现有普通签名WSS请求保留，不新增设置入口或客户端音色覆盖。多路现有BatchPlus对应界面和快照映射已核对，新增真实尺寸播放控件替身测试覆盖三类结果转写展开、各路录音和两次积分结算、批次评价身份。

固定 Flutter3.32.0/Dart3.8.0，保留锁文件；每微批 analyze 与定向测试，跨页连续覆盖首页→对话→列表→详情→恢复。覆盖网络/空态、分页竞争、重复操作、旧账号响应、迟到事件、通话物理/业务终态分离和终态恢复。交付前因跨模块里程碑执行一次全量。Android/iOS设备、真实电话/媒体/后台/生产升级分别记录，mock不等于设备验收。关键批次中文提交，仅暂存本需求文件，核对后仅推送 origin/codex/refactor-conversation-task-flow，不force，不直接更新origin/codex/dev。

## Rulings / Environment

- 原生工作树工具因会话根目录不是Git仓库返回 Not a git repository；已核对无新目录后，使用仓库的 Git worktree 在既有 `_isolated` 下隔离开发，原工作区未修改。初始本地codex/dev后已切换codex/refactor-conversation-task-flow，并按用户最新指令恢复远端codex/dev基线；恢复仅在新分支备份核验后使用精确94991e52的force-with-lease，后续禁止直接推送codex/dev。
- 当前系统D:/tools/flutter为3.44.6，不在项目支持区间；独立准备3.32.0，不升级现有工具链。设备环境待核对。

## v66.0.3 功能补齐（2026-10-08 探索，2026-10-09实施）

### 功能基线与保留规则

- 唯一功能对照：旧仓库 `D:/work/kexin_ai/aiassistant` 的 Android `origin/test/v66.0.3`，fetch 后 `a0bedb12afd8aa47c82f70fe1e93bf034706f727`。只通过 `git show` 读取该快照，31项原未提交内容不动；不切换旧工作区分支。
- Flutter 当前比较点：`codex/refactor-conversation-task-flow` 的 `dda4283d`。已实现首批的历史记录保留，但不作为本轮遗漏功能的完成证据。
- Java 契约重新 fetch：`origin/feat/v70-parity` 为 `25e4f18e164b97ca2d92298501de7c30b0e849b9`。原 v3 工作区不改；实现前再次冻结对应接口快照。
- Android v66.0.3 决定有效功能与执行语义；当前后端决定鉴权、路由、DTO和有效服务能力。保留 Flutter 已有明确优势：统一分页/服务端顺序、请求代际、账号/命令/attempt 隔离、显式失败重试、终态恢复和普通退出不自动挂断。涉及执行/确认/停止的差异不能用“更好细节”豁免。
- 范围沿用首页对话任务、统一编排、列表直接详情/恢复及通话结果；只补这些功能的直接依赖。Android独有的系统目录/文件 URI 不照搬到 iOS，功能结果保持一致。

### 源码证据与差异裁决

下表“缺失/改为”记录探索时差异；现已按第7–10节实施，结果见docs/engineering/V66_TASK_PARITY_VALIDATION_20261009.md。运行验收仍区分自动、Android隔离设备、iOS环境及真实服务，不以源码完成勾选未执行的运行项。

下列 Android 路径均相对于固定快照的 `android/app/src/main/java/com/vvtech/aiassistant/`，不把旧工作区当前检出版本当作证据。

| 能力 | v66.0.3 源码入口/所有者 | Flutter差异与裁决 |
| --- | --- | --- |
| 待确认外呼 | assistant_session/ConversationCallConfirmationHandler.kt → assistant_agent/AgentStreamConfirmCallHandler.kt | 当前 ConversationSignalFlow → ConversationCallController.receive → CallLaunchCoordinator.schedule 自动延迟提交；改为卡片呈现后等待用户确认。1500ms 是确认后的可取消准备时间，不是收到卡片后的自动确认。 |
| 确认补充问答 | assistant_session/CallConfirmationReplyCoordinator.kt、ConversationCallConfirmationHandler.kt、data/local/conversation/CallConfirmationSupplementOutbox.kt | 明确确认/编辑/取消优先本地判定；其他回复走分类。QUESTION/WAIT/UNCLEAR 等保留待确认工具并把问答写入同一 ledger；缺少对应端口与 outbox。 |
| 停止 | assistant_agent/AgentTaskStopCoordinator.kt、assistant/TaskBatchStopConfirmationDialog.kt | 当前本地中断不足。停止按原 session/command 请求服务器；批量先确认，失败可重试，结果继续从原流或 timeline 收敛。关闭页面与主动停止保持不同操作。 |
| 草稿 | assistant_shell/AssistantTaskDraftShellEffect.kt、data/local/taskdraft/TaskDraftStore.kt | 当前 Composer 仅持有 TextEditingController；新增账号/环境/session 草稿存储，成功接受后清理，失败保留，不恢复即发送。环境隔离沿用 Flutter 已有保护。 |
| 任务产物 | assistant_artifacts/PureVoiceArtifactCard.kt、ArtifactDownloadCoordinator.kt、data/repository/artifact/TaskArtifactRepository.kt | Flutter只识别部分模板来源，消息/回执缺完整产物与下载。支持模板和批量CSV，历史只显示，不自动下载。 |
| 置顶折叠 | assistant/FinalTasksPage.kt、assistant_tasks/TaskPinnedUnreadVisibilityPolicy.kt | 当前置顶操作已接，折叠缺失。仅在现有列表上形成展示分组；折叠保留未读可见，按账号存储折叠偏好，置顶成功定位目标，保留服务端页序。 |
| 首页卡片 | assistant_home/HomeConfigViewModel.kt、domain/HomeCardPreferencePolicy.kt、SkillCardSettingsRoute.kt | 缺 defaultVisible/账号显隐排序/恢复默认；仅增必要技能卡管理入口。最低版本使用实际安装版本，不再传字面量1.0.0。 |
| 任务播报/语音引导 | assistant/AssistantSingleFlowPageHost.kt、SingleFlowNativeDemoScreen.kt、assistant_voice/VoiceGuidePolicy.kt、VoiceGuideCompletionStore.kt | 补任务AI播报开关和既有按住/松开/取消/短按引导，不据此重构ASR/TTS或通话模型。引导完成条件为有效按住说话提交，设备级偏好按原生语义保留。 |
| 分享与独立结果页 | assistant_shell/AssistantRootHostArgsShell.kt、assistant/AssistantNavigationPolicy.kt | onShareResult只提示“分享功能待接入”；resolveFinalSubPageTarget将Result重定向到统一对话。前次把独立结果页分享/AI建模按钮直接列为有效缺口证据不足。本轮不新增占位分享或该停用页面按钮；不删除已有其他有效联系人功能。 |
| 首页缓存 | data/homeconfig/HomeConfigRepository.kt、HomeConfigFallbackPolicy.kt | v66.0.3网络失败也使用内置配置，Flutter相同路径不算缺口；不新增上轮基于v71推导的缓存回退行为。 |

对源码中其他新增文件必须核实正式可达调用链后才能纳入。整个旧App的记忆、国内SIP、可信来电、OTA等不因“对齐v66.0.3”自动扩展本次范围。

### 接口契约与必要依赖

| 契约 | 语义与身份 | 当前提供方/处理 |
| --- | --- | --- |
| POST /api/agent/call-confirmation/reply | userId/sessionId/pendingToolCallId/cardText/userText → decision及可选answer；CONFIRM/EDIT/CANCEL/NEW_REQUEST/QUESTION/WAIT/UNCLEAR；分类本身不拨号，故障保守UNCLEAR。 | v66.0.3 backend/assistant/controller/CallConfirmationReplyController与agent/CallConfirmationReplyClassifier有效；当前Java未找到。候选迁入agent-sse独立Controller/DTO/classifier及原提示词，通过既有账号校验和模型配置；不得加入AgentService巨型分支。 |
| POST /api/agent/conversations/{sessionId}/call-confirmation-supplements | recordId/pendingToolCallId/userText/assistantText → recordId/eventId；按账号/session归属，幂等写CALL_CONFIRMATION_SUPPLEMENT，不发新Agent轮次、不消费pending工具。 | v66.0.3 history/api与application/confirmation已有。候选迁入当前agent-sse现有ledger层；先检查当前event类型/DTO/projector是否支持，必要的兼容增量单列，禁止第二套表或历史。用户已批准在隔离新分支实现最小补齐。 |
| POST /api/agent/conversations/{sessionId}/stop | userId/targetCommandId；STOPPING、NOT_ACTIVE或BATCH_CONFIRMATION_REQUIRED；不以HTTP成功判任务终态。 | 当前Java AgentTurnStopController已存在；Flutter新增薄API与协调职责，复用原流/ledger。 |
| POST /api/agent/conversations/{sessionId}/batch/stop | userId/batchId；展示服务器返回的挂断成功/失败，失败项允许用户重试。 | 当前Java AgentBatchCallController已存在；普通单路挂断仍走既有call控制。 |
| GET /api/agent-artifacts/{artifactId}/content | 账号归属的二进制内容，保留服务端类型/文件名及可用状态，错误可重试。 | 当前Java TaskArtifactController已存在；下载与UI状态分别负责，不将文档上传/录音保存冒充产物能力。 |
| 统一列表、详情、timeline、首页发布配置 | 继续现有有效身份与服务端权威投影，首页defaultVisible按真实DTO补齐。 | 当前现有接口复用，不退回三源合并。 |
| HTTP/SSE/内部WS鉴权与签名 | 按实际路由提供方选当前协议，sdk-api与agent-sse分别核对；旧Androidv2、当前SSE C1不可互换，Bearer/刷新保留。multipart、二进制及外部URL有各自范围。 | 先定义端点路由/签名矩阵，复用现有请求层接入小模块。凭据来源与现网网关/路由待真实确认；不复制源码密钥、不写日志、不关闭后端验签绕过。 |

用户已批准后端最小补齐：仅在codex/v66-task-parity隔离工作树迁入确认分类和补充ledger接口及必要契约测试；原Java v3工作区不修改。接口部署与真实联调单独验收，不能用Mock报告已部署。提示词变动仅可能涉及旧确认分类规则迁移，不扩展模型职责；SIP、数据库、Redis和电话状态权威保持当前实现，任何额外需要的迁移先列影响。

### 分层及文件职责选择

扩展现有接口，不向477行ConversationController堆新职责：确认交互Policy/Coordinator、停止Coordinator、草稿Store、产物Repository/下载Controller/卡片、任务展示Preference、首页卡片Preference分别为小模块。API/DTO留data，纯规则留domain，UI仅绑定事件。既有CallLaunchCoordinator改为显式确认触发，继续保留准入、防重和取消准备能力；不保留第二个自动拨打所有者。

确认补充事实进入现有ConversationMessage/ledger映射与timeline水合；outbox只负责未确认落库的展示问答重试，不承载任务终态。请求签名使用现有AccountApi/DioAgentGateway接入点，按服务角色拆Signer/credential source；网络、权限与文件保存不能混入UI。

Android产物保存到系统允许的位置并提供原生已有下载结果入口；iOS提供Files/系统保存能力，不能放Android路径或把仅缓存文件算作保存成功。现有录音保存端口专用于audio/mp4，不能直接拿来保存docx/CSV；新增通用任务文件端口与两平台实现，不改翻译录音业务。

后续类似产物类型通过已定义描述符/下载端口扩展；本次只实现v66的有效类型，不添加模板编辑器、自动分享、自动外呼、定时任务或新状态机。

### 验证与完成门槛

1. 固定Flutter3.32.0/Dart3.8.0，每源码/测试微批至多3文件；先写能证明差异的行为测试，批后analyze与相关模块/直接调用方测试，不以旧断言复制新实现。规格/记录另批。
2. 确认专项：未确认不产生confirm_call；确认只提交一次；显示前/旧卡/旧账号分类结果失效；修改或取消准备阻止拨打；QUESTION/WAIT/UNCLEAR可见并持久化；网络失败保留待确认；历史恢复不确认。语音/文字同入口。
3. 停止专项：普通停止、批量确认/撤销、部分挂断失败与重试、断流后读取timeline、停止中迟到工具不执行；普通关页不调用停止/挂断。
4. 草稿/列表/首页：退出重进与进程恢复、成功接受后清理/失败保留、账号切换隔离；折叠未读仍可见、置顶成功定位/失败保留；卡片显隐排序恢复默认/新发布卡/禁用卡/实际版本。
5. 产物：实时与历史同形、模板/CSV下载、防重、失败/取消/重试、旧账号响应隔离、文件实际类型与打开；Android/iOS保存选择取消均有证据。补充记录在详情/恢复后不丢、不重复。
6. 连续流程：首页→对话→待确认→补问/等待→确认或停止→列表→详情→恢复；普通、失败、终态、批量、账号切换分别覆盖。跨模块里程碑跑一次全量。
7. 双平台共享规则测试与平台主题测试只是自动证据；Android/iOS分别构建/设备运行、文件保存和手势/键盘操作。Windows当前无可用mac/iOS设备，iOS构建与设备项保持待验，需要macOS执行环境才能声明双端完成。不能用Platform.iOS主题或Mock代替。
8. 真实后端签名/鉴权/接口联调、真实电话、媒体/录音、后台与生产升级分项验收，当前无证据。保留数据安装，不卸载清数据，不扩大真实外呼授权。新任务全部完成且运行依赖验收后才报告功能完整，未验收不归档。
## 2026-10-09 登录首页和任务tab微批设计与源码依据
- 展示接线：AuthRoute直接组合ShellRoute，初始化模块保留给已有独立能力/演练，不在首页入口启动；不创建新的状态机或绕过标记。回归测试令初始化provider主动失败，证明首次登录、会话恢复与首页/任务切换不访问此依赖，Android/iOS主题共同覆盖。
- 配置映射：HomeConfigMapper按当前Android data/homeconfig/HomeConfigMapper.kt resolveAssetUrl接受合法HTTPS云图片及SDK相对素材，URL仍校验assetId、用户信息及fragment。HomeCardIllustration外部云图使用Image.network不携带凭据，SDK路径仍由SignedHomeAssetSource限定同源并签名；后端HomeConfigServiceImpl.hydrateAssetUrls保留原有效云URL。
- 直接模型API：当前Java RealtimeModelSettingsController、RealtimeModelSettingsDtos.UpdateCallModelRequest和VoiceCloneAuthenticationFilter第117–119行要求模型/音色Bearer和切换modelId；AccountApi仅补这两项受保护前缀，ApiCallModelRepository提交字段对齐。共享克隆音色调用仅自动获得同一路由鉴权，不变更克隆规则。原“音色不带Bearer”测试同步当前契约；另保留公开请求无Bearer及两个模型端点401刷新用例。
- 对照快照：旧origin/test/v66.0.3 a0bedb12及当前Android origin/v71 0e960e258ff890115374ce5406d0054e09f17c49中V61InitializationOverlay只有函数定义，正式引用检索无调用。Java运行origin/v71 8ebd7db4；不合并旧确认分类/补充补丁，不改库。
- 职责与扩展：页面只负责入口组合，mapper只解析发布DTO，Repository仅提交模型请求，认证/刷新仍由既有AccountApi负责；未来接口扩展仍接现有服务路由/请求层，不把网络或业务逻辑放进页面大文件。
- 验证：固定3.32定向认证/任务132、首页/网络61、最终网络/模型/首页/登录/通知174全部通过（集合重叠），mapper收尾7通过；analyze无问题，ARM64正式main构建与当前手机保留数据安装成功。真机主流程为实际服务器账号，不是MOCK；没有触发外呼/上传/模型写入，iOS编译与设备验证未做。


### 2026-10-09 环境检测、录音气泡与输入图标纠偏
用户进一步明确保留带三行步骤的检测框。正式SingleFlowNativeContentShell → SingleFlowPureVoiceContent → PureVoiceStage → PureVoiceThreadList确实挂载PureVoicePrecheckCard，先前仅恢复头部文字不完整。独立PrecheckPresentation负责原版行文案/颜色映射，Controller仍只负责既有网络/模型事实及展示时序，独立Card只渲染，ConversationPage组合入口/历史尾部位置，不增加业务状态或SIP探针。

添加内容中两项MOCK由migrationPreviewsEnabled默认debug开启带入正式菜单；删除菜单枚举和路由中的演练分支，独立测试工作台保留。换行闪动来自TextField从单行Row移动到另一Row导致EditableText销毁；用固定布局路径调整同一输入控件的左右留白、底部工具行，复用焦点/输入连接，不引入自动动画或新的输入状态机。
只复用旧 origin/test/v66.0.3 a0bedb12 的正式链路：SingleFlowPrecheckPresentation / PureVoicePrecheckModels / V67SpeechStatusPresentation、SingleFlowConversationContent 的 real_live_user、VoiceManualControlHandler.cancel 与 PureVoiceInputDockControls / ic_task_input_expand / collapse。环境检测控制器仅拥有网络观察及短暂展示定时器，模型事实来自现有 CallModelController；无外呼探针，无登录初始化。临时识别气泡只读 VoiceInputState，取消及迟到事件沿用既有录音代际。图标组件只绘制原版路径，编辑与发送沿用原草稿回执。

用户后续明确撤回额外回答表单。正式ASK_USER仅渲染现有问题文字，使用普通message及原pendingTool身份回答；删除此前新增表单、日期/选项字段、结构化提交端口及对应旧测试，更新连续演练为自然回答。原版餐厅候选、确认卡和回执不在额外表单删除范围。停止按钮回到输入行，文字模式复用发送位置，语音模式复用中央56dp渐变按钮。

### 最新任务列表及对话可见已读
以v66 assistant-task-list-r20-r33及后续有效代码为准，旧“折叠所有置顶”和“置顶后整页重载”已被未读可见与单项响应替代。TaskRecordPresentation只格式化标题/开始时间；TaskSceneTitles只按session补充activeSkillTitle；TaskPageMutation只调整既有分页窗口。操作、防重、回滚和代际仍归TaskController，不创建第二套状态机。NativeTaskIcon、TaskListControls和TaskActionOverlay分别绘制原XML图标、分页/折叠入口和原菜单。ConversationResultReadHost与VisibleTaskResultRead只在当前页面前台显示最终回执后确认已读，物理结束/SSE完成不算最终结果。文档导入工厂改为页面期间订阅，避免路由可见性变化重建时触发autoDispose重复调度。

用户最新只同步任务对话，设置暂不动。v66 FinalSettingsHomePage隐藏“我的身份”，TaskVoiceSettingsSection/Sheet的Maia、Andre选择入口在设置，不移植到任务页面。任务播报默认请求恢复Maia；当前Java TaskTtsVoicePreferenceService按独立任务配置优先解析，保留此有效契约，不用通话模型/音色或preview覆盖，不改Java、库或克隆业务。音色设置页面后续另行同步。

### 订餐联系人记忆询问
用户补充联系人确认和任务内记忆范围。v66 RestaurantContactMemoryAskStore和OfferPolicy只存账号级已询问布尔值；当前Java UserContext.restaurantContactMemoryAsked、MemoryPromptProvider和RestaurantContactMemoryPromptPolicy已提供有效契约。新增独立RestaurantContactMemoryOffer协调标记、SecureRestaurantMemoryAsked存储及可见询问Host；AgentContextBuilder仅组合其上下文，原ConversationController、自然回答和通用manageMemory不变。联系人读取/写入及开启状态由后端通用记忆负责，不调用IdentityRepository、不伪造身份、不新增专用保存接口或记忆设置页面。后台/离页/账号变化不标记；存储错误不阻断当前对话且不得伪造成功。Android旧账号标记迁移与生产升级若未实测须单列待验。
### 2026-10-10 历史补拉重复提问与外呼进度清理
ConversationQuestions 仅扩展既有后端参数解析，兼容 items/questions/questionsJson，不增加回答控件；ConversationMessageMerge 的 command/tool 隔离规则保留。现有 bindConversationCalls 在物理结束时按原提交命令清理临时普通工具；ConversationController 的流关闭清理不再依赖 sending 状态，ConversationEventFlow 在ready后拒绝迟到普通进度。复用 finishTools，不改 ledger、任务状态、播报规则、后端及数据库。测试使用合成数据重现同工具实时/历史重复、不同工具/命令合法提问，以及电话先结束流后关闭。原Controller仍499行，无新增业务职责；提问解析与事件清理分别留在已有单职责模块，后续协议兼容沿用该解析入口。
