# 声音克隆创建共享交互与集中验收

## 2026-09-18：正式创建页面装配（当前状态）

本节覆盖下方历史批次中的“正式入口/总编排/播放器尚未接线”描述，**不覆盖真实认证、真机播放、签名安装和视觉待验收结论**。

- 入口：设置→语音大模型→音色与声音克隆→「创建我的声音克隆」；设置→我的身份→「声音克隆」。正式入口先读取真实目录，只列支持的模型；选择后共用 `CloneCreationRoute` / `CloneFlowPage`。返回刷新音色、身份资料和实际钱包余额，不使用旧候选中的 remainingPoints 冒充余额。
- 组装：`app/clone_flow_providers.dart` 连接 AccountApi、身份/钱包、认证/候选/完成端口及加密录音仓库。`CloneFlowController` 编排既有三个独立控制器，不把 HTTP/SDK 判断放进页面。账号 epoch 改变卸载旧流程；进入页面和勾选说明不初始化 SDK。
- 认证：同意说明后读取已认证姓名并锁定，身份证仅在表单/请求中短时存在；提交前再次检查 300 积分、替换身份确认，才 prepare/capture。Web 明确不支持真人采集，在查询替换/初始化前拦截；不会偷偷降级为 MOCK。
- 候选：已有候选只读恢复，不收取新生成准入；有效私有录音跳过 SDK、隐藏保存选项；失效先清理再回认证。生成/认证/确认不确定时分别只读同步；未知生成后的当前候选保留“不代表已核实本次计费”提示。立即 READY 的生成响应也正确传递录音 grant，已补回归。
- 完成：试听、停止、确认、仅保存重试、重新录制计费提示、未确认退出提示均复用已有组件。确认成功与录音保存失败分开；重录按候选来源选择完整认证/录音复用；未确认的认证候选退出只恢复指定模型系统音色、不删除候选。身份替换取消不调用 SDK。
- 播放：固定 audioplayers 6.4.0，下载仍由 AccountApi 同源鉴权、有界 WAV 处理。原生使用自身临时目录的 WAV（结束/停止/关闭后删除），Web 使用内存字节；不把凭据 URL 交给播放器，不采用插件的持久哈希缓存。切后台、确认、重录、退出取消试听；真实插件音频输出/抢占/中断效果必须真机验收，现有跨模块 AudioResourceCoordinator 尚未统一装配到所有媒体消费者。

### 自动验证与浏览器证据

- 新增 33 项：18 项总编排、5 项共享页面（三宽度 320/390/430）、4 项目录映射、3 项临时文件/播放器关闭、3 项正式 Route/账号 epoch 生命周期。含重复操作、无授权、Web 禁止采集、积分不足、姓名锁定、替换取消、三类只读同步、立即 READY grant、保存独立重试、录音失效清理和账号晚到。
- 浏览器复用已有 Web 登录：正式入口真实 GET 展示 QwenOmniPlus/Seeduplex V3 并取消返回；未选择/修改真实模型。随后进入「正式流程装配：录音保存失败」MOCK，说明→合成表单→候选→确认成功但保存失败→仅保存重试→已确认→返回。未发短信、提交真实身份、采集音视频、上传录音或扣费。
- MOCK 使用 `preview_clone_flow.dart` 的全合成端口与正式协调器/页面；六个新场景包括成功、认证同步、生成未知、确认未知、保存失败、录音失效。旧演练仍保留作组件参考，正式安全语义以新装配为准。
- 验证过程中发现模型弹层下方常转 spinner 导致持续动画，改为静态选择提示，Route 三项回归通过。源码默认 500 行边界保持；本批最大总编排 427 行。
- 本轮全量/最终三端构建汇总见根 tasks.md。Android 首次新插件编译有 Kotlin 增量缓存跨盘 fallback，最终产物成功；iOS CocoaPods 既有 Profile 配置警告仍在，仅 Debug 无签名通过，不外推 Release/安装通过。

