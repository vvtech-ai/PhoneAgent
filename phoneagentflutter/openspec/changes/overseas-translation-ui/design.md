## Context

首页 translation 分支仅显示提示，普通 DialerPage 已有可复用号码、地区、键盘和系统电话交接。v65 当前生产使用 TranslationCallScreen，旧 AssistantTranslateCallV88Page 不能作为行为基线。固定源 TranslationPresetsSheet/TranslationLanguagePickerPage/AssistantDialerPreferenceState/OverseasTranslationSettingsPage 定义配置交互。

## Goals / Non-Goals

**Goals:** 共享配置→环境检查→翻译通话→终态返回，显式模拟外部能力而不模拟真实业务完成。本批实现配置和共享通话页；真实端口任务保持未完成。

**Non-Goals:** 国内SIP、真实号码自动外呼、未经授权的定位/麦克风申请、设计独有折叠面板、国内结算页。

## Decisions

### iOS编译后启用共享设备工厂（2026-09-20）

Mac恢复连接后，在独立源码目录以Xcode15.2编译现有两个Swift双工端口通过；继续将translation_device_media_providers的平台门禁扩为Android/iOS，复用同一个LiveKit/AppAudio组合，不另写iOS业务流程。修改该provider与工厂定向测试（移动双平台可构造完整端口、桌面/Web不可用），不改变权限/地区/媒体ready门禁。原Swift端口保持硬件职责，随本批验证纳入；签名/安装/调试启动复用已解锁screen。编译与页面启动不等于双工声音、蓝牙、中断或真实电话通过，集中人工项仍保留。

### Android完整设备工厂与拨号前麦克风门禁（2026-09-20）

将已编译Android双工草稿与共享DeviceTranslationPcmBridge纳入本批验证/提交；iOS两个Swift草稿仍未编译，不启用iOS真实工厂。新translation_device_media_providers组合既有LiveKit工厂及AppAudioTranslationMedia+VoiceSocket+双工PCM，两者共用权限来源和全局音频租约，按transport创建新单次实例，不能只有LiveKit。原有可覆盖provider名称保留导出，Web/非Android默认空；iOS复用同一Dart工厂的后续启用以原生编译为前提，不复制业务实现。

固定v65 AssistantRootActionGraph为翻译请求RECORD_AUDIO。运行时在明确拨号、请求快照校验后，先读授权，denied才请求一次；未授权不创建HTTP服务/后台会话，返回明确麦克风提示，账号失效或离页晚到不拨号。端口仍在实际connect时只读复查授权。正常ASR/TTS默认duplex=false不变。测试定向覆盖完整工厂选择/作用域、授权拒绝/迟到和既有媒体协议/PCM；新增Android原生能力只构建Android，不冒充iOS或听音验收。

### 正式拨号运行时装配（2026-09-20）

新增TranslationDialRuntime按确认快照固定登录身份、服务节点与原音设置，复用TranslationSessionFactory的Finished/归档。节点级语言和HTTP客户端归单次会话所有，create晚到与hangup清理完成后才关闭；退出账号立即禁止新create/merchant，旧账号清理不受新账号凭据影响。并行准备/重复拨号拒绝；异步准备期间离页时关闭返回的控制器。

绑定支持FutureOr以等待原音读取，普通同步MOCK绑定保持兼容。运行时只接完整双媒体工厂；该设备工厂在iOS双工未编译前仍为null，生产Web仍不可用，不用LiveKit单路代替完整回退。此批完成共享HTTP/快照/资源总装配的可验证部分，原生2.2e2和正式外呼验收不勾选。

微批依次为：运行时/HTTP资源/生命周期回调，provider与异步绑定/路由，定向测试及记录。只运行翻译相关测试和原连续入口冒烟，不全量、不重复无关平台构建。

### 完整App Web演练翻译贯通（2026-09-20）

普通TranslationDialerRoute优先使用显式sessionBinding，其次读取可作用域覆盖的translationDialSessionBindingProvider；provider默认null，真实媒体尚未装配时继续拦截，不启用真实外呼。preview=true的独立页面不隐式继承正式绑定。UI只组合入口，不访问HTTP或设备。

