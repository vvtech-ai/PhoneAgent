# 国外翻译配置与共享通话页验证

## 2026-09-20后续：双端共享工厂与iOS阶段安装

iOS双工端口现已编译验证，正式provider同时支持Android/iOS，复用相同LiveKit/AppAudio、权限/地区门禁和归档编排，未新增iOS专属业务。8项工厂/运行时/PCM定向测试、analyze及iOS签名安装启动通过；严格签名、Bundle ID和源码哈希核验见[设备阶段记录](DEVICE_STAGE_20260920.md)。本批没有真实电话、开麦、蓝牙或归档请求；下方早期“iOS未编译/工厂为空”已被本增量取代，集中人工步骤仍全部保留。

## 2026-09-20：Android完整媒体工厂已接线

`translation_device_media_providers.dart`将现有LiveKit工厂及AppAudioTranslationMedia/VoiceSocket/DeviceTranslationPcmBridge组装到正式运行时，两路共用权限与音频占用。Android默认可进入真实会话准备；iOS双工尚未编译，默认工厂仍空；Web继续隔离演练。读取工厂不启动麦克风/Socket，只有显式确认呼叫才执行。

固定v65 AssistantRootActionGraph的translationCallAudioPermission为依据，新增共享拨号前麦克风门禁：先只读检查，denied才申请一次，拒绝/不可用不打开服务或创建后台会话；权限提示不代表采集。账号失效丢弃迟到结果。端口connect仍只读复核权限，AppAudio仍等merchant_audio_ready才采集。普通ASR/TTS默认参数不变。

66条相关定向测试通过（7秒测试阶段），另复核正式provider使用默认设备工厂而非替身通过；analyze无问题，Android Debug9.9秒通过。纳入此前5个Android/Dart桥接在制文件及3项通道测试，iOS两个Swift草稿不提交。没有全量、真实外呼、开麦、设备安装或新iOS编译。

集中验收追加：先拒绝麦克风确认无create/merchant，再允许后检查LiveKit；受控故障切AppAudio，确认先关闭旧房间、app_audio_ready不采集、merchant_audio_ready才采集；检查静音/音源/采样率切换/后台/挂断后普通语音恢复。需要授权测试号码及后台时间窗关联；实际声音/真机路由/服务端收件目前均未验。

## 2026-09-20：正式拨号运行时装配

[TranslationDialRuntime](../../lib/app/translation_dial_runtime.dart)与[provider](../../lib/app/translation_dial_runtime_providers.dart)按确认快照固定节点、账号、号码/语言/模型和原音设置。语言目录与HTTP控制使用同一节点，使用现有独立客户端而非主账号Bearer；Finished与归档沿现有TranslationSessionFactory。

原音异步读取失败不默认拨号；并行准备/重复创建拒绝。离页后迟到控制器不启动而直接释放。退出账号立即作废新业务步骤，但已分配会话仍以原身份挂断；HTTP资源等待迟到create/merchant及hangup完成后关闭。刷新token不换登录所有者。Web正式入口继续不可用，完整App演练仍仅覆盖外部合成端口。

历史运行时子批当时尚未开放真实电话；Android工厂现已由上方子批接线。iOS仍待双工编译，Mac此前SSH5秒超时，无新iOS编译/双端安装证据。

验证：新增6项运行时、1项离页、1项正式provider；257项翻译模块及完整App冒烟22秒通过，另1项provider通过，analyze无问题。不跑全库、不重复平台构建或逐屏截图。测试只替换外部服务与媒体，不访问真实号码或权限。

集中验收顺序：补设备工厂并双端编译→授权号码确认原音/节点快照→LiveKit及强制失败后的AppAudio回退→准备期间返回/退出登录→后台核对唯一会话与清理→通话结束核对本机记录及归档。自动化证明顺序和资源契约，不证明设备声音或后台收件。

## 2026-09-20：旧服务显式拒绝能力声明的兼容

来源为固定v65 `4c781e3` 的 `HttpBackendTranslationClient.createSession` 和同名测试：旧节点可返回 `400 / UNKNOWN_FIELD / capabilities unsupported`，需要省略capabilities再次创建。共享[HTTP仓库](../../lib/features/translation/data/http_translation_backend_repository.dart)已补这条路径，不新增页面、媒体或调用开关。

