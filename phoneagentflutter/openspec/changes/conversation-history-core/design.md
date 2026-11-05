## Context

v65 固定提交 4c781e3。已有公共 AccountApi 与按账号代际隔离的会话；首页模型里程碑 2b87ec9 已推送。任务详情是 envelope，timeline 是原始 JSON；两者不能统一盲目 unwrap。原 Android 的 timeline 503/IO 或明确空 ledger 才允许兼容视图。

## Goals / Non-Goals

目标：严格协议、历史完整性、任务列表的可恢复入口、统一文字输入的状态边界；让后续复杂工具有清楚的扩展位置。

非目标：本批自动真实外呼、真实录音/ASR/TTS、擅自增加会话删除/搜索、将 CLOSED 映射为禁止输入、将流 done 映射为业务成功。复杂回执、权限/通讯录/OCR/文档/批量工具未完成前不得标记统一页完成。

## Decisions

- AccountApi 增加显式 raw-response 与指定 HTTP 状态暴露，仍复用身份隔离/刷新。timeline 不混用 envelope；401/403 不得误落旧数据 fallback。
- 纯 Dart LedgerSync 通过 TimelineSource 加载分页；缓存按账号+session 隔离。按 sequence/eventId 双去重，冲突或缺口最多完整重同步一次，分页游标必须前进，禁止静默漏消息或无限循环。
- 未知类型/schema 保留原始持久事件并推进游标，但不生成臆造消息。Projection 是服务端事实，readOnly/continuable 不用来新增输入门禁；只限制 pending-tool 恢复。
- SSE 帧解析与 Agent 事件解码分离；支持分块 UTF-8、CRLF、多行 data、心跳、done。命令 ID/幂等键/traceId 在提交时创建并保留；默认 channel=voice，文字来源不切换后端通道。
- TaskRepository 读取 conversations 与 call-history，按时间排序并稳定去重；任何有 sessionId 的普通任务可进入恢复。翻译记录使用独立详情路径，不能当 Agent session。
- 补充源证据：TaskCallHistoryController 还读取 api/task/list，只补充没有 durable call 覆盖的成功终态任务（isTerminalTask 实际限定 successful terminal，不能扩大为全部失败任务）。三路独立加载；部分失败保留对应旧数据并显示失败，不伪装空列表成功。
- UI controller 只编排状态；取消本地普通流/退出清当前对话，不自行调用后台 hangup/interrupt；批量后台活动需专门 coordinator，不能删掉保护分支。
- 实施微批：网络 raw 扩展+测试；ledger 模型/source/sync+测试；SSE 帧/事件/命令+测试；任务数据/状态+测试；设计提取和页面；最后设备自动化。每微批最多三文件，默认每文件 500 行。

## Risks / Trade-offs

- 时间线持续写入：按每页 head 和单调游标验证，可重试；不把有限页截断当完整历史。
- 旧数据内容缺失：限定 fallback 为空消息且无 pending，展示技术状态，不从 messagesJson 猜测还原。
- 真实 Agent 可能自动批量外呼：合成回放覆盖确定性分支；2026-09-16 用户已授权测试环境文字多轮与恢复联调，真实冒烟只发送不带目标号码且明确不外呼的整理信息请求，不自动执行外呼。
- 复杂工具逐步迁移：入口明确未实现，保留未完成清单，不将普通文本链路当全功能验收。

## Validation

### Agent索要文档续接（2026-09-21）

固定4c781e3的FinalHomeAgentSheets、AssistantAgentDocumentPickerActions、AgentStreamUserActionPolicy.documentSubmit及DocumentParseService为证据。live IMPORT_DOCUMENT_REQUEST先展示上传弹层，单选过滤acceptedMimeTypes白名单（无合法项回默认集合），maxBytes缺省5MiB，解析复用api/documents/parse。submit_document动作携带完整解析结果及原session，按源action协议不附pendingToolCallId/message/inputKind；本地仅显示源echo摘要，不泄露文件正文。取消回USER_CANCELLED，解析失败回PARSE_FAILED，超过请求/服务上限回FILE_TOO_LARGE。主动docx/xlsx多选规则不变。