tool/previews/shell_translation_preview.dart复用TranslationCompletionPreviewController及正式拨号/通话/记录组件，仅覆盖外部配置、可信位置、倍率、目录、节点探测和内存记录；合成登录代次变化重建会话演练资源。ShellPreview的合成首页配置只将既有translation动作卡设为可用，不修改正式builtinHome或真实后台配置。原音读取本演练内存偏好，未接真实主业务API仍保持空配置失败。常驻工作台MOCK标识不移除，普通Web电话不调用原生系统。

文件微批：app/translation_dial_binding_provider.dart与translation_dialer_route.dart；tool/previews/shell_translation_preview.dart、shell_preview.dart、shell_catalog_fakes.dart；专项连续导航测试和文档。验证三宽度、确认取消/就绪/接通/控制/终态与最近记录、退出重开清理；真实双工iOS编译、外呼总装配及设备验收仍独立待办。

### 旧服务capabilities显式拒绝兼容（2026-09-20）

固定v65 HttpBackendTranslationClient.createSession及其测试确认：首次带默认mediaTransports，旧服务400/UNKNOWN_FIELD且message为capabilities unsupported时，不带capabilities再创建一次。旧Android对任意IOException均重发，本迁移继续遵守已有未知网络结果不重放约束：仅400、UNKNOWN_FIELD、message完整词capabilities且响应没有callSessionId字段时允许一次重发。其他字段拒绝、403/500/超时/断网、已分配ID、第二次失败均不再创建。未知响应不冒充旧服务。

复用同一请求快照，仅复制JSON去掉capabilities，账号/号码/语言/原音/provider不变；第二次成功照常严格解析cluster/grant/媒体，已知ID但字段错误仍只hangup清理，不再create。无需新增公共错误契约，仓库私有类型标记可识别拒绝，不传递原始message或凭据到UI/日志。修改http_translation_backend_repository.dart和专项测试，规格/记录独立微批；不改媒体、按钮接线或真实呼叫门禁。真实旧服务可用性仍待集中联调。

### 国外服务端归档（2026-09-20）

固定v65 RealtimeTranslationArchivePolicy/Coordinator/Runtime、PhoneAgentRealtimeTranslationApi为依据：仅WORLD_CALL；实际接通证明后记录connectedAt，结束时间至少connectedAt+1ms，既有字幕500ms收尾，按clientCallId幂等PUT api/realtime-translation-calls/{id}。未接通丢弃待办；进程中断的已接通条目使用lastObserved结束，不重新拨号。归档成功才刷新任务数据，不推断钱包settlement。

新增translation/domain/translation_archive.dart（不可变快照及存储/服务契约）、data/translation_archive_codec.dart、secure_translation_archive_store.dart、api_translation_archive_gateway.dart；presentation/controller/translation_archive_controller.dart独立于页面生命周期串行持久化/封口/恢复。仅保存所需WORLD_CALL locator/grant与字幕到既有系统安全存储，环境/API/账号隔离；不保存LiveKit token、媒体URL或日志正文。坏格式/写失败不覆盖原数据，显示可重试状态。

TranslationSessionController向账号级归档器提交生命周期快照，TranslationSessionFactory统一注入；媒体照常立即关闭，不为归档延长采集；500ms仅处理已排队的既有字幕。provider在登录后恢复持久待办、成功刷新任务；原拨号页显示同步状态/重试。现有预览只替换归档API/存储，验证返回后继续归档和失败恢复，无新独立页面。微批≤3文件：规格→契约/codec/端口→协调器/测试→工厂/provider/现有页面→集中验收。原生双工及实际呼叫装配仍独立待办。

### 拨号到会话共享入口与计费边界（2026-09-20）