| 结果 | Flutter处理 |
|---|---|
| 400、UNKNOWN_FIELD、message含完整词capabilities，且没有callSessionId字段 | 复制原JSON，仅删除capabilities，最多追加一次创建 |
| 超时/断网、403/5xx、其他字段/错误、已分配或异常callSessionId字段 | 不重新创建，按原错误路径返回 |
| 第二次仍失败 | 直接失败，没有第三次请求 |
| 第二次成功但cluster/grant/媒体字段无效 | 保持严格解析；已知合法ID只执行hangup清理，不重新create |
| merchant-call/hangup错误 | 不进入此创建兼容分支；原媒体未就绪有界重试规则不变 |

**与旧Android的有意差异**：旧代码捕获任意IOException后重发；这里继续遵守本项目既有“未知网络结果不重放”约束，只接受有明确字段拒绝证据的响应。不能据本子项宣称所有旧服务错误格式都兼容。服务若返回不同schema错误，需要先抓取脱敏错误码/字段再确认，不能自动放宽到任意400或网络异常。

[专项测试](../../test/features/translation/translation_legacy_create_test.dart)覆盖13个正反路径，连同原仓库6项测试通过。请求快照、账号头、号码/语言/原音/模型和节点保持不变，不携带主业务Bearer，原始错误message不传入UI或日志。

最终2097项全量测试（2分31秒）、analyze、OpenSpec19项、格式/diff、Web Debug30.7秒和Android Debug3秒通过。Android使用Flutter项目既有Android Studio JBR；工作区仍含7个原生音频在制文件且不随本提交交付，因此该APK不是纯本提交版本或真机验收证据。未改变页面，不重复浏览器逐屏截图；iOS本批无法构建。

集中人工步骤：待正式媒体总装配及授权测试号码就绪后，在受控旧节点确认首次字段拒绝、第二次不含capabilities；确认只产生一个有效会话，媒体ready后才merchant-call。再验证超时不会创建第二条记录，终态/录音grant仍有效。必须关联节点时间窗和sessionId，不能用合成请求计数代替后台事实。本批不发真实create/merchant-call、不使用真实用户数据；Mac SSH超时，iOS编译和双端真机仍待办。

## 2026-09-18 最新：协议事件驱动共享通话页

已补v65事件/字幕归并、共享协调器事件及控制、页面生命周期与协议驱动隔离演练，详见[共享会话验证](TRANSLATION_SESSION_VALIDATION.md)。29新增/1672全量、三端构建通过。以下早期手动阶段MOCK仅为旧UI演练；新入口使用共享协调器但外部端口仍为MOCK，正式媒体SDK、拨号装配、归档与真机未完成。

## 2026-09-18 最新：模型准入、倍率与开发者偏好

正式拨号/模型弹层/海外设置已接可信地区和强制海外策略，正式开发者翻译配置共享持久偏好；账号GET倍率已接，旧账号值和晚到隔离。24新增/1558全量、三端构建和浏览器演练通过，见[实现及集中验收](TRANSLATION_ACCESS_VALIDATION.md)。以下早期“模型准入/倍率未接”由本节更新；初始化决策、真实媒体/事件/归档、真机和视觉仍未完成。

接口澄清：本地海外目录不依赖独立节点模型可用性查询；账号provider配置GET存在并用于倍率，旧文“没有可用模型接口”不能理解为没有账号配置接口。

## 2026-09-18 可信地区与国家选择

正式普通/翻译国家页已接共享定位Controller、环境隔离可信缓存、Android/iOS薄定位/权限/逆地理编码端口；离页立即取消，位置成功不自动选区号。专用Web演练复用正式页面、状态，仅替换来源/存储，见[定位实现与集中验收](TRANSLATION_LOCATION_VALIDATION.md)。新增24项、1534全量及Web/Android/iOS无签名构建通过。以下历史“定位全部未接”由此更新；模型准入与强制海外开发者例外、倍率、初始化决策和真实媒体仍待接，不将定位端口通过等同真实翻译完成。

## 2026-09-17 拨号模型sheet与节点响应检测

