# Flutter 迁移当前接线与收尾清单

增量核验日期：2026-09-21；基点 `1d4a99b`加旧国外翻译待归档兼容，分支 `codex/flutter-foundation`。本页不是完成报告；历史增量保留各自证据版本，不构成最新版本全量验收。

## 先看当前结论

最新设备增量（c93e783）：[文档增量阶段](AGENT_DOCUMENT_VALIDATION.md)的iOS请求/成功/取消/继续文字四点通过，禁止原生调用0，普通main已恢复并查看USB登录页。Android阶段包安装成功但启动/附加遭执行策略拒绝，未跑本组27点；已在15:32:45恢复普通main，安装身份及两份安全偏好摘要保持，本次恢复后未重新冷启动。不是手机连接故障或要求用户确认安装结果。

最新实现增量：[Agent索要文档](AGENT_DOCUMENT_VALIDATION.md)已补正式单选弹层、解析及submit_document成功/取消/失败续接；62相关定向+4架构检查及Web成功→取消→继续文字通过。目录27入口不代表全部页面完成；新文档Android阶段、双端真实文件选择/服务收件仍明确待验。主动docx/xlsx多选规则未改。

**14:46最新设备事实（覆盖下文历史未登录描述）**：[Android登录与确认卡阶段](ANDROID_LOGIN_CONFIRMATION_STAGE_20260921.md)已确认现有登录可复用，冷启动回首页、真实两轮文字/退出/任务恢复通过，无新验证码。确认卡六点32秒通过，安全存储摘要不变；恢复普通包后登录与两轮历史仍保留。不是全部页面或真实媒体完成证明。

最新用户确认及设备结果：[决策D01–D03](MIGRATION_OPEN_DECISIONS.md)。D01撤销匿名本地导出，只保留日志上传；D02旧未绑定异常标记不重放，任务以服务端最新状态为准，新Flutter队列不变。Android普通Dev已保留数据覆盖成功，09-21 14:26:03更新、UID/首次安装不变、冷启动普通登录页；不再等待用户确认安装，当前未登录且未发SMS。旧OTA与生产签名/版本仍是发布边界。以下旧批次同类待确认描述已被本条取代。

最新设备增量：[iOS确认卡](IOS_CONFIRMATION_STAGE_20260921.md)在ec643d5上独立53–58六图/29秒通过；普通卡历史计费、扩展卡联系人展开/恢复文字确认已验，9项相关预检与analyze通过，不重复全量。Android安装时间未变、登录复用仍无新证据，不发SMS；真实持久化/生产升级另验。

2026-09-21旧状态核对续项：[迁移台账](LEGACY_STATE_INVENTORY.md)替代泛化“继续盘点全部旧状态”。L01[语音语言](LEGACY_VOICE_LANGUAGE_VALIDATION.md)、L03[已提示标记](LEGACY_CALL_ADMISSION_VALIDATION.md)与L04[确认卡历史计费](CONFIRMATION_BILLING_VALIDATION.md)实现及定向验证完成；真实同签名升级和识别声音另验。剩余L02无账号补偿/L05旧OTA需归属与发布边界。缓存不复制旧格式、批准排除项不复活。

当前纠偏：首次初始化已正式接入两步「身份→通话模型→首页」，Web和iOS独立合成阶段已通过，不再等待国外翻译第三步。双端正式语音及国外翻译媒体工厂已接，不能按下方历史增量重复实现。旧翻译待归档首次导入完成，见[专项](LEGACY_TRANSLATION_ARCHIVE_VALIDATION.md)；Android普通包登录、剩余旧状态/发布策略和集中人工能力仍待。以下“最新增量”措辞均指各自历史批次，当前优先以集中主清单和正式入口表为准。

2026-09-21新增：[普通与扩展确认卡费率/余额历史快照](CONFIRMATION_BILLING_VALIDATION.md)已接共享存储、生产Android旧源与正式路由；普通卡16核心定向、Android Debug及Web换模型/恢复通过。扩展batch-plus另补结构化展示、四人展开、历史投影、同卡决策与执行确认去重；24相关定向和提示补漏7项复验、analyze、Web恢复后文字确认通过。L04实现关闭，真实升级及当前版本双端仍独立待验。

统一入口为[集中验收主清单](MIGRATION_HANDOFF.md)：包含原目标逐项审计、共享/原生分工、14组可执行人工步骤、证据与失败处理。旧批次记录仅追溯，不能覆盖该主清单和本页正式入口表。

