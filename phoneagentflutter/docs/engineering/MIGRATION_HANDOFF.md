# Flutter 迁移集中验收主清单

更新时间：2026-09-22；本轮交接核对基点 `5351d75`。本文只描述当前状态和操作；旧过程仍可从 Git、[问题记录](../codex_issue_log.md)和各专项追溯。三步目标逐项证据及83项定向收尾验证见[基础迁移交接核对](MIGRATION_GOAL_AUDIT_20260922.md)。

设备事实更新（09-22 16:59）：确认Codex进程16:53启动后，沿既有授权重试原启动/附加命令，仍在执行前被blocked by policy拒绝，27点未运行。具体拒绝来源尚未定位，不再要求重复重启或确认弹框。已保留数据恢复普通main（16:59:10），本次阶段安装前后安全偏好摘要/安装身份保持；恢复后冷启动及UI树确认**已登录首页**，不代替增量测试通过。

## 1. 当前结论与剩余工作

2026-09-22用户批准本次Android增量27点暂缓：22–38、47–52、59–62保持“未执行”，不删除用例、不标通过、不继续安装重试，也不再作为其他开发任务的阻塞。对应模块后续按第4节集中真机验收；其他自动测试与真实能力验收要求不变。

**用户定义的基础迁移阶段已具备交接条件，接下来可按本文集中人工验收；本文不是所有真实能力或正式发布通过证明。** 页面/共享实现、自动检查、待人工验证和正式发布条件分别记录，不能相互替代。Android27点按用户明确决定暂缓，视觉精校按此前批准后置，不反复把这些事项扩成新的页面开发。

| 用户要求 | 当前证据 | 仍待处理 |
|---|---|---|
| 尽量复用Android登录 | [09-21真实登录阶段](ANDROID_LOGIN_CONFIRMATION_STAGE_20260921.md)：冷启动首页、真实两轮文字→退出→任务恢复→续聊成功；阶段后普通包登录/历史仍保留，没有新验证码 | 不重新发送短信。09-22 16:59:10恢复普通main后，冷启动及UI树再次确认已登录首页；UID/首次安装与本次阶段安装前后的两份安全偏好摘要保持 |
| Web完成有效页面与交互 | [正式入口表](PAGE_FLOW_COVERAGE.md)列P01–P29及P08a；[工作台](WEB_MIGRATION_WORKBENCH.md)复用正式页面与控制器，外部端口明确MOCK。真实8080文字闭环及恢复见[实测](WEB_REAL_TEXT_STAGE_20260921.md) | 视觉精校已获准后置；全部交互完成不能仅由目录数量或搜索无TODO证明。按入口表列明的证据判定，不反复从旧文档新造功能 |
| 阶段性双端真机验证 | 双端基础/扩展流程、确认卡已验证；iOS后续拨号/翻译、单路/日志、开发者、网络恢复、键盘、初始化及[新增文档](AGENT_DOCUMENT_VALIDATION.md)各有独立证据 | Android增量22–38、47–52、59–62因启动/附加执行策略拒绝而未执行，现已获用户批准暂缓；不阻塞其他开发，不将定向预检当设备通过 |
| 人工依赖能力先实现，再集中验收 | 当前正式Provider和双端注册已核对：ASR/备用转写/TTS、单路监听、翻译LiveKit/AppAudio、身份SDK/克隆、录音播放/保存均已接线 | 按第4节集中验证真实声音/电话/身份/权限/文件/后台收件；MOCK不证明硬件、服务端收件、实际计费 |
| 清晰交接 | 本文第2–6节给入口、共享/原生分工、操作/预期、日志及失败处理；09-22[权限连续链路](PERMISSION_TOOL_VALIDATION.md)新增24项定向与实际浏览器验证 | Android新增阶段已暂缓，真实能力及第7节生产条件仍独立待验，不标全部迁移完成；不要求用户现在逐项手测来替代自动检查 |

已确定且不再询问的范围：

- 初始化仅“身份（可跳过）→通话模型→首页”，不要求国外翻译模型。
- 日志只有现有“日志上传”；没有匿名本地导出产品需求。
- 任务以服务端最新状态为准；旧无账号/环境异常标记不导入、不重放，原文件保留。新Flutter有效账号队列仍正常持久化/重试。
- 统一页默认按住说话，底部切文字；普通退出结束本地会话，任务列表恢复。不添加“暂离”模式或确认卡执行按钮。
- Android保留系统通话记录和OTA；iOS仅App通话记录，无OTA。国内App SIP翻译、可信来电SDK、充值支付、历史独立对话模式及设计独有未来功能均不迁入。

