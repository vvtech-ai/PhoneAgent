# 积分与评价协议基础

## 2026-09-18 会话激活与克隆同步（最新）

本节覆盖下方历史批次的“激活/缓存/克隆同步待接入”：缓存已由65e6015接线；本批接通登录赠送、恢复会话激活、前台同步和克隆共享余额。国外翻译结算仍依赖真实翻译事件/页面装配，尚未完成；整体验收和视觉仍未完成。

### 实现和来源

- 固定v65 `4c781e3ccfcd148c1f205921534907ee0c5aa864` 的 PointsSessionActivationCoordinator、PointsWalletForegroundSyncEffect、PointsWalletApi、AssistantAuthRuntimeController、LoginGrantToastPolicy 为激活依据。短信成功登录已激活，使用内存LoginOutcome、标记本进程账号成功并消费赠送；恢复安全存储会话无该事件，调用 `POST api/points/session-activations`（Bearer、无业务body）。没有再次发验证码。
- `points_activation_registry.dart` 按账号合并在途请求、成功一次、失败允许下一轮；provider按环境/API重建 registry。`points_session_controller.dart` 前台先激活再只读刷新，30秒间隔，后台取消计时，恢复前台立即同步。token正常刷新不重建，登录epoch改变使旧实例失效。不在客户端推算每日奖励，不在跨日时额外发奖励请求。
- `points_session_providers.dart` 保持当前登录的消费状态跨页面重建；`PointsSessionHost` 在 AuthRoute 正式登录分支挂载，接生命周期并显示一次性SnackBar。INITIAL_GRANT / DAILY_LOGIN_GRANT使用后端金额，未知类型无推断提示；不持久化赠送事件、不本地增加余额。Shell原有重复前台钱包刷新已移除。
- `PointsWalletController.acceptServerAccount` 发布完整服务端摘要、标记流水待刷新并复用缓存；旧account/ledger/缓存与独立准入查询不能覆盖较新摘要，后续准入不复用摘要到达前的在途GET。失败不把未知当0，也不从赠送金额构造流水。
- `clone_flow_providers.dart` 两处正式准入改用共享 `refreshBalance`；服务端候选计费状态和确认（含未知确认后的只读核验）经 `WalletSettlementSync` 去重只读刷新。身份以模型/candidate分帧，版本以billing/chargedPoints/confirmed判重，不将候选历史remainingPoints写成当前余额。观察者失败不影响认证/生成/确认，不重发付费请求。v65 ModelFlowCoordinator/AssistantVoiceCloneModelRuntime 的计费通知展示服务端扣费事实，本批新增共享只读同步，不伪造新扣费。
- 全部业务/状态为Flutter共用，未改SDK、权限、依赖、原生、数据库或ASR/TTS/SIP。固定iOS源目录未发现独立积分钱包实现，不声称复制了不存在的iOS钱包；两端共用v65有效业务。
- 当前无专门网络状态插件：断网保留缓存，前台每30秒和恢复前台重试；与v65联网回调相比，网络恢复可能等待最多一个周期。后台不轮询，失败没有递归重试；此差异需在集中网络验收中观察。

### 自动验证与安全边界

- 新增31项：协议/激活去重9、会话控制器7、余额竞争5、正式会话provider4、生命周期Host1、正式克隆provider2、克隆通知回归3；全量1333项通过，analyze无问题，OpenSpec19项通过。格式检查涵盖592个lib/test文件和独立预览入口。
- Web Debug、Android Debug测试配置构建通过；最终API上下文为 `https://agent.vvtech.tech/aiassistant-api/`。首次编译参数遗漏上下文，已按正确配置重建，不把首次产物用于安装。
- 独立 `tool/previews/points_session_preview.dart`（debug-only）使用合成会话/内存服务覆盖正式provider/controller/host/wallet页面，浏览器8094验证：初始激活0→开始→提示“今日登录赠送 ✦100 积分已到账”/余额900/激活1→流水→返回→重新挂载仍激活1且不重放提示。非截图推断，无真实API/存储/短信/积分写入。
- 原真实Web 8080仍保留原会话和先前运行实例；本批没有对它热重启，以免自动触发未验收的真实赠送。普通新构建启动会进入已接好的正式激活逻辑。没有新设备安装或iOS新构建；不是双端真人/计费验收。

### 集中人工验收步骤

