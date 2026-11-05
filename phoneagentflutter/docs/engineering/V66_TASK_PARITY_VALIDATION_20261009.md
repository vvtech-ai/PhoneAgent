# v66.0.3 首页、任务编排、列表与详情补齐记录

## 基线及交付边界

本轮功能范围以用户指定的 Android `origin/test/v66.0.3`（a0bedb12afd8aa47c82f70fe1e93bf034706f727）为准。当前 Android v71仅帮助核对有效接口；历史iOS仅追溯。分享占位及被重定向的独立结果页按钮不属于有效缺口，不新增记忆、翻译、克隆、积分或通用设置功能。

Flutter工作树为 `D:/work/04phoneAgent/_isolated/phoneagent-task-flow`，分支 `codex/refactor-conversation-task-flow`，源于保留的 `origin/codex/dev` 9a8d4e642ec1e892df4128992b84e8686233e732。不合入dev_zys，不修改foundation或旧dirty工作区，不直接推送dev。

Java最小提供方工作树为 `D:/work/04phoneAgent/_isolated/java-task-v66-parity`，分支 `codex/v66-task-parity`，基于当前对应 `origin/feat/v70-parity` 25e4f18e164b97ca2d92298501de7c30b0e849b9。中文提交62e540a0补齐确认分类和补充ledger接口，不改数据库、Redis、外呼或电话状态机；部署未经验证。

## 功能对照及源码依据

2026-10-09再次核对正式入口与遗漏功能，追加复核表见[V66_TASK_PARITY_RECHECK_20261009.md](V66_TASK_PARITY_RECHECK_20261009.md)。修正旧四阶段栏及会话列表多插入详情页；补齐普通消息复制与结构化ASK_USER问卷，复用当前answer_questions动作。会话历史直接恢复原统一对话，无session历史资源保留必要详情入口。

下表旧Android路径相对固定快照的 `android/app/src/main/java/com/vvtech/aiassistant/`，不是旧工作区当前检出源码。

| v66有效能力及依据 | 本轮Flutter实现 | 保留的当前细节 |
| --- | --- | --- |
| `features/assistant_session/CallConfirmationReplyCoordinator.kt`、`ConversationCallConfirmationHandler.kt` | ConfirmationPolicy/ReplyCoordinator/Flow；卡片呈现后才接受明确确认，确认后进入既有准入及1500ms可取消准备；七类回复及持久化outbox | 完整账号/session/tool/spec/generation隔离；否定修改正则不吞掉后续明确修改；未看卡片不拨打 |
| `features/assistant_agent/AgentTaskStopCoordinator.kt`、批量确认对话框 | StopRepository/Coordinator/Binding、正式页停止入口、批量确认/失败重试及timeline收敛 | 关闭页面不等于停止或挂断；SSE结束不等于任务成功；停止使迟到工具失效 |
| `data/local/taskdraft/TaskDraftStore.kt`、`features/assistant_shell/AssistantTaskDraftShellEffect.kt` | SecureTaskDraftRepository/Controller/Composer，保存文本与选区，明确服务端接受后清理，失败保留 | 账号/环境/endpoint/session隔离，迟到读取不覆盖新编辑，历史恢复不自动发送 |
| `features/assistant_artifacts/ArtifactDownloadCoordinator.kt`、`PureVoiceArtifactCard.kt` | TaskArtifact/Projection/Card/DownloadController，模板DOCX和批量CSV共用实时/ledger/详情投影；显式下载、保存、重试/打开 | MIME/大小/同账号限制；页面持有下载状态，卡片滚出不清状态；已保存的快速重复点击不重复下载 |
| `features/assistant_tasks/TaskPinnedUnreadVisibilityPolicy.kt`、`features/assistant/FinalTasksPage.kt` | TasksPresentationHost/TaskPinnedVisibility，置顶折叠与账号偏好、成功置顶展开定位及滚动保持 | 未读置顶仍可见，保留服务端分页15条、排序、删除限制和操作防重 |
| `features/assistant_home/domain/HomeCardPreferencePolicy.kt`、`SkillCardSettingsRoute.kt` | defaultVisible、账号卡片显隐/排序/恢复默认、最小卡片管理入口；实际安装版本门禁 | 禁用卡片过滤、配置新增卡片保留、失败重试、防重复导航；保留v66内置配置回退 |
| `data/local/speech/TaskAiSpeechPreference.kt`、`features/assistant_voice/VoiceGuidePolicy.kt` | 设备级任务播报开关、有效按住/松开/取消/短按引导，共用Dart规则 | 读取失败不误播报；关闭时打断且重新开启不重放历史；Android同包旧偏好仅只读迁入，debug不读生产数据 |
| 统一对话详情/恢复与历史结果入口 | 会话列表直接ConversationRoute.restore原session，展示补充问答与产物；无session历史资源保留原TaskDetail入口 | 仅明确无ledger兼容，网络失败重试；账号切换退出、操作返回刷新、历史不重放外呼/权限/上传 |

业务规则共用Dart，系统差异仅在平台端口。Android/iOS均注册TaskFileChannel；Android使用ACTION_CREATE_DOCUMENT/受控内容URI打开，iOS使用UIDocumentPicker导出与系统预览。两端AppInfoChannel提供真实版本/签名上下文，iOS工程Sources登记新文件。新增端口不是第二套任务状态机。

## 当前后端请求契约

AccountApi与DioAgentGateway继续作为统一入口。ServiceRoutes按当前SDK/Agent所属端点解析；C1Transport序列化一次、SM3/HMAC-SM3签名、明确编码URL、每请求新时间/nonce，刷新后重签。HTTP、SSE握手、内部语音WS、二进制及multipart均接入签名端口，不关闭验签。

凭据从构建环境 `SDK_API_KEY/SDK_API_SECRET/AGENT_API_KEY/AGENT_API_SECRET` 及本机安装身份读取，不复制真实密钥。正式部署须正确提供 `API_BASE_URL`、`SDK_API_BASE_URL`、供应方凭据及设备上下文；无凭据失败，不假成功。WS已接受连接不自动重放，迟到签名或旧token不连接；真实过期令牌/网关行为待联调。

| 接口 | 边界 |
| --- | --- |
| POST `/api/agent/call-confirmation/reply` | userId/sessionId/pendingToolCallId/cardText/userText → 七分类与可选answer；分类故障UNCLEAR、不提交Agent或外呼 |
| POST `/api/agent/conversations/{sessionId}/call-confirmation-supplements` | recordId/pendingToolCallId/userText/assistantText → eventId；唯一ledger展示事件、幂等归属、不消费工具或终态 |
| POST `/api/agent/conversations/{sessionId}/stop` | userId/targetCommandId → STOPPING/NOT_ACTIVE/BATCH_CONFIRMATION_REQUIRED |
| POST `/api/agent/conversations/{sessionId}/batch/stop` | userId/batchId；批量明确确认后调用，匹配数量/失败数量只供展示与重试，最终状态仍读服务端 |
| GET `/api/agent-artifacts/{artifactId}/content` | 当前owner、C1/Bearer；DOCX/CSV、20MiB限制；只允许当前描述符定义的冒号/点号ID，不放宽其他路径 |

公共首页配置/同源资源使用SDK签名且无Bearer；内部录音/上传等直接调用方继续走原端口。翻译历史只补其独立AccountApi的签名注入，以使任务原有翻译详情入口适配当前契约，不更改翻译业务。

