## Context

v65 UserIdentityModels/MyIdentityScreen/UserIdentityScreenSaveUseCase/AssistantContactRuntimeController 为契约。资料包括既有 workIdentities/description；当前表单仅姓名/手机/性别，不据 DTO 新增旧字段入口。

## Decisions

### 初始化独立设备小阶段（2026-09-21）

从已有正式App初始化连续测试提取同一阶段函数（integration_test/initialization_stage_pages.dart），保留320/430预检并追加短屏平台预检；integration_test/initialization_stage_test.dart仅运行填写与跳过两条路径，六个截图检查点，不重复前46图。所有身份/模型/跳过/登录均隔离内存端口，安全存储及系统拨号通道设为禁止；模型保存一次、无短信、翻译Provider未创建、重新检查门禁不重复保存均断言。阶段驱动新增initialization白名单，仍attach-only和keep-app-running。iOS复用screen签名构建安装，结束恢复当前普通测试环境包；Android等待已请求的手动恢复，不绕过安装限制。此阶段证明真机共享交互，不证明真实账号/存储冷启动、SDK或像素对齐。

### 正式两步初始化（2026-09-21用户最新确认，覆盖此前三步选择）

- 用户纠正此前理解：国外翻译非高频，不放入初始化。最终为身份→通话模型→首页；不读取/写入翻译偏好，不恢复国内SIP。原翻译设置及所有准入不改。移除初始化第三步及独立演练中的过期第三步，避免保留无用历史流程。
- 登录后StartupUpdateHost/PointsSessionHost内部增加共享InitializationHost；已有姓名或安装/环境级跳过直接进入Shell。加载失败保留重试，不把失败当空资料或自动放行。第二步保存通话模型后保存非空姓名身份或持久跳过；返回保留草稿、最终重试不重发已成功模型选择。
- 新app provider按loginEpoch装配现有身份/模型Repository和跳过Store，无翻译依赖。账号换代销毁旧初始化，不继续旧结果之后的操作，完成时刷新身份/模型消费者。
- 正式Host不使用Preview gateway；完整App隔离宿主仅替换已有外部Repository和内存跳过存储，可显式选择空身份进入初始化，默认已有人物的旧演练保持兼容。
- 定向验证初始化/账号生命周期及主入口，Web走正式Host的两步完成/返回/跳过；无真实身份写入、短信或外呼。本次Android用户确认尚未手动恢复，不尝试绕过安装限制；阶段设备验证保持独立。

### 完整App身份与克隆隔离演练（2026-09-20）

ShellPreview保持正式Settings/Identity/CloneCreationRoute/CloneFlowPage，只在tool目录装配合成模型、创建、认证、候选、播放器和内存录音。正式cloneFlowPreviewProvider默认false；演练作用域true使表单明确要求合成信息并提供既有测试数据按钮，不能引导输入真实身份证。默认正式服务不替换。

扩展现有PreviewCloneFlow候选参数，使返回modelId跟随请求而不是永远千问；原有默认样例不变。完整App合成目录补支持的Seeduplex V3，原有测试模型保持兼容。确认结果写回本演练的分模型资产/选择模式和已认证身份；保存录音仅保存内存布尔/合成数据，复用时不重采集。删除身份或分模型音色仍经共享控制器与确认UI，但仅清演练数据，不访问账号/系统文件。退出场景销毁资源，未据模拟扣减真实积分。

按≤3文件微批：规格；preview_clone_flow.dart与模型fixture；tool/previews/shell_clone_preview.dart/克隆端口/绑定宿主；app预览标志和CloneCreationRoute；连续回归及文档。验证两种支持模型的认证/保存/试听/确认/回流、取消、已认证姓名、复用及场景清理。真实SDK与双端设备不以本批通过代替。

### 删除后的本地处理重试（2026-09-18）

生产IdentityController在DELETE成功后已有本地清理失败提示，但IdentityPage没有对应重试出口。新增domain/identity_deletion_cleanup.dart保存每次删除的独立本地任务（跳过偏好、旧录音清理），已成功步骤不重跑。controller只重试该任务，不重发DELETE；UI增加pending/cleaning状态及明确按钮，非业务身份编辑失败不能误走清理。任务按当前账号控制器生命周期持有，不持久化敏感数据；退出页面后不自动重试，不把此批称作崩溃恢复。

certified_recording_repository.dart提供捕获删除时写入边界的clear operation；同slot串行队列下只清除边界之前成功保存的录音，后续成功替换不能被旧任务重试删除，后续失败的保存不会假装已替换。所有同slot实例共享成功写入序列，close/换账号仍拒绝旧操作。原clear保持用于既有显式业务。app/certified_recording_providers.dart与identity_providers.dart组装独立任务，不在重试时重新绑定账号。

微批文件：domain/identity_deletion_cleanup.dart、controller/identity_controller.dart；recording repository与providers；identity_page/identity_route；专用离线演练与测试；每批不超过3文件。核验本地部分失败重试、重复点击、退出晚到、新录音保护、同slot实例/在途保存、页面按钮和跨路由合成隔离。全量/analyze/OpenSpec/Web与双端构建；不发真实DELETE，不清理真实录音。首次初始化第三步产品决策仍独立待确认，列表和权限重置前置记录源/提示状态另列后续，不以占位闭环冒充完成。