最新页面覆盖索引为[PAGE_FLOW_COVERAGE](PAGE_FLOW_COVERAGE.md)：从正式入口分29组，本轮联系人→备注→任务→恢复的Web断点已修复，62条定向及浏览器通过；文档/OCR及回执评价完整App连续证据、扩大双端仍不能由已有目录推断完成。

- iOS SSH、Xcode/Flutter设备识别及App VM均已实测正常，连接不阻塞；安卓Dev曾因默认drive卸载丢登录，尚未证明恢复，不重发验证码。
- Web目录24入口、最近43条定向与浏览器评价/积分通过；不等于全部页面/双端真机覆盖。
- Android/iOS国外双媒体工厂、克隆真实SDK/候选/录音和共享ASR后端回退均已有正式装配；不能再按旧“尚未接入”重复实施。
- 剩余开发/决策及验收缺口：Android生产发布及有效旧状态迁移/降级核对、全部页面/发布隔离和更广双端证据。匿名诊断导出已撤销，不是开发项；旧异常标记处置已确认。首次初始化正式门禁已接，不重复列为未实现；其真实持久化仍待设备验收。具体区分见主清单第1节，不能统一写成“只待人工验收”。
- 用户允许视觉精校及真实声音/认证/电话人工验证后置，不允许缺失正式实现；全目标保持未完成。

## 历史增量记录（不作为当前待办）

以下“最新/本轮/尚未”均是对应批次当时的措辞。版本或设备状态以顶部当前结论、主清单及最新实测为准，不能跨批相互覆盖。

最新Web验收（2026-09-20）：集中目录24入口，新增已有赞踩/条件评分和积分会话宿主，草稿/失败重试/只读、激活去重/流水/退出重置已通过浏览器；根成功弹窗遮蔽目录出口已修复。43条定向、analyze、OpenSpec26项通过，不重复平台构建或全量。详见[Web入口](WEB_MIGRATION_WORKBENCH.md)；不代表真实奖励或全页面迁移完成。18:36再次实测Mac主机名SSH、Xcode/Flutter识别iPhone及运行中VM响应正常，iOS连接不是当前阻塞；安卓登录恢复仍待配合。

最新本机记录升级增量（2026-09-20）：旧v65当前账号JSON元数据已接同生产Android只读导入，新信封权威、空信封防清理复活，27新增/77条定向、analyze、OpenSpec26项及Android Debug最终9.4秒通过。无真实记录读取或安装；同签名升级仍待验，见[本机记录迁移验证](LEGACY_CALL_RECORDS_MIGRATION_VALIDATION.md)。

最新升级增量（2026-09-20）：旧认证录音只读导入已实现，同生产Android/精确API门禁、新槽位优先、清理空标记与失败重试已接正式provider。80条Dart定向及6条原生格式单测、analyze、OpenSpec24项、Android Debug构建通过；未安装、不读真实录音。真实同签名升级、本机记录与降级策略仍待办，见[旧录音迁移验收](LEGACY_RECORDING_MIGRATION_VALIDATION.md)。

**最新双端阶段与异常（2026-09-20 17时）：** 共享完整App的模型→文字候选→任务恢复→两条翻译详情→保存取消→设置返回已在Android/iOS同一测试通过，各11张图已核对；不是全页面/真实外部能力通过。首次直接flutter drive默认结束卸载App，导致Android Dev本机登录丢失，普通包已恢复但当前停在登录页；已告知用户并发送一次验证码等待输入。下方较早“安卓登录保留”只是事故前历史证据，不能代表当前。新增attach-only并强制keep-app-running入口和4条保护测试，尚待实机无损证明。iOS普通调试包已恢复、VM连接正常，原安卓正式App未操作。详见[双端阶段与事故记录](SHARED_DEVICE_STAGE_20260920.md)。

最新Web历史增量：完整App任务列表的两条翻译样例已接正式详情与录音控制器，合成Repository/计时播放器/保存弹层无外部副作用；实际浏览器不同字幕、返回重开、播放暂停和保存取消/模拟成功通过。修复TasksPage在JS使用1<<40导致时长为00:00，现列表正确00:12。19项定向7秒、analyze/OpenSpec通过；不代表真实音频或后台归档。其余连续入口与双端全页面仍按下表推进。