Java源码：当前agent-sse的 `assistant/history/api/ConversationTimelineController`、`ConversationEventWriter`、`TaskArtifactDescriptor/TaskArtifactIds/TaskArtifactContentService` 与新增CallConfirmationReplyController/Classifier及CallConfirmationSupplementService。测试细节见Java工作树 `docs/architecture/evidence/FLUTTER-V66-CONFIRMATION-2026-10-08.md`。

## 自动验证及修复记录

固定Flutter3.32.0/Dart3.8.0，PUB_HOSTED_URL沿用pub.flutter-io.cn。锁文件仅增加pointycastle3.9.1，不升级原依赖。手写微批至多三文件；格式化另记机械批次。主Controller将选项校验交由SubmissionFlow后502行，原准确路径例外见file_exceptions；其余新增业务文件不超过500行。

- C1/HTTP/SSE与登录/首页直接调用方、内部WS迟到头、下载401重签/MIME/旧账号及分类/stop DTO均有定向证据。签名拒绝不自动刷新；401非JSON流先取消，避免一直等待未关闭的错误body。
- 确认七类回复、重复/迟到/呈现门禁、准备取消与原准入，补充记录outbox写入失败/重试及同ledger去重；停止普通/批量部分失败、关闭不停止与停止后迟到工具均通过定向测试。
- 草稿分类等待、失败恢复、明确清空与显示型补充接受，语音引导有效时间戳/取消/完成、播报偏好失败重试与Android只读迁入测试通过。测试事件的按住时间采用实际PointerEvent timestamp，不把单纯pump等待当有效长按。
- 首页显隐/排序/恢复默认与账号迟到响应、置顶折叠/未读/账号偏好通过页面测试；详情补充问答/模板下载/重复点击与终态恢复通过Android/iOS主题两例。这是组件自动证据，不是iOS设备验证。
- 首轮全量暴露旧自动拨打假设、MOCK读取真实存储、HTTP时序及恢复边界；补充显式确认演练、可注入内存偏好/任务端口。空outbox不触发无意义重投影；无ledger兼容历史继续保留原显示内容。窄屏键盘测试恢复后滚动查找历史消息，不能把懒加载离屏当内容丢失。
- 同步更新预览pendingRestorable契约：未确认工具可恢复，成功提交/已结束的工具不可恢复。设备首轮新增确认链失败（confirm_call实际null）由旧MOCK投影错误导致；修正数据端口并重跑，不放宽产品对服务端pending状态的判断。
- 最终analyze无问题；交付全量和Android完整运行统计在下方更新。此前3325通过是上一批证据，本轮不沿用该计数。

## Android构建与运行

默认Gradle构建长时间下载Flutter3.32引擎依赖；仅终止本任务构建客户端，不动共享daemon/其他任务。离线明确失败原因是x86_64_debug 1881800949 JAR无缓存；设置本机FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn后固定SDK构建成功（71.2秒，后续18.5秒/66.8秒）。未改Gradle仓库、依赖版本或提交镜像配置。

独立设备emulator-5556/PhoneAgent_TaskFlow，包com.vvtech.aiassistant.dev。只install-r，最终核对firstInstallTime仍为2026-10-08 11:03:40，lastUpdateTime为2026-10-09 01:58:14；不卸载、清数据或覆盖旧原生设备。

前次设备七步链和五张截图属于界面修正前证据。再次追踪SingleFlowNativeContentShell/SingleFlowHeader正式调用后，确认已经不显示旧四阶段栏；不能用仅存在的SingleFlowPolicy阶段定义证明正式界面仍显示该栏。最新设备链已改为列表直接恢复统一会话，并加入结构化问卷恢复/显式回答/只读历史/系统复制，结果及新截图在最终结果节登记。

自动审批曾拒绝安装/启动/驱动组合命令，仅返回blocked by policy且无执行；拆成单独安装/启动/转发/驱动后继续。不得把测试driver退出0直接视为测试通过，必须检查done/result与failure段。

## 保留待验

- Windows无macOS/Xcode/iOS设备：iOS文件适配已实现并登记工程，不能声明iOS编译、系统Files保存/取消/预览或设备完整链通过。
- Android连续MOCK链不验证生产C1路由、真实模型分类、Java MySQL落库/幂等或生产账号。Java新增接口尚未部署，真实联调须先落地提供方与构建凭据。
- Android/iOS真实电话、SIP/媒体/录音、真实按住采集、系统文件保存和打开、后台恢复、生产同包升级/旧草稿迁移分别待验；只读Android偏好迁移的通道测试不是正式升级证据。
- 公共图片签名路径、真实WS过期令牌/网关、产物真实文件内容及系统保存须环境验证。并未模拟真实成功来勾选这些项。
- 共享逻辑、双端系统实现及自动验证可交付，但全量/设备/联调结果应分别报告，未验收不归档。

## 最终结果

- 固定3.32的最终flutter analyze --no-pub无问题（44.9秒）；openspec validate --all为35通过/0失败。
- Android正式lib/main.dart调试APK编译通过（24.1秒）；任务演练APK另行构建，未把测试入口APK冒充正式产物。仅x64调试构建，不证明生产发布或16KB原生依赖适配完成。
- Android八步骤连续链通过、七张1080×2400截图已查看。覆盖首页、原会话详情、继续、失败/终态/批量恢复、显式确认和MOCK结束结果、结构化问卷恢复/回答/只读历史以及实际系统剪贴板读回。结果位于.local/shared-stage/task-flow/android/result.json，ignored截图01–07与日志保留本机，不提交真实账号/构建缓存。
- 首次系统复制读取失败：16KB兼容性提示遮挡焦点，ClipboardService拒绝非焦点访问；关闭OK且确认MainActivity焦点后重跑通过。没有关闭验签、改权限或抑制系统兼容检查。16KB与生产升级专项仍待验。
- 首次安装时间保留；原Flutterfoundation工作区无改动，Java原工作区22项与旧Android31项未提交保持不变。origin/codex/dev仍为9a8d4e642ec1e892df4128992b84e8686233e732。
- 最终完整flutter test --no-pub --concurrency=8 --reporter json：3395通过、1既有可选跳过、0失败/0错误，done.success=true，807.900秒、进程退出0。日志v66-audit-full-tests-final2.jsonl；不沿用前批3325计数。旧hitTestable断言修正后的联系人/双端尾部专项另通过。
- 分支交付：Flutter实现提交160be0b6已非force推送origin/codex/refactor-conversation-task-flow；Java确认契约62e540a0已推独立codex/v66-task-parity，未部署。未向origin/codex/dev、dev_zys、原Java v3或旧Android分支推送；OpenSpec保持active，运行态待验不勾完成。
## 2026-10-09 当前荣耀手机真实首页/任务tab优先验收