- 普通翻译拨号增加“翻译模型：当前模型”入口，底部sheet只列迁移范围内GPT/Gemini；选中（含再次点当前项）保存并关闭。关闭图标、遮罩、系统返回只关闭当前sheet，保留拨号草稿和选择。原海外服务区域设置仍独立。
- `translation_model_sheet.dart`负责语义控件，`translation_quality_providers.dart`负责区域和生命周期，`HttpTranslationModelProbe`独立无凭据GET当前节点languages，复用原`translationEndpointProvider`白名单解析；不请求账号、电话或媒体。2.5秒连接/读取限制、禁止重定向；沿v65将HTTP100..499作为节点响应，5xx/异常为不可用。耗时0–199良好，200–499一般，500起较高延迟；不代表模型实际可用。
- Web使用既有同源GET代理，耗时包含本地代理、网络与响应读取；原生也包含读取，不冒充v65只到响应头的完全等值测量。刷新保留旧样本并禁重复，失败可手动重试；关闭自动释放端口，区域family隔离旧结果。`preview=true`仅合成140/620ms，刷新切换失败/恢复，不挂真实provider。
- 11项新增回归：阈值、状态码/非JSON、鉴权头/超时、异常、双模型并发/区域隔离、选择/取消/返回、刷新单飞/晚到、MOCK隔离与320/390/430短屏。全量807/analyze/Web与Android Debug/OpenSpec19/421文件格式通过。普通浏览器复用登录，测速1045/1063ms，刷新→GPT→重开选中→恢复Gemini→首页完整路径通过，无电话或新短信。
- 样式按v65静态sheet参数及既有组件实现；语义刷新文字代替源图标、行布局/色阶等留视觉校准，未冒充测量通过。国内SIP选项不带入；地理可用性、计费倍率、初始化决策仍未完成。本批无新iOS构建或真机安装证据。

## 2026-09-17 后端控制协议与共享准备编排

- 固定v65依据：HttpBackendTranslationClient、BackendTranslationCallRuntimeSession及BackendMerchantCallStarter。新增独立HTTP仓库支持create/merchant-call/hangup，裸JSON与x-user-id，不带主业务Bearer、不自动重定向、不重放未知网络结果。创建结果校验会话、集群、录音授权和媒体地址；已知会话后续字段无效时尝试一次回收，不重新创建。
- TranslationSessionCoordinator为纯Dart单次会话：查询实际语言目录并规范语言码→create→等待媒体就绪→merchant-call。媒体端口契约要求LiveKit room+realtime或AppAudio ready，不能用socket open替代。10秒媒体超时；LiveKit关闭后才尝试返回的WS地址。只有明确409/MEDIA_CHANNEL_NOT_READY按500ms、有界窗口重试，started只代表开始拨号，不代表接通。
- 取消禁止后续外呼；创建晚到仍回收；已发merchant-call返回后才hangup；媒体与服务器清理单飞，销毁后不更新页面。新增23项合成协议/时序测试，覆盖超时回退、重入取消、晚到创建、挂断顺序、409恢复/上限、未知网络不重拨和清理失败；全量796项、analyze及415文件格式检查通过。仓库层回收失败同样传递“结束状态待确认”，不能被后续stop洗成已结束。
- 最终Web Debug与测试环境Android Debug构建、19项OpenSpec及diff检查通过。产物可编译不等于真实媒体或设备验收。
- 本批没有真实HTTP POST、音频、外呼、扣费或新平台依赖。普通呼叫入口仍明确未接通；现有页面MOCK控制器未冒充生产协调器。未生成新浏览器页面、iOS构建或设备安装证据。
- 当时剩余项的当前状态以[MIGRATION_CURRENT_STATUS](MIGRATION_CURRENT_STATUS.md)为准；旧服务capabilities显式拒绝兼容已由2026-09-20小节更新。协议子项不代表真实翻译完整验收。

## 2026-09-17 独立服务节点语言目录