最新iOS阶段增量（2026-09-20）：Xcode15.2最终签名构建68.8秒、真机安装启动57.5秒及VM调试连接成功；com.chaken.phoneagent.test严格签名校验通过，实际截图为登录页（没有复用到iOS登录，不发新SMS）。两个Swift双工端口已编译，Android/iOS复用同一Dart双媒体工厂，8条定向测试和analyze通过；原生声音/全页面仍未验。下文带“此前/历史”的旧工厂为空与Mac超时记录不再作为当前待办。通用验证脚本已强制显式测试范围，见INCREMENTAL_VALIDATION。

最新阶段真机（2026-09-20）：用户已批准Dev保留数据覆盖；测试环境Android阶段包9.4秒构建、同证书V2核验、install-r成功，设备更新15:26:42，冷启动保留登录并进入首页，无新短信。Mac原地址.49已变为主机名解析的.51，原主机密钥校验通过并恢复SSH；Xcode15.2与iOS16.7.16真机可识别。此前“Mac超时/安装未授权”记录已不再是当前阻塞。完整页面对照与iOS本阶段编译/安装仍待完成，详见[设备阶段记录](DEVICE_STAGE_20260920.md)。

最新Web连续对话增量：完整App演练不再只支持固定历史，新建文字需求、候选、任务列表、恢复和续聊共用隔离内存事件源；未选可继续/已选禁用，不重发恢复命令，合成登录代次及场景退出重置。37项定向、analyze及8122重新编译通过；浏览器实际新建→未选恢复→选择→再次恢复→续聊通过。正式lib未改、未全量/重复平台构建/安装，不是实际后台持久化或全功能验收。见WEB_MIGRATION_WORKBENCH。

最新导航清理：日志上传和音色页的两个未受控MOCK入口已补Debug门禁；开发者、附件、联系人、拨号、翻译和Web OTA复用同一ENABLE_MIGRATION_PREVIEWS常量。默认23项/关闭演练17项定向通过，正式上传入口/创建克隆/原开发者功能保留；没有全量或重复构建。本次ADB确认安卓真机在线，Mac SSH仍5秒超时，未安装或读取凭据。

最新升级增量：Android固定白名单旧偏好已接正式两个安全存储，包含翻译语言/地区/海外模型节点及原音设置；新值优先、跨实例串行、失败可重试。34条定向测试、analyze和Android Debug编译通过，无全量/安装。真实同签名升级及身份录音/本机记录仍待验。见[偏好迁移与集中步骤](LEGACY_PREFERENCES_MIGRATION_VALIDATION.md)。

最新正式装配增量：Android完整LiveKit/AppAudio设备工厂已接TranslationDialRuntime、HTTP、Finished/归档，拨号前先检查/必要时申请麦克风权限；66条定向测试、默认provider复核、analyze及Android Debug9.9秒通过。Android具备真实链路装配条件但未拨号/开麦/安装；iOS两个双工Swift草稿尚未编译，其正式工厂继续为空。后续不重复运行时与Android工厂，继续iOS编译启用和集中真机验收。见TRANSLATION_CALL_VALIDATION。

最新增量：完整App设置→身份→两种模型克隆→音色管理已接入隔离合成端口；认证资料、分模型音色及录音复用状态可跨页验证。修复共享克隆页在initState复用录音时修改Riverpod状态的问题，改首帧后启动。321项相关模块与主导航定向回归22秒通过；不跑全量或重复平台构建。详情见Web验收入口。用户2026-09-20要求日常定向测试，全量留到跨模块里程碑/交付前，已写AGENTS与incremental-validation-policy；六个收尾工作包不因此标完成。

本轮补充：完整App Web演练已可从合成首页翻译卡进入正式配置/通话页面，结束回原号码与偏好、清空号码显示内存最近记录；浏览器实际点击通过。新增作用域绑定默认null，普通App仍不启用真实电话。合成位置/媒体/账号资源说明及三宽度回归见[验收入口](WEB_MIGRATION_WORKBENCH.md)。Mac本轮SSH仍5秒超时，未完成iOS双工编译或阶段安装，不将此演练子项视为正式总装配。

最新增量：8122目录现22项，第一项可连续操作正式首页/模型/任务/设置/积分路由。基础数据为隔离合成端口，未替换接口空配置失败；固定历史不是新对话持久化。2084全量、analyze、OpenSpec19项、Web Debug构建和浏览器文字候选/历史/积分/联系人/退出重登通过；未修改正式业务或原生代码，未生成新设备安装证据。详见[验收入口](WEB_MIGRATION_WORKBENCH.md)。