- Android参考重新fetch到origin/v71 0e960e258ff890115374ce5406d0054e09f17c49；Flutter以当前独立开发分支实施，保留origin/codex/dev 9a8d4e64，不合并dev_zys。
- 复现：实际用户已登录但AuthRoute被InitializationHost挡住；手机显示初始化资料加载失败。移除该登录阻断后保留原会话，主页与任务tab可达。
- 真实首页依赖复核：原签名首页GET为200，但HomeConfigMapper拒绝有效云素材导致整体回退；按Android resolveAssetUrl修复后真实发布配置8张卡片正常解析。模型端点原缺Bearer，对齐Java v71鉴权及modelId后手机显示QwenOmniPlus ×1.0。未主动修改用户模型偏好。
- 固定3.32定向结果：认证/任务/通知132通过，首页/网络61通过，最终网络/模型/首页/登录/通知174通过，mapper收尾7通过。集合有重叠，不相加、不宣称本轮全量；最终flutter analyze无问题。首轮旧无Bearer断言2项失败已按真实提供方契约更新，保留失败日志。
- 正式lib/main.dart ARM64调试构建成功，原证书覆盖安装；package com.vvtech.aiassistant.dev，versionCode45/versionName1.0.51-foundation，firstInstallTime仍2026-09-18 12:54:52。安装系统提示按单次确认继续，未关闭安全模式或扩大权限。
- 真机已验证：首页无初始化/配置失败提示，服务端发布卡片、余额、通话模型正常；任务列表真实记录可见，最终正在同步=0、失败提示=0。首页→任务tab→首页与进程停止重新进入首页/再打开任务tab成功，保留登录状态。未创建任务、下载、确认外呼或发送短信；任务tab沿用现有未读标记。
- 本机运行纯Java v71 Agent/SDK（28080/28082），USB reverse连接，数据库仍202 ai_assistant_ref_dev；没有执行DDL。与v71确认分类/补充两接口的缺口仍见11.10，不将首页/列表成功扩大为完整对话任务链验收。
- 本机证据：_isolated/phone-local-runtime/home-entry-tests.log、home-contract-tests.log、home-final-tests.log、home-entry-final-build.log；task-entry-home-final.png、task-entry-tasks-final.png为真实账号截图，仅保留本机，不提交私密任务内容。最终安装及重启状态另按实际命令输出核对。
- iOS共享逻辑及主题自动测试通过，但Windows无macOS/Xcode/iOS设备；iOS构建/安装、真实电话/媒体/后台/生产升级仍未验证。OpenSpec保持active，不归档。

## 2026-10-09 对话布局、文案、输入与实际语音纠偏

来源重新显式fetch：旧Android origin/test/v66.0.3 a0bedb12afd8aa47c82f70fe1e93bf034706f727。需求#1860 R1–R3/R23–R25与有效SingleFlowConversationContent、V67SpeechStatusPresentation、TaskSpeechWaveIndicator、TaskComposerTextInput、PureVoiceInputDock及VoiceGuidePolicy为本批依据。保留Flutter现有账号/session/轮次隔离，不复制原生巨型页面或增加任务状态机。

状态行恢复七段26×27声纹、44dp无底色喇叭及透明52dp关闭按钮，上下按钮中心对齐，取消独立声纹占位。状态原文为「语音待命中...」「正在聆听...」「AI 思考中...」「AI 回复中...」，依次采用实际错误、播报、聆听、思考、待命优先级；不新增暂停、连接或识别过程文案。取消喇叭下独立提示行，原版首次「按住说话」/短按「请按住说话，说完松开」复用麦克风旁浮层。极小键盘/放大字体视口将同一状态行放入时间线滚动区，关闭按钮仍固定，不溢出。

文字编辑支持1–5行、回车换行、超限内部滚动与85%可用高度展开编辑，收回保留草稿/光标并隐藏键盘、单行摘要可恢复。沿用TaskDraftController及原提交门禁，AI输出时编辑可用。新ConversationTextEditor仅负责展示，ConversationStatusPresentation仅投影既有状态。账号/页面所有者移除时仅关闭所属展开编辑路由，避免原账号草稿浮层残留到新页面；重现测试先失败后修复，两平台主题均通过。

实际语音根因：v71把ASR/TTS与备用实时字幕路由移入runtime-netty，Flutter原先连Agent端口。本批增加RUNTIME_API_BASE_URL，可在统一网关下默认回落API_BASE_URL；沿用既有AppConfig校验、Bearer/C1及PCM协议。新任务开场通过现有ConversationSpeechController首次播放，偏好/页面/通话/输入占用门禁保留，历史恢复、重新开播或输入打断不补播。没有后端业务、数据库或供应商协议修改。

运行本机纯Java origin/v71 8ebd7db4既有runtime-netty，JDK21/Maven -pl aiassistant-runtime-netty -am package -DskipTests成功16.789秒；跳过测试不能表述后端测试全绿。仅本机28085语音/28086指标绑定127.0.0.1，沿用已批准202 ai_assistant_ref_dev及Redis DB3配置，DDL/init禁用；Agent28080/SDK28082保持。手机USB转发三端口，凭据仅存在Git忽略的本机配置。

实际手机证据：已接受C1的TTS连接返回32个音频帧，AudioTrack启动播放约5.2秒；ASR连接上传127个PCM帧。用户随后明确确认「播报和录音都正常」，记为用户真机确认，不以主题/Mock测试替代。未主动确认拨打、录音电话、发送短信、修改系统权限或清除数据。

验证初始记录：固定Flutter3.32，状态/位置及小键盘6项、展开编辑生命周期6项、最终状态/输入16项、取消初始化的直接调用方14项通过。首轮完整回归3399通过/12失败/1跳过，12项全部为此前取消初始化后仍要求初始化页面的旧脚本；已按正式首页→任务→首页入口更新对应共享脚本，14项回归全绿。一次受影响集合891通过/1失败，失败暴露ASR清理后idle仍保留真实错误；修正状态投影后输入/状态16项全绿。最终完整回归3415通过/1既有跳过/0失败，报告器10分56秒、退出0。全量启动后的喇叭长按气泡收尾另以相关页面/直接调用方30项通过复核，集合不相加。最终analyze无问题53.2秒，格式化单列为机械批次。

最终正式lib/main.dart ARM64调试构建28.1秒，SHA256 4544FC8EE9B3DE9ACDE8D81C5A5430CC2F21B78256B0DE928165157AB9B7DBE2。喇叭按钮仅保留原版「关闭 AI 发声」/「开启 AI 发声」无障碍描述，不显示新增长按气泡。新增文案包第一次安装因锁屏时系统返回INSTALL_FAILED_ABORTED: User rejected permissions，未卸载回退；安装和键盘实机结果仍待用户解锁后继续。核验phone原包存在，firstInstallTime仍2026-09-18 12:54:52，lastUpdateTime仍2026-10-09 13:04:16（已确认播报/录音正常的前一语音修复包），不能将最终文案包表述为已安装。

iOS仅共享Dart与TargetPlatform.iOS主题测试，Windows无macOS/Xcode/iOS设备，实际构建、媒体/键盘仍未验收；真实电话、后台电话恢复、系统文件保存、生产升级及纯v71确认分类/补充接口缺口继续按11.2–11.4/11.10保留待验。没有扩大其他模块业务，OpenSpec保持active。实际三个拆分仓库未登记PMReport，不按只读旧项目代报。

## 2026-10-09 环境检测、实时ASR气泡、输入图标与表单撤回

源码依据（只读原版a0bedb12）：SingleFlowPrecheckPresentation.kt与PureVoicePrecheckModels.kt规定300/350/350/500毫秒展示顺序；V67SpeechStatusPresentation.kt在正常四种状态前显示检测/不可用。SingleFlowConversationContent.kt的real_live_user使用临时用户气泡，VoiceManualControlHandler.cancel清空本次识别且不追加历史。PureVoiceInputDockControls.kt规定圆角Add/KeyboardVoice/Send、停止位置和“输入任务内容”；ic_task_input_expand.xml/collapse.xml定义72单位双角路径。不得用历史巨型页面或陈旧PDR状态文案覆盖正式可达行为。

