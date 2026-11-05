## Context

工程固定 Flutter 3.32.0；已有 Android/iOS、Dio、Riverpod、secure storage，但没有 Web 宿主。当前日常页面验证依赖设备点击截图，反馈周期过长。

## Goals / Non-Goals

Goals：共享代码在浏览器可运行，手机宽度预览，普通 API 和 POST SSE 可调试，自动回归可重复。

Non-Goals：不开发独立 HTML 业务页面、不将 Web 作为正式发布产品、不迁移音频/OTA/系统通讯录到浏览器、不以 Web 验收替代原生验收。

## Decisions

- 2026-09-22用户明确暂缓Android migration-increment的27个检查点（22–38、47–52、59–62）：保留未执行状态、既有测试和集中验收项，不再重试安装/附加，不作为继续其他工作的阻塞，不扩大为取消所有自动测试。
- 下一微批补完整App权限工具连续演练：当前正式Provider已接DevicePermissionChannel、独立Preview已覆盖协议，但shell宿主未替换该端口，也没有REQUEST_PERMISSION合成事件。仅tool按登录代次注入隔离权限源并在同一内存ledger记录请求/结果/续聊；从正式首页到统一页发送明确合成指令，验证允许、拒绝、需设置三类结果，退出任务恢复不重放，不新增正式按钮或权限规则。新增独立端口/定向测试，shell文件保持500行以内；禁止真实权限/存储/SMS，浏览器取证和定向测试，不重打平台包。

- 2026-09-21交付收敛：复核现有正式路由和人工能力工厂，不为历史未勾选项重复开发。补正常main的Android Profile产物已知演练标记检查（非生产Release，不安装、不解除签名保护），与现有Web Release证据分开。集中主清单以当前状态替换累积历史叙述，保留全部有效页面、共享/平台实现及人工操作/预期/失败证据，明确Android增量执行限制与生产OTA条件；不以文档重排声明全部迁移完成。

- 2026-09-21增量设备组migration-increment：Android只执行尚缺的22–38拨号/翻译、单路/日志、开发者和47–52两步初始化，不重跑01–21/53–58；两端追加59–62文档请求/成功/取消/续聊。复用现有共享步骤，新增migration_increment_stage_pages/test与文档阶段函数及预检，驱动白名单增加独立组。测试必须禁止真实存储/文件选择/媒体/电话；仅测试目标和文档，无正式业务、接口、权限、音频规则变化。先定向预检再保留数据安装，留普通二进制、Android安全偏好摘要/安装身份及普通登录核验；iOS沿已解锁screen，不读取密码。MOCK不代替系统能力与真实后台收件。

- 2026-09-21开发者页面阶段：新增integration_test/developer_stage_pages.dart复用正式暗号解锁、外呼设置失败/保存/取消/删除、列表清理/刷新、权限提示重置、网络门禁和退出取消，截图33–38。shared_stage_test.dart接入完整回归，同时新增developer_stage_test.dart只执行本组，阶段验收不重复前32图；test/developer_device_stage_test.dart先跑双尺寸×两平台样式、禁真实存储/电话。沿原MOCK数据源，不改正式lib或外部协议，名单操作只清合成仓库。使用现有attach-only驱动与已解锁Mac，保留并恢复普通二进制；Android仍是存储探针页，未解除安装限制不绕过、不发验证码。视觉参数级校准继续后置，本阶段只验证列明入口/可读性/返回与平台差异。

- 2026-09-21下一设备阶段：复用既有完整App同源MOCK，把P18单路监听/音源/挂断/任务恢复续聊及P27日志失败重试/仅清理/返回重进加入共享设备脚本，新增26–32七截图。新增integration_test/call_log_stage_pages.dart，shared_stage_test.dart和extended_device_stage_test.dart各接一次；仅测试脚本，无产品状态/接口/原生变化。先375×667、393×820双平台主题定向预检，再沿已解锁Mac会话保留普通二进制、构建测试入口、attach-only driver、截图检查及恢复普通入口。Android安装限制未解除时不绕过，单端证据不扩大为双端。视觉按用户要求后置，继续标记VISUAL_CONTRACT_COMPONENT_COVERAGE_MISSING，无真实音频/电话/上传/SMS/设备存储。