### 本轮正式接线核查范围

直接读取了 `AuthRoute`、`ShellRoute`、`SettingsRoute`、`DeveloperToolsRoute`、conversation providers及动作消费者，核对导航、恢复和文档工具；读取语音、翻译双媒体、克隆、TTS、回执录音的正式工厂和Android `MainActivity`/iOS `AppDelegate`注册。对应源码均在当前仓库，不依赖旧仓库当前分支。

这证明列出的入口/工厂存在正式装配，不证明所有运行路径都成功。没有为历史“工厂尚空/待登录/匿名导出”继续增加实现；具体业务证据按专项及第4节集中验收，不以关键词检索当穷尽证明。

## 2. 实现分工：共享Flutter与平台边界

Android行为源固定`4c781e3ccfcd148c1f205921534907ee0c5aa864`；iOS原生参考固定`ddb996a28f98559ea7d8b76ca9d7712703dedbc1`（iOS_newui2）。不复制旧架构，不从当前参考仓库分支猜行为。

| 能力 | 当前共享实现/正式入口 | 仅平台相关部分 | 当前验收边界 |
|---|---|---|---|
| 登录/模型/动态首页/任务 | `AuthRoute`、`SessionController`、`ShellRoute`及business providers；HTTP/状态/路由共用 | 双端安全存储；Android同生产包旧登录导入 | 正式接口已接；Android登录/真实文字恢复已验，iOS真实登录待验 |
| 统一文字与工具 | `ConversationRoute`/conversation providers；SSE、历史、候选、恢复、联系人/附件/权限工具共用 | 系统权限、选文件/图片、OCR、通讯录薄端口 | Web真实基础文字曾通过，复杂工具后台收件另验；不恢复废弃文本/语音独立页 |
| 按住说话/识别回退 | `conversation_voice_providers.dart`、`VoiceInputController`、`FallbackVoiceInputSession` | `DevicePcmCapture`与双端`PcmCaptureChannel` | 主ASR错误或8秒未ready单次后端转写回退；不是平台识别SDK。真实麦克风未验 |
| TTS/监听/音频互斥 | conversation_speech/tts_playback/call_monitor/audio_focus providers | 双端PCM输出、系统音频路由/中断；播放器插件 | 共享生命周期已接，实际声音/路由未验；多路不进入单路页 |
| 国外翻译 | [共享设备工厂](../../lib/app/translation_device_media_providers.dart)、TranslationDialRuntime、会话/Finished/归档 | LiveKit插件、AppAudio双端PCM双工；位置/麦克风权限 | Android/iOS工厂均非空且编译过；Web正式媒体禁用，演练才模拟。真实接通/归档另验 |
| 身份/声音克隆 | [clone_flow_providers](../../lib/app/clone_flow_providers.dart)、共享核验/候选/计费/录音协调 | Android固定认证AAR与`IdentityCaptureChannel`；iOS固定SDK及`IdentityCapturePlugin`；加密录音薄端口 | SDK结果不直接判PASS，后端权威；真实认证和iOS取消释放另验 |
| 录音播放/导出 | recording/call_recording providers、共享缓存校验与播放器控制器 | 双端播放器与`RecordingExportChannel`、系统文件选择 | Web只模拟计时/保存；真实声音、文件内容与权限另验 |
| 联系人/普通拨号/最近记录 | Contacts/Dialer controllers、备注/查询/号码与国家规则、App记录仓库 | 双端Contacts/SystemDialer/位置；Android CallLog | iOS仅App通话历史，普通电话交给系统不冒充App内通话 |
| 积分/赞踩/条件评分 | points/session/wallet_settlement/task_rating providers；缓存/草稿/幂等全共享 | 既有安全存储插件 | eligible决定评分入口，客户端不自加余额；真实赠送/收费/奖励对账待验 |
| 设置/开发者/日志 | SettingsRoute、DeveloperToolsRoute、共享原音偏好/ZIP上报 | 系统位置/权限/包信息；日志存储插件 | 保留原开发者功能；新演练仅Debug。仅日志上传；真实收件与设备异常见集中验收 |
| Android OTA/迁移 | StartupUpdateHost、安装控制器/校验契约、Dart迁移仓库 | Android系统下载/包检查/安装器、固定只读旧存储通道 | 无iOS OTA；生产签名、旧任务处置与真实升级/降级条件见第7节 |