| 项目 | 实现与边界 |
| --- | --- |
| 环境检测 | 新ConversationPrecheckController只负责展示定时与网络观察，provider复用现有CallModelController事实。失败不通过，网络恢复/模型重试继续，释放订阅/旧回调。不增加登录初始化页，不探测真实外呼；实际准入仍归CallAdmission。 |
| 实时录音 | 移除输入栏上方普通文本，复用NativeConversationTextBubble(user=true,copyEnabled=false)。实时修改进入滚动revision，取消整条撤销，ledger不追加，取消代际沿用旧Controller。历史、文字草稿、迟到录音专项覆盖。 |
| 输入图标 | 自定义20dp图标按原XML路径绘制双角展开/收起，圆角Add/KeyboardVoice/Send及灰色禁用态复原。无新增Tooltip。 |
| 停止 | 移除头部“停止任务”行，文字发送位置40dp灰底Stop，语音中央56dp渐变白色Stop；展开编辑同样复用停止门禁，停止不清空/提交草稿。 |
| 用户最新覆盖 | 删除ASK_USER表单、日期/选择/独立输入控件及answer_questions动作；问题只用已有普通文本，通过原文字/语音message回答。保留原版餐厅候选、确认/回执/复制/附件。此前结构化方案及验收记录是历史，当前有效规则以本节和delta spec为准。 |

契约核对：当前Java纯v71 8ebd7db4的aiassistant-agent-sse/assistant/agent/AgentService.java，run(String,userMessage,context,pendingToolCallId)在427–468行按原pending身份normalizePendingAnswer并追加工具结果，支持自然回答。本批没有Java源码或数据库变更。v71确认分类/补充两接口原缺口继续按11.10待验，不能以本批Mock任务成功宣称真实全链路兼容。

本批验证日志：v66-task-input-final及v66-input-caller-pass（23专项、22直接调用方，集合有重叠不相加）；v66-input-affected-verified（1098通过/1既有跳过/0失败，退出0，3分53秒）；v66-input-delivery-analyze；v66-input-stage-unblocked（Android Mock八步骤/七截图/剪贴板读回，退出0）。第一轮16个旧定位失败，第二轮7个脚本/新增测试问题已修正；不删除失败记录。连续设备报告result.json的末项历史marker仍写structured-question，运行内容已是自然回答，随后仅更正marker文字，没有重跑或拼接报告。

模拟器两次Clipboard null的根因是Android App Compatibility系统提示覆盖窗口（16KB页面：现有flutter/webrtc/noise/ocr库兼容），仅确认本次OK后前台焦点恢复，重验通过；没有修改依赖或关闭此警告。七张截图为合成账号，已复读06-natural-questions确认无表单、无额外回答框，问题与原输入框同页。真实手机的TTS/ASR此前已有用户“播报和录音都正常”确认；新气泡/取消规则的真人说话和完整实机键盘交互仍需设备验收，Mock/主题测试不冒充此证据。Windows无iOS构建环境，iOS实机、真实外呼、媒体后台与生产升级继续待验。

补记前批640c1b1e最终文案包已于13:34:43解锁后安装成功，firstInstallTime保持2026-09-18 12:54:52；前文“等待解锁”是当时状态。当前新批显式versionCode45，第一次默认版本号1被系统拒绝未改变原安装；14:22:45修正包保留数据安装成功，交付包进一步核对标准versionName后另记最后更新时间。所有实际账号截图、连接配置与原始日志只在本机忽略目录，不提交。

## 2026-10-09 三步检测框、正式附件菜单与换行焦点修复

用户进一步明确要保留v66.0.3入场的步骤提示框，正式链路SingleFlowNativeContentShell → SingleFlowPureVoiceContent → PureVoiceStage → PureVoiceThreadList确实显示PureVoicePrecheckCard。此前只有头部文字不完整，已补回「正在初始化任务执行环境」及网络连接、大模型服务、外呼通道三行；原版300/350/350/500毫秒、圆点/详情颜色、入口92%卡宽、历史尾部内联及失败保留/通过后隐藏均复用同一展示控制器。模型名、错误和弱网来自已有事实/开发模式；无新增SIP探针、检测项目、按钮或页脚，无登录初始化阻断。

添加内容依据PureVoiceAttachmentSheet.kt只保留相册/文档和原副标题。删除正式AttachmentChoice中的preview/ocrPreview及其页面分支，不再由默认debug迁移开关带入两项MOCK；独立tool工作台仍只用于测试，不进入该正式菜单。

换行闪动的重现证据为EditableTextState由同一实例变为旧实例defunct，焦点与系统输入连接被释放。原布局把TextField在两个Row间移动；现改为固定Stack/Padding/ConstrainedBox路径，调整留白及底部工具位置，不重新挂载输入。Composer移除逐行AnimatedSize，保持底部锚点并沿用原草稿/提交/展开规则。测试以同一输入连接注入连续换行、自动折行、删回一行及有效组合区，验证编辑实例、焦点、光标、组合文本和键盘保持；不是每次重新showKeyboard掩盖缺陷。

固定Flutter3.32专项17通过；受影响conversation/attachments及直接调用方最终952通过/1既有跳过/0失败，退出0，3分35秒（集合与先前1098有重叠，不相加）。最新分析No issues（v66-delivery-final-analyze，11.2秒）。红测试先复现2个换行重建、3个MOCK菜单；首轮有新增测试无效组合区/工作台全局MOCK断言及平台override清理错误，均修正为真实输入条件/菜单范围/TargetPlatformVariant；一次宽集合错误传入不存在的test/features/voice及2个旧Tooltip定位，纠正目录/控件标识后最终通过，不隐藏失败日志。

Android模拟器最新连续流程八步骤/七截图/系统剪贴板读回通过，退出0（v66-precheck-task-stage）；result.json collectedAt=2026-10-09T06:53:01.866546Z，末项已为natural-question-restore-reply-history-and-copy。仍为Mock业务、真实页面/导航/剪贴板，不代表真实服务器/电话链。更新APK后的16KB App Compatibility提示仅确认本次OK，现有依赖兼容风险未修复。

正式main ARM64调试包v45/1.0.51-foundation已于14:45:58保留数据安装到荣耀AEUN9X1507G02040，firstInstallTime仍2026-09-18 12:54:52；SHA256=522E15F47467AEFFCD879D0022B7DC87C4A5A4C888BD65925348FC38FEA80557。包使用原本机后端/202开发库配置，未修改服务/数据库、未卸载或清登录。此前同批标准版本包最后时间为14:25:42；早先14:22:45是纠正版本号后的中间包，最终以本段为准。

真机键盘验证在正式输入模式切换后因页面状态变化/USB断开未完成，所有写测试文字的命令在输入框检查处退出，未提交任务/拨打/上传。已请求用户确认新版连续换行表现；真人ASR临时气泡/撤销、新步骤框入场及完整物理键盘验收仍待证据。Windows无macOS/Xcode/iOS设备，iOS仅共享Dart和主题测试；真实电话、媒体、后台、系统文件保存、生产升级和纯v71确认/补充两接口缺口继续待验。
### 补记：手机重新连接后的换行验证
荣耀正式包在USB重连后，以系统输入按键输入两行/三行合成草稿：focused均为true，mShowRequested/mInputShown均为true，输入范围分别[74,716][590,852]及[74,674][590,852]，底边852保持。随后严格核对本次LineOne/LineTwo/LineThree合成草稿才删除，恢复空白后焦点和系统键盘仍保持；未点击发送，未创建服务器轮次或外呼。证据v66-input-keyboard-phone.png仅在本机忽略目录。这补齐前文USB中断时尚未完成的连续回车证据，中文输入法组合、真人ASR撤销及入场检测卡实机仍未完整验收。