- 2026-09-21 P27完整App日志连续入口：LogReportRoute原来直接创建ApiLogUploader，无法使用宿主隔离端口；新增app/log_report_providers.dart迁移原有仓库装配，正式默认仍为当前账号Journal/ZipLogRepository/ApiLogUploader，页面只读取Provider。tool按登录代次覆盖仓库，使用同一内存诊断Journal、真实ZIP，首次上传与清理分别合成失败以验证两个重试路径，不发HTTP或写设备存储。正式页面文案保持，目录常驻MOCK明确整个流程合成；默认Provider不能依赖tool。两宽完整App从设置进入、返回重开、晚到及登录重置定向验证，浏览器核查后更新矩阵。不扩展为匿名日志导出或原生crash实现。

- 2026-09-21 P18完整App单路连续演练：复用PreviewCallFlow和PreviewCallMonitor作为内存外部端口，新增tool/previews/shell_call_preview.dart按登录代次管理session与通话目标；shell_conversation_ports.dart仅在明确合成输入“演练单路通话”及该会话后续命令时委托，任务/restore共用同一实例。shell_preview.dart覆盖准入/通话查询/监听工厂，不复制业务Controller或页面，不访问真实HTTP/安全存储/设备音频。每会话隔离，恢复不重新confirm，关闭/账号变更取消在途合成命令；未知目标拒绝而非取其他通话。验证两宽正式入口→自动通话页→监听/静音/音源→显式挂断→回对话→任务恢复，以及只返回不挂机、真实通道0调用；Web实测独立留证，真实电话/音频与新增双端阶段继续未验。

- 2026-09-21 iOS阶段：f96a105独立源码包复用已解锁screen构建签名/安装测试入口，安全driver只附加。真机首轮新增路径因Cupertino转场未完找到两个dial-delete，定位为测试固定350ms等待不足；tap默认pumpAndSettle，只有显式媒体ready等待不settle，不用first吞歧义。两尺寸双主题4预检通过后，同一真机热重启修正并复跑25截图/26步骤通过。正式lib未改；原生拨号及安全存储零调用，真实能力仍未验，恢复普通入口单独核对，Android本批不安装。

- 2026-09-21落地核验：两Route及openDialer/区号/设置/会话使用RouteProviderScope，仅目标容器不同才补UncontrolledProviderScope，避免同容器注册重复调度；跨容器覆盖及外部所有权保留。新增7项边界/作用域测试，40相关定向通过。Chrome默认ID测试明确RangeError(max=0)，将1<<32改4294967296后Chrome通过；追加记录/边界21项通过。共享设备步骤22–25复用正式路由，增加原生拨号通道拦截并断言0；375×667/393×820预检通过，尚未运行新版真机。首轮脚本未清前一段联系人号码、长按未滚动，均按实际UI操作修正，不修改业务规则或削弱命中检查。

- 2026-09-21浏览器普通呼叫模拟后显示记录保存失败：补AppDialHistoryRecorder默认ID的纯Dart Chrome测试，不再只注入固定ID；检查32位位移随机上限的JS差异。保持记录格式、普通/翻译分类和最近列表筛选不变，不为MOCK改正式业务规则。

- 2026-09-20拨号/翻译连续核验：TranslationDialerRoute默认构造SystemDialerChannel，DialerRoute打开翻译还显式构造同端口，绕过完整App宿主已覆盖的systemDialerProvider；普通翻译关闭后的电话可能逃到原生。先在完整App首页/拨号配置两个入口设置原生通道失败防线，最小失败回归捕获，再将Route可选显式端口保留、缺省由当前Provider作用域提供，普通Dialer子路由不传硬编码默认端口。正式Provider仍是原SystemDialerChannel，产品拨号行为/权限/接口不变。修复仅两Route；测试覆盖显式端口优先、默认真实端口类型、两入口合成计数且原生通道0。之后扩展共享步骤到区号搜索、语种/模型、合成普通呼叫、翻译确认/媒体ready/字幕/按键/结束最近回流；每批≤3文件，只定向验证，设备安装证据独立记录。
- 2026-09-20活跃路由登录失效：最小完整App回归通过rejectSession触发与直接signOut相同的ApiFailure.signedOut。单纯重建GoRouter与Route入口鉴权均失败：Riverpod先刷新仍被旧Widget订阅的账号Provider，再卸载页面。采用显式两阶段身份转换：SessionController提供无Flutter依赖的释放回调，持久写/清成功后先封闭credentials，App的SessionNavigationHost卸载整个Router子树并在帧末确认释放，然后发布新SessionState触发loginEpoch失效与新Router。没有宿主的纯控制器调用无需等待UI；宿主销毁也完成等待，不使用固定延时。Token刷新不进入释放屏障；持久化失败不先移走页面；旧API仍由真实SessionController校验，不保留旧凭据、不吞鉴权异常。定向覆盖活跃对话、弹层/详情、令牌刷新、重登录和释放期间拒绝旧请求；仅使用合成账号，不发短信。

