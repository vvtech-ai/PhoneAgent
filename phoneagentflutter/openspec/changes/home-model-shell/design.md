## Context

首页入口与缓存的当前规则以本 change 已修订的 delta 和用户批准的 `task-orchestration-v1` 为准；下方 v65 来源与历史验证仅供追溯，不再规定网络优先等待。完整合同入口见仓库 AGENTS。

行为基线为 Android 4c781e3（v65），视觉基线为 0cd58de9 的 memory/index.html。当前登录及安全会话存储已实现，登录后仍为工程页。用户要求持续推进可自动验证的初版功能，暂不优先投入录音/播放和真实外呼。

## Goals / Non-Goals

目标：动态首页、四个主导航入口、模型列表/选择和系统音色设置；统一受保护请求刷新，账号隔离；可重复的契约和 UI 测试。

非目标：复制旧首页对话框、设计稿未来版本功能、国内 SIP、充值、iOS OTA、真实语音克隆采集、实际外呼。未完成下游入口须明确标识，不冒充可用。

## Decisions

1. core/network 只管理请求与认证协议；通过会话端口读取、条件更新或清除会话，不能依赖具体页面。仅 voice-clone、points、agent/conversations、task-ratings 路径携带 Bearer。401 单次刷新，刷新共享且账号切换失效；网络失败不退出登录。
2. HomeRepository 管理 DTO 校验、ETag/304 和完整入口快照。有效缓存先发布，无缓存使用经确认随包快照，后台更新供下次进入；缓存损坏时排除，不把缓存说成实时最新。缓存写回、图片和标语轮换不阻塞入口，当前会话不被刷新改写。禁用 / 版本 / comingSoon 门禁保留，缓存不能授予权益。
3. CallModelRepository 管理当前模型及音色；controller 持有加载/保存状态，服务端成功后才更新选择。普通音色页按 v65 使用 active-provider 的 realtime-call-voice GET/PUT；models/{modelId} 留给声音克隆退出协调，不擅自替换主流程。切换模型后的过期音色响应丢弃。可用状态依据 available，不推断 configured。
4. presentation 按 home、call_models、shell 拆分；页面只能依赖状态和回调，组装在 providers/route。导航传递明确技能参数，不使用可泄漏的全局待选技能。
5. 设计资产从固定 HTML 提取并追踪哈希；不以 Material 图标替代设计中存在的业务资源。UI 以设计为准、业务以 v65 为准；网络图片失败保留卡片文字入口。
6. 默认每个手写源码不超过 500 行，每个微批不超过 3 个文件。先网络与测试，再首页数据和测试、模型数据和测试、controller、视觉页面与导航；机械生成的设计清单单独验证。

## Risks / Trade-offs

- 首版版本号仍为 1.0.0，不能伪造 v65 版本绕过服务端门禁；正式 OTA 发布前单独解决版本和迁移。
- 模型/音色保存使用离线网关验证，不擅自改变真实账号设置。在线仅读取当前配置。
- 各主导航下游分批接入，任务与设置未完成时不得将导航壳标记为完整初版。
- 本次不改变服务端、数据库、提示词或 SIP/ASR/TTS。认证失败只按明确的刷新 401 清除会话，其他错误可重试。

## Validation

### 生产创建页面装配（2026-09-18）

继续5.10，复用现有consent/identity/candidate/sheet组件和固定HTML静态契约，不重做视觉。按data模型入口/播放器、共享生产协调器/状态、Route/provider/既有入口三个微批实施，每批≤3手写文件。生产协调器组合已验证的Verification/Candidate/Completion控制器，不将演练的失败即重生成策略用于真实请求；请求未知明确只读同步，身份失效清理认证录音后回授权，重录按原来源准入。

真实试听固定audioplayers6.4.0，业务层只接收同源有界WAV，不向播放器交付账号URL或Token；原生临时文件须停止/销毁后清除，Web只用内存源。页面离开/后台停止试听，失败不冒称播放完成。SDK仍仅显式授权后启动，普通Web不能执行身份采集；独立演练复用正式协调器和页面，注入合成端口不修改真实账号。钱包/身份/模型刷新不能以旧候选remainingPoints覆盖实时余额。

### 正式创建完成动作（2026-09-18）

v65 后台 confirm 会把候选提升为 current 后删除候选行，因此未知确认结果不能反复 GET candidate 或重发 POST。保存候选 providerAssetId，用 models 当前同模型 READY/active/同资产且没有新候选严格核对；无法证明时保留待同步，不宣称成功。正常 POST 返回也必须同模型/候选/资产及 CONFIRMED，拒绝错归属。