源码树采用feature-first分层，页面不直接访问设备/网络。表中“已接线”只指存在正式装配，不等于所有外部服务或真机场景已通过。

## 3. Preconditions / Build & Install

| 入口 | 用途 | 边界 |
|---|---|---|
| [8080普通Web](http://localhost:8080/) | 测试环境真实登录与文字业务；优先复用已有浏览器存储 | 不清登录、不自动发验证码；不触发真实外呼或认证 |
| [8122工作台](http://127.0.0.1:8122/) | 移动宽度共享UI交互，常驻MOCK，场景退出重置 | 文件、权限、媒体、SDK或服务端结果按各场景说明模拟；不是独立HTML产品 |
| Android普通Dev | `com.vvtech.aiassistant.dev`，正常 `lib/main.dart` | 保留数据安装；不覆盖正式App，不将集成测试入口留给用户 |
| iOS普通测试包 | `com.chaken.phoneagent.test`，正常 `lib/main.dart` | Debug由保留Mac调试会话启动；当前在普通登录页，iOS登录与安卓独立 |
| 集成测试包 | 同源正式页面＋隔离外部端口，限定检查点 | 完成后恢复普通包；不能用测试包页面替代真实账号验证 |
| Profile检查产物 | 正常main，非Debug演练开关检查 | 本轮只构建/读产物，未安装；不是生产签名Release，也不替代真机行为验收 |

构建与执行约束：

1. Flutter3.32.0/Dart3.8.0，测试环境 `agent.vvtech.tech/aiassistant-api/`；记录commit、系统/设备、包名/版本/安装时间，不混用各阶段产物。
2. Android仅 `adb install -r` 保留数据覆盖Dev，安装失败不卸载。先留普通APK并核对登录，APK备份不是数据备份。
3. 设备驱动使用[只附加入口](../../tool/run_shared_stage.dart)，强制 `--use-existing-app` 与 `--keep-app-running`，不直接用默认flutter drive。启动/附加策略拒绝时停止该操作，不拆命令绕过。
4. Mac使用 `VVTechdeiMac-804.local` 和既有 `ios-toolchain/env.sh`，保留已解锁screen及当前普通App窗口。按SSH→Xcode设备→Flutter设备→App VM逐层定位，不反复重登Apple ID。
5. 先完成非人工检查，再集中授权测试电话、声音、认证。手机解锁，系统弹窗可见；锁屏/通知覆盖不算App截图证据。
6. 本轮Android Profile的11个已知MOCK标记未保留、8个正常功能标记存在，见[产物核验](RELEASE_PREVIEW_BOUNDARY_VALIDATION.md)。这不是全部路由或原生Release验收；现有Cupertino字体警告仍需在iOS系统控件检查中关注。

## 4. User Actions / Pass Criteria：集中执行顺序

2026-10-06六类能力自动核查和修复更新见[新版专项矩阵](HIGH_RISK_CAPABILITY_VALIDATION_20261006.md)，其R01–R06展开下方M06–M11。当前源码与自动证据以该矩阵为本轮补充；下方历史设备状态不充当本轮实时状态，真实能力仍分别待验。

每条两端分别记录“通过/失败/未执行/不适用”；只执行适用平台。下面均为**待真实人工验证**，已通过的Web/合成证据不自动勾选。

| ID | 入口与操作 | 通过条件 / 不允许出现 | 专项说明 |
|---|---|---|---|
| M01 登录与冷启动 | 打开普通Dev，检查已登录；结束进程后再开。确需OTP时集中输入一次，不清数据 | 当前账号保留；读取失败有重试，不当退出；不能反复自动发短信。iOS存储独立，不声称自动复用安卓 | [认证](AUTH_API_VALIDATION.md) |
| M02 首页/模型/设置 | 首页模型切换→打开动态Skill→返回；设置模型→音色→选择→两级返回 | 模型和音色上下文一致，动态入口按后端；无旧首页内嵌功能、记忆/支付等未来入口 | [模型](HOME_MODEL_VALIDATION.md)、[设置](SETTINGS_VALIDATION.md) |
| M02a 两步初始化 | 使用需初始化的专用测试账号：填写身份→下一步→选择通话模型→返回保留输入→完成；另测空身份跳过，重启普通App | 仅身份和通话模型；进入首页，无国外翻译初始化。保存失败可重试，已完成或持久跳过不循环要求初始化；不要清除现有已登录账号来构造此场景 | [初始化](INITIALIZATION_VALIDATION.md) |
| M03 统一文字/恢复 | 默认语音页切文字，发送无真实外呼的需求；候选/补问→退出→任务恢复→继续文字 | 普通退出终止本地会话，恢复不重发旧命令；已完成任务有有效session仍可恢复；候选发“第N个”，不新增执行按钮 | [对话](CONVERSATION_CORE_VALIDATION.md) |
| M04 附件/OCR/权限工具 | 使用不含私人资料的docx/xlsx和文字图片，选取/取消/导入；分别允许和拒绝所需权限；退出恢复查看附件 | 取消不上传；识别/选择结果与当前会话匹配；失败可重试、不假成功、不重复请求旧工具；历史按当前锚点恢复 | [文档](DOCUMENT_IMPORT_VALIDATION.md)、[OCR](OCR_VALIDATION.md)、[权限](PERMISSION_TOOL_VALIDATION.md) |
| M04a Agent索要文档 | 真实Agent发起importDocument，按请求过滤单选TXT/Markdown/DOCX/XLSX；依次验证成功、系统取消、解析失败、解析中离页、取消后继续文字 | 原session的submit_document状态正确且不重复；取消为USER_CANCELLED，失败不伪造成功，旧会话迟到结果不续接新会话；历史恢复不自动重新选择 | [Agent文档](AGENT_DOCUMENT_VALIDATION.md) |
| M05 通讯录/普通拨号 | 使用测试联系人，先拒绝再去设置允许，两个联系人分别查看/备注/返回；普通拨号用授权号码，验证国家/T9/最近回填 | 两人详情不串，备注不串账号；系统拨号交接不当接通。Android按授权读CallLog；iOS无系统CallLog | [联系人](CONTACTS_VALIDATION.md)、[拨号](DIALER_VALIDATION.md)、[最近](DIAL_RECENT_VALIDATION.md) |
| M06 按住/松手/上滑 | 默认语音页长按说一句、松手；再次按住上滑取消；切文字/后台/断网恢复；主识别故障由受控测试环境注入 | 单手势最多提交一次；取消/离页后不继续采集，草稿保留；最多一次后端转写回退，备用失败明确停止，不无限重连 | [输入](VOICE_INPUT_VALIDATION.md)、[回退](ASR_FALLBACK_VALIDATION.md)、[恢复](VOICE_TURN_RECOVERY_VALIDATION.md) |
| M07 单路/监听/多路 | 明确授权后分别发起单路和小规模多路；单路监听/音源/挂断、退出与回执；多路逐项结果/退出恢复 | 单路显示监听/挂断/音源；多路不进该页。正常退出观察不等于挂断后台电话；终态/失败/计费以后台事实为准 | [单路](CALL_FLOW_VALIDATION.md)、[监听](CALL_MONITOR_VALIDATION.md)、[多路](BATCH_FLOW_VALIDATION.md) |
| M08 国外实时翻译 | 确认可用国家/节点/模型/权限→授权号码呼叫→双向说话；静音/扬声器/DTMF/挂断；受控测试主媒体失败回退；结束查看记录与历史 | create→media ready→merchant-call顺序；双语方向/声音正确；按当前配置混入原音；只归档当前call，不重复外呼/扣费，不启用国内App SIP | [通话](TRANSLATION_CALL_VALIDATION.md)、[LiveKit](LIVEKIT_MEDIA_VALIDATION.md)、[AppAudio](APPAUDIO_TRANSLATION_VALIDATION.md)、[结束](TRANSLATION_FINISHED_VALIDATION.md) |
| M09 身份/声音克隆 | 合法测试身份并单独同意采集后，设置→身份→克隆→选模型→认证→候选试听/确认；取消、拒绝权限、重录、后台、另模型复用、删除 | SDK1000/2006后仍查后端PASS；未通过不生成。候选/收费幂等，模型资产不互删；iOS取消后确认相机/麦克风释放再重入，不靠超时强制解锁 | [克隆](CLONE_ENROLLMENT_VALIDATION.md)、[SDK](IDENTITY_SDK_VALIDATION.md)、[清理](IDENTITY_CLEANUP_VALIDATION.md) |
| M10 录音/音频互斥 | 翻译历史与普通回执分别播放/暂停/重试，保存先取消再成功；与试听/TTS/SDK交叉、锁屏/蓝牙/耳机断开 | 不同时占用冲突资源；取消保存不报成功，实际文件可播放且对应call；失效grant不泄漏或串账号，释放失败不假装已释放 | [历史录音](HISTORY_RECORDING_VALIDATION.md)、[回执录音](RECEIPT_RECORDING_VALIDATION.md)、[互斥](AUDIO_FOCUS_VALIDATION.md) |
| M11 钱包/评价 | 冷启动/前后台→钱包/流水；有eligible的回执评分，关闭重开、断网重试、成功查看；另测赞/踩 | 后端余额/流水对齐；草稿/重试key稳定，奖励不本地累加、不重复发；无资格不显示评分；赞踩独立保留 | [钱包评价](WALLET_FEEDBACK_VALIDATION.md) |
| M12 原音/开发者/日志 | 原音开关保存重启；现有暗号解锁开发者，检查固定号码/网络/地区/重置；准备日志后明确同意才上传 | 原音影响新会话，不改变当前通话；开发者解锁仅显隐非鉴权；打开日志页不上传。上传成功以后台ID/大小/摘要匹配为准 | [设置](SETTINGS_VALIDATION.md)、[日志](LOG_REPORT_VALIDATION.md) |
| M13 系统布局/返回 | 上述主要页两端竖屏；短屏、系统键盘、放大字体、系统返回、弹层取消，再进入另一个列表项 | 关键按钮可达，无大面积裁切/遮挡；弹层关闭回原页且可继续交互；不画假的系统键盘/安全区。系统控件允许平台差异 | [双端阶段](SHARED_DEVICE_STAGE_20260920.md) |
| M14 Android OTA | **先完成第7节发布条件核验，不能直接删除构建保护**：备份→同生产签名/更高版本覆盖；测试下载断网/进程恢复、拒绝未知来源、安装取消、升级后读取旧状态 | 错包/错签名/旧版本/错误摘要必须拒绝；安装器打开不是更新成功；成功后版本增加、有效登录/偏好/录音/记录保留。iOS不适用 | [OTA](OTA_INSTALL_VALIDATION.md)、下方迁移链接 |

Android旧数据集中核对：[登录](LEGACY_LOGIN_MIGRATION_VALIDATION.md)、[有效偏好（含初始化跳过）](LEGACY_PREFERENCES_MIGRATION_VALIDATION.md)、[认证录音](LEGACY_RECORDING_MIGRATION_VALIDATION.md)、[App通话元数据](LEGACY_CALL_RECORDS_MIGRATION_VALIDATION.md)、[条件评分草稿](LEGACY_RATING_DRAFTS_VALIDATION.md)。新存储优先、清理后不能从旧源复活；旧文件保留不等于旧App降级能识别新退出/清理标记。2026-09-20已补设备级初始化跳过导入（70条定向及Android编译通过）；09-21正式两步门禁也已接，但真实旧数据升级及设备持久化仍需验收。

## 5. Expected Logs / Forbidden Logs

不要假设每个业务都有完整客户端结构化日志。当前可直接核对的证据如下：

| 范围 | 应采集/关联的事实 | 不能推断 |
|---|---|---|
| 通用账号请求/Agent流及工具 | ZIP内`operation=accountRequest/agentStream/agentSignal/agentEvent`、`result=started/succeeded/failed/cancelled/received`，UTC时间、状态码/耗时；有合法UUID才带sessionId/traceId；可选agent含固定事件/信号/工具/持久类型与ledger序号 | received只代表收到事件，succeeded只代表请求/流；均不代表电话接通、工具/任务完成或实际扣费成功；ledger序号不是本地上传清理水位 |
| Flutter主运行时异常 | ZIP内`operation=flutterFramework/dartUnhandled`、`result=failed`和固定`failureKind`；账号按异常发生时选择，原处理器仍执行 | 无异常原文/堆栈，类型不足以证明根因；不覆盖宿主挂载前、子isolate、原生崩溃或强杀，异步保存不是强杀落盘保证 |
| 单路关闭/监听 | Debug中的`CALL_OBSERVATION_CLOSED`、`reason=local_only_no_hangup`；`CALL_MONITOR_STATE`及taskId/callId/phase/attempt | 这些是assert内Debug日志，Release没有不能判为业务失败；关闭观察不能充当hangup证据 |
| ASR/翻译/认证/积分 | 测试时间窗＋实际sessionId/taskId/callId/attemptId/candidateId/ledgerId，查询对应测试后台请求/事件记录，按专项协议核对 | 本地没有对应日志时标“证据缺失”；不臆造ASR_READY等日志，不把MOCK计数当后台收件 |
| OTA | UUID job、系统下载ID、包名/版本及`OTA_OPERATION_FAILED`/`OTA_HANDOFF_FAILED`错误码（失败时），最终安装包/版本事实 | 无错误日志≠已升级，安装Intent成功≠安装成功 |

禁止的运行信号：Android `FATAL EXCEPTION`、`E AndroidRuntime`、`ANR in <目标包>`；Flutter未处理异常、RenderFlex overflow；iOS目标App崩溃/重复拉起。普通`D/I AndroidRuntime`启动日志不当崩溃。

禁止的业务/隐私结果：取消后重复提交、跨账号回调、重复外呼/付费、未PASS生成、录音并发失控；日志出现token、OTP、真实证号、metaInfo/certifyId、媒体grant、签名下载URL/HTTP头、完整通讯录或对话/录音正文。

## 6. Failure Follow-up

1. 先停止当前可能产生电话、费用、认证或文件副作用的操作，不自动无限重试。
2. 记录用例ID、commit、平台/系统/包版本、起止时间和复现步骤；截图只截目标App，不收集通知栏等无关内容。
3. 按相同时间窗和关联ID核对客户端与后台；连接失败按Windows→Mac SSH→Xcode设备→Flutter设备→App VM分层，不要求用户反复重登。
4. 分类为共享UI/状态、平台端口、服务端/配置、权限/硬件或证据不足，再决定最小修复；跨端共有问题优先改共享代码。
5. 修复后只复测该项及直接调用方。没有证据或未执行保持未通过，不用扩大MOCK或放宽断言代替真实能力。

记录模板：`Mxx | 平台/包版本/commit | 环境 | 时间窗 | 操作 | 预期/实际 | 关联ID（脱敏） | 通过/失败/未执行 | 截图/日志位置 | 后续处理`。

## 7. Android正式发布前置条件（不是普通Dev安装问题）

当前 `android/app/build.gradle.kts` 的生产签名未配置，Release保护保留。Dev/Profile包名及debug证书不能覆盖已发布正式App；iOS没有OTA，不用iOS Bundle ID解决Android升级。

发布前必须：

1. 提供与已发布Android兼容的生产证书及更高versionCode；核对最终包名、V2签名、证书和实际升级结果，不能只取消保护。
2. 按[旧状态台账](LEGACY_STATE_INVENTORY.md)验证已实现的登录、有效偏好/定位/识别语言、认证录音、App通话元数据、评分草稿、国外翻译待归档、积分不足提示和确认卡历史快照。新存储优先、清理后不从旧源复活。
3. 旧无账号异常标记已确定不重放，不再等待决策。首页/时间线/钱包为服务端镜像，不复制旧缓存格式；首次离线差异见台账。
4. 旧OTA活动下载/已下载APK的处置仍需明确：过期或已安装目标不能重装，不信任/删除旧记录中的任意路径；是否续用高版本旧任务须核对新服务端元数据、目标包及签名。详见[剩余发布决策D03](MIGRATION_OPEN_DECISIONS.md)。
5. 旧App不识别新退出/清理标记，不能因保留旧文件就宣称安全降级；升级/回退策略须单独确认并实测。

以上发布条件没有在本轮偷偷放宽，也不能由普通Dev无损覆盖或MOCK升级测试证明。真实人工项目按第4节集中执行；未执行保持未通过。