- 2026-09-20 P10联系人工具连续补漏：完整App的号码/姓名查询尚用Api续接端口，独立领域测试不能证明完整路由。仅tool的ShellConversationPorts提供明确合成指令“按号码查询联系人”“按姓名查询联系人”的工具信号、同源TOOL结果/候选ledger；shellContactsOverrides装配正式PhoneContactLookup/NameContactLookup和同一PreviewContacts，续接替换为内存端口。姓名同名候选由正式匹配器产生，经共享候选选择“第N个”继续，号码查询返回合成说明；不新增正式按钮/关键词规则，不读取OS联系人或真实API。测试两宽完整App发送→自动续接→候选→退出/任务恢复→选择→再恢复，并断言命令/结果次数、typed来源、关闭拒绝和登录隔离。定向测试/analyze/浏览器即可，不因tool接线重新打双端包。

- 双端数据核对发现完整App演练仍实例化正式diagnosticJournalProvider；关闭时flush向安全存储写入合成作用域诊断。两宽最小回归实际捕获read/write，不能据空API声称所有存储隔离。仅tool宿主覆盖为按登录代次创建的内存DiagnosticJournal，保持正式诊断语义/生命周期，新增零设备安全存储访问断言；真实安全存储既有内容不删除。重新定向回归并验证设备摘要，历史首轮结果保留为“页面通过、存储隔离失败”，不追改为成功。

- 真机防护进一步捕获Android启动OTA记录读取，桌面因原生包信息不可用未到此步骤。tool宿主改用正式StartupUpdateController与内存当天已检查外部端口，保持Android启动路径而非关闭功能；iOS仍按平台规则不启动OTA。独立OTA场景保留，本阶段不宣称验证更新/安装。最终两端安全存储调用0，Android两份既有加密偏好摘要不变；不从未卸载推断登录恢复。

- 2026-09-20扩大双端阶段：沿用shared_stage_test/driver和只附加安全入口，新增独立extended_stage_pages.dart组织联系人备注/拨号回填、回执评分、身份克隆及钱包路径，不复制正式业务。保留此前11步及无SMS断言；新增截图编号从12起。安装前后核验Dev包身份/签名/firstInstallTime/数据目录摘要，普通包独立备份后install-r恢复；iOS仍复用已解锁screen。评分奖励/SDK采集/试听均合成，不触发用户资料或系统电话。先VM定向跑共享步骤再构建两端，保存结果与截图到.local，不重复全量或声称系统键盘/音频通过。

- 2026-09-20回执连续链路：仅tool层新增单路/批量历史样例，ShellConversationPorts任务和restore/续聊都保留同一组种子ledger；不让普通新对话自动伪造外呼完成。正式ConversationRoute的回执、录音、赞踩和TaskRatingRoute全部复用，外部评价/评分/草稿按FeedbackTarget及登录代次隔离；单路允许评分且首次提交模拟失败，批量不允许评分但保留赞踩。普通录音Provider复用createPreviewCallRecordings和MOCK保存弹窗，不发声音或写文件；生命周期沿用正式host。微批按规格→种子/会话→端口/宿主→连续测试推进，每批不超过3文件。验证任务恢复、录音播放暂停/保存取消、评价、评分草稿跨页、失败重试成功只读、另一目标不串数据及退出重置，定向测试与浏览器取证；正式lib/原生/接口/积分不改。

- 2026-09-20附件连续链路：完整App宿主仅覆盖documentImportFactory和OCR source/recognizer/repository；正式菜单、导入controller、会话controller与历史投影不复制。文档成功按现状直接发送，合成USER_TURN_ACCEPTED保留inputKind，列表标题不暴露序列化正文；OCR上传仅把样例图片和OCR_IMAGE_COMMITTED写入同一会话内存ledger，恢复从同源按session/id读取，单独选图不自动发送Agent。端口绑定登录代次，退出拒绝晚到写入。默认演练使用内置合成文档和名片，失败/取消由定向测试及既有独立演练覆盖；MOCK常驻，不打开系统选择器、上传或访问真实账号。定向附件/共享宿主测试、analyze和实际浏览器连续恢复验证，未修改原生不重复双端打包。