- **代码已接线**：正式入口能到共享实现，有实际Repository/端口装配；不等于真实服务或设备已验收。
- **合成通过**：使用正式页面/控制器，替换外部端口；不把假账号、假声音、假外呼或请求计数当线上证据。
- **真实通过**：必须记录相同版本的运行结果；构建、旧包截图、旧页面缓存均不能替代。
- 当前允许沿用HTML/CSS与组件先完成功能，视觉统一校准后置；不因此新增设计独有功能或削减默认语音/同页文字。

## 当前正式入口核验

以下路径相对项目根目录，点击可查看。结论只覆盖列出的入口和接线。

| 范围 | 当前代码证据 | 结论与剩余边界 |
|---|---|---|
| 登录与恢复 | [AuthRoute](../../lib/features/auth/presentation/pages/auth_route.dart)、SessionController、[MigratingSessionStore](../../lib/features/auth/data/migrating_session_store.dart) | 恢复/重试/登录分支已接；新增同生产Android包/精确prod API旧登录安全导入，消费标记防退出复活，跨实例串行。合成通过，真实升级与在线凭据有效性未验；无需为每次开发重发短信 |
| 首页/模型/音色 | [ShellRoute](../../lib/features/shell/presentation/pages/shell_route.dart) `_entry/_voices/_back`，CallModelsPage/CallVoicesPage | 动态入口、首页模型sheet、设置音色正式接线。三宽度新回归验证选择、返回、任务恢复；没有为隐藏的sheet音色按钮臆造新路径 |
| 统一对话 | [ConversationRoute](../../lib/features/conversation/presentation/pages/conversation_route.dart)、[正式providers](../../lib/app/conversation_providers.dart) | 文字/候选/模型、退出恢复、权限/联系人、OCR、回执/评价/录音、单路Host都有接线；各复杂工具的真实后台收件仍需集中验收 |
| 默认按住与文字切换 | [conversation_voice_providers](../../lib/app/conversation_voice_providers.dart)、VoiceInputController | Android/iOS共用ASR及一次后端转写回退（不是原生SDK）；错误/8秒启动、实际释放、账号隔离已接，69项定向与8122 Web两路径通过。断网业务句恢复已接，真实声音仍待集中验收 |
| TTS/单路监听 | conversation_speech_providers、ConversationCallHost、call_monitor_providers | 正式输出/监听工厂已接，实际声音/路由/系统中断待设备验证；多路不进入单路页面 |
| 任务与翻译结果 | ShellRoute `_task`、taskControllerProvider、TranslationHistoryRoute | 具有session的任务可恢复；国外历史有独立详情/录音入口。真实多路事件、ledger及权限另验 |
| 通讯录/拨号/最近记录 | ContactsRoute、DialerRoute、dial_recent_providers、app_call_record_providers | 正式系统读取、App记录和备注入口已存在；Web通讯录为明确隔离演练。iOS不读取系统通话记录；真实授权与旧数据待验 |
| 身份与声音克隆 | [IdentityRoute](../../lib/features/identity/presentation/pages/identity_route.dart)、[clone_flow_providers](../../lib/app/clone_flow_providers.dart)、CloneCreationRoute | 身份保存/删除/本地清理、创建选择→共享认证/候选/录音/钱包已接；不是仍只有克隆协议demo。SDK、相机/麦克风与服务端认证尚需人工 |
| 首次初始化 | AuthRoute正式挂InitializationHost，共享身份/模型/跳过存储 | 已按用户最新确认仅两步，完成直接进入首页，不读写翻译偏好；Web及iOS独立合成阶段通过，真实身份保存/跳过持久化冷启动集中验收 |
| 积分/评价 | points_providers、points_session_providers、wallet_settlement_providers、conversation_providers、clone_flow_providers | 缓存/激活/普通回执/克隆余额刷新已接，赞踩与eligible评分独立。国外归档不能伪装结算；不复制被排除的国内usage-session |
| 国外翻译配置 | [TranslationDialerRoute](../../lib/features/translation/presentation/pages/translation_dialer_route.dart)、translation_access/catalog/quality_providers | 定位/准入/节点/语言/模型/偏好有实现；Android/iOS完整工厂与拨号前麦克风门禁已接，Web正式媒体仍不可用。完整App Web合成通话与记录已贯通；实际呼叫未验 |
| 国外翻译会话与归档 | translation_session_factory、translation_device_media_providers、translation_archive_providers、translation_finished_providers | 共享create→媒体ready→merchant-call、双媒体、本机保存及持久归档已双端装配、编译；真实声音和后台收件待集中人工验证 |
| 设置/开发者 | [SettingsRoute](../../lib/features/settings/presentation/pages/settings_route.dart)、DeveloperToolsRoute | 身份/模型/原音/日志/退出及条件开发者入口已接；保留旧功能条件。开发者4个新增MOCK及日志/音色演练已受统一Debug门禁；关闭参数下正式主导航与原工具定向通过。尚无本批Release运行或整体验收结论 |
| Android OTA | StartupUpdateHost及[build.gradle.kts](../../android/app/build.gradle.kts) | 启动检查/下载/验签/恢复及旧登录导入子项已有；Release仍保护、signingConfig=null。**正式同签名升级及其余旧数据迁移尚未完成**；`.dev`不可作升级产物，旧文件保留不是自动降级安全。iOS无OTA |