键盘脚本补充了不重新showKeyboard的逐行/折行/删除检查；模拟视口预检8项通过（v66-keyboard-preflight-final）。首次预检在恢复后被有限检测卡时序重新滚动，旧文字断言过早，改为等待健康检测完成再定位历史。Android模拟器独立OS键盘首轮在初始等待处实际inset=0，明确失败，未模拟键盘回退；日志v66-keyboard-os-stage保留，重试结果另按实际补记。手机实际系统键盘成功与模拟器脚本失败分别记录。

### 独立Android系统键盘重试结果
原首轮在兼容提示仍覆盖输入时inset=0失败。重启测试App并使用start-paused等待附加，在确认本次原生OK后启动脚本，v66-keyboard-os-retry退出0，17秒，五步骤/五张Flutter表面截图；报告collectedAt=2026-10-09T07:05:25.431469Z，completed=true，forbiddenNativeCalls=0。输入、连续换行/折行/删回一行和发送时实际系统inset均336.380952dp，主动收起与原任务恢复后为0。业务端口仍Mock，文字注入，截图只含Flutter表面而非完整系统IME，中文输入法组合与视觉像素验收没有由此完成。此设备脚本没有卸载App；模拟器firstInstallTime保持2026-10-08 11:03:40。


### 提交与边界核验
54个本需求文件以中文提交80f6ccd74a1226cb64dea550ed5b905090a743bd（恢复V66环境检测并修复输入焦点和额外控件），已非force推送origin/codex/refactor-conversation-task-flow；远端codex/dev仍9a8d4e642ec1e892df4128992b84e8686233e732。本批最终分析无问题，OpenSpec35通过，暂存diff检查0，50个现存修改文本UTF-8严格复读无替代字符；4个删除文件为此前额外表单及旧表单测试。工作树当时干净，修正验收记录单独提交。未合入dev_zys，未修改Java或历史工作区，active change不归档。

## 2026-10-09 模型弹窗、倍率与最新语音引导

只读基线再次fetch确认origin/test/v66.0.3仍a0bedb12afd8aa47c82f70fe1e93bf034706f727。模型按V88VoiceModelSheet/ModelLatencyPill内容撑高、420宽上限、20上圆角；复用原目录和延迟Controller，独立Sheet所有者隔离关闭/重开/账号迟到响应。当前Java纯v71的AssistantRealtimeController延迟端点属于Agent，AccountRequestPolicy要求Bearer/C1，SDK目录ID与latency.modelId对应：只补Flutter精确端点路由/鉴权与DTO，未改后端或数据库。任务选中标签显示后端倍率。

TTS期间麦克风隐藏，原中央方形停止控件只中断播报、不启动录音。1868 PDR最后一次R3更正要求：无欢迎语麦克风可用即显示“按住说话”，有欢迎语等待结束/失败，首次持续至按下；短按提示“请按住说话，说完松开”约3秒。依据PureVoiceBottomControlHint.kt使用14×7底边尖角和140ms整体淡出，保留文字、配色和位置至退场结束。完成仅在有效语音进入对话时写设备标记，不清除现有完成记录。

用户报告模型未点击却弹出：其中本轮ADB模型入口验证点击是已确认原因，已说明并停止手机点按。正式源码打开路径只在入口点击回调；Android/iOS主题覆盖目录初载、刷新、关闭后刷新不弹出，不把既有自动延迟刷新当自动打开。

固定Flutter3.32：最终20项专项通过；模型/网络/conversation/attachments/home受影响集合1124通过、0失败，3分43秒（model-voice-guide-affected-final.log），包含现有首页与任务导航直接调用方；analyze无问题，46.6秒。较早1121集合为补充气泡前证据，最终以1124为准；没有把定向集合说成仓库全量。OpenSpec35通过，失败过程保留issue log。

正式main ARM64 debug v45/1.0.51-foundation构建18秒；手机保留数据安装Success，lastUpdateTime=2026-10-09 16:13:31，firstInstallTime仍2026-09-18 12:54:52。最终APK本机忽略路径v66-model-voice-guide-phone.apk，SHA256=4AB7AC01141F4746BCC052D0ED3F89AB8EE306758932C7387CE66F42C9C034C3。未卸载、清数据、切换模型或发送任务。停止ADB点按后未启动或操控用户页面。

前一模型包真机记录：三模型延迟144/209/199毫秒，弹窗720px屏幕中高544px，任务标签QwenOmniPlus ×1.0；新任务TTS期间原停止可见、麦克风不显示，随后自然结束。实际手动停止TTS未验，当前设备已有完成标记，首次引导/真实短按仍需真人验证。Windows无macOS/Xcode/iOS设备，iOS仅共享Dart和主题测试；真实电话、媒体后台、系统保存、生产升级及纯v71确认/补充接口缺口继续待验。PMReport check：实际拆分仓库未登记，不以只读旧aiassistant代报；OpenSpec保持active。

## 最新任务列表、首页回退与联系人记忆批次

来源：只读v66.0.3 a0bedb12最终任务OpenSpec和原图标；当前Java origin/v71 8ebd7db4的统一分页/单项pin/read契约，MemoryPromptProvider、RestaurantContactMemoryPromptPolicy、UserContext.restaurantContactMemoryAsked及TaskTtsVoicePreferenceService。功能仍沿用统一Controller、ledger和自然回答，没有新增任务状态机、额外表单、身份入口或音色选择入口；设置页暂不动。根知识库导航属于OMS，未将OMS边界套入此项目。

验证过程保留：首轮全量3433通过/1跳过/19失败（task-latest-full-regression.log）。标题格式恢复后旧fixture定位、恢复/环境检测后旧滚动位置及路由可见性触发文档导入工厂autoDispose调度是实际失败；更正定位，继续要求真实命中且只有限重定位，工厂改为watch保持页面订阅，没有删除业务断言。复验同一失败集及受影响home/tasks/conversation与直接调用方942通过、0失败（task-latest-delivery-recheck.log，3分45秒）。记忆、账号上下文、自然回答、拒绝/继续、存储和可见性专项26通过（task-memory-contract-final.log）。最后公共上下文/页面接线新增后再次做交付全量，结果待补记，不把942定向写成全量通过。

连续设备证据：独立Android模拟器附加已有App并keep-app-running，task-latest-continuous-stage.log退出0；result.json于2026-10-09 09:08:04Z记录8步骤/7截图，覆盖首页→对话→列表→原session详情→继续，以及失败/终态/批量恢复和自然回答。未重放工具；场景为Mock内存账号，没有真实外呼/上传/后端写入。独立模拟器16KB兼容系统提示曾遮挡，读取当前控件后只点该模拟器OK；原生兼容问题未修。普通文字复制阶段有一次longPress位置警告，最终Clipboard原文读回断言通过，不据此称全像素验收。已复读任务详情截图，含原三步检测、同一行声纹/喇叭、倍率及原输入控件。

手机网络事实：三个本地服务进程仍在，手机USB连接的28080/28082/28085 reverse为空，恢复后HTTP可达；SDK未签名请求401只能证明路由可达，不算配置读取成功。用户已确认“已恢复，能看到文字”，这是实际ASR恢复证据；没有手机ADB点按/启动、清数据、发送任务或拨号。USB重连仍可能再次丢失映射，不新增驻留监控。

记忆实现只记录当前前台页面实际呈现的餐厅联系人可选询问，并按当前账号持久；后续上下文传restaurantContactMemoryAsked。询问未显示、后台、账号替换和迟到读不标记新账号；存储错误不伪造成功，不阻断当前对话。现有Java按通用记忆开启状态/既有联系人/已询问优先及明确同意处理manageMemory；客户端不新建专用接口、不从身份/历史任务自动补齐电话。单元/主题证据不等于真实模型已询问或记忆保存成功，后者尚未执行。iOS为共享Dart及主题验证，Windows无Xcode/iOS设备；真实电话、媒体后台、供应商音色、生产升级/旧记忆标记迁移及v71确认分类/补充接口缺口保持待验。