- 联系人连续链路核验（2026-09-20）：实测完整App已注入联系人端口，但ContactsRoute直接按kIsWeb转入独立PreviewContacts/ContactTaskRoute，无法验证正式Agent/任务恢复。将默认平台路由选择提取为contactsSharedFlowEnabledProvider（默认仍为!kIsWeb），仅tool宿主覆盖为true；正式Web仍显示不支持及既有显式演练，手机行为不变。tool/previews/shell_contacts_preview.dart按loginEpoch创建联系人/备注和计数系统拨号端口，复用正式controller/detail/editor/skill/conversation，不读取OS通讯录、不拨真实电话、不跨登录保留备注。ShellPreviewPage移除长生命周期联系人实例并接入override。测试两宽连续备注保存取消/不同联系人/拨号回填/Skill首轮selectedContact/退出任务恢复及登录重置，实际浏览器验证Web分支；不将VM测试当浏览器证据，不重打原生包。正式入口覆盖矩阵记录本次与既有证据及待补项，不能由目录数量推导全覆盖。

- 完整App开发者连续入口补漏：浏览器通过正式拨号暗号解锁后固定外呼号码加载失败，原因是演练未替换该Repository。新增tool/previews/shell_settings_preview.dart按loginEpoch提供内存外呼Repository，页面关闭后保留、退出登录/目录后重置；shell_preview.dart仅装配，不复制DeveloperToolsRoute或OutboundNumberPage。新增两宽连续测试覆盖真实解锁、保存/取消/删除/失败重试、网络门禁、列表操作、权限重置到翻译页及返回；浏览器另验。共享正式控件只纠正过期“媒体未接入”说明，不改后端、权限、数据模型、电话/ASR/TTS。定向测试/analyze/Web编译，不为工具接线重复原生构建。

- 2026-09-20评价/会话积分目录补漏：将已有feedback_preview与points_session_preview暴露为可嵌入宿主并注册集中目录，不复制正式页面。评价Repository/草稿随宿主实例创建；积分ProviderContainer、合成服务和通知随场景创建并在退出释放。保留原独立启动入口。验证赞踩、条件评分草稿/失败重试/只读、积分激活一次/重挂载及退出重置；无真实接口/存储/积分发放，正式lib和原生不变，不重复双端构建或全量回归。

- 浏览器发现评分成功showDialog默认根导航会遮蔽工具栏；嵌套MaterialApp仍不能阻止findRootAncestorStateOfType越层。将目录工具栏放到MaterialApp.builder中所有导航层之外，沿用后绘制语义；剩余内容按实际约束提供MediaQuery。返回目录清理根弹窗和场景子树。两宽根弹窗可访问退出/销毁重开回归与评价成功断言覆盖；此修复仅tool宿主，不改正式评分导航语义。

- 本轮执行纠偏：首次drive缺保留参数，框架结束卸载App导致Android Dev登录丢失，原定无损目标未满足，不能用上述计划当成功证据。新增tool/run_shared_stage.dart与纯命令构造器，固定use-existing-app+keep-app-running，仅附加既有测试进程；构建/显式保留数据安装/启动分开，不让drive持有待卸载包。4条命令保护测试通过，实机无损证明仍待；普通App已恢复，安卓已请求一次验证码等用户输入。完整事故及验证边界见SHARED_DEVICE_STAGE_20260920。

- 2026-09-20共享页面双端阶段：新增integration_test/shared_stage_test.dart与test_driver/shared_stage_driver.dart，复用完整App的隔离演练宿主和正式控件。自动走首页/模型/文字候选/退出恢复/两条翻译历史/保存取消/设置返回，按状态断言并采集关键截图；不读取持久账号，不发SMS、外呼或真实音频。Android/iOS各构建一次测试入口，保留普通Dev二进制以便保留数据恢复；iOS沿用已解锁screen。结果按平台留.local，不据MOCK结果勾选真实接口、系统键盘、声音或全页面视觉验收。用户已允许视觉校准后置，本阶段标记VISUAL_CONTRACT_COMPONENT_COVERAGE_MISSING，仅检查可用区域/裁切/可读性及与已验证Web共享结构的一致性。

- 同轮浏览器核查发现真实跨平台差异：TasksPage用1<<40作为时长clamp上限，JS位运算截为32位导致12秒列表显示00:00，而详情显示00:12。仅替换等值十进制常量1099511627776，保留移动端范围与格式；补负数/零/秒/分/小时页面测试，并以浏览器列表12秒显示验证JS路径。非新需求，不改后端或任务状态，不为一行展示修复重复双端打包。