1. 测试环境已登录账号，在Android/iOS正常结束进程后重新打开，不清数据：应无需验证码；首次前台触发会话激活，按后端grantEvents决定有无提示，打开钱包核对account/ledger。后台用账号+时间窗核对 `/api/points/session-activations` 和ledgerId，日志不得输出token/响应正文。
2. 同一次进程多次前后台、钱包/流水往返、正常token刷新：成功激活不重复POST，不重复赠送提示；每次前台及30秒周期仅只读更新。退出后另一账号不能看到前者摘要/提示。重新进程的激活可以再次请求，但服务端不得重复发同一日奖励。
3. 断网启动→恢复网络：缓存明确非最新、不用于准入；恢复前台或最多下一30秒周期同步。激活失败不立即连发请求；余额/流水失败可重试，不能误显示已到账。真机后台/锁屏无持续定时请求。
4. 已获真实认证/克隆测试授权后，生成/候选轮询/确认或只读恢复：以modelId/candidateId及后台流水核对实际扣费，首页/钱包应刷新当前余额，不退回历史remainingPoints；钱包失败不能再次生成或确认。Web MOCK未调用SDK、未提交真实身份或录音、未实际扣费。
5. 本批不含国外翻译结算接线、整套网络状态即时回调、Android旧钱包数据迁移、真实存储/双端阶段安装及统一视觉校准；父任务2.3仍保留未完成。

2026-09-16，行为固定 v65 `4c781e3`。

## 来源与实现

- PointsWalletApi/Repository/Coordinator：GET account、GET ledger(page=0,size=20)。首屏余额和流水一起成功才替换快照；未知余额不是0；失败保留并标记stale；过滤零变动、跨页稳定ID去重。并发刷新合并一次尾随只读刷新，dispose后不再请求下一步或更新状态。
- AgentCallEvaluationApi/Repository/Contract：单路与批量路径独立，GET加载/PUT GOOD或BAD；空modelName不展示；单路averageLatency映射同端点，批量minimum/maximum范围，负时延不显示。不和多维评分合并。
- TaskRatingApi/Repository/ViewModel/Contract：GET calls/batches资格，发送调用方clientVersion；eligible、稳定ID、CALL/BATCH锚点全部匹配才可用。已提交只读；1–5分、300 Unicode码点建议、克隆未评价排他；提交沿用调用方稳定idempotencyKey，响应必须包含currentSubmission。奖励只读服务器字段，无本地加积分。
- AccountApi固定账号与登录epoch；points/task-ratings用Bearer，agent-calls/evaluation按现有账号头。合成测试中的65.0.0仅样例，不伪造Flutter生产版本。

## 验证

`scripts/verify.ps1 -SkipAndroidBuild`：160项测试、analyze无问题、OpenSpec13/13通过。11项新增测试覆盖DTO错误/路径/方法/鉴权/分页/未知/部分失败/并发晚到/跨账号/回执锚点/Unicode/只读/重试key/缺少提交结果。

只使用SyntheticAccountApi，域名example.test不实际发网；没有真实账号评价、赠送激活、外呼或扣费。未修改依赖/原生/平台构建；未尝试绕过当前设备安装策略阻塞。

## 2026-09-16 时的未实现范围（历史）

钱包设计页面与首页入口、持久离线缓存、登录/前台激活赠送及提示去重；真实通话计费准入/结算同步。评价还未挂载统一页回执，条件评分草稿/owner/提交Controller/奖励提示与钱包刷新待实现。iOS、真实账号和设备验收未做。OpenSpec保持active，不归档。

## 2026-09-17 页面与交互增量

用户允许静态HTML/CSS与既有组件优先完成交互，视觉差异以后集中校准。固定行为仍为v65，不采用原型未来的会员/购买/订单/发票。

| 范围 | 实现位置与数据来源 | 验证边界 |
|---|---|---|
| 首页余额→积分→流水 | points/presentation + app/points_providers；真实账户GET、流水GET | Web复用现有登录只读验证；未新发短信、未激活/扣费 |
| 回执GOOD/BAD | feedback/presentation/controller/call_evaluation_controller、widgets/call_evaluation_card、pages/call_evaluation_route | 真实API挂载；写操作只用合成仓库，失败回滚、保存互斥 |
| 条件评分/只读/成功 | task_rating_controller、task_rating_sheet、task_rating_route | 后端eligible+稳定锚点控制；表单/成功页在浏览器MOCK实测 |
| 草稿/重试/账号隔离 | domain/task_rating_draft_store、data/secure_task_rating_draft_store | 现有安全存储插件，按环境/API/账号/任务隔离，串行写入、先存key再POST；自动测试 |
| 奖励/钱包刷新 | task_rating_providers连接pointsWalletController | 仅服务端rewardGranted与正奖励值才展示，成功后只读刷新；不本地加余额 |

以上均为共享Flutter代码；平台差别仅通过既有flutter_secure_storage适配，不新增原生页面或网络实现。当前客户端评分资格版本为真实Flutter `1.0.0`，不伪装成Android `65.0.0`；后端最低版本可能因此隐藏入口，须在真实资格验收时确认。升级pubspec版本时需同步该provider。

### 自动与浏览器证据

