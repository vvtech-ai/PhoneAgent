## Context

三个禅道问题的客户端诊断具有相同的表象：`accountRequest` 多数为 HTTP 200，`agentStream`/`agentEvent` 仍有完成相关事件，部分附件出现 `finalResponse`、`batchCallResult` 或 `committed`，但当前会话或任务列表仍显示加载、未读或未完成；重新进入会话后历史结果可见。23678 还同时出现“任务完成”与“AI 思考中”的并存状态。220 test 日志进一步确认 23772、23773 在 `RUNNING -> INCOMPLETE` 中间投影后才提交最终批量结果；23678 对应服务端历史未命中。

当前 `ConversationCallController` 在物理终态后调用有界 `_sync`，`needsAgentOutcome()` 只覆盖部分终态组合；`ConversationOutcomeFlow` 依赖当前历史读取；任务列表刷新主要由 detached batch stream 的完成回调或显式 refresh 驱动，单路物理终态没有统一失效入口。已有 `conversation-error-status-sync` 负责异常退出补偿，本变更只扩展“挂断后结果事实仍需观察”的边界，不重做通用 SSE 事件分层。

约束包括：不修改只读迁移源，不改变后端协议，不把客户端 diagnostics 当后台证据；代码按 feature-first 和小批次拆分；新增行为需先更新 OpenSpec，再由后续 apply 阶段实施。

## Goals / Non-Goals

**Goals:**

- 把物理通话终态与业务结果事实解耦，覆盖异常挂断、网络异常、积分不足和多路结束。
- 让稍晚到达的结果在当前会话内可被合并，并解除思考中/加载状态。
- 让单路和多路结果到达后都能触发任务列表的幂等刷新或失效。
- 保留有界、可恢复的同步窗口和稳定诊断字段，便于 sessionId、taskId、callAttemptId 与后台日志对照。
- 用定向测试证明正常成功、业务失败、无结果超时、重复结果和旧事件覆盖等边界。

**Non-Goals:**

- 不把 SSE done、物理 hangup、音频中断或网络断开直接当作业务成功。
- 不修改后台服务、数据库、结果接口契约或积分扣费规则。
- 不自动重放用户需求、重复外呼、无限轮询或强制把 pending 状态提升为 RUNNING。
- 不在本变更中处理未明确环境/模块的后台日志查询；后台证据缺口作为验收前置条件记录。

## Decisions

### 本次批量待核对回执的展示仲裁

本地源码复核发现原多路后段 60 秒轮询可能形成较长原页空窗；不能据此认定 2026-10-21 dev 现场的终卡提交与客户端读取时序。现将前 12 次未决重读维持 5 秒，后段改为 10 秒，并以独立五分钟计时器限定整个自动观察窗口。截止到达时即使进度或账本请求仍 pending，也直接反馈未确认；迟到响应仍按批次/会话/代次校验。前台或原路由重新可见、收到设备网络 `available` 事件时，当前账号/会话只读补查；重复恢复合并进行中的同身份读取。网络平台事件共享同一个 EventChannel 上游订阅。VoiceHost 可能在订阅前错过 `unavailable`，因此不要求它先收到离线事件；只要当前路由和会话身份有效，收到 `available` 就请求一次有界只读恢复。网络可用只允许尝试读取，不代表 Agent 服务已可达。

单路在有界观察结束后保留原 call/attempt 与 command 身份，恢复时只读补查，不重新开启 32 次循环。已知 callId 的结果观察和无 callId 的命令账本观察分别具有独立五分钟截止时间，慢请求不能无限延长页面等待；读取异常记录脱敏原因并保留待确认状态。本次没有新增系统电话状态直接监听；来电未造成生命周期、路由或网络事件变化时，原页只能依赖既有有界结果观察，不能宣称电话状态本身触发了刷新。当前 dev APK 的厂商 AAR 虽声明 `READ_PHONE_STATE` 和接收器，任务页没有接入该回调；已连接测试手机上该运行时权限为 `granted=false`，所以不能把厂商接收器当作本机挂机补查的可靠入口。

已知 callId 且有物理闭合证据的旧观察到点后，客户端关闭本地状态轮询，保留旧目标供前台只读补查。若后端随后给出不同 tool 的新拨号确认，新卡按新身份呈现，用户再次明确确认并通过既有准入才提交；旧 callId 进入排除集合，防止新 observer 误绑。旧结果补查与新 observer 的当前身份分离，旧回包不能关闭新线路。无 callId 的旧确认或仅收到 call_finished 时仍缺物理闭合证明：新拨号工具不给出无法执行的确认卡，显示待核提示。call_finished 的内层结果即使带 callId/attemptId，若本地尚未绑定线路，也仅能凭当前确认 command 启动无注册账本读取；本地只知道 callId 而未知道 attemptId 时，已匹配 callId 的内层结果可启动现有线路只读补查，不能把未知 attemptId 强行与 callId 比较。事件本身不视为物理结束或业务结果。