- 2026-09-20任务详情演练补漏：浏览器已复现完整App任务列表翻译样例进入后加载失败，原因是详情Repository仍走空API。新增tool/previews/shell_history_preview.dart提供严格ID匹配的两组国外合成详情，复用正式TranslationHistoryRoute/RecordingAudioController；只覆盖历史Repository和录音外部端口，内存播放计时/模拟保存弹层不发网络、不读写文件或设备音频。绑定登录代次，离页销毁播放器，切记录不串字幕；保留常驻MOCK。微批先规格，再端口/宿主/定向测试，最后任务样例与文档。正式lib、接口、权限、数据库、SIP/ASR/TTS均不改；测试覆盖任务→详情→播放暂停→保存取消/模拟保存→返回另一记录/重开，浏览器取证，不重打平台包。当前只做交互核验，按用户要求视觉校准后置，不声明高保真通过。

- 2026-09-20 连续对话验收补齐：新增 tool/previews/shell_conversation_ports.dart，由同一内存实例实现 AgentGateway、TaskRepository 和 ConversationHistoryRepository；每个 session 独立顺序事件/候选，保留固定历史样例作为初始数据。提交只在合成流接受后记账，取消前未接受不生成任务，恢复只读不重发；新任务按实际输入展示，选择结果消除 pending。实例绑定合成登录 epoch，退出登录或退出目录重开不泄漏旧演练数据。正式 lib 无改动，不模拟真实持久化、外呼或通话完成。修改 shell_preview.dart 接线，定向单元/跨页测试以及浏览器新建→退出→恢复→续聊验证，不重复平台构建或全量测试。

- 集中目录增加正式共享App基础导航演练，直接使用PhoneAgentApp/AuthRoute/ShellRoute，不复制首页或业务页面。复用纯Dart测试端口和已有AuthScenario；Web调试器不能引用入口目录外的test/support，故将两份合成实现移到tool/previews，原测试文件仅导出兼容，正式lib不得反向引用。强制空API配置、独立登录内存、模型/任务/历史/Agent样例、积分和原声偏好内存端口；未替换接口按未配置失败，不向真实环境回退。样例历史固定，不声称新对话已持久化恢复。系统/复杂业务继续从已有明确MOCK场景验收；该入口不意味着所有正式能力装配完成。

- 2026-09-20：集中验收入口采用tool/previews/migration_workbench.dart及同目录目录/宿主，复用已有演练Widget，不建立第二套业务页面。独立loopback端口，无API代理，常驻MOCK和返回目录；选择场景后使用独立Navigator，退出销毁子树，避免嵌套页面无返回或旧控制器残留。既有登录/统一页验收宿主仅公开Widget名称，原启动文件仍可用。按模块列清合成边界，不将目录可打开当所有正式路由、真实接口或设备已完成。正式main不导入验收工具，保留8080登录与7个原生在制文件；初始化第三步产品决定和Mac编译仍单列。

- 收尾核验以当前正式App入口和跨页连续操作为准，不按历史增量文档中反复出现的未勾选条目重复开发。新增主导航Widget回归（320/390/430宽）及当前收尾矩阵，列清源代码接线、真实/合成证据和未实现/待人工验证的区别；不由单页测试或静态搜索推出全功能完成。原登录保留，不为核验重新发送短信。
- 原生端保持现有运行路径；Web 大屏预览最大宽度 430，窄屏自适应，Navigator/MediaQuery 位于相同约束内。
- 先验证已锁定 Dio 浏览器实现；若缓冲响应则使用 Fetch ReadableStream 薄适配，复用 SSE 解码和全部 Controller。取消/超时向浏览器 AbortController 传播。
- 开发服务器只绑定 loopback，固定转发测试环境 API；不关闭浏览器安全机制，不暴露任意 URL 代理，不记录请求体/凭据。流式透传、不缓存，客户端关闭取消上游。
- 浏览器独立登录存储，localhost 安全上下文。2026-09-16 用户明确授权优先复用安卓登录：仅通过一次性 loopback 内存通道交给同一工程 Web 安全存储，不落凭据文件、不输出 token；完成后删除临时代码并关闭通道。不借 Web 改动 release 配置校验。
- 固定状态 UI 测试与真实 API 联调分别取证；只对关键页面/状态截图。移动端每闭环一次冒烟，平台能力独立测试。
- SSE 不保证发送所有 USER/TOOL 持久事件。遇到序号缺口只读同步时间线一次，不重发 POST；SSE 与 REST 对同一事件仅允许 occurredAt/committedAt 元数据差异，以 REST 持久副本为准。身份、序号、内容、命令归属及其他元数据仍必须一致；历史内部冲突继续使用完整指纹检查。