固定v65 PointsAwareTranslationCallGateway.start仅包装LocalSipDomestic/LocalSipInternational，BackendWebRtc直接delegate.start；BackendTranslationCallGateway/RuntimeSession无BillingSettled解析。此前“国外需复制PointsAware心跳/结算”的推断不成立，不迁移被排除的国内SIP计费，不伪造海外settlement。正式后端权威费用/归档另按实际协议核对。

新增纯Dart TranslationDialRequest 固定确认后的号码/名称/国家/语言/模型/节点快照，并映射原音设置至现有create请求；不把手选区号推断为可信位置，不自动发送分机按键。TranslationDialSessionBinding作为presentation组合端口，已存在的TranslationDialerRoute通过该端口进入同一TranslationSessionRoute；缺少绑定仍显式拦截，不能绕过媒体/归档尚未装配的门禁。确认弹层取消、网络拦截、地区不允许均不创建会话；结束回原配置，不重新拨号。

复用TranslationAccessPreviewPage的隔离ProviderScope，显式开启“配置到通话流程”后走同一个拨号按钮；原有合成服务/媒体/本机记录负责外部替身，完成后可核对快照与本机记录。原音由组合方提供已加载快照，不由domain读存储。微批≤3文件：契约/绑定/Route→控制器/演练→回归/文档；无原生改动、真实HTTP、权限或账号写入。Web回归三宽度、取消/双击/关闭晚到/配置不串线；iOS在制双工仍单列，不据此完成实际外呼总装配。

### AppAudio双工回退（2026-09-20）

固定v65 BackendAppAudioSocket/BackendPcmAudioBridge/RuntimeSession：WS加入downlinkAudio=binary，发送java-v1 start；app_audio_ready只放行merchant-call，merchant_audio_ready才启动16k/PCM16/mono采集。静音丢弃上行而不是发送零帧或停下行；二进制或JSON译音按非负sequence单调去重，负序号不去重，输出支持返回采样率。DTMF不支持，不能假成功。空会话ID沿v65兼容，其余不匹配丢弃。

新增translation/domain/translation_pcm_bridge.dart、data/app_audio_translation_media.dart、data/device_translation_pcm_bridge.dart；复用现有codec、VoiceSocket、PCM端口、全局受保护音频租约，不创建第二套页面。Dart负责有限队列、收发顺序、权限只读检查、旧回调隔离及释放失败保护。采集/播放只在merchant就绪后启动；socket开放不能提前开麦。

原生微批扩展既有PcmCaptureChannel/PcmOutputChannel的显式duplex选项；默认ASR/TTS/监听路径保持不变。Android通信采集源和路由；iOS双工采集与播放共用引擎/会话持有者，最后一个资源释放才恢复原会话，不能由播放采样率切换停止麦克风。所有原生代码只处理硬件，不读取任务/账号/字幕/HTTP。

每微批至多3文件，手写500行；协议/桥接/原生/生产工厂/同页演练/测试依次验证。测试真实本地WS、顺序门禁/静音/重复译音/格式切换/超时/终态/账号和共享页面，再三端构建。真实电话/声音/系统权限和阶段安装保留集中验收；不因AppAudio子项完成提前勾选归档/钱包/正式拨号总装配。

### Finished本机记录接续（2026-09-19）

固定v65 AssistantCallRuntimeControllers的Finished消费和AssistantClientCallRecordPolicy：本机记录使用clientCallId、开始时间、目标号码/名称、拨号国家和双方语言，按账号去重；它不等于服务端归档或积分结算成功。服务端RealtimeTranslationArchiveRuntime另有连接证明、500ms字幕收尾、持久journal、WORLD_CALL定位和PUT归档协议，钱包另有PointsAware结算；本子批不得用本机记录冒充这两部分。

新增domain/translation_call_finished.dart（不可变结束契约与本机元数据映射）、presentation/controller/translation_finished_recorder.dart（账号生命周期串行保存/显式重试）、app/translation_session_factory.dart与translation_finished_providers.dart。现有TranslationSessionController在终态通知导航前先发一次Finished，dispose及旧事件不得重复；账户工厂固定账号并注入记录器。生产拨号仍因AppAudio/准入/计费总装配缺口保持门禁，不能据工厂完成声明已可实际拨号。