单路确认后若 SSE 在注册 callId 前收到未知 502/503 握手失败，不能证明请求未执行。对没有可核验业务拒绝事实的 5xx 保留传输不确定性，仅按原确认 command 在当前会话有界读取账本：先立即读，再按既有 1.5 秒节奏最多读 32 次，并以独立五分钟墙钟时间截止；其他命令的终卡不能解除当前观察。已提交的同命令 `EXECUTION_ERROR` 原位展示终卡，到点仍未知则退出等待并保留原身份供前台或网络恢复补查，不自动重拨。无活动 call 的高频 `NOT_FOUND` trace 仅在 DEBUG 级别记录。

诊断采用现有 `PHONEAGENT_DIAGNOSTIC_LOG_LEVEL` 构建配置，默认 INFO，DEBUG 保留细粒度事件，WARN/ERROR 可进一步收窄。Agent 流握手记录 `DiagnosticEvent.statusCode` 的 0–599 受限整数及阶段/耗时，不记录响应正文、URL 或凭据；本地定向回归及静态检查已通过，但尚未进入并验证目标 dev 包。此前提供的旧诊断 ZIP 只见 502/500，未见 503；本轮没有可关联的 2026-10-21 dev 来电 session 或完整服务端时序，不能把旧 ZIP 或上述设计推断写成当前现场已证实。

账本中同 batchId 的 `ASSISTANT_TURN_COMMITTED` 若包含批量回执且各项不再是运行态，即使批次 `status=PENDING`，也由账本回执覆盖本地进度卡。`executionStatus=EXECUTION_ERROR` 只说明执行异常，不补造物理终态或结算。进度接口返回结果、历史同步命中结果、最终可见卡片分别记录结构化诊断，不记录正文、号码或凭据。

进度接口的 `batchCallResult` 来自同一已提交账本事实。若返回正数 `resultSequence`、精确匹配 batchId 且各项不再运行，即使独立的 timeline 同步暂时不可用，也可直接用这份已提交回执替换当前进度卡并结束等待；不接受仅有 `resultPresent` 标记、身份不匹配或仍在运行的回执。

若进度和历史在约五分钟的补偿窗口内都没有可见的已提交结果，客户端停止自动轮询，在原临时进度卡上显示明确的“结果尚未确认”提示，保留已知逐路事实；不得仅因本地待核状态变为 `UNCLEAR` 就绘制“执行结果／结果回传”的终卡区域。在当前页面保持批次身份和发送门禁，避免自动重拨或把缺失证据当成业务失败。重新进入会话时重新读取历史；仅当服务端仍报告活动批次时，恢复进度读取。

本机全屏来电等遮挡结束后，当前会话首次回到前台时重新触发同身份的只读核对；活跃批次使用现有进度及账本恢复器，已停止观察但仍显示本地临时进度卡时同步账本。恢复不调用会取消实时流的完整 `restore()`，不重发命令。进度快照中 `SDK_STATUS`、`PRIMARY_CLOSED`、`STOP_ACCEPTED`、`PHYSICAL_TERMINAL` 的同 attempt 事实可解除对应路的笼统待核，`ADMISSION` 和缺项仍待核；沿用现有版本仲裁。成功取得归属正确的进度快照后撤销旧连接中断顶部提示。批次正常完成仍只认同同批次已提交且非运行的回执；已提交的 `executionStatus=EXECUTION_ERROR` 执行终态按既有规则结束等待，即使某条逐路 `status` 仍为 `RUNNING`，未知事实继续待核。账本读取异常不能阻断已核验的进度回执应用。

### 1. 增加统一的终态结果观察编排

在现有会话终态编排和 `ConversationOutcomeFlow` 之间引入职责单一的结果观察策略（名称和文件在 apply 阶段按现有边界确定），输入为 session/task/callAttempt 身份、物理终态和当前结果快照，输出为 `pending`、`business-success`、`business-failure` 或 `unconfirmed`。它复用现有历史/timeline/result 读取，不新增网络协议。

`needsAgentOutcome()` 继续表达已有正常 Agent outcome 语义；新的观察策略负责补充“物理终态已发生但结果可能稍后落库”的窗口，避免把所有 `ENDED`/`FAILED` 无条件当成成功或失败。

### 2. 以身份和 generation 做幂等与旧事件隔离

每次同步都携带稳定的 sessionId，并在多路场景附带 taskId/callAttemptId（如果现有模型已有该字段则直接复用）。结果合并前校验当前 generation；已经确认的结果拒绝旧 generation 的 hangup、transport failure 或错误提示覆盖。重复 `finalResponse`/`batchCallResult` 只产生一次业务结果和一次列表刷新信号。