## 去重后的真实收尾队列

这些是工作包，不是用数量估算完成百分比；每包内部仍按固定v65和已批准需求验收。

1. **正式国外翻译总装配**：Android/iOS完整双媒体设备工厂、节点/原音快照、账号生命周期、麦克风门禁及会话/归档运行时已接且双端编译。剩余授权真实呼叫/路由/归档验收，不能把合成回归或安装启动当双端听音成功。
   - 旧节点明确400/UNKNOWN_FIELD拒绝capabilities时的单次兼容已补；未知网络、其他拒绝和已分配ID不重发，仍严格核验录音定位。详见[协议与集中验证](TRANSLATION_CALL_VALIDATION.md)，不代替总装配。
2. **首次初始化集中验收**：正式门禁和两步页面已接，Web及iOS独立阶段已有证据；继续真实持久化/冷启动验证，不再等待第三步范围或重复生成UI。
3. **语音集中验收**：共享后端转写单次回退已按v65接入正式工厂，不新增原生识别SDK；协议/生命周期/同页合成通过。剩余实际服务启用、识别声音/路由/中断验证见[回退实现与步骤](ASR_FALLBACK_VALIDATION.md)，不重写已有ASR/TTS/断网恢复。
4. **Android无缝升级**：旧登录、有效翻译/原音偏好、认证录音及App内通话元数据同生产作用域导入已实现并合成验证；继续其余有效旧状态完整盘点、旧包不识别新退出/清理标记的降级策略；同生产身份/证书/versionCode真实升级验证。不得解除Release保护冒充完成。
5. **同版本双端阶段包**：已有同一MOCK主流程各11截图通过，随后普通包恢复；当前安卓Dev登录丢失待恢复，iOS调试正常但未登录。继续扩大页面/键盘/安全区/返回检查，并证明attach-only安全入口不卸载或清数据；不得用旧首页或安装启动抵扣全页面验收。
6. **整体验收与交付清理**：按[主清单](MIGRATION_HANDOFF.md)补全覆盖、发布隔离和人工步骤；日志当前只覆盖有限结构化事件，与旧日志范围的差异是明确待核对项，不是“仅待上传测试”。视觉按用户批准后置；真实人工项目可说明实现后交接，不能写成已经成功。

旧文档中的“普通录音provider未接”“克隆创建未装配”“TTS编排未接”“归档未实现”“启动更新未接”等不能继续当新任务；上述当前代码已经提供相应路径。本页没有据此批量勾选那些包含真实设备/用户验收的父任务。

## 本次新证据与环境限制

### 移动Web集中验收子批（基点4cfbff4）