- 全量 `flutter test`：380项通过（前批359，本批新增21）；`flutter analyze`无问题；`openspec validate --all`17/17。
- `scripts/web/verify.ps1`：273项共享页面/协议回归、2项Chrome流传输测试、1项Node代理测试通过。
- 正式 `lib/main.dart` Web Debug及Android Debug构建通过；Android API固定 `https://agent.vvtech.tech/aiassistant-api/`。非OTA升级产物。
- 普通Web `localhost:8080`：首页积分入口→钱包→流水，两条服务端记录可读→返回；未知/加载/空列表/旧快照错误/分页重复/加载更多状态由合成自动测试补齐。
- 独立 `tool/previews/feedback_preview.dart`（debug-only，8093）：赞→条件评分→三维选择→克隆不评价→建议→关闭/再打开保留→首次失败→原稿重试成功→服务端合成7积分→只读。无账号/API依赖；MOCK显式标识，刷新会重置内存数据，不代表真实积分入账。
- 重复回执同目标只显示一个评分入口；晚到请求不刷新另一账号，存储失败不发POST，已成功但清理失败不允许重复提交，全部有回归测试。

### 尚未完成与人工验收

1. 真机：本批未重新安装Android/iOS。此前安装操作被工具策略拦截，未绕过；现有设备上的旧包不能作为本批证据。后续恢复允许的安装链路后核对钱包/评分布局、输入键盘、系统返回和持久草稿。
2. 真实评分：在测试环境选择有资格的已完成通话/批次，记录callId/batchId/eligibilityId；先填后关再开确认草稿；提交后应只读，仅真实rewardGranted才显示奖励；后台同幂等键只能有一次有效提交/发放。禁止用虚假高分或真实外呼自动制造资格。
3. 安全存储：同账号重启恢复未提交草稿；切换账号/环境不串数据；新服务端submission覆盖旧本地草稿。Web mock不能证明真机钥匙串持久化。
4. 钱包激活赠送、持久离线缓存、克隆/翻译结算事件尚未完成；准入及单路/批量回执已由下方增量接通。UI预计分钟沿v65基准100积分/分钟，仅展示，不作为实际扣费依据。
5. 像素级视觉与双端差异留集中校准：见design/wallet/generated-ui-summary.md。OpenSpec active，整体迁移不标完成。

## 2026-09-17 准入与钱包余额同步

来源：固定v65 TaskCallPointsAuthoritativeBalanceRefresher、PointsWalletBalanceUpdates及PointsWalletCoordinator.applySettledBalance。此前准入直接查Repository，仅返回数字，首页/钱包仍使用旧State；现在通过同一PointsWalletController.refreshBalance查询并发布完整服务端account，app/call_admission_providers仅装配，不重复持有余额。

- 同时的准入余额刷新单飞，并与普通整页刷新共享account请求。独立刷新不请求流水、不伪造扣费或赠送。
- 普通整页仍按account+ledger成功成对替换；新增独立余额revision保护，期间较新余额成功或失败均不被旧整页结果覆盖。余额成功而流水未更新时ledgerStale=true；页面明确“余额已更新，积分流水待刷新”，流水页不把未同步冒称空记录。
- 刷新失败保留旧数字供展示，但admissionBalance为未知；普通API失败交后端原子准入。signedOut/sessionChanged继续抛出，不可当作未知而放行；账号epoch重建/销毁后不能返回新执行依据或写回状态。两种stale不互相冒充。
- 12项新增（10项共享状态、1项正式provider装配/账号替换、1项页面语义），749项全量测试、analyze、Web/Android Debug构建通过。保持原有部分刷新不伪造整体快照测试。测试全部合成，无网络/真实扣费写入。
- 普通Web复用登录，只读验证首页余额→积分→两条已有流水→返回刷新。没有制造真实积分变动；并发及“余额更新/流水过期”分支仅自动合成验证，不宣称已在真实外呼中出现或验收。
- 本批没有iOS新构建/设备安装证据；未绕过原安装阻塞。持久缓存、激活、单路/多路/翻译/克隆结算通知及集中人工真机/视觉仍待完成，OpenSpec 2.3不整体勾选。

## 2026-09-17 单路与批量计费回执同步