### 3. 有界重试改为“可恢复退出”，不做无限轮询

保留现有次数/时间上限模型，但将达到上限后的状态从静默停止改为显式 `unconfirmed`/待同步事实：页面停止无限 loading，允许重新进入或网络恢复继续同一身份的读取。每轮重试使用现有节流和 generation 取消机制；账号切换或会话销毁时取消旧观察者。

### 4. 结果合并与任务列表失效采用固定顺序

顺序固定为：读取并判定结果 → 合并会话消息/回执 → 关闭当前 loading/思考状态 → 发出幂等的任务列表 invalidate/refresh。单路终态和 detached batch stream 都调用同一个轻量刷新入口，避免只覆盖批量回执路径。刷新失败不抹掉已确认的会话结果。

### 5. 明确失败事实的映射边界

只有历史/timeline/result 读取中出现的结构化业务失败、积分不足或网络失败事实才能进入 `business-failure`；本地 transport 异常只进入 `pending` 或 `unconfirmed`，除非现有服务已返回明确的失败结果。这样可以保留用户可见的失败提示，同时不把“没有收到结果”误报成后台业务结论。

当同一 attempt 的服务端结果 `status=EXECUTION_ERROR` 已提交，单路结果组件以执行异常终态展示标题与状态；简短的公开业务说明可见，内部诊断与技术码不进入任务卡。它结束任务等待，但不推导物理通话或业务成功。只有缺少服务端结果事实时才使用“结果未确认”的同步提示。

拨号启动即异常时，`callResult` 可能没有 `callAttemptId` 或 `callId`；实时 `task_failed` 仍按当前 command 渲染终卡，历史 `ASSISTANT_TURN_COMMITTED` 以事件身份稳定投影，同一 command 的实时与账本副本只展示一张卡。已到达结果时清除该通话旧的临时警示。`billingSummary` 未到 `SETTLED` / `RELEASED` 时只显示“待核对”，不将部分回包中的数字 0 当作已确认零扣费。

同 attempt 已有物理 `CALL_*` 事实、却缺少 `CALL_OUTCOME_REPORTED` 时，已提交的 `ASSISTANT_TURN_COMMITTED.callResult` 只有携带可信业务结论才能成为终卡；当前单路观察以明确的 `agentOutcome` 或已提交明确的 `status=UNCLEAR`／`EXECUTION_ERROR` 为准。`resultCode` 可补充已确认结果的原因或类型，单独不能解除等待。仅有 `status=COMPLETED` 且无可信报告和明确 `agentOutcome` 时，即使 Assistant turn 已提交，仍保留结果观察和中间等待反馈；不能借 `COMPLETED` 或单独的 `resultCode` 推断绿色完成，也不能画黄色结果卡。有可信结论时的状态优先级为执行异常、已报告语义结果、已提交可信终态、物理状态。投影沿用物理 callId、字幕和已确认账务，且无本地 callId 的观察只接受本确认 command 的持久结果。若 reported 与 committed 并存，reported 保留语义 outcome，不能把同 sessionId、callAttemptId 的 committed `headline`、`detail`、`resultCode`、`fields` 和已确认账务整体遮蔽；已显示终卡在原位补全。V70 物理事件、Agent 语义报告与最终 Assistant 提交分别生成自己的 `commandId`，合并时不要求三个事件的 `commandId` 相等；当前命令观察的结束标记仍核对 committed 自身的 commandId。不同 session 或 attempt 的提交结果不能污染当前卡。后端源码支持这些事实组合，但本次 dev 来电缺少对应账本，不能将其定为现场根因。

单路 `UNCLEAR` 描述已报告的业务结论尚不明确，不能被结果组件解释为“客户端仍在确认中”。只要同身份的 `CALL_OUTCOME_REPORTED.outcome=UNCLEAR` 或非运行最终 `callResult.status=UNCLEAR`／`metadata.agentOutcome=UNCLEAR` 已可信到达，便按既有任务类型显示已结束终卡：任务型标题“任务未完成”、普通电话标题“通话未完成”，状态均为“未完成”。已有报告先显示终卡，随后同 sessionId、callAttemptId 的提交结果在原位补齐业务字段、简短业务说明与已确认账务；观察器也按同一终态准入结束读取。任务卡可显示简短的 `headline` 或业务原因字段，不直接展开长篇 `agentReason`／`resultReason`、技术码或诊断正文；原结果供状态判定与内部诊断，通话转写和账务不受此展示规则影响。