- 固定v65证据：TranslationProviderUiCatalog是本地OPENAI/GEMINI目录；HttpBackendTranslationClient使用裸JSON `GET /api/app-translation-calls/languages`，不走主业务AccountApi。此前“可用模型真实查询”待办措辞不准确，已纠正；语言目录成功不证明模型已启用。
- 共享实现：core/config/translation_service_config按v65环境默认值及TRANSLATION_DEFAULT_URL/US_URL/JP_URL显式覆盖；data/http_translation_catalog_repository独立Dio，不发送Authorization/账号头，禁止重定向；app/translation_catalog_providers按区域拥有异步结果；presentation/widgets/translation_catalog_status展示加载、错误重试、空及实际目录。
- 正式翻译配置→海外模型与服务区域挂载目录；原有七种语言picker和两个模型选项不被后端目录扩展或自动修改。演练不挂载真实查询组件、不访问真实服务。
- Web开发仅本地8080白名单 `/translation-catalog/{DEFAULT|US|JP}/api/app-translation-calls/languages` GET转发；拒绝任意路径、query目标或POST，并剥离所有非白名单请求头。不是通用开放代理或翻译呼叫代理。自定义节点不走此固定代理，需服务端正确CORS，不能关闭浏览器安全策略。
- 新增7项协议/配置/Widget测试及1项Node代理测试；766项全量、analyze、Web/Android Debug测试环境构建通过，Node代理2项通过。切区域晚到不覆盖当前结果，失败需手动重试，合成测试不发网络。
- 普通Web复用原登录：同声传译→海外设置，Default实际返回3种语言（中/英/日）；切US实际返回13种，截图可见模型、目录及三地区选项；恢复原Default。仅GET目录和本地偏好临时切换，无新短信、外呼或真实账号写入。
- 风险/后续：v65默认及生产节点名字与test节点存在历史混用，沿固定源保留而未擅改部署；真实create前必须按所选节点目录校验语言，不能认为所有节点能力一致。本批无iOS构建或新设备安装证据；首次第3步待用户确认，定位、模型网络质量sheet、真实create/media-ready/merchant-call与平台音频仍未完成。

2026-09-17，OpenSpec `overseas-translation-ui` 1.1/2.1；不是实时翻译真实外呼完成报告。

## 实现及来源

- 固定v65 `4c781e3`：TranslationPresetsSheet、TranslationLanguagePickerPage、AssistantDialerPreferenceState、OverseasTranslationSettingsPage、TranslationCallScreen、TranslationCallContract、TranslationCallTranscriptPresentation/SecondaryPolicy。
- 设计 `0cd58de` 的拨号/translateCallPage静态HTML与已有组件；现行v65四按钮和左右双语气泡覆盖旧原型三按钮/折叠分区。不带入国内SIP或国内结算。
- `features/translation/domain`：语言/偏好/通话展示模型与双语次行规则；两个独立Controller分别管理页面配置及明确MOCK状态。Page/Widget无API、存储、设备调用。
- 配置复用DialerPage/号码规则/SystemDialer端口。首页同声传译直接进入；普通拨号页“实时翻译配置”携带原始号码和地区，不重复拼区号。
- 翻译/普通分别记忆地区；显式选择地区同步对方语言，切模式不覆盖语言。默认Gemini/Default、中文→英文、七种可见语言来自v65。持久偏好现已接通，见下方新增验证。
- 关闭翻译后明确普通呼叫才交给系统电话；翻译呼叫尚无真实端口，校验后提示未接入，绝不自动转普通电话。浏览器验证不执行真实系统电话。
- 入口复核：v65 `RegionAwareTranslationProviderSettingsHost` 在地区已解析且海外时显示海外设置，拨号模型入口使用独立模型sheet。当前海外专用配置页直接提供模型/区域选择用于覆盖交互，尚未实现地区条件显隐与原拨号模型sheet，不作为入口一致性验收通过。

## 演练边界与操作

Debug首页→同声传译→进入翻译通话演练（MOCK）→三场景之一。无需填写号码，不使用或传输输入号码。

正常场景：模拟下一阶段四次依次走环境检查→拨号→振铃→接通→翻译；添加合成双语；切静音、扬声器；打开拨号盘发送合成DTMF；挂断自动返回配置，显示未产生真实记录或费用。活跃状态系统返回不退出，单独“退出演练”用于测试清理。

失败场景：环境失败在首次推进后返回并显示失败；挂断失败首次保持页面和错误，显式再次点击才返回。没有自动重试外呼。退出/终态取消计时，后续合成事件不再改变状态。

MOCK范围包括地区/网络检测、阶段、计时、转写、静音、音源、DTMF和挂断；没有HTTP、WebSocket、LiveKit、麦克风、播放器、蓝牙、收费、归档或账号写入。模拟控制器不是生产create/media-ready/merchant-call协调器。