### 集中人工验收（不是未接线占位）

1. Android/iOS 从正式入口走授权、锁定姓名/身份证、替换取消/确认、系统相机/麦克风权限、跟读；关联 attemptId 核实后台 PASS 后才生成。SDK 取消、拒绝、后台、网络断开分别检查；iOS 无公开强制取消能力，复用门禁与实际相机释放仍待验证。
2. 真实 300 积分生成与计费、断网后只读同步、不同设备替换候选、确认后实际通话音色；不能以 MOCK 成功或单纯编译替代。
3. 真实 WAV 起停/完成/打断/后台停播，临时文件清理、系统音频焦点和跨模块媒体互斥；真实录音保存、钥匙串/锁屏、再次复用、失败仅保存重试、身份变化清理。
4. 新真机安装需恢复授权后执行，本轮未安装、不操作 Mac 保留的解锁会话。字体/间距/动效等视觉差异遵循用户授权，后续统一校准；OTA 旧录音导入不在本批完成。

## 2026-09-18：真实候选完成动作

新增 `domain/clone_completion.dart`、`data/api_clone_completion_port.dart` 和独立 `presentation/controller/clone_completion_controller.dart`，候选 DTO 补保留 providerAssetId。这是正式创建装配的组成部分，**尚未替代现有页面演练控制器**；总编排、真实试听播放器、身份预填/锁定、钱包与正式入口仍由 home-model-shell 5.10 继续完成。

固定代码依据：Android `VoiceCloneModelFlowCoordinator`、`VoiceCloneUnconfirmedExitSystemVoicePolicy`、`AssistantRealtimeCallVoiceCatalog`，后台 `VoiceCloneCandidateLifecycleService`，均为 `4c781e3`。后端 confirm 将候选提升为 current 后删除候选行，因此“候选不存在”不等于确认成功或失败。

- 确认：POST `voice-clone/models/{model}/candidate/confirm`；请求前必须 READY+CHARGED 且有资产身份。响应必须同模型/候选/资产/来源、CONFIRMED+CHARGED；不使用旧 activate，不额外 PUT 切模型。
- 未知结果：每个完成控制器最多一次确认写入，后续只 GET models。只有同模型 current READY、active、与原候选同资产且没有新候选才核对通过；失败、不同资产或仅缺候选保留待同步。后端不接受 candidateId 条件确认，跨设备恰好在 POST 前替换候选的竞态仍不能由客户端彻底解决；客户端严格核对返回，不误报成功，本批不改后端协议。
- 保存：确认成功后按已勾选选项调用现有私有录音仓库；保存失败仍保持已确认事实，重试只保存，不再 POST 确认/认证/生成。关闭/账号变化和状态通知引起的归属变化均阻断后续调用。录音 grant 仅私有字段短时持有，不进入页面状态，保存成功/关闭清除。
- 退出：GET/PUT **指定模型** `realtime-call-voice/models/{model}`，按 v65 支持列表依次采用 activeVoice、首个 selected、response defaultVoice、固定安全默认音色。PUT 返回未同步时仅再 GET；过滤不展示音色及重复项后校验唯一选中。不会取消或删除已生成候选，也不会切换当前模型。
- 试听：候选/当前资产分别用固定同源 candidate/preview、clone/preview GET；Bearer/账号检查/401 刷新共用 AccountApi，最多 10MiB，限定 WAV 类型且拒绝重定向。这里只获取字节，**没有本批真实播放或 native audio 接线**。

32 项新增协议/状态测试覆盖正常确认、模型/候选/资产错归属、请求未知后只读同步、保存失败独立重试、重复操作、关闭/账号失效、音色恢复优先级及只读补查、隐藏选中项和试听有界下载调用。全量与构建结果记于根 tasks.md。全部使用合成 HTTP/存储，不改真实身份、模型、积分或录音；未做新真机安装或 iOS 构建。