实现微批：agent_document_request.dart与platform_agent_document_picker.dart、api_document_parser.dart（显式Agent模式）；agent_document_controller.dart与conversation_action_coordinator.dart；conversation_controller.dart、conversation_providers.dart、attachment_providers.dart；agent_document_host.dart与conversation_route.dart；隔离预览及定向测试。权限续接复用提取后的action协调，主Controller不新增文件IO。请求去重，restore/close使等待选择与解析失效，历史不重放；只选择文件后上传，无新增权限/依赖/原生实现。Web合成端口覆盖成功/取消/失败/超限及后续文字，真实系统选择器和服务端收件列集中人工验收。

### 权限工具正式续接（2026-09-18）

固定v65 AssistantRootSecondaryShellEffects全局接入FinalAgentPermissionEffect，非旧页专有入口；GrantPolicy文档选择恒可用，定位精确/粗略任一授权可用，空androidPermission只检查不申请。后端AgentService白名单仅microphone/contacts/location/document_picker，拒绝CALL_PHONE；NormalActionEntryHandler以permission_result沿chat stream回传且appendUserEcho=false。iOS_newui2的AILocationService使用WhenInUse，权限信号只有通用兼容处理，不能声称已有完整续接可复制。

新增domain/tools/conversation_permission.dart（白名单、状态/结果、去重与生命周期）、data/tools/device_permission_channel.dart（仅授权状态，Web不调用原生）；原生PermissionChannel.kt/swift检查或申请对应权限，无联系人/坐标/录音采集，无系统设置自动跳转。Android定位同时申请coarse/fine以支持Android12选择近似，接受任一；iOS仅WhenInUse、不要求精确定位。声明最小用途文案，不加后台定位/拨号权限。保留当前Xcode15.2和iOS15.5，采用兼容AVAudioSession录音授权API。

主Controller先将恢复和实时UiState纯投影移至conversation_presentation_projection.dart，再装配权限协调和permission_result新command续流。工具身份去重、退出或账号变化后不回传、旧done不结束新流；恢复历史不自动重放权限请求。重用当前AgentGateway及OCR上下文，不创建新HTTP接口或用户消息。独立permission_preview_page/data端口用同一Controller验证允许/拒绝/需设置及后续文字，不使用真实权限、账户或外呼。各微批最多3文件，源码默认500行。

验证：白名单/空权限/已授权/拒绝/不可用/重复/晚到、实际AgentCommand字段与流代际、MethodChannel不调用Web、历史不重放；Widget连续文字/返回、小屏；Web演练和双端构建。真实系统提示、设置撤权与后台收件列集中验收，不用合成响应冒充权限已授予。

### OCR正式页面装配（2026-09-17）

本轮以v65 ConversationLedgerTimelineMapper/Reducer、ConversationTimelineToClarificationStepsAdapter、PureVoiceOcrBindingFactory为源step证据：OCR项不进入源steps，同ID更新保留初始顺序；documentBatch/confirmBatchTask/artifact/receipt有各自身份，确认后的makeBatchCalls不重复占位，未知schema/纯状态不生成step。新增纯Dart conversation_source_steps.dart与conversation_ocr_boundary.dart，将源step边界映射到Flutter可见消息身份，不使用messages.length充当wire anchor；未实现展示的有效源step仍保留计数。实时尚未提交消息仅作为暂态源step，提交后由同一事实投影替换。

正式装配分微批：边界映射与测试；conversation_submission.dart提取现有命令创建、controller注入独立OcrSessionController及关闭/恢复钩子（不加图片IO）；ocr_providers.dart工厂和conversation_providers.dart账号租约绑定；conversation_ocr_host.dart共享图片卡监听、route/相册入口接线；端到端合成测试与Web实际演练。底层Repository已做鉴权代际隔离，provider同样随loginEpoch销毁，图片不使用带凭据的NetworkImage。AgentCommand只发送成功OCR上下文，不伪造用户消息；新会话先OCR仍保留首轮skill/contact契约。

补充纠正上一批假设：v65 PureVoiceOcrCoordinator.synchronizeHistory在历史图片读取失败时跳过该附件，而非仅跳过图片保留可用文字。包装器须遵循：成功下载或当前已有本地图的附件才合并为可用成功项；仍保留未加载元数据用于以后重试/ordinal，不把失败历史图送入userContext。这一规则由源码核验更新，不能继续以旧合成测试作为完成证据。

### OCR平台适配（2026-09-17）

