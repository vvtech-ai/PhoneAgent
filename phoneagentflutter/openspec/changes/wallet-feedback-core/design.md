## Context

固定 v65 PointsWalletApi/Repository/Coordinator、AgentCallEvaluationApi/Repository/ViewModel、TaskRatingApi/Repository/ViewModel/Contract 为证据。原始数据与可见状态分离，两个评价协议不互相替代。

## Decisions

### 会话激活、前台同步与克隆余额（2026-09-18）

固定v65 PointsSessionActivationCoordinator / PointsWalletForegroundSyncEffect / LoginGrantToastPolicy：新短信登录已由后端激活，标记本进程账号已激活并展示响应中的 INITIAL_GRANT / DAILY_LOGIN_GRANT；恢复登录调用 POST api/points/session-activations，成功后同一环境/API/账号本进程不重复调用。失败不标成功，前台每30秒及再次进入前台重试；后台停止定时，不重新发短信。赠送金额/日期均来自后端，不推导每日赠送或本地跨日发放。

Flutter共用会话控制器、激活去重器与生命周期Host；正式provider跟随登录epoch销毁，token刷新不重建。激活/登录完整walletSummary进入共享钱包并标记流水待同步，再GET余额/流水；较旧GET、缓存、旧账号晚到不能覆盖。新登录缺少points仍标已激活，不伪造摘要。识别的赠送提示只消费一次，不持久化或因页面重建重放。现阶段无网络状态插件，断网失败保留缓存，前台30秒/恢复前台重试；不以失败推断余额为零，无紧密重试。

克隆准备和流程准入改为共享钱包refreshBalance；候选服务端billing变更、确认成功/结果只读同步触发WalletSettlementSync只读刷新，不直接使用候选历史remainingPoints或扣300。沿用同一账号生命周期与摘要去重。

手写微批（各最多3文件）：1）activation domain / API / account mapper；2）session controller / activation coordinator / wallet controller；3）session provider / lifecycle host / AuthRoute；4）clone services / controller / provider；5）分组协议、并发、provider和组件测试。随后更新本tasks、根tasks和验收记录。无新插件/原生/后端数据库/日志字段/提示词/SIP/ASR/TTS；当前真实浏览器不热重启触发激活，使用合成装配验证，真实赠送/克隆留人工清单。

### 钱包持久快照（2026-09-18）

固定v65 SharedPreferencesPointsWalletCache与PointsWalletCoordinator：账号切换可先呈现上次完整account+ledger，完整刷新、翻页、权威余额更新后保存；缓存是离线展示，不改变服务端计费权威。本项目使用既有flutter_secure_storage（Android encryptedSharedPreferences / iOS unlocked_this_device）薄存储，Dart共用版本化codec、环境/API/账号SHA256命名空间和跨实例串行队列，不另建原生存储系统。

新增domain/points_wallet_cache.dart、data/secure_points_wallet_cache.dart；控制器可选cache保持现有纯测试兼容，initialize并行恢复与GET，所有网络发布递增快照代次；晚到缓存不覆盖任何已成功网络状态。恢复同时标记余额stale和ledgerStale，准入admissionBalance为null；保留当前页与hasNext，下一页按正确页码读取并去重，不用分页成功把旧余额标最新。成功只读account更新和已有流水一起写快照，仍不造流水。

只保存完整已有account+ledger快照；写入非阻塞且失败不改变在线成功，读取失败/坏schema/错scope为缓存未命中。编码长度最多1MiB、最多5000流水项，超限跳过整个快照而非静默截断页面；界面与在线分页不受该缓存安全上限约束。缓存不含token，正文不进入日志。每次读写及排队操作检查当前登录归属；失效旧实例不能在新账号槽位读写，新实例写入不被旧队列覆盖。

微批：快照模型/安全存储/codec；controller/provider/测试；持久化与正式装配回归/记录。复用当前钱包与流水页、非最新文案，无新页面/设计或权限。新增缓存测试、完整test/analyze/OpenSpec、Web与Android构建；合成存储与账号使用同一正式装配验证，无真实短信/赠送/扣费/设备安装。激活赠送与克隆/翻译结算保留2.3待办，不能用缓存完成代替整项完成。

### 单路和批量计费回执同步（2026-09-17）