正式TranslationDialerRoute显示共享记录保存失败与重试；已有TranslationSessionPreviewPage复用同一会话工厂/记录器和最近记录列表，存储只替换为隔离内存。每微批≤3文件、手写≤500行：规格→契约/记录器/控制器→工厂/provider/状态组件→页面接线→专项与全量测试/构建/浏览器。无新媒体/权限/真实账号写入，视觉后置。服务端归档与钱包结算保持父项待办。

### LiveKit真实媒体适配（2026-09-19）

固定v65 BackendLiveKitAudioClient/ReadyProtocol/StartupCoordinator及RuntimeSession确认：连接room后先默认听筒路由、开启麦克风、设置roomReady并可靠发布web_client_ready；必须同时收到本session（兼容空ID）的realtime_ready，不以worker_ready/room连接单独放行merchant-call。只接空topic或translation-call.control；DTMF为该topic自有JSON，不是SDK SIP DTMF。暂时Reconnecting/Reconnected沿v65不触发业务终态，真正Disconnected失败。销毁后不得因SDK连接或麦克风调用晚到复活。

浏览器发现旧共享View默认speaker=true与实际默认听筒相反，统一为false并同步控制失败保持值/成功后切换及三宽度页面语义断言。仅改变错误的初始展示，不新增产品音源策略。

新增纯Dart TranslationLiveKitRoom接口、SDK薄包装SdkTranslationLiveKitRoom和LiveKitTranslationMedia：订阅先于连接、双ready门禁、端口错误清洗/有界消息、串行控制、关闭等待在途硬件操作并释放实际room；全局音频受保护租约在真实关闭确认后才归还。已授权检查在媒体适配内只读，不偷偷请求；Web真实SDK工厂拒绝，合成演练仅替换room/权限端口，共用媒体适配和既有会话/页面。

依赖固定livekit_client 2.4.6，依据pub官方元数据及缓存源码确认Dart>=3.6支持本项目3.8；2.6.5/2.7.0的meta>=1.17等依赖与固定Flutter测试SDK基线不匹配，不升级Flutter或做dependency_override。锁文件/生成插件注册为机械更新，三端构建检查双端WebRTC依赖。原生摄像头不启用，Android只补WebRTC所需MODIFY_AUDIO_SETTINGS普通声明，不在本批新增权限弹窗。

微批≤3手写文件、500行上限。先规格→依赖/房间接口/SDK→共享媒体适配→测试与协议驱动Web演练→证据。AppAudio PCM输出/回退、生产按钮/钱包/完成归档及真机仍保持父任务待办，不以本端口或模拟事件宣称真实电话通过；视觉统一后置。

### 共享事件与通话页面接线（2026-09-18）

读取固定v65 BackendRealtimeProtocol、BackendTranscriptAccumulator及BackendTranslationCallRuntimeSession：只有call_connected或非空merchant字幕证明接通；merchant-call started不能证明接通，抢先事件不能被迟到HTTP结果降级。字幕按sourceLeg+segmentId分组，input和译文独立append/replace，final为累积标志（不能用整条final丢弃后来译文）。空sessionId沿v65接受，其他会话ID丢弃。LiveKit支持DTMF，AppAudio没有该控制，不能显示发送成功。

微批文件计划（每批≤3手写文件）：domain/translation_realtime_event.dart、data/translation_realtime_codec.dart、domain/translation_transcript_accumulator.dart；domain/translation_media_port.dart和translation_session_coordinator.dart；presentation/controller/translation_session_controller.dart、domain/translation_call_view.dart；presentation/pages/translation_session_route.dart、translation_call_page.dart；data/preview_translation_session.dart、presentation/pages/translation_session_preview_page.dart、tool/previews/translation_session_preview.dart；各对应test文件及文档独立小批。通过可注入媒体事件与控制端口驱动同一个正式协调器/控制器/通话页，演练只替换外部端口，不再用手动修改页面phase证明协议链路。