实际远端为macOS13.7.8/Xcode15.2，仓库iOS最低版本15.5（此前文档16.7描述不准确）。固定image_picker1.1.2与google_mlkit_text_recognition0.13.0；后者官方包维护者文档支持Xcode15，不能使用要求15.3的0.15。iOS显式GoogleMLKit/TextRecognitionChinese6.0，Android中文模型16.0.1。保留Flutter3.32工具链和现有最低系统版本，不升级Mac。插件仅桥接系统相册/本地MLKit，业务仍共享Dart。相册单选、requestFullMetadata=false，无相机/视频权限；Web不调用移动识别插件，仍使用显式隔离演练。Android进程重建丢失选择不自动归入新会话或上传，在下次选图前消费插件遗留结果并提示重新选择，不恢复旧会话授权。

手写微批：依赖/Android/Podfile；图片domain/选图适配/识别适配；Info.plist/测试；后续再接正式生命周期/锚点/历史/上下文。选图读取限制10MiB，取消无消息；中文识别按v65块与行顺序、trim去空，异常仍释放识别器，不记录路径、图片或文字。测试覆盖选择参数、取消/格式/超限、识别成功/失败资源释放和Web拒绝。新增插件必须Web/Android/iOS无签名构建验证，未接入页面前不标记3.15完成，不自动读取真实照片。

生命周期微批为ocr_controller.dart（支持成功历史合并/已知ID）、ocr_session_controller.dart（组合相册、识别、上传及账号页面租约、内存图片）、ocr_session_controller_test.dart。已有OcrController继续作为处理状态单一事实源；会话包装器只持有选择阶段、图片字节和持久记录，不复制处理状态机。只有已成功保存且本地图可用的附件进入userContext；历史图片读取失败按v65跳过可用项，元数据仅用于序号与以后重试。同页重复同步不无限重试图片，串行队列在关闭后不续发下一张。关闭后清空内存并拒绝后续上传、状态回写或上下文使用。正式入口已按上方装配批次接入，不用消息数近似冒充正确锚点。

### OCR持久协议与受保护图片（2026-09-17）

固定v65 ConversationOcrAttachmentRepository/Api、后端attachment/api与validator，以及PureVoiceOcrHistoryProjection。共享Dart实现multipart(image+application/json metadata)、稳定ocr-command/ocr-trace/idempotency身份、10MiB限制、四类失败中的整理/保存区别、返回身份验证；不向普通chat伪发文件JSON。AccountApi每次发送复制FormData，401仅一次刷新并使用新上传体，不因网络未知失败重传。只暴露调用方明确允许的稳定错误代码，不泄露任意服务错误正文。

历史二进制使用AccountApi同源固定路径、凭据世代检查、有界流式读取与超时，不使用服务端contentPath作为可执行URL，不把Bearer放入NetworkImage/第三方源；获取后由上层按账号生命周期持有，不新增跨账号磁盘图片缓存。Dio提前缓冲的限制加在接收进度和消费两处，接收预算max(预期大小,64KiB)，最终大小仍严格校验；Web使用既有FetchStreamAdapter的redirect:error，避免XHR自动跟随重定向。按OCR_IMAGE_COMMITTED/schema1恢复，保留选择时anchorStepCount及createdOrdinal，按附件ID最新事实去重；不以提交时sequence推算图片位置。历史投影与HTTP适配复用同一严格值对象。

先落地网络/持久模型/历史投影及实际multipart、刷新、分块/超限/跨账号测试，再接相册/识别、ConversationController上下文和时间线显示边界。后者不能用UI消息数量冒充v65源step边界；本子批不勾选完整OCR接线。每微批≤3文件；无新插件/后端/数据库/提示词/ASR/TTS变更，不上传真实用户图片。

### 图片OCR交互页（2026-09-17）

固定v65 PureVoiceOcrCoordinator/Models/Cards为行为证据：单飞选图，图片气泡与Processing→Success/Failed，失败分EmptyText/RecognitionFailed/AiRefinementFailed/CloudCommitFailed；成功字段和完整文字只读，超过50字展开/收起。不得迁移HTML旧mmOverlayOcrResult编辑确认弹窗。样式采用0cd58de的pv-ocr-card CSS，图片仅使用同设计源MOCK图片作演练素材，禁止整页截图或写入生产账号。

本批新增attachments/domain/ocr_attachment.dart、presentation/controller/ocr_controller.dart、data/preview_ocr.dart；widgets/ocr_attachment_card.dart和core/design/ocr_tokens.dart；pages/ocr_preview_page.dart从添加菜单明确MOCK入口可达。ConversationPage通过锚点时间线插槽显示共享OCR卡，不向主Controller增加识别/图像IO职责。演练识别、整理、文字回复全部内存；真实MLKit/系统相册、multipart云端提交、ledger恢复/userContext接线仍单列，不把UI完成当作OCR生产完成。