## 证据

- 新增21项回归；全量484项、analyze通过；Web共享405项+Chrome流2项+Node代理1项。
- Web Debug、测试环境Android Debug构建通过；OpenSpec19项通过。
- 320/390/430宽度；短屏DTMF曾溢出48px，已修复并回归；语言页/提示层系统返回、号码保留、海外配置恢复、拒绝错误号码/国内模型、普通交接边界有自动测试。
- 浏览器真实首页→配置→法语选择→海外JP节点→返回已验证；演练环境到翻译→双语→静音→DTMF1→扬声器关闭→挂断返回已验证，截图检查四按钮/气泡/号码键盘。
- 当前Android真机、iPhone16.7.16和Mac已解锁screen均在线；只读查询已验证。因历史安装拒绝，已向用户询问恢复标准安装，本批尚未重新安装；不将构建通过当作真机验证。

## 剩余实现和集中人工验收

| 项目 | 接入要求 | 人工步骤及禁止情况 |
|---|---|---|
| 偏好/定位 | 环境隔离存储已接；真实地区/权限、可用目录待接 | 双端切语言/地区后重启；拒绝权限有明确恢复；禁止模拟定位当真 |
| 创建/呼叫 | 共享create→media ready→merchant-call，保留v65 fallback | 授权测试号码，观察媒体ready后才拨号；票据不等于接通，不自动重发电话 |
| 媒体 | Flutter统一协调，平台薄录放音/路由 | 双向说话、静音、扬声器、原音混音、DTMF；断网/耳机/中断/权限，确认无漏音/重播 |
| 终态/历史 | 服务端结束、录音/转写归档、任务刷新 | 远端或主动挂断后回来源；任务展示真实历史/录音，不展示国内结算或虚假积分 |
| 双端UI | 当前共享页面阶段安装 | 同一路径/屏宽/安全区/字体；不以Web截图代替双端证据 |

真实协议/媒体待实现，日志字段和自动恢复规则届时按真实端口落地；此批无真实callId，不虚构后端日志证明。视觉静态先行，最终运行态测量/差异校准仍待做。

## 持久偏好批次（2026-09-17）

- 来源：v65 `AssistantDialerPreferenceState`保存模式/提示/双方语言/独立地区，`TranslationCallSettingsRepository`保存海外模型和节点；都是设备偏好，不按账号清除。
- 共享实现：`TranslationPreferenceStore`端口、`SecureTranslationPreferenceStore`安全存储、`TranslationSetupController`加载/串行合并写入、`translationSetupProvider`跨页面保活。存储按environment+API base隔离，不存电话号码、通话记录或认证数据。原音设置使用既有独立存储，未被覆盖。
- 读取失败禁改配置并提供“重试读取”；保存失败保留最新草稿并提供“重试保存”。未知schema报错而非静默重写；未知语言/模型/地区枚举回退安全默认。退出配置页不dispose共享Controller，未完成保存仍可完成。新环境创建独立Controller/存储key。
- 配置页、海外模型页使用同一保存状态提示。号码不持久化；联系人预填保留双方语言。无store控制器仅供隔离测试；正式路由始终通过provider注入真实存储。通话MOCK没有偏好写入口，仍完全独立。
- 新增12项：存储往返/环境隔离、无效版本、读失败和加载单飞、快速修改最终快照、写失败重试、dispose晚到、演练隔离、跨路由待写保留、两页失败提示；全量596项、analyze与格式检查通过，OpenSpec19项通过。
- 浏览器普通App已验证：现有登录→同声传译→对方语言法语→刷新App→再次进入仍法语；随后恢复英文。未输入真实号码、未发短信、未呼叫、未变更后端账号数据。
- 本批Web Debug（APP_ENV=dev）和测试环境Android Debug构建通过；双端安装/钥匙串真实写入仍待集中验证。本批没有新增依赖或原生修改，未重跑iOS构建，不以Web持久化证明iOS钥匙串已验收。

集中人工补验：两端同环境修改语言/地区/节点，关闭页面及重启App后检查；切账号应保留设备设置，切环境不串值。模拟存储失败时不得出现“已保存”或自动电话；正常恢复后显式重试应保留选择。不输出存储正文或认证token日志。定位/权限、正式目录、初始化第三步、真实通话依然未完成。