微批一为候选资产字段/mapper 与新完成动作domain；微批二为 API完成适配、独立完成Controller和录音接口接线。完成控制器只负责确认、已确认后的可选录音保存和只读同步，不重复 SDK/生成/扣费；保存失败单独重试，不改变已确认事实。退出未确认READY候选恢复指定模型默认系统音色，遵循v65 resolver，不删除候选；试听仅补受保护有界WAV获取，真实播放器和页面装配在5.10。微批三添加API与控制器回归，按每批≤3文件执行；无真实账号POST或设备采集。

### 身份SDK双端薄适配（2026-09-18）

固定Android 4c781e3中的8个Aliyun/安全SDK AAR及iOS ddb996a中的2.3.50框架/资源，不复制可信来电或其他历史SDK。未修改供应商文件，单独记录来源及校验值；本地CocoaPods封装iOS链接/资源，Android指定identity目录和已用依赖，不升级Flutter/Xcode。适配按device_identity_capture_port.dart、Android IdentityCaptureChannel.kt、iOS IdentityCapturePlugin及App注册分批，每手写微批≤3文件。

通道仅prepare/capture/abort，带独立session租约；构造/注册不调用SDK，用户授权后prepare才安装并读取metaInfo。原生全局单飞、回调只交付一次、取消只作用于自身session。共用Dart负责HTTP/分类/核验和账号租约，不在平台代码生成候选或判PASS；Web明确不可用，不自动模拟。

Android调用SDK release并清理；iOS公开头文件无abort API，使用本次专属展示容器、关闭后抑制旧回调，在旧SDK回调未结束前保持重入门禁，不能声称强制释放相机。真实系统取消/后台/权限和密钥/包名环境集中验收。仅增加认证必要的相机用途声明，不初始化后台采集、不申请相册/定位/NFC用于认证。

验证共享通道生命周期与Web拒绝、构建依赖/资源完整性、Android Debug和Mac iOS无签名构建；不进行真实prepare/meta采集、身份认证或安装，不以编译冒充供应商运行通过。现有创建演练继续MOCK，正式页面装配独立完成。

### 共享认证协议与服务端核验（2026-09-18）

以v65 VerificationApi/Models/Coordinator/SDK分类及后台Dtos/Service为准，iOS固定ddb996a VerificationService/FaceAuthAdapter用于平台边界参考。共享repository实现replacement-check、init、status、client-observation；不调用旧complete/activate/collection覆盖v65分模型候选。consentVersion固定voice-clone-enrollment-v2，metaInfo由SDK端口提供，不伪造；SDK返回原文仅短时分类，不进入状态或日志。

新增domain/clone_verification.dart与clone_sdk_diagnosis.dart，data/api_clone_verification_repository.dart；独立presentation/controller/clone_verification_controller.dart处理准备、初始化、SDK采集、最多60次一秒查询。1000/2006均查询后台，只有PASS可向后续候选交付attempt；其他SDK返回只上报脱敏观察并终止。观察失败不能改写认证事实。失败/超时后的同步只GET同attempt，不能再采集或初始化；关闭/账号代际变化丢弃晚到且不续发观察。替换确认仍由既有共享页面显式门禁处理，不由控制器猜测用户同意。

后台实际INITIATED与旧页面INIT同属处理中，未知状态失败关闭。expiresAt为后台LocalDateTime无时区值，仅校验结构并保留，不用本机时区推断有效性，最终EXPIRED由服务端确定。每实例仅允许一次初始化；认证参数/身份证/SDK原文不放状态。当前SDK真实二进制及页面装配另批完成，合成SDK仅注入测试，不能在生产回退为成功。

测试涵盖真实AccountApi合成传输、字段/归属/未知状态、1000/2006与取消、服务端FAIL、观察失败、同步不重启、关闭和账号切换；analyze、全量Flutter测试、Web/Android构建。无本批新增原生变更，不能宣称SDK双端已可用。

### 认证录音下载与加密私有存储（2026-09-18）

v65 CertifiedRecordingStore为证据：10MiB音频上限、版本/账号/身份指纹/脚本/receipt和摘要校验、加密与原子替换、损坏失效。Flutter共享codec/下载/顺序编排，Android Keystore AES-GCM+noBackupFilesDir、iOS CryptoKit AES-GCM+ThisDeviceOnly钥匙串+排除备份私有目录仅作为opaque blob端口。固定slot由环境/API/账号绑定摘要生成，不接受文件路径；业务元数据与录音一起加密，Web不落真实录音。