- 来源：固定v65 `AssistantPointsWalletSettlementEffect`。正式conversation provider监听共享Controller消息，从单路billingSummary及批量items.billingSummaries提取信号，交给纯Dart WalletSettlementSync；UI不发网络请求。
- 只读取当前钱包account/ledger，不将回执remainingPoints直接写入当前余额，不按本地时长扣费。恢复旧任务也只触发当前查询，无计费身份不推测扣费。
- 计费身份+摘要版本去重，微任务合并、刷新中最多排一次尾随；失败由钱包显示错误且不自动无限重试。同步器绑定钱包依赖并随账号替换销毁；去重仅在共享provider存活期内，全部对话关闭后重入允许重新查询，并非持久事件消费记录。
- 新增8项domain测试与2项正式provider集成测试：单路/批量/历史、旧余额不回放、重复/重排/新版本、并发/失败/销毁及独立生命周期。759项全量测试通过，analyze无问题，OpenSpec19项、399文件格式检查及Web/Android Debug测试配置构建通过。所有回执均合成，真实账号无扣费、无外呼或写入；没有将单元测试当作真实结算验收。
- 本批没有新页面或视觉变更；此前Web只读钱包证据仍属于上一批。iOS、双端安装及真实结算仍需集中验收：完成获授权测试通话→回统一页→打开积分及流水，核对服务端当前余额/计费ID；恢复旧任务不得回退为旧剩余值，失败应允许手动刷新，不能循环发起电话。
- 激活赠送、持久离线缓存、克隆/翻译结算及媒体不在本批完成范围；OpenSpec2.3保持未勾选。

## 2026-09-18 钱包持久快照正式接线

本节更新前述“持久缓存待完成”状态；激活赠送和克隆/翻译结算仍待完成。

- 固定v65 `SharedPreferencesPointsWalletCache` 与 `PointsWalletCoordinator` 为行为来源：保存服务端account与已加载ledger，重入先呈现离线快照，完整刷新/分页/权威余额更新后保存。Flutter共享domain快照、版本化codec、controller与provider；复用既有`flutter_secure_storage`平台适配，不复制旧安卓架构或引入新原生逻辑。
- 命名空间是环境/API/账号的JSON分帧SHA256，快照中含scope校验但无token/明文账号标识。Android使用encryptedSharedPreferences，iOS使用unlocked_this_device，Web使用既有插件实现。跨实例同槽队列串行，失效旧实例的排队操作不再读写；已发出的旧槽写入即使完成，也不会落入其他账号槽位或越过后发写入。
- 首次`initialize`并行恢复与GET，不阻塞在线查询。缓存恢复只在尚未发布网络数据时生效；晚到缓存不能覆盖整页或独立准入刷新。恢复余额stale/流水ledgerStale均为true，`admissionBalance`为null，必须重新查服务端；不本地赠送、不加减余额。账号epoch变化重建整个状态和缓存归属，token正常刷新不改变槽位。
- 保留缓存页码与hasNext；离线缓存后下一页从真实下一页读取，按ledgerId去重，分页成功不会把旧余额标成最新。只有已存在完整account与ledger时保存；独立余额刷新不捏造流水。缓存不提供查询失败时的准入放行回退。
- 坏JSON/schema/错scope为未命中；读写失败不覆盖在线成功、不输出缓存正文或底层异常。单快照1MiB/5000行安全上限，超过则放弃整个新快照而非截断UI，保留已有快照供非最新展示。新命名空间不覆盖旧Android缓存；v65原数据导入仍属于升级任务。

### 验证

- 新增33项：controller13、codec10、安全存储7、正式provider1、320/430宽离线Widget2。覆盖重建恢复、独立余额/完整页面与慢缓存竞争、页码/去重、未知不当0、存储失败不改在线成功、跨环境/API/账号隔离、复制blob拒绝、队列顺序/失效跳过、关页晚到。
- 正式provider集成使用真实缓存类+合成安全存储，验证在线保存→容器销毁→同账号离线重建→切另一账号不显示旧数据；不是只测孤立模型。没有真实登录请求、积分写入或赠送。
- 全量 **1302项通过**；`flutter analyze --no-pub`无问题；579文件格式检查，OpenSpec19项；Web Debug和Android Debug构建通过。浏览器原登录→首页余额→积分→流水只读流程通过，未发新短信、激活POST或扣费。
- 本批没有iOS新构建、双端新安装或真实断网/进程重启设备验收；Mac保留解锁会话未动。页面与设计资源未变，沿用既有非最新提示，不宣称新的视觉校准通过。

### 集中人工验收补充

1. 在授权安装的测试包中联网进入积分并加载多页；退出进程、断网后重新进入，同账号仍显示上次余额/已加载流水且标非最新。无缓存的账号必须显示未知，不显示0或另一账号流水。
2. 断网时尝试需要准入的授权演练，旧缓存不得当有效余额放行；恢复网络刷新后以服务端当前余额与流水为准，历史缓存不能覆盖较新结果。
3. 在测试/正式环境、不同API上下文和账号之间切换验证隔离；iOS锁屏/重新解锁、Android存储临时不可用后，缓存失败不能阻断在线钱包，恢复后可再次保存。
4. 从分页快照恢复继续加载，确认请求正确下一页、旧行不重复；并发新回执刷新或克隆准入读取时余额不回退。真实计费、激活、克隆/翻译结算事件仍应另外核对后台权威事实。

OpenSpec仅勾选2.3a；2.3、双端实际设备和最终用户验收不提前完成。