集中验收追加：在正式页面装配后，确认成功但本地写入失败应只提示录音保存失败；网络断开导致确认响应未知时只能同步；离页未确认应保留候选且仅恢复目标模型系统音色。日志按时间窗/modelId/candidateId关联，不输出 grant、receipt、身份或音频；同候选重复确认 POST、以任意 current 冒充成功、存储失败导致再次扣费均为失败。

2026-09-18认证进度：replacement/init/status/observation真实协议、SDK分类和共享有界核验控制器已实现，见[认证协议与核验记录](CLONE_VERIFICATION_VALIDATION.md)。固定双端SDK二进制与薄端口已集成，1116全量及三端构建通过，来源/打包和iOS取消限制见[SDK验证记录](IDENTITY_SDK_VALIDATION.md)。正式页面装配仍待完成，MOCK入口未切换，未进行真实认证。

2026-09-18后续：认证录音下载/摘要/账号绑定、双端加密私有存储和身份删除清理已实现，见[录音存储记录](CLONE_RECORDING_VALIDATION.md)。现有创建演练仍不写真实文件，正式SDK/钱包/候选/存储的页面装配及设备验收仍待完成。

2026-09-18追加：真实候选生成/读取协议、稳定幂等键及独立有界观察核心已实现，详见[候选生命周期记录](CLONE_CANDIDATE_VALIDATION.md)。以下各历史批次的“未接真实生成”现应区分：协议代码已有，SDK/录音存储/钱包与正式页面装配仍未完成；现有演练仍明确MOCK，不能视作生产链路通过。

## 本批实现与入口

2026-09-17：设置→语音大模型→音色与声音克隆→创建克隆交互演练（MOCK）。原账号模型/已有克隆选择继续走原实现；新演练使用独立合成端口，不导入真实身份，不读写正式provider或积分。

已实现授权说明/勾选门禁、姓名及身份证表单、替换身份确认/取消、采集→服务端核验→生成、候选试听/停止/失败重试状态、保存认证录音选项、确认成功/失败、未确认返回提示、重新录制计费提示、重录清空授权及表单、完成后返回原页面。采集取消、认证失败、生成失败、试听失败和确认失败可单独复现。

这些是共享Flutter Widget与controller，不是HTML播放器。真实SDK、身份认证请求、声音生成、音频播放/文件保存和扣费 **均未执行**。模拟试听只改变UI状态，不会发出声音；保存选项只传给内存端口，不产生录音文件。页面持续显示MOCK，不以成功文案证明真实能力完成。

## 来源与有效流程

- Android固定v65 `4c781e3`：VoiceCloneConsentStep、VoiceCloneEnrollmentUi/Contract、ChinaIdCardValidator、VoiceCloneResultPage、VoiceClonePromptPolicy、VoiceCloneModelFlowContract/Coordinator。
- iOS固定 `ddb996a`：AIVoiceCloneEnrollmentRepository.m将初始化/替换检查/状态/complete交给服务端；本批不从旧iOS activate方法倒推覆盖v65模型候选协议。
- HTML固定 `0cd58de9`：voiceClonePage的vcStep1/vcStep2；现有ShellTokens。v65已由同一次SDK人脸跟读同时完成认证与声音采集，不移植HTML过时的分离录音步骤/假摄像头预览。
- 验证日期/校验位与v65一致；地区码不另加规则。演练样例使用000000地区码，不对应真实身份证，页面明确不填写真实身份。

## 分层与安全边界