下载仅使用同源固定verification/{attempt}/certified-recording与grant查询参数，复用AccountApi受保护有界下载与401/账号检查；不跟随响应URL。保存前校验SHA-256，grant过期不发请求；下载失败保留旧文件，读发现明确损坏才清除本slot，暂时I/O/钥匙串失败不得误删。串行队列等待保存完成再读/清理；关闭或账号变化后的下载不写入。新格式独立目录，保留旧安卓文件，OTA导入不在本批冒充完成。

微批按3文件：domain端口/codec/下载；平台channel/原生安全适配；共享保存仓库与provider；测试/文档。无权限申请、SDK采集、播放或真实上传。验证合成二进制下载、损坏/越界/错账号、并发替换/清除、Web拒绝写入、双端编译；真实存储与系统锁屏/恢复留集中验收。

### 真实候选生命周期（2026-09-18）

固定v65 VoiceCloneModelApi/ModelModels/Repository与后台ModelController/ModelDtos/Snapshot为协议依据；iOS参考EnrollmentRepository将认证交给服务端，不使用旧activate替代分模型接口。首批补domain候选/认证录音提交/下载凭据、data真实生成与读取仓库、独立候选Controller；AccountApi只新增受校验的X-Idempotency-Key参数，401重放保持同值，禁止任意调用者覆盖Authorization等头。

生成来自已完成verification attempt或已校验本机认证录音；两者请求结构不同。返回按目标model、candidate ID、source校验，READY且CHARGED才允许后续确认。录音与grant只在短时内存，不放页面状态/日志。创建结果未知或读取失败只读同步，不以重试按钮隐式再创建；已知候选轮询不能接受另一candidate覆盖，2秒间隔最多60次，销毁后不续发。这里只做候选生成/观察，不自动确认、播放、保存、删除或再次扣费。

微批：候选domain与mapper/API请求参数；data仓库与独立controller；协议/生命周期测试；最后更新文档/任务。默认500行、每批最多3文件。正式SDK/本机录音存储/钱包准入和创建页面装配仍是后续必做项，本批不能冒称正式创建入口已可用。用合成HTTP验证真正请求路径/体/幂等键与401、同账号绑定，状态测试验证失败/重复/跨候选/轮询/离页。无真实身份、录音或积分写入。

### 创建模型入口与认证录音复用（2026-09-17）

固定v65 ModelPickerSheet/ModelFlowCoordinator/EntryPointsGate为依据：只列支持克隆模型，available控制可点；已有current或READY+CHARGED候选先提示重新认证，确认后不复用录音。无已就绪克隆时先检查300积分，再读取可复用认证录音；缺失/无效回完整认证，录音身份服务端判定失效须清理后回认证。已有非ready候选直接打开其处理/失败状态，不再次扣准入或创建。

首微批新增domain/clone_creation.dart、controller/clone_creation_controller.dart、data/preview_clone_creation_port.dart；第二微批扩展既有enrollment domain/controller及candidate组件以复用候选结果（录音复用隐藏保存选项、无未保存认证录音警告、重录按来源决定复用）；第三微批新增共享picker及入口route、再接演练入口。所有入口持续标MOCK，不从真实账户读取录音/身份，不发生成或确认请求。生产的model/candidate/attempt归属、轮询和结果未知同步仍必须单独完成，不能直接套合成失败重试。

验证：纯状态分支、300门禁、单飞/关闭晚到、三宽度弹层/取消/返回与候选连续操作、浏览器录音复用路径；analyze/全量测试/Web/Android构建。静态v65 sheet 420最大宽、顶部圆角20、20×24内边距、14行距作为布局输入，复用ShellTokens和语义按钮；无新图像资产或截图背景。视觉最终校准与新设备安装仍独立记录。

### 分模型删除与管理演练（2026-09-17）

依据v65 AssistantRealtimeCallCloneVoiceSection、VoiceClonePromptPolicy和VoiceCloneModelApi：仅已就绪current且没有READY候选时显示删除；二次确认锁定modelId，取消无写入。DELETE models/{modelId}/clone，不调用candidate取消接口，不额外清身份/录音/其他模型；服务端负责系统音色回退。删除后只读刷新，网络未知或刷新失败进入待同步门禁，禁止直接重试DELETE。