仅有 `CALL_*` 物理完成或 `call_finished`、尚无可信业务报告时，参照 v66.0.3 在通话文字后显示独立的黄色“正在确认通话结果”小提示，不投出整张黄色“结果确认中／结果未确认”回执卡，也不重复显示思考卡。结果观察仍按原身份有界读取；截止仍无可信结果时改为“通话已结束，结果待核实”，后续同身份结果到达再原位替换为终卡。物理回执的 `resultCode` 单独不能推断语义终态，不把业务未知改写为成功、未拨出或已结算。这里的小提示只使用客户端展示文案，不新增后台中间状态码。

禅道 #23809 是上述规则的 220 test 单路订餐样本：`CALL_OUTCOME_REPORTED` 报告 `UNCLEAR` 后任务投影为 `INCOMPLETE`，`ASSISTANT_TURN_COMMITTED.callResult.status=UNCLEAR` 随后落账，客户端已读到该提交序号。现场持久结果没有 `sceneType`／`resultCode`，有订餐字段，`callResult.detail` 是通话转写，长语义原因在 `metadata.agentReason`。订餐未获明确确认的终卡显示“任务未完成／未完成”，保留简短业务说明；长原因与物理诊断仅供内部核查，也不推断短信已发送。v66.0.3 的结构化任务卡只显示业务字段和状态，不自动展示 `metadata.agentReason`；其旧配色不作为本次依据。

投影物理 `CALL_COMPLETED`、尚无业务报告或已提交结果时，过滤工具结果 metadata 中的临时 outcome，防止物理结束被工具草稿误认成语义结果；原始 metadata 传入的 `_ledgerOutcomeSource` 也不作为账本来源。结果 overlay 在同一通话已提交 SUCCESS／FAILED 缺少字段或账务时，可以补入实时同通话已有值；迟到的实时 `UNCLEAR` 不覆盖已提交的结论、原因与字段。已报告 `UNCLEAR` 遇到不同 billingSession 的待结算账单时，保留物理事件中已结算的账务事实。已提交 `status=UNCLEAR` 的现有红色未完成卡语义保持不变。

批次 journal 与账本都不可读时，服务端可能提交 `executionStatus=EXECUTION_ERROR`、空 `items` 且无 `batchId` 的汇总回执。当前 command 的结果事件可结束本轮等待并展示“执行异常”及公开说明；历史以 command / 事件身份恢复。空项卡不显示逐路数量、成功数或扣费。普通无身份或无结果标记的回执仍不能替换进度卡。此规则不放宽需要同 batchId 与正数序号的独立进度快照校验。

### 6. 诊断字段只记录关联信息

在现有 diagnostics 事件中增加同步阶段、尝试序号、终态分类、结果判定和结束原因；只记录稳定 ID 与枚举，不记录通话内容、用户文本、token 或账号敏感字段。字段名称与现有 diagnostics schema 对齐，后续通过真实后台环境的 trace/session 规则做关联。

### 7. 后台日志证据采用先定位后查询

已确认环境为 220 test，按结果/SSE、任务历史/积分和通话运行态服务读取日志；23772、23773 的“结果写入→SSE/回执→客户端读取”顺序已回读。23678 未取得对应回包，因此保留 `unconfirmed` 分支，不修改后端契约。

## Risks / Trade-offs

- 观察窗口变长可能增加少量历史读取 -> 保留统一上限、指数/固定退避和 generation 取消；仅在物理终态且结果未确认时触发。
- 任务列表刷新可能与已有批量刷新重复 -> 使用 session/task 级去重信号和单飞刷新，不改变列表接口。
- 后台明确失败与客户端 transport 失败边界不一致 -> 只接受结构化结果事实，未确认状态保留可恢复入口并记录证据缺口。
- 旧页面已有 loading 文案依赖特定状态码 -> 先以状态投影测试覆盖，再逐页调整展示；不在本变更中重写视觉层。
- 多路任务中部分 callAttempt 结果缺失 -> 按 attempt 聚合，批量终态只有在现有协议明确允许时才结束；否则显示可解释的未确认状态。

## Migration Plan

1. 先在后续 apply 中实现纯策略、结果分类和定向测试，不改平台与后端。
2. 接入单路会话终态、历史结果读取和任务列表 invalidate，再接入 detached batch stream，分批验证每个入口。
3. 增加 diagnostics 关联字段，使用脱敏的本地演练和已授权的真实测试日志核对时序。
4. 若出现回归，关闭新终态观察入口并回退到现有有界 `_sync`；不需要数据迁移，已确认的历史结果保持不变。

## Open Questions

- 23678 对应的 220 历史日志何时可回收？当前仍缺少该问题的服务端回包。
- 后台对于积分不足、网络失败和异常挂断分别返回哪些结构化状态/错误码？23772、23773 已证明结果落库可能晚于 SSE done，积分不足错误码仍待确认。
- 多路任务的批量结果在部分 attempt 缺失时，后台认定的最终状态和可重试条件是什么？
- 产品是否要求“未确认”状态展示重试入口，还是仅允许重新进入会话触发恢复读取？