验证状态机/失败/空结果/重复/晚到/多图锚点、展开收起与返回、320/390/430竖屏，正式登录保持不变。无新HTTP、日志正文、数据库、提示词或音频修改。既有16.7 iOS目标不因OCR UI引入不兼容插件。

### 主动文档添加（2026-09-17）

来源为v65 PureVoiceAttachmentSheet、AssistantAgentDocumentActionHandler/ImportUseCase和AssistantUserDocumentTurnCoordinator。添加菜单保留相册/文档两项，文档多选仅docx/xlsx，默认每文件5MiB；先统一校验后逐文件解析，任一失败不提交部分文档。成功组装user_document_batch.v1、documentBatchId、documents字段，沿原session发送inputKind=document、channel=voice、pendingToolCallId=null；UI只显示文件摘要而非JSON正文。系统选择取消不创建用户消息；退出/销毁后不得继续读取、解析下一项或发送。

file_selector 1.0.3封装系统文件选择，Dart业务端口仅接文件名/MIME/长度/延迟读取。解析复用AccountApi，multipart单字段file到api/documents/parse。无新数据库/提示词/音频修改，无后台自动重试。独立DocumentImportController防单飞/晚到，不增加ConversationController的文件IO职责。正式路由使用真实端口，debug演练从添加菜单显式进入、完全隔离，无真实HTTP/文件/账号副作用。Agent主动IMPORT_DOCUMENT_REQUEST（自带限制/取消结果）、OCR和权限live工具不借本批勾选完成。

2026-10-20 Android 选择器兼容补充：旧 Android `d14230823` 曾因华为内部存储无法选择文档，将精确 Office MIME 改为 `application/*`，并继续在选取后检查 `.docx/.xlsx`。Flutter `PlatformDocumentPicker` 自 `2584bd7d` 起仍传精确 MIME；Android 的 `file_selector` 将其交给系统文档选择器过滤。仅 Android 改传 `application/*`，保留扩展名、大小及解析校验；其他平台的类型过滤不变。华为真机点击和实际上传仍需在新包上验收。

设计为固定0cd58de的pvAttachmentSheet/pv-sheet CSS，文档行按v65有效实现补齐，用户批准静态先行。使用真实菜单控件/SafeArea/Navigator关闭；解析进度由共享底部sheet展示，成功自动关闭，布局差异留统一校准。微批：spec/dependency；domain/controller；picker/API；sheet/composition；对话接线；测试与文档。验证大小/扩展名/多文件部分失败/取消/晚到、API multipart、document命令与消息脱敏、窄屏返回及Web隔离流程，双端构建。

### 历史pending边界核验（2026-09-17）

固定v65 `AssistantConversationRestoreSnapshotMapper.pendingToolRequest`按modelTurnId/toolCallId/toolName/ordinal身份排除已有结果，再选择最大sequence未完成请求；仅continuable、pendingRestorable且非CLOSED时恢复标识。`AssistantConversationRestoreUiStateReducer`恢复时间线/pendingToolCallId，明确清空agentOptions、agentPermissionRequest、agentDocumentRequest，没有重放联系人查询。Flutter沿用时间线候选+pending标识，不添加打开历史自动权限/查询/回传/外呼。补恢复候选选择、完整工具身份、已解决、门禁组合、查询不重放及退出晚到回归；普通输入不以终态封锁。附件/权限live工具仍独立待办，不能因核验恢复边界而整体勾选复杂工具完成。

### 姓名查询与工具协调（2026-09-17）

继续固定v65 DeviceContactCandidateLookupUseCase、ContactPinyinSearchEngine和AssistantAgentContactLookupEffects。文字typed/unknown只做trim、繁简归一、忽略大小写精确匹配；asr先姓名精确、无结果时包含匹配，再按原评分/声韵母变体/四音节上限追加拼音候选。姓名+规范化号码去重，多号码保留；纯pinyin_fallback即便单项也必须MULTIPLE_CANDIDATES，不替用户选首项。结果交后台SHOW_OPTIONS，复用现有第N个；不迁移当前effects未使用的旧本地选择弹窗。