- Repository 显式 save(draft, verified)，已认证 PATCH 只发送 userId/gender/contactPhone；未认证 POST 完整清洗草稿，不把已认证姓名覆盖。
- 账号由构造时固定，不信任表单携带 userId。响应 userId 如存在必须匹配，AccountApi 防跨账号晚到。
- UI 以后只用 controller，不访问 API。草稿可保留旧 workIdentities/description；保存清理无 company 的职业项。
- 操作互斥，load/save/delete 不交叠；保存失败保留编辑输入；删除失败保留原资料。删除必须显式确认信号，实际 UI 确认弹层接入后才可触发。
- 首次 EMPTY 保存不返回设置，已有资料保存后返回设置；作为明确结果交给未来 route。删除后的引导跳过/模型刷新属于后续跨模块协调，不在本批伪造完成。

## Validation

完整App录音复用回归发现CloneFlowPage.initState同步start会在构建阶段修改Riverpod状态。启动移到首帧后且检查mounted；同一完整App连续创建QWEN和Seeduplex V3的320/430宽度用例固定覆盖，不用纯页面fixture掩盖provider生命周期约束。

2026-09-18录音清理接线：正式DELETE已成功且账号/控制器仍有效后，与本机跳过状态同时调用认证录音仓库clear（等待在途保存结束，按环境/API/账号slot隔离）。任一清理/本地保存失败保留服务端空身份且提示本地处理失败，不再次DELETE；Web未保存真实录音，clear不读写浏览器存储。后台删除失败/旧账号晚到不触发效果，仍保留原回归。

## 页面批次

固定设计稿 runtime 提取 EMPTY/FILLED/VERIFIED/编辑/删除确认五态，真实 SVG 图标，SafeArea 代替原型系统栏。页面/表单组件只收状态与回调；IdentityRoute 组装 provider、Navigator 和确认弹窗。手机可空、认证姓名不可改、首次保存停留、已有资料保存返回设置均以 v65 为准，不采用原型的必填手机号校验。

声音克隆入口按 v65 跳到模型设置（本批沿用现有模型页，不伪造克隆成功）。删除成功使模型 provider 失效重新加载；认证媒体清理与首次引导跳过状态仍待后续实现。全量单元/Widget 流程测试；设备阶段受此前安装策略阻塞，记录为未验收，不能把 Widget 测试当真机结果。

纯合成网络 GET/POST/PATCH/DELETE 路径/字段/账号测试；认证状态/姓名不可改/手机号清洗/空姓名、并发/失败/退出晚到。analyze/test/OpenSpec，无平台或依赖变化。设备安装策略阻塞不通过替代命令绕过。

## Risks / Trade-offs

## 删除协调与首次引导源核对（2026-09-16）

固定 v65 的 `V61InitializationOverlay` 是身份、通话模型、翻译模型三步；第一步跳过只进入模型选择，最后姓名为空才持久跳过。`AssistantInitializationPolicy` 只在资料成功加载且姓名为空时判定需要初始化，加载失败不是空资料。`AssistantContactRuntimeController` 的 `identity_initialization_skipped` 虽然内存变量含 ThisSession，但 SharedPreferences 实际跨启动保存，源代码没有按账号清除。

本批仅完成删除后的独立协调：服务器 DELETE 成功后先更新资料、清空模型/音色缓存并重新取服务端选择，写入当前环境本机持久跳过标志。账号切换或页面销毁后的晚到结果不触发这些效果；DELETE 失败不触发。本地保存失败不能把已经成功的 DELETE 报成删除失败，也不能再次 DELETE 重试本地存储；保留空资料并显示本地保存失败提示。标志按环境/API 隔离但不按账号清除，与 v65 的本机偏好语义一致。

原生的认证录音清除属于尚未接入的克隆录音存储，不能宣称本批已完成。首次三步引导仍待运行态设计与翻译模型接入，不复用普通身份页冒充完整引导。

认证 SDK 与身份替换流程后置；不能把普通资料保存当认证成功。未接页面前此 capability 为接口基础里程碑，不称身份模块完成。

## 首次引导共享流程（2026-09-17）

- 用户授权静态HTML/CSS+既有组件先行，不再等待运行态截图。identityInitOverlay提供两步视觉，v65 V61InitializationOverlay定义身份/通话模型/翻译模型三步和跳过语义；第三步复用同一模型卡组件。
- 新增initialization feature：纯Gateway契约、Repository适配、独立Controller、共享Page/输入与模型卡、显式MOCK入口。原身份编辑和模型Repository复用，不把初始化状态塞进Shell。
- 启动先读跳过和身份，成功加载为空才需要引导；失败不能等价空资料。第二步完成写通话模型；最后写翻译偏好并保存非空姓名身份，否则持久跳过。各阶段已成功的选择不因后续失败再次重复提交。一次操作在途锁定返回/输入/重复提交，销毁后不继续下一次写。
- v65第三步国内可选、国外禁用，与用户本期只接国外范围冲突，已异步询问。目录通过Gateway注入；本批不自动挂生产初始化门禁，不持久写未经确认的翻译默认值。MOCK目录仅用于交互验证，不构成上线模型决策。
- 演练只用合成账号和内存偏好，主App已有登录不清除；普通适配代码可复用真实身份/通话模型仓库，但没有在浏览器触发真实写入。SDK/认证/克隆媒体继续后置。