- [统一目录8122](http://127.0.0.1:8122/)和[入口说明](WEB_MIGRATION_WORKBENCH.md)已提供，复用21个既有演练，常驻MOCK及返回目录、独立场景销毁、搜索/分组；不是新做21套页面，也不是整个App已完成声明。
- 新增24项目录/场景/无障碍测试，最终**2081全量**（2分34秒）、analyze、OpenSpec19项、格式通过；最终验收入口Web Debug构建35.5秒。正式lib/依赖/原生未改，不重打正式APK或iOS包。
- 浏览器验证登录进出、搜索、翻译配置→媒体就绪→接通/字幕→结束→合成记录与归档各1条；返回目录按钮在嵌套路由内保持可访问。搜索状态可保留，但未聚焦文字绘制差异仍列视觉校准，不用Widget通过覆盖浏览器现象。
- Mac本批SSH5秒超时，国外实际拨号总装配、双工iOS编译和阶段真机仍未完成；没有为此开启缺失回退的真实呼叫。原8080登录与7个原生在制文件保留。积分/评价等独立演练入口尚未全部合并，正式主导航继续按既有入口验证。

### 旧登录导入子批

- 20新增、58认证、**2057项全量**（2分32秒）、analyze无问题；正常main的Web构建35.8秒、最终Android Debug构建9.2秒通过。OpenSpec19项及变更文件格式/链接检查通过；Web既有Cupertino字体提示保留到视觉校准，不称视觉验收完成。
- 新代码只在精确生产Android作用域读取固定旧来源；MethodChannel合成测试不是原生XML/Keystore或正式签名升级测试。本批无真实登录/短信/安装，也无新iOS构建；既有7个原生音频在制文件不纳入提交验证结论。
- [旧登录实现及集中验收](LEGACY_LOGIN_MIGRATION_VALIDATION.md)记录幂等顺序、跨实例退出保护、失效凭据和降级限制。仅更新登录/OTA相关行，其他入口沿用下方主导航批次核验，不冒充再次真实运行。

### 前一主导航批次（历史证据）

- 本轮最终`flutter test` **2037项通过**（2分28秒），`flutter analyze`无问题，OpenSpec19项通过，新增测试格式无变化，本文所有本地链接可解析。仅新增测试与文档，未修改运行代码/依赖/原生配置，因此不重复生成Web/APK/iOS产物；不能将本轮验证写成新包交付。
- 新增[正式App主导航回归](../../test/features/home/shell_navigation_test.dart)：320/390/430宽，复用PhoneAgentApp/AuthRoute/ShellRoute，首页模型选择与系统返回→设置模型→音色选择→两级返回→任务恢复→首页；历史恢复不提交Agent命令。仅Repository合成，没有线上账号写入。
- 原有[文字主流程回归](../../test/features/conversation/conversation_navigation_test.dart)独立覆盖恢复→文字→候选→退出→恢复→结果详情；二者互补，不声称覆盖所有页面状态。
- 浏览器现有`localhost:8080`标签仍显示已登录后的积分页面；本次未刷新凭据、未清存储、未触发SMS。**这是UI快照，不是在线认证成功证据**。
- ADB本次确认真实OCE-AN10在线；`com.vvtech.aiassistant.dev`为`versionCode=1 / 1.0.0-foundation`，最后安装更新是**2026-09-16 20:47:02**。这不是c52dc5a阶段包。此前安装拒绝后的继续覆盖安装答复尚待确认，不绕过。
- Mac `192.168.1.49:22`本次5秒SSH连接超时；没有新构建/安装，不操作保留的解锁会话。不反复轮询或重建它。

## 集中人工验收入口

| 验收组 | 实现、步骤与失败边界文档 |
|---|---|
| 登录复用/表单 | [认证](AUTH_API_VALIDATION.md)、[Web登录](AUTH_WEB_VALIDATION.md)、[v65旧登录升级](LEGACY_LOGIN_MIGRATION_VALIDATION.md) |
| 统一页/工具/图片 | [输入](VOICE_INPUT_VALIDATION.md)、[网络恢复](VOICE_TURN_RECOVERY_VALIDATION.md)、[权限](PERMISSION_TOOL_VALIDATION.md)、[OCR](OCR_VALIDATION.md) |
| 普通通话/批量/录音 | [主流程](CALL_FLOW_VALIDATION.md)、[批量](BATCH_FLOW_VALIDATION.md)、[录音](RECEIPT_RECORDING_VALIDATION.md)、[监听](CALL_MONITOR_VALIDATION.md) |
| 国外翻译 | [准入](TRANSLATION_ACCESS_VALIDATION.md)、[会话](TRANSLATION_CALL_VALIDATION.md)、[媒体](LIVEKIT_MEDIA_VALIDATION.md)、[回退](APPAUDIO_TRANSLATION_VALIDATION.md)、[结束归档](TRANSLATION_FINISHED_VALIDATION.md) |
| 身份/克隆/积分 | [克隆](CLONE_ENROLLMENT_VALIDATION.md)、[核验](CLONE_VERIFICATION_VALIDATION.md)、[录音](CLONE_RECORDING_VALIDATION.md)、[钱包](WALLET_FEEDBACK_VALIDATION.md) |
| 系统与设置 | [本机记录](APP_CALL_RECORDS_VALIDATION.md)、[拨号权限](DIAL_PERMISSION_VALIDATION.md)、[设置](SETTINGS_VALIDATION.md)、[OTA](OTA_INSTALL_VALIDATION.md) |

需要服务端事实的验收必须按测试时间窗与sessionId/taskId/callId/commandId关联后台；不输出token、媒体grant、真实身份或音频正文。没有对应来源的结果保持“未验证”，不得由合成日志推断成功。