## Risks / Trade-offs

- Web 插件差异：构建和真实浏览器测试先行；不将手机特有能力伪装成功。
- UI 输入/安全区差异：保留移动端验收，不要求系统控件像素相同。
- 模型输出非确定：使用脱敏协议回放做断言，真实请求用于端到端冒烟。

## Migration Plan

先规格与 Web 基础，再流式/布局自动测试，再页面状态及真实闭环。修改可独立回滚，不影响原 App 安装数据。

### 统一页视觉微批

使用 design/conversation-history 中同提交的浏览器运行态快照、computed style、资源与本地 preview。2026-09-16 浏览器禁止直接访问本地 file URL，不绕过；本微批只修已采集区域（Header、状态提示、输入 dock），未采集的消息/工具状态保留差异待补，不冒充全状态视觉通过。

Header 改为独立展示组件，依据 18/800 标题、54 高头部、32 高阶段区、7px 状态圆点等已有参数。输入 dock 复用原 SVG，不以 Material 麦克风/发送图标或 Unicode 箭头替代资产；语音入口按已批准按住语义，不复制原型自动语音/停止演示行为。消息补显式可访问文本语义，便于浏览器回归，不改消息来源。测试覆盖源参数、输入发送/切换、窄屏键盘与返回。

### 工具展示微批

依据 v65 AgentStreamSseEventParser.parseToolCardEvent、AgentStreamToolStepReducer.upsertToolCard 和 PureVoiceStepPresentationPolicy：处理中的 tool_card 展示 methodLabel/body/result；body 缺失时从 conditions 格式化。按 command + toolCallId 去重，空 ID 按工具名/方法名/body 匹配，重复更新保持顺序。普通卡在本轮完成/中断后收起，askUser/showOptions/requestPermission/importDocument 保留，但已有同 toolCallId 的结构化持久消息优先，不能重复或覆盖同轮普通 AI 回答。未知原始工具参数不直接展示。

TimelineApiMapper 会清除普通工具参数和结果，故普通卡不从空历史重建，不增加本地持久化。该批不声称普通工具流态在恢复后完整重现。只读卡片无执行按钮；复杂确认/回执另批。先三文件领域/解析/测试，再三文件控制器/测试，再展示组件；每批验证。无后端/数据库/提示词/SIP/ASR/TTS 修改。

### 移动视口连续回归

补齐已有正式页面在 320/390/430 宽度、键盘挤压、大字体、空会话、同步失败和长候选下的交互测试，不新造产品布局。页头和输入区保留；非固定内容必须能滚动，错误恢复操作必须可达。发送只在 controller 接受后清空草稿；语音/文字切换不丢草稿。测试直接使用正式页面与 controller，合成 gateway/history 不访问线上、不发短信/外呼。

一键 Web 验证应覆盖统一页相关测试全集，而非只跑 controller 与空壳视口。Flutter VM 的布局测试与实际浏览器冒烟分别记录，不能声称 VM 测试等于浏览器渲染验收。

### 登录表单 Web 闭环验收

复用正式 PhoneAgentApp/AuthRoute/AuthPage/AuthController/SessionController，新增 tool/previews 下独立 debug-only 合成网关与内存存储入口。它不得调用真实 HTTP 网关、读取持久安全存储或污染普通 Web 登录；仅通过 provider override 替换外部端口。预览常驻 MOCK 标识、独立端口，场景切换销毁旧作用域。登录源截图已重新检查，继续沿用已有布局，不因验收新造视觉模板。

覆盖验证码错误、发送与倒计时、邀请码挑战/显式返回、邀请码失败/成功、认证成功但本地保存失败仅重试保存、启动恢复失败重试。Widget 自动化覆盖 320/390/430 宽度与键盘/大字体，浏览器操作另行取证；假账号只在内存，不访问线上，不新增短信。文件按合成端口、验收宿主、UI 回归拆分，默认500行。正式产品仅在自动化复现缺陷时做最小修复，不改后端/数据库/提示词/音频或登录协议。