媒体订阅在connect前建立、回退先取消旧订阅，端口身份+生命周期阻止晚到；终态停止计时、取消订阅、清理一次，挂断仍等已发控制请求返回。静音/音源只有端口执行成功后更新，不支持DTMF或失败明确可见。不新增无限重连、真实音频采集或外呼；Web正式入口保持未就绪门禁，LiveKit/AppAudio SDK、全局音频资源和归档未装配，父任务2.2不勾选。未知事件不推进状态，协议错误不泄漏原始payload/票据。回归覆盖JSON/binary协议、字幕、早到接通/终态、fallback旧连接、控制失败与共享页面返回。

### 模型准入、倍率与正式开发者偏好（2026-09-18）

按v65 TranslationCallEffectiveSelectionPolicy/TranslationCallRoutePolicy分开选模型和呼叫准入：非CN可信位置允许海外模型；未知/CN默认禁选，不带入国内SIP。构建testControlsEnabled且持久forceBackendWebRtcForTesting可开放海外模型，但呼叫策略仍要求已解析真实位置。海外普通设置入口按真实非CN显隐，开发者页有独立海外模型/US/JP选择；手选区号、节点质量和倍率不参与地区判断。强制开关不重写真实位置、不自动改节点；旧文案“固定US”与实际策略不一致，遵循代码实际selected serviceRegion。

在TranslationPreferences/codec/controller增加兼容旧schema的forceBackend字段，保留原环境隔离和写失败重试。正式DeveloperToolsRoute仅解锁后进入，挂真实翻译设置及持续标识尚未接通媒体；其他工具保留明确MOCK演练入口，不冒充全部开发者消费者已完成。ENABLE_TRANSLATION_WEBRTC_TEST_CONTROLS默认true沿固定v65构建值，可显式false让持久开关不生效。

新增纯DartTranslationAccess策略及provider，正式拨号/模型sheet/设置共用；未知位置只读缓存，不自动申请权限。新增账号ApiTranslationBillingRepository GET api/account/settings/realtime-translation-provider，仅提取有效正有限billingMultiplier并规范海外模型别名，按v65显示×一位小数；空/失败不填默认倍率，不据available字段更改海外地区准入，不发送PUT。provider绑定AccountApi账号代次，旧账号返回隔离；演练完全覆盖倍率与节点来源，导航显式继承ProviderContainer。

微批≤3文件：偏好三文件→domain/data/app→正式设置与弹层/拨号接线→测试/预览。全部Dart共享，无新原生依赖/后端变更/电话或账号写请求；全量test/analyze/OpenSpec与Web/Android/iOS构建，浏览器合成地区/强制/刷新/返回闭环。初始化第三步和真实媒体仍未完成。

### 可信地区与国家选择（2026-09-18）

固定v65 DefaultTranslationRegionRepository、DialCountryLocationState：可信地区来自定位和逆地理编码，不来自手选拨号区号、SIM/语言或服务节点；首次仅读缓存，点击获取才请求系统权限和一次定位。定位失败保留已有可信地区，不新增缓存过期产品规则。Flutter用独立共享Controller管理加载/获取/拒绝/需设置/失败及环境隔离存储，仅保存国家ISO和采样时间，不保存坐标；存储失败可见，离页取消并丢弃晚到结果。国家页展示当前位置，点击已识别且支持的国家才选择区号，不自动覆盖号码/语言。

Android薄端口使用系统LocationManager和Geocoder，支持粗略或精确权限；iOS参考iOS_newui2 AILocationService使用CoreLocation和CLGeocoder。系统适配只返回结果和权限分类，不复制业务准入/缓存策略。Web正式端口明确不支持，演练注入内存来源和存储，不请求浏览器位置或写真实设置。拒绝且不可再弹权限时显示去设置，返回后显式重新获取；超时/关闭移除位置回调，原生逆地理编码晚到通过请求代次隔离。