新增contact_name_matcher.dart与contact_pinyin_search.dart（纯Dart）；字典固定lpinyin 2.0.3，用逐字首拼音避免引入词组改写。繁简/罕见字/多音字字库与旧Android ICU/TinyPinyin可能有差异，集中验收必须包含目标通讯录姓名；拼音规则不等于字库逐字一致已验证。无需原生拼音库。source枚举typed/asr/unknown独立于UI语音按钮；当前文字统一页始终typed，ASR端口后续传asr。

新增NameContactLookup和api_name_contact_lookup_continuation.dart；POST device-contacts-lookup-result，results包含name/requestedName/status/inputSource/matchType/candidates及RESOLVED时的首项字段，channel=voice。拒权/不可用逐名返回，无整本通讯录上传。共享ConversationToolCoordinator持有工具去重、查询与HTTP后ledger同步，Controller只应用返回结果，防止继续增长巨型文件。每微批最多三文件；匹配/API/controller/Widget测试，Web演练及三端构建。

架构门禁补充：domain 不直接依赖第三方 package。ContactNameDictionary 定义字典端口，data/LpinyinContactDictionary 封装固定版本字库，由 composition 注入 NameContactLookup 和 ContactNameMatcher。繁简/分词/候选评分规则仍在 domain，不能用放宽架构测试规避依赖边界。

### 号码联系人查询接线（2026-09-17）

固定v65 AssistantAgentContactLookupEffects、DeviceContactResolver.findByPhone、AgentStreamContactLookupResultUseCase及AssistantApiService是本批事实源。共享PhoneContactLookup用既有DeviceContactSource请求权限并读取；按规范化号码双向后缀匹配，第一匹配行姓名为空时仍按未找到处理，不用列表的“未知联系人”占位伪造命中。仅返回found/source/displayName/可选系统label(note)，不上传整本通讯录或后台备注。Android/iOS薄端口补系统号码label，查询规则留Dart。

结果POST api/assistant/agent/contact-lookup-result，body保持sessionId/pendingToolCallId/userId/result。HTTP AgentChatResponse映射回共享事件投影；不伪造用户文字、不重发原chat、不新增确认按钮。后端AgentLookupContactController通过LegacyConversationCommandAdapter产生新的续接command，已有ledger时回传后只读同步，再使用最新command投影，防止旧assistant消息遮挡回复或新增重复。查询前后检查当前代际；重复同一tool只处理一次；失败进入历史同步恢复而不盲目重复POST。HTTP后续若再要求不同tool可继续，同一tool不重复回传。

微批：domain查询与HTTP续接适配；联系人模型/通道label；双端系统label；controller/provider接线；合成端口与生命周期测试；文档。姓名候选（含繁简/ASR拼音）、附件、权限工具、外呼协调仍未完成，不能借号码查询通过勾选3.5整体。

### 统一页阶段接线（2026-09-16）

来源为固定 v65 `SingleFlowPolicy.kt:sfRealRestaurantStage`，由 `assistant_singleflow/SingleFlowNativeEffects.kt` 接入真实统一页，不使用首页进度策略。将当前已经接入的消息、候选、通话请求和 typed 单路/批量回执投影为阶段；结果优先于执行，执行优先于需求确认。普通 done、CLOSED 会话状态不等于通话结果。新的用户轮次处理中抑制历史终态；当前轮次的明确结果仍能显示第四阶段。MAKE_CALL_REQUEST 对应 v65 agentCallSpec，第三阶段仅表示进入执行流程，现有“尚未拨号”提示保留。

该投影不持有第二份任务状态、不触发 API，不将用户消息内容用于关键词阶段匹配。已确认的 assistant 文案保留 v65 的关键词兼容。未接入的通话页面/ASR/TTS 状态不伪造，待其 Coordinator 接入时补充对应阶段输入及测试。视觉继续使用已有运行态组件和样式，本批仅改变当前项并补无障碍语义，不宣称动态完成态视觉已全面验收。

实施文件：新增 domain/conversation_progress.dart；修改 conversation_state.dart（只读 getter）、conversation_header.dart（阶段参数及语义）、conversation_page.dart（含窄高度接线）；新增阶段策略和真实 controller/widget 连续测试。每微批不超过三文件。

覆盖分页、重复、冲突、缺口、倒退、错 session、账号切换、未知事件、503 与鉴权错误区分；SSE 任意字节分块与多行、错误/断流；统一页晚到/退出/重入、候选第 N 个、done 非成功。设计固定 HTML 自动化捕获；设备集成使用专用合成账号，不覆盖真实登录作为保数据验收。