### 本批最终交付证据

固定Flutter3.32全量最终3464通过、1既有跳过、0失败，12分12秒，退出0（task-memory-full-final.log）；该轮启动后新增的实际任务路由文件另行验证Android/iOS共2通过，6秒（task-memory-route-recheck.log），两集合不相加冒充单轮全量。路由首轮失败为脚本在注入手动回复前等待循环加载，修正发送等待顺序后，继续要求真实ASK_USER呈现、只写已询问布尔值、无Checkbox及原pending自然拒绝/继续。最终analyze无问题，43.7秒（task-memory-delivery-final-analyze.log）。

Android正式main ARM64调试包以现有镜像构建13.6秒，aapt确认com.vvtech.aiassistant.dev、versionCode45、versionName1.0.51-foundation；APK SHA256=40F3CA6288CAF28B9B3ABE812DEAABF36F49D11A1FCC067B3247FC9F3FBD6DEF。手机显式install-r成功，lastUpdateTime=2026-10-09 17:58:27，firstInstallTime仍2026-09-18 12:54:52。未卸载、清数据、启动或点按用户页面；安装后28080/28082/28085 reverse仍在，三个本地监听进程保持运行。此包保留原本地后端/202开发库配置，不含生产升级验收。

提交前64个需求文件UTF-8严格复读正常、无新增超过500行的Dart文件，diff检查通过；旧仓库31、原Java22、原Flutter0、纯v71运行树0处改动保持。新分支交付，origin/codex/dev仍9a8d4e642ec1e892df4128992b84e8686233e732，不合入dev_zys、不force、不归档。手机号/账号、密钥、截图、私有定义和构建日志只保存在本机忽略目录。

本地中文提交e58150ef85853dea082bf7a675513e17c659e1f2包含本批64文件。push只指向refs/heads/codex/refactor-conversation-task-flow，但远端HTTP403拒绝；核对远端地址、分支与干净状态后，只读ls-remote也403，未重复盲推或修改凭据。推送未完成，随后记录另行本地提交。前次可用远端查询的新分支为599308ba、codex/dev为9a8d4e64；拒绝后的实时远端状态无法再读，不能称新提交已发布。OpenSpec17.4保持待办，不改推旧分支。

### 18:03之后播报失败及v71重建排查

用户反馈任务“播报失败，可继续文字交互”，并要求重新拉取v71构建后端。手机reverse三端口与三个本机服务仍在；电脑TCP实测10.1.1.202的3306/6379/9876均不可达，OpenVPN/TAP适配器Disconnected。Netty日志自18:03出现NoRouteToHostException及RedisCommandTimeoutException，故不能仅以进程存活认定服务可用。当前TaskVoiceTtsWebSocketHandler/TaskTtsVoicePreferenceService仍从现有运行配置与音色源取数据，普通synthesize的speaker不覆盖账号音色；没有证据先修改Maia、请求purpose或页面失败提示。

Java原工作区fetch v71返回HTTP403；核对地址后只读ls-remote、单次禁用进程代理的只读对照仍403，未修改永久Git配置/凭据。本机缓存origin/v71和干净java-local-v71仍8ebd7db4，不能称已取得远端最新。三个服务及公共依赖离线compile成功，16.001秒（v71-tts-offline-compile.log），不等于最新版本打包或真实播报。开发网络恢复后的fetch、构建/更新和实际TTS保持待办；原后端服务暂不停止，数据库不修改。

### 切换开发域名打包（用户后续指令）

用户将本次交付改为App直接连接https://chakenai-dev.vvtech.tech并重打包。只复制现有私有凭据至忽略的.local/cloud-dev/device-defines.json，APP_ENV=dev；Agent、SDK、语音分别使用同域/aiassistant-api/、/aiassistant-sdk-api/、/aiassistant-runtime/。既有ServiceRoutes与TaskVoiceEndpoint保留前缀并将HTTPS转换WSS，不改业务源码、数据库或签名验证；本机后端重建不再阻塞该安装，远端最新v71仍未取得。

云端只读C1探针复用当前签名实现，SDK首页配置HTTP200/code000000，Agent无Bearer返回HTTP401/AC0002；任务TTS WSS无登录返回401，证明保护入口可达，不是实际音频成功（cloud-dev-signed-probe-final.log）。配置、服务归属、C1和语音签名专项25通过，3秒（cloud-dev-routing-tests.log）。此前缓存Java TTS/音色/派发/准入定向27通过，9.226秒，仅Mock/契约，未接供应商（v71-tts-contract-offline-recheck.log）。

固定Flutter3.32/现有JDK21/mirror构建main ARM64 debug成功25.1秒；aapt核对com.vvtech.aiassistant.dev、v45/1.0.51-foundation。APK调试kernel三条云端完整地址均存在，127.0.0.1:28080/28082/28085三旧完整地址均不存在。SHA256=C9AC2F555BC0B877E50426DFDFBEF41AF36DCAB60C24F75595DFCD11048D1493，忽略目录备份v66-task-cloud-dev-phone.apk。install-r停在荣耀系统“来历不明的应用”确认，已请求用户点击继续；此时lastUpdateTime仍17:58:27，不能宣称云端包已安装。没有启动或点击任务页面、提交任务、拨号、清数据或卸载；实际手机登录和播报仍待验证。

## 单路/多路积分胶囊及220联系人事件核对

以上安装暂停为当时状态，随后19:08:04云端包安装Success。本批确认卡包19:49:02再次显式install-r成功；手机firstInstallTime仍2026-09-18 12:54:52，com.vvtech.aiassistant.dev、v45/1.0.51-foundation，正式main构建23.8秒。APK本机备份v66-task-confirmation-capsules-phone.apk，SHA256=FECFE9A382DDEAC3A94D14BED30143B6A76E10D1FEF4D9BB3C151FCDBC2BD44A。kernel三个云端地址存在、旧本地地址不存在；不会把稍后构建的模拟器integration APK当作正式手机包。没有自动启动、点按用户页面、提交任务或确认拨打。

源码依据：v66 a0bedb12的AgentCallConfirmCard、AgentCallConfirmBillingNotice及PhoneAgentPricingPresentation；VPN恢复后App origin/v71更新为257f512538d08f8b4b5ccafe1d601041479cc07a，最新删除快照另加脚注，改回原固定脚注，与本批一致。Flutter只改既有纯展示组件及footer复用，单路/多路同一胶囊：数字不加空格、EAF8EF背景、187A3A粗体、999圆角、H5/V2；两段计费标注和原多路脚注，余额不足原黄色标记。单路卡320宽度、原可执行头部和渐变；不调整价格/快照/倍率/准入/执行。按用户明确取舍，contactPhone及CallConfirmation原解析保持，无额外摘要字段。

固定Flutter3.32：受影响calls/conversation及shell直接调用方1005通过，0失败，4分02秒（confirmation-regression.log）；最终展示/原解析/单路/批量/主题恢复23通过，0失败（confirmation-final-direct-tests.log），Android/iOS主题覆盖248宽度、2倍字体和375×667/393×820恢复，不误用为实际iOS。最新analyze无问题，9.2秒（confirmation-delivery-analyze.log）；OpenSpec35通过。较早3464全量属于前批，本批范围明确，不重复冒充全量。