- `voice_clone/domain/clone_enrollment.dart`：阶段、校验和外部端口。SDK采集完成不等于认证通过，必须单独核验后生成。
- `presentation/controller`：单飞、顺序推进、身份值仅短时内存保存、不写日志；销毁后不发起后续调用；试听独立序号，停播/重录/确认后晚到结果失效。
- `presentation/widgets`：说明、表单、处理状态、候选；页面负责Navigator/PopScope/弹窗，所有按钮是实际语义控件。销毁释放控制器和字段。
- `data/preview_clone_enrollment_port.dart`：仅延迟和一次合成错误，无Dio、账号、设备、文件或权限依赖。不得直接用此端口替代生产实现。
- 当前创建控制器用于本批页面演练。生产接入前必须按attemptId/modelId/candidateId补后端归属、轮询/超时、幂等及未知结果只读同步；不能直接把当前合成失败重试策略套到有扣费副作用的真实生成/确认。

## 验证证据

- 15项新增自动测试；845项全量通过；analyze无问题；Web dev及测试API Android Debug构建通过。
- 三宽度320/390/430：授权门禁→合成身份→结果→系统返回提示→继续完成→重录取消→试听→确认→完成返回。另测替换取消/确认、核验失败返回空表单后重试。
- Controller覆盖日期与校验位、未授权/非法身份无调用、SDK与核验顺序、重复提交、销毁阻止后续核验、保存false、重录重置、失败恢复。
- 初次失败源于合成样例校验位计算错误，修正fixture而未放宽验证。正式姓名/身份证未出现在测试和日志中。
- 浏览器复用现有登录：设置→音色→演练→授权/合成表单→候选结果，确认未确认返回提示并检查截图无明显溢出。未做新设备安装或iOS构建，不将既有设备记录冒作本批证据。

## 未完成与集中人工验收

1. 生产入口及门禁：认证身份预填/锁定/失败脱敏重编辑；正式身份/模型入口装配与真实认证录音读取。创建模型弹层和录音复用共享交互已完成隔离演练。分模型删除已接共享页面/API，真实删除及服务端系统音色回退仍待集中验收；不能据本批勾选完整克隆模块。
2. 真实后端及SDK：使用后端返回的认证参数和跟读文案，确认相机/麦克风权限、拒绝/取消/中断/超时、前后台和真实回调；按attemptId关联服务端最终认证结果。SDK返回成功不能代替服务端PASS。
3. 候选与计费：真实READY且CHARGED才可确认；确认成功读失败仅同步，不重复确认；生成结果未知不盲目重新创建。已扣积分失败、跨账号/跨模型晚到需专项测试。
4. 文件与媒体：实际试听开始/停止/完成/下载失败，离页停播；勾选保存/不保存、保存失败、旧认证录音替换、身份变化清理；不能保存到公共目录或写日志。
5. 双端新包阶段验证和统一视觉校准：SafeArea/键盘、大字/短屏、SDK系统界面与字体/卡片/结果按钮。当前原生系统能力未接，不标真机通过。

目标保持active。本批完成“认证到候选的可交互页面演练”，不宣称生产声音克隆完成。

## 追加：分模型管理与删除（2026-09-17）

- 来源：固定v65的AssistantRealtimeCallCloneVoiceSection、VoiceCloneModelFlowCoordinator、VoiceCloneModelApi及VoiceClonePromptPolicy。仅已有current且无READY候选时显示删除；确认绑定当时模型，切模型后旧确认不生效。
- 正式接口：受保护的DELETE `api/account/settings/voice-clone/models/{modelId}/clone`，别名规范化且仅支持既有模型；响应必须为true。不请求删除身份/认证录音/另一模型，也不额外PUT系统音色，回退状态以服务端重新读取为准。
- 未知写结果或写后读取失败：禁止重复删除和切换音色，先显式同步。测试分别覆盖失败未删除、成功但读取失败、销毁晚到及重复点击。
- 演练入口：原“创建克隆交互演练（MOCK）”内新增分模型管理、删除失败、删除成功但刷新失败三入口。两个合成模型共用正式CallModelsPage/CallVoicesPage/Controller，独立内存Repository，无真实账号/HTTP/设备数据；不是另做一套展示页面。
- 自动验证：13项新增，858项全量测试、analyze、19项OpenSpec、445文件格式检查，Web及Android Debug构建通过。Widget覆盖320/390/430宽度的取消/确认/返回、另一个模型保留及同步恢复。
- 浏览器验证：复用原登录进入明确MOCK；取消后Qwen仍使用克隆，确认删除后显示尚未克隆且模型列表回退合成系统音色，进入Seeduplex V3仍显示当前使用克隆。真实账号的Seeduplex选择未改变。
- 视觉差异：删除暂用现有语义文本按钮，后续与原删除图标统一校准。身份入口创建模型选择与已存在模型重录门禁，不由本次普通模型管理演练冒充完成。
- 本批没有真实DELETE、媒体/认证/扣费，没有新设备安装或iOS构建；正式端点契约测试不等于后台真实联调通过。