本子批不启用真实翻译外呼，不提前改变所有模型准入：v65还存在testControlsEnabled + forceBackendWebRtcForTesting例外，须与正式开发者配置接线一并实现。倍率来自账号翻译provider响应，非节点测速，后续独立补齐。初始化第三步产品选择仍保留待确认。

### 拨号模型弹层与只读质量（2026-09-17）

按v65 AssistantTranslationModelSheet/TranslationModelEndpointProbe补拨号模型入口，海外专用迁移仅保留OPENAI/GEMINI，不迁移国内SIP选项。选择即持久化并关闭，关闭/遮罩/返回不改选择；区域设置仍独立。每次打开与手动刷新对两个选项并发GET当前节点languages路径，2.5秒连接/读取限制，100..499算节点可达，500或异常不可用，200/500ms为质量分界；不拿严格目录解析代替探测，不据质量启用模型或电话。Web仍使用固定GET代理，测量含代理往返及响应读取，不宣称与原生头部探测完全同值；不放宽CORS或开放POST。失效区域/关闭后的结果隔离；刷新单飞。演练使用显式合成样本，不发真实请求。复用静态样式与组件，视觉后校准，定位可用模型门禁和真实计费倍率仍待接，不伪造倍率。

### 后端控制协议与共享会话编排（2026-09-17）

固定v65 HttpBackendTranslationClient/BackendTranslationCallRuntimeSession/BackendMerchantCallStarter：独立裸JSON POST create、merchant-call、hangup，写操作x-user-id，音色provider默认twilio，OPENAI/GEMINI映射实际后端值，返回必须具有callSessionId、US/JP cluster及recordingAccessGrant。iOS_newui2指定提交搜索未找到该后端控制链路，不虚构已有iOS实现。Flutter新增协议、独立HTTP仓库和共享会话协调器，媒体通过薄端口注入；不会从普通按钮启用未完成媒体链路。

查询语言后才create；媒体端口ready契约必须是LiveKit room+realtime ready或AppAudio ready，10秒超时；优先LiveKit失败后尝试有返回地址的WebSocket。只在ready且未退出时merchant-call；仅服务端409/MEDIA_CHANNEL_NOT_READY沿v65每500ms、最多10秒重试，不对网络未知结果重复外呼。create单次请求层不自动重放，旧服务缺capabilities兼容回退需后续真实协议证据确认，不将此部分提前标完成。用户取消/销毁对新步骤生效，create晚到仍回收服务器会话；控制请求与hangup顺序串行，返回started不当作电话接通。媒体及服务器清理一次，失败不自循环。

本批合成协议与并发测试，无真实POST/音频/原生依赖；记录连接凭据只在内存，不写日志/fixtures。后续真实媒体事件→共享页面、定位准入、归档和双端仍属于2.2/2.3，不能以HTTP仓库或纯逻辑通过当作实时翻译完成。

### 国外节点语言目录（2026-09-17）

核对固定v65 TranslationProviderUiCatalog、HttpBackendTranslationClient和TranslationModelEndpointProbe：海外选项是本地固定OPENAI/GEMINI，准入不使用独立节点模型可用性列表查询；账号provider配置GET确实存在，按后续子批读取倍率，不能与节点接口混淆。翻译服务独立于account API；GET `/api/app-translation-calls/languages` 返回裸languages数组，无账号头或Bearer。新增domain/translation_service_catalog.dart、data/http_translation_catalog_repository.dart、core/config/translation_service_config.dart；app/translation_catalog_providers.dart装配账号无关的只读查询；海外设置页由独立route接入状态组件。保留固定两个模型及现有偏好，不把节点可达当作模型可用、媒体就绪或呼叫成功，不改变原七语言picker。

节点遵循固定v65默认值并支持显式dart-define覆盖，空区域节点按原规则回默认，非法配置拒绝而不静默改目标。生产仍使用HTTPS。Web开发通过同源loopback固定白名单GET语言目录转发，不发送账户/Authorization/cookie，不开放任意URL或翻译POST；生产Web和移动端直接使用配置的HTTPS节点。切区域产生独立查询，取消/销毁不展示晚到结果；错误给重试，无后台循环。只读目录不受初始化第3步产品决策阻塞，真实create/media仍另行实现。