独立Android模拟器integration APK显式保留数据安装。首轮及有限重试均在确认后CallSessionPage断言失败，报告completedSteps为空；延长真实帧等待仍未解决，已撤回该试改，原断言保留。当前系统16KB兼容提示只在读取新UI后点击模拟器OK，未修改兼容性。未取得本批六截图或设备连续恢复通过证据，不能以主题测试补写。Android真机新确认卡视觉/恢复及真实电话、媒体后台、生产升级待验；Windows无Xcode/iOS设备，iOS构建和实机未做。

用户停留确认卡的实际事件只读匹配：220开发Agent release144，19:11:58模型makeCall里的knownFacts姓名/号码与卡片脱敏比较相同；当前三条用户消息均未提供，system.user_memories包含两项，上一askUser只补人数/时间。由此定位为记忆建议未经本任务确认直接被模型用于生成卡，非客户端自动填登录号码的已证实行为；必填有值校验不能证明授权。日志、UI、姓名、号码及SSH凭据不提交。

Java origin/v71重新fetch仍8ebd7db4。独立分支codex/fix-restaurant-memory-confirmation仅在原餐厅提示策略和skill中明确：已有候选记忆尚未获本任务同意则askUser，当前任务已明确提供/选择则不重复问，账号已询问保存不能代替使用确认；无新HTTP/DTO/表/状态机。先红11中2失败；最终81项及可执行JAR联合package通过，32.573秒；中文提交97d93ea0已推新分支。运行release144包含更好的手动联系人记忆及关闭提醒细节，与v71存在差异；部署源提交尚未核验、Jenkins API无权限，所以没有替换云端JAR或重启服务，真实模型修复尚待部署重验。

Flutter本批中文提交2b0ae1e6非force推送codex/refactor-conversation-task-flow成功，之前未推e58150ef及后续记录一并上送；14个本需求文本UTF-8严格复读、diff/OpenSpec校验通过。原工作区脏文件数量仍Flutter0/Java22/旧工程31/Java运行树0/App0；codex/dev保留9a8d4e64，不合入dev_zys，未提交日志/凭据/真实fixtures，不归档待验变更。

## 确认回复、通话请求及自动分页续批

请求依据独立App origin/v71@257f512538d08f8b4b5ccafe1d601041479cc07a：

| 源码 | 当前有效契约与Flutter修正 |
| --- | --- |
| data/service/AssistantApiService.kt:65–77、network/NetworkModule.kt | POST call/session/status、monitor/token、hangup使用Agent基地址及账号鉴权；修正ServiceRoutes归属及AccountApi的Bearer遗漏 |
| data/repository/recording/CallRecordingRepository.kt:52 | 录音使用SDK基地址；提供器的内容校验/保存作用域改SDK，不再拒绝服务端有效SDK地址 |
| features/assistant_audio/CallMonitorAudioSocketClient.kt、CallMonitorAudioRouteManager | 监听票据WSS和通信音频/听筒路由；Flutter既有适配保留，不新增平台状态机 |
| 当前Java AssistantRealtimeController、AgentCallEvaluationController | 交叉核对Agent三端点和SDK录音/评价权限，未修改Java/数据库或部署 |

界面/交互依据旧origin/test/v66.0.3@a0bedb12的CallConfirmationPresentationPolicy、AgentCallConfirmCard、AssistantTaskLoadMoreEffect、FinalAiCallPage、AgentCallResultCard/PureVoiceCallResultPresentation。补入原固定确认问句普通气泡/TTS，单轮工具去重，不改变1500ms呈现及明确确认门禁；静音/历史/旧账号不重放。单路/多路正式卡同一320宽上限。系统返回只收起本地通话观察，沿用原监听/挂断/音源，未增加原版没有的关闭按钮。

新增小型TaskPaginationScrollHost只负责底部可见/尺寸变化；原TaskController处理分页、防重、刷新和账号代际。结构化结果恢复任务完成/失败/结果确认中、字段先于状态；普通回执使用服务端headline，detail未识别为对话时保留正文。既有转写、录音、账单、模型评价和任务评分组件继续接线；服务端未返回时不合成数据。

固定Flutter3.32红绿记录：确认提示10通过；路由/鉴权/分页13通过；结构化结果及监听页9通过；C1传输/确认宽度19通过；SDK录音提供器及混合消息间距5通过；普通结果收尾7通过。各集合有重叠，不合计。首轮全量3482通过/1跳过/9失败（11分45秒、退出1），为旧Bearer、问句后的完整消息边界和播报数量断言；已保留日志并逐项更新有效契约，最终全量复验运行中。最新analyze无问题（48.4秒）。日志全部在本机忽略.local/cloud-dev下。

真实电话、监听音频及听筒切换、转写到达、录音播放/保存、后台和生产升级未验证；当前没有自动发送或拨打授权，不以Mock填补。独立模拟器连续确认链之前失败仍保留。Windows无Xcode/iOS环境，双平台主题和共享Dart测试不代表iOS原生运行。手机包构建/安装、最终全量及远端交付另补实际结果。

正式手机包：固定3.32/JDK21构建main ARM64 debug成功（65.4秒、退出0），aapt确认com.vvtech.aiassistant.dev、v45/1.0.51-foundation。备份为本机忽略目录phone-local-runtime/v66-call-task-parity-phone.apk，SHA256=A20639348FFF4829604D454E8B0F0F744301749CA572157289F33945A9183369；kernel三条云服务完整地址存在，原本机三端口地址不存在。21:08:06明确install-r返回Success，首次安装时间2026-09-18 12:54:52不变；未卸载、清数据、自动启动或点按、提交或拨号。已请求用户只查看确认问句和列表自动翻页，尚未收到这两项真机反馈。

交付检查：31个本需求文件严格UTF-8复读无替换字符，新改Dart均不超过500行；白名单暂存、diff检查和OpenSpec35项通过。fetch再次核对本地/远端开发新分支23614f19一致，origin/codex/dev仍9a8d4e642ec1e892df4128992b84e8686233e732。原Flutter0/Java22/旧工程31/App0/Java运行树0/后端修复树0处改动保持，不合入dev_zys。最终全量和中文新分支提交结果稍后补记，不归档。

## 最终宽度纠正、监听签名及开发域名重打包

用户已确认自动翻页和确认问题显示，但指出确认卡宽度仍不同。复核v66的FinalDefaultPureVoiceMode=true及正式入口，当前默认链实际使用PureVoiceCallConfirmSummaryCard.max280；先前320来自非默认AgentCallConfirmCard，判断有误。现改同一展示组件为280、原标题无可执行标记/圆点、EDFAF0/D6F5DC渐变，单路/多路一致；原胶囊/计费/contactPhone/门禁不变。宽度先红3通过/3失败，最终宽度/录音语义/消息间距14通过（width-recording-correction-green.log）。

独立App监听WSS实际有C1签名和账号头。Flutter原提供器匿名connectVoiceSocket改为现有SignedVoiceSocket.open；新增生产提供器合同验证升级头和Android/iOS听筒/外放/停止调用，先红2失败，修正后2通过（monitor-provider-green-verified.log），不冒充实际平台音频成功。

全量复验第二轮3491通过/1跳过/2失败，为正式录音直接调用方新增结果正文后暂停控件移到可视区域外；测试在播放后先ensureVisible再断言/点击暂停，保留启用与功能断言。最终交付全量3495通过/1既有跳过/0失败，11分40秒、退出0（call-parity-delivery-full.log）；analyze无问题43.5秒、退出0（call-parity-delivery-analyze.log）。源码冻结后正式main ARM64构建21.5秒及21:29:29保留数据安装成功。