## 追加：创建模型弹层与录音复用（2026-09-17）

入口仍在“创建克隆交互演练（MOCK）”，新增八个来源场景。共享CloneCreationSheet使用底部弹层、300积分标签、模型可用性/已有克隆状态；取消和系统返回只关闭当前层。CloneCreationController先选择目标，再按v65 current/candidate→重认证确认、已有非ready候选→读取、无候选→积分准入→认证录音可用性分支，不修改普通通话模型。

认证表单与结果复用CloneEnrollmentPreviewPage/Controller/CloneCandidateStep，不新增另一套结果UI。复用认证录音的候选隐藏“保存本次认证录音”，退出不弹虚假的未保存提示；重新录制按候选来源决定复用还是完整认证。已有克隆的创建入口确认后强制完整认证，不能因本地有录音跳过。已有失败候选重试只演练读取，明确重新录制才切换新生成路径。

源依据：Android固定4c781e3 ModelPickerSheet/ModelFlowCoordinator/FlowPresentationPolicy/EntryPointsGate/PromptPolicy；iOS固定ddb996a EnrollmentRepository仍把认证初始化/替换检查/结果查询交给VerificationService，不拿旧activate接口覆盖v65分模型候选协议。布局参数及差异见design/home-model/clone-creation-contract.json；本批没有新图像或preview背景。sheet最大宽420、圆角20、20×24内边距来自v65；行按钮/关闭控件复用Flutter语义控件，积分星标/箭头/精确字重等待统一视觉校准。

### 合成范围与生产接入要求

本批验证：22项新增、880项全量测试、analyze、Web/Android Debug构建通过；320/390/430宽Widget覆盖sheet系统返回/重开、已有克隆取消/确认、录音失效、余额不足、候选失败读取后显式重新生成。浏览器已验证现有登录→音色→MOCK→Seeduplex V3→录音复用候选（无保存checkbox）→确认→返回，截图无明显溢出；不能据此声称像素校准或真机通过。

- PreviewCloneCreationPort仅持有两条合成模型、900/299积分与录音状态；PreviewCloneCreationEnrollmentPort模拟等待、成功/失败/身份失效。没有真实认证录音文件、账号请求、媒体播放或扣费。
- 正式入口尚未连接此创建流程；演练不是实际身份页“创建声音克隆”能力已交付。真实API必须补modelId/candidateId/attemptId归属，生成结果未知只读同步与有限轮询，不可照搬MOCK重试生成。
- 真实本地录音端口必须检查账号/身份匹配、文件完整性与保存任务完成；服务端身份失效后清理对应旧录音，再回认证。当前bool合成结果只验证UI分支，不等于文件校验/清理已实现。
- 每次真实新生成（含结果页重新录制）须重新检查钱包准入；演练只验证入口300阈值和重录提示，不声称真实余额变化、扣费或结算完成。
- 阶段真机、SDK和权限、后台超时、真实音频/存储/扣费及视觉校准继续按上方集中清单验收。本批未新安装Android/iOS，也未进行新的iOS构建。