### 持久偏好子批（2026-09-17）

以固定v65 AssistantDialerPreferenceState和TranslationCallSettingsRepository为证据：配置是设备偏好，不随账号清除；普通/翻译地区独立，切模式不推导语言。新增domain/translation_preference_store.dart、data/secure_translation_preference_store.dart及app/translation_providers.dart，复用既有安全存储按环境/API隔离，不保存电话号码或认证数据。TranslationSetupController拥有加载、串行合并保存、失败显式重试；provider跨页面存活以免离页截断写入。存储读取失败时禁止默认值覆盖旧值，未知版本不得静默重写。无store的Controller仅供明确隔离测试/演练。

修改translation_dialer_route.dart、translation_selection_pages.dart，新增共享保存状态条；异步加载后恢复地区，联系人预填不覆盖语言。配置主页面和模型页显示加载/保存/失败状态，真实翻译仍未接，不改变呼叫权限。测试覆盖codec/环境key、读写失败、快速变化最终值、dispose晚到、路由重开与MOCK隔离。无新依赖/HTTP/数据库/日志正文/媒体。

- 第一微批不复制拨号盘，DialerPage增加可选配置区域和主按钮语义；新TranslationDialerRoute组合既有号码Controller和独立TranslationSetupController。
- 翻译与普通拨号分别记忆地区，切模式只切地区、不反向改语言；用户选择地区按v65同步对方语言。七个可见语言遵循picker，不据底层支持表增加入口。
- 顶层表单和拨号前sheet共用设置状态；sheet内语言选择push页面，取消返回sheet而非首页。关闭翻译后可用既有系统普通电话端口，页面明确该行为；不自动执行真实电话验证。
- 未接持久存储前配置仅页面会话内有效，UI标注。默认Gemini来自v65 TranslationCallRouteModels，不把演练配置回写初始化第三步，二者决策分离。
- 主入口可见配置，点击翻译呼叫校验后明确说明真实链路未接。后续独立MOCK完整通话入口替换外部端口，不能用普通拨号或虚假成功回退。
- 通话页按最新v65四按钮：静音/拨号盘/扬声器及独立挂断；国外终态直接回来源，不显示国内结算。真实链路严格create→media ready→merchant-call。
- 海外设置页不是废弃页：v65 RegionAwareTranslationProviderSettingsHost按已解析地区进入，拨号模型入口另用模型sheet。当前海外专用配置入口用于共享交互覆盖，不代表已复刻地区显隐或拨号模型sheet；这些生产入口规则和真实地区解析归1.2，最终校准不可遗漏。

## 共享通话页批次

TranslationCallPage只消费View和控件回调，TranslationPreviewController明确仅UI模拟器，无API/媒体/账号依赖，不能当生产协调器复用。调用方主动从debug-only演练入口选择三场景；用手动阶段推进替代伪造真实连接，恒定显示MOCK，不传入输入号码。终态自动返回配置并显示模拟结果。

双语展示复刻v65本地原文优先/远端译文优先、同语族/相同/空文本不重复显示次行。模拟更新按leg+segment替换，final不被晚到partial覆盖；计时在Connected起算，dispose/终态停止。DTMF纯内存、最多保留16位；挂断失败必须显式第二次点击，系统返回不退出活跃通话（演练提供单独退出按钮）。

首轮320×568展开DTMF触发48px溢出，改为剩余转写区域不足140时标题和气泡同区滚动，底部四按钮不挤出。按钮语义去除重复可见标签的朗读；三宽度和错误返回回归通过。模拟环境进度35%是合成展示，不是服务端测量。

## Risks / Trade-offs

静态原型含旧三按钮翻译页 → 当前v65行为优先，视觉差异单独列出。配置暂存未持久化 → 页面持续说明，生产偏好和跨入口一致性列为后续任务，不声称已完成真实迁移。设备策略旧记录不等价当前在线状态，但不通过替代路径绕过已发生的安装拒绝。