用户再次要求直连开发环境：已读取私有打包参数确认APP_ENV=dev以及Agent/SDK/runtime三个开发域名前缀，重新正式main构建4.6秒、退出0（call-parity-cloud-repackage.log）。APK kernel三个云地址均存在，127.0.0.1:28080/28082/28085旧地址均不存在；aapt确认com.vvtech.aiassistant.dev、v45/1.0.51-foundation。备份v66-call-task-parity-cloud-repacked.apk，SHA256=DE93027378A25703750C4436D7B7DFFE09FDCF816F06FAC3869B572B76797A4A；21:46:04 install-r成功，firstInstallTime仍2026-09-18 12:54:52，未清数据、卸载、自动启动、点按或拨号。重新打包与21:29包同源码/参数、同哈希，没有因此重复全量测试。

用户仍报告监听失败和识别无效。手机云HTTPS可达仅证明入口，不能证明ASR健康。220只读最新日志确认21:38:53–21:38:55四次票据请求拒绝“通话不存在”，此前21:10八次；21:42 SDK事件INBOX持续IllegalStateException，Runtime21:29事件outbox Redis超时、21:30转写初始化IOException。当前源码提示ASR兼容配置未启用/连接关闭竞态，仅作推断，部署JAR提交未核验。结果日志没有完整payload，不把未解析字段写成响应空字段。脱敏交接与逐项判断见[后端故障交接](BACKEND_CALL_VOICE_HANDOFF_20261009.md)。本轮不追加后端代码/库/部署，也未发送报告给第三方。

真实监听/音源切换、转写、录音、评分/账单闭环、后台、生产升级和iOS原生构建/设备仍未验收。用户已确认的自动翻页/确认问题与未确认的最新280卡宽分别记录；不归档。

最终交付：35个本需求文件严格UTF-8及中文复读、Dart500行上限、暂存白名单相等和diff检查通过，OpenSpec35通过。中文实现提交eeddf96e已非force推送codex/refactor-conversation-task-flow，远端查询核对一致；codex/dev仍9a8d4e642ec1e892df4128992b84e8686233e732。原Flutter0/Java22/旧工程31/App0/运行Java0/后端修复树0改动数保持，不合入dev_zys或提交私有日志/配置。后端交接为仓库文档，没有发送第三方。

## 结果卡及最新App单路/多路媒体回执复核

2026-10-09用户要求结果完成、失败和异常UI与积分恢复，随后明确单路/多路功能参考最新App，界面最终仍参考v66.0.3。App只读fetch成功：origin/v71从257f512更新为fd2d5bee8f7525f1dbe3f2c1d08b296393efdbf3（提交时间21:20:16），为当前远端分支列表最近提交；本地v4不切换、不合并。

| 项目 | 源码依据与实际处理 |
| --- | --- |
| 结果UI | v66 PureVoiceCallCards/PureVoiceCallResultPresentation：280上限、16圆角、完成/失败/确认中及预订失败原因。新增纯展示映射，不承担任务状态转换。 |
| 积分UI | v66 TaskCallBillingSummarySection/PureVoiceSummaryRow：12/16双列、值右对齐、10间隔/1像素分隔线/6间隔，单路无额外标题。多路保留积分结算/第N次结算。 |
| ledger积分 | 现有投影遗漏工具结果billingSummary及receiptFields，终态无账单又覆盖开始账单；现按同session/attempt有序有效数据恢复，零扣费保留，无有效数据仍为空。 |
| reported回执 | 最新App CallAttemptTimelineProjector优先reported.callReceipt，ConversationTimelineToClarificationStepsAdapter把callId写入metadata。Flutter此前只读terminal/started且未写录音锚点；已对齐reported优先及有效锚点，恢复转写、录音与评分请求身份。 |
| 单路录音 | v66 callRecordingAnchor仅依metadata.callId，最新App额外排除已知未接通；Flutter额外转写门禁已去除，保留有效服务端锚点和已知未接通隐藏。录音未就绪走原元数据/刷新而不是伪造文件。 |
| 多路 | 最新App BatchPlusCallCard/BatchPlusCallResultItem与v66正式入口一致。现有Flutter批次DTO、转写展开、各路callId、最后连接账单门禁、多次结算、终态batch评分身份已核对，并新增双平台主题组件回归；无新增多路业务。 |
| 任务AI语音 | App TaskTtsClientFactory普通播放无preview purpose。当前Java QwenTaskTtsWebSocketHandler/TaskTtsVoicePreferenceService普通任务从账号配置或受信session.selectedVoice选择TASK_TTS音色；Flutter既有签名账号WSS和普通请求符合此规则，现有专项验证没有preview覆盖。不新增设置入口或客户端音色缓存。 |

本轮先红后绿证据：结果卡/账单首轮7失败，直接修复35通过；媒体reported专项1通过/8失败，修复集合20通过。单路/多路/TTS最终专项23通过。多路初测4失败为测试用长文字录音替身的溢出及点击位置；替身改为实际48像素按钮尺寸并等待滚动，未修改生产多路渲染以迎合测试。受影响第一轮1259通过/6失败：旧执行结果标题断言及长字段布局溢出；标题按原生更新、生产长字段用最大标签宽度约束修复，直接验证35通过。最终分析/定向回归/云环境包和交付随后记录，不将前批3495全量通过冒充本轮验证。

真实电话、媒体生成、实际评分/账单响应、后台和生产升级仍待验。iOS只有共享Dart与平台主题自动验证，Windows没有iOS原生构建/设备证据。网络与后端异常继续单列交接，不以当前客户端修复证明云端全部正常。
最终验证补记：本批固定Flutter3.32.0定向集合1282通过/0失败（4分31秒、退出0），覆盖conversation/tasks/feedback/points/calls及录音语义和正式回执工作台直接调用方；不是重复全量。analyze初轮新增条件花括号规范4提示，修正后无问题45.3秒、退出0。源码冻结后正式main ARM64构建18.7秒退出0，三个开发域名前缀存在、旧127.0.0.1:28080/28082/28085不存在，aapt确认com.vvtech.aiassistant.dev、v45/1.0.51-foundation。

APK备份v66-task-result-ui-billing-phone.apk，SHA256=31C6E0ACD7D51D78CDB31AEF4B12FB1CDDF20C94AF19F4EB59963B1FF0B40DFD。install-r被手机系统以INSTALL_FAILED_ABORTED: User rejected permissions中止，未安装成功，不盲目重放、不卸载或清数据；手机仍21:46:04旧包、firstInstallTime仍2026-09-18 12:54:52，已请求用户手机准备后重试。安装及真实UI/媒体结果仍待验，OpenSpec相应安装项不勾完成。

原工作区改动数保护复核Flutter0/Java22/旧工程31/App0，原Flutter仍foundation；当前App仅fetch更新远端引用。PMReport registry不含实际拆分Flutter/Java/App，历史工程只读不代报。只暂存本需求源码、测试、规格和脱敏文档，忽略的环境参数/原始日志/凭据/APK不提交；未归档。
交付补记：23个本需求文件严格UTF-8/中文复读、Dart默认500行上限、暂存白名单与diff检查通过，OpenSpec35通过。中文实现提交ed61bd3b66dd64250bdab8a664539d0f6acbe494已非force推送codex/refactor-conversation-task-flow，ls-remote核对远端一致；origin/codex/dev仍9a8d4e642ec1e892df4128992b84e8686233e732，工作树干净。系统安装许可中止后的手机安装仍待用户准备，真实运行项不补勾，未归档。