修改domain删除端口/data适配/controller（首微批）、共享CloneVoiceCard/CallVoicesPage/删除弹窗（第二微批），再接Shell回调和分模型内存演练。复用原CallModelController的保存互斥与世代，不新增第二份正式音色状态。演练使用现有模型页/音色页，两模型独立current，删除只影响合成内存；真实账号不发DELETE。测试覆盖取消/确认、候选隐藏、异模型晚到、重复点击、删除成功读失败只同步、旧选择回退及三宽度。无SDK/音频/存储/后端变更。

### 创建克隆共享交互（2026-09-17）

先补完整认证→候选结果的共享页面和状态机，薄端口留给后端/SDK；当前入口明确“MOCK”，只注入合成端口，不读取真实身份或变更模型。固定v65 EnrollmentUi/Reducer、ModelFlowDialogs/ResultPage为行为依据，HTML voiceClonePage仅提供静态表单/卡片来源；不迁移旧分离的人脸→再次录音流程。同一次SDK跟读用于克隆，必须区分SDK返回、服务端核验及生成，不能SDK成功即宣称认证通过。

代码按domain契约、controller、preview端口、page/steps/dialogs拆分；CallVoicesPage只挂演练导航，500行/3文件微批。说明勾选→身份表单→替换提示（由端口决定）→SDK采集→结果核验→生成→可试听/保存录音选项→确认；未确认返回有提示、重录有计费提示、忙碌及离页晚到保护。MOCK失败可手动重试，不操作真实麦克风/摄像头/身份/积分。模型选择管理、已保存认证录音复用、真实SDK/API、删除/真实计费仍独立待完成。

验证：共享controller异步边界、表单/弹窗/候选返回、三宽度Widget和浏览器连续路径，analyze/test/Web与Android构建。静态优先不代表视觉通过；平台安装不冒用旧证据。

### 克隆目录与选择闭环（2026-09-16）

依据固定 v65 `AssistantTaskSettingsPageHost` 的 onSelectCloneVoice、`AssistantRealtimeCallVoiceCatalog` 的模型门禁、`VoiceCloneModelApi` 及 `VoiceCloneModelFlowCoordinator`。GET voice-clone/models 读取 current 与 candidate，严格归属 modelId；只有 QWEN_OMNI_PLUS / DOUBAO_SEEDUPLEX_3_0 支持克隆（旧 QWEN alias 归一）。READY 且 billingStatus=CHARGED 的 candidate 优先于 current（VoiceCloneModelFlowContract.ready），确认 POST models/{modelId}/candidate/confirm；否则已 READY 且 asset 非空的 current 用 PUT realtime-call-voice {selectionMode:CLONE}，不得错误调用旧 activate 接口。确认之后只 GET 刷新，后续读失败不得重复确认 POST；UI 保留“已提交，待同步”，阻止再次选择直到重试同步。系统音色仍用既有 PUT AI。

共享 domain 克隆快照、独立 data 仓库；CallModelController 统一本页写入互斥、模型代际和状态读取；正式 ShellRoute 注入。页面消费已有 runtime cloneVoiceGroup/selectCloneVoice/cloneVoiceStatus/cloneVoiceDetail/rerecordVoiceBtn 节点的视觉数据，状态文字由后端事实决定。当前模型不支持则不显示克隆卡；请求失败不是未克隆；不把其他模型的 current 或未确认 candidate 标为已选。没有本批请求授权的真实账号写入，线上仅读取。

文件分批：domain/clone_voice.dart、data/api_clone_voice_repository.dart；call_model_controller.dart、business_providers.dart；clone_voice_card.dart、call_voices_page.dart、shell_route.dart；独立契约/状态/UI tests。默认500行，每批最多三文件。已有设计产物更新对应动作，不生成新布局或整页模板；创建/录音/试听/删除未完成，触发采集入口明确提示，不视为无响应或假成功。

视觉门禁历史复核：本地 voiceIdentity.png 实际为初始化身份引导遮挡层，与已缓存 voiceIdentityPage 节点不符，不能作为音色页验收截图。2026-09-17 用户明确批准先使用已有 HTML/CSS/组件完成交互，解除新卡片实现前置；按静态 cloneVoiceGroup 参数复用现有卡片和选择指示器，视觉差异后续统一校准。5.3 以真实组件交互回归通过勾选，不冒称像素级视觉或录音采集验收。

单元测试覆盖刷新并发、账号切换、失败保留会话；首页严格解析、304、失败兜底、状态/版本门禁；模型失败回滚、过期响应。控件测试覆盖选择/返回/重试。Android 配置测试环境构建并用离线集成与真实只读页面检查；iOS 构建及真机结果单独记录。保留未完成项，未验收不归档。