依据v65 AssistantPointsWalletSettlementEffect从单路billingSummary和批量items.billingSummaries采集。新增纯Dart WalletSettlementSync及ConversationBillingSignals，provider装配监听正式ConversationController状态，按账号生命周期共用同步器。billingSessionId与摘要版本（状态/计费数值）去重，顺序/重复消息不触发额外查询；一轮微任务合并事件，查询进行中新摘要只排一次尾随刷新。仅调用现有钱包只读refresh，不从历史remainingPoints覆盖当前余额，避免恢复旧任务回退余额。无计费ID不推测发生扣费，不按duration重算。失败不循环重试，保留钱包错误/重试入口，新信号可触发新查询；销毁清理待办，账号epoch替换不共享去重集。克隆/翻译事件接入、持久缓存和激活赠送仍另行完成。

### 准入余额与钱包权威同步（2026-09-17）

固定v65 TaskCallPointsAuthoritativeBalanceRefresher将account查询余额发布给PointsWalletCoordinator。本批保留普通整页account+ledger成对替换规则，同时新增独立refreshBalance通道，成功仅更新服务端完整account，并标记ledgerStale；流水尚未同步不可冒称最新。PointsWalletController成为准入/首页/积分页共用的内存状态源，合并同一时刻account请求；独立刷新版本号保护，旧整页成功/失败不得覆盖较新余额或把其错误标成过期。明确分开余额stale和ledgerStale；失败保留最后已知数字供显示，但准入读数未知，继续由后端原子判断。签出/账号变化错误不当作普通未知放行，dispose晚到不写新账号。API和原生无变化，不增加本地加减余额。持久缓存、激活与结算事件另行实现，2.3保持未完成。

- 钱包未知为null；account+首屏ledger一起成功才替换快照。流水过滤delta=0，分页参数0起/size20；失败保留并标记stale，dispose晚到不写；不按本地时长算扣费。
- AccountApi的points/task-ratings路径使用Bearer刷新，agent-calls/evaluation遵守原有账号头；ID只允许安全单路径段，外部URL不入网关。
- 评价GOOD/BAD使用PUT；返回modelName决定是否可展示；latency仅格式化有效非负值。条件评分只有eligible和稳定ID/锚点都有效才可见。
- 评分提交保留idempotencyKey参数，不隐式重试/生成随机新key；1–5分、300 Unicode码点建议、不评价克隆与评分互斥。提交成功必须有currentSubmission，不本地加奖励积分。
- 初始协议批次不挂载回执UI；2026-09-17页面增量已补UI、评分草稿持久化/卡片owner/奖励提示。真实激活赠送、结算与钱包缓存仍待接入，不宣称完整积分模块。

## Validation

### 页面接入批次（2026-09-17）

用户已批准静态 HTML/CSS 与现有组件优先，视觉后校准。首页接入可用余额徽标，打开积分页，再进入独立流水页；复用现有 PointsWalletController 和账号 API，普通页面只读。原型 monetization.js 中会员/积分购买/订单/发票不是 v65 有效功能，全部排除。余额数字沿 v65 千分位及负数显示保护，预计通话分钟仅按基准100积分/分钟展示，不参与真实计费；未知余额显示“--”，失败旧快照标记未同步。

新增 app/points_providers.dart、points/presentation/pages/points_wallet_route.dart、points_wallet_page.dart、widgets/points_balance_badge.dart；首页与 ShellRoute 仅传状态/事件，前台和返回钱包刷新。回执评价接入独立 feedback route/controller，不把网络和保存状态放进消息控件。已有模型/登录/联系人逻辑不改变；每批最多3个文件，手写默认500行。

### 条件评分接入

固定 v65 TaskRatingViewModel/Sheet/Route/DraftStore：独立资格 GET 决定入口；多维1–5分无默认答案，克隆维度依资格显示且可“不评价”，建议最多300 Unicode码点；保存中禁止关闭或再次提交，成功后只读。草稿按环境/API/账号/taskType/taskId隔离并串行持久化；提交前持久化幂等键，原稿重试复用，编辑后重置。服务端提交优先于本地草稿；奖励仅按服务端字段显示并触发钱包只读刷新，不本地加余额。重复回执共用控制器并由一个挂载实例持有入口。客户端版本使用当前Flutter版本，不伪装v65以绕过后端门禁。对话/钱包/评分均Flutter共用，无数据库结构、后端接口、提示词、SIP/ASR/TTS修改；合成仓库验证完整交互，真实评价留集中人工验收。

合成HTTP验证路径/方法/鉴权/字段、错误锚点隐藏、缺失提交响应失败；钱包分页/并发/失败/未知/晚到；评分范围/Unicode/幂等键。全量test/analyze/OpenSpec，无真实写入。
