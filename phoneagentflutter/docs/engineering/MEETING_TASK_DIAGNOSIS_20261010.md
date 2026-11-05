# 大型会议任务客户端修复与后端确认项

日期：2026-10-10。仅修改 Flutter；Java、部署及数据库保持只读。环境为 `https://chakenai-dev.vvtech.tech`，开发包 `com.vvtech.aiassistant.dev`，版本 1.0.51（45）。

## 证据范围

- 手机当前开发包进程与前台确认；没有发送任务、确认外呼、手动上传诊断或清除数据。本次手机 logcat 未取得评分 HTTP 响应；Flutter attach 未连接到 VM，已结束诊断 CLI，手机进程保持运行。
- 220 开发 Agent/SDK 日志只读，会议定位别名为 session SHA-256 前八位 `212f7093`，batch 别名 `c5390981`；原始日志和真实标识仅在 ignored `.local/meeting-audit/`，不提交真实会议、联系人、号码、凭据。
- 使用已获授权的根目录开发数据库配置，只读查询成功，并以日志中会议 session 精确匹配账本；只执行 SELECT，没有迁移、补数据或调用评分写入。
- 重新 fetch：Android `origin/v71` 为 `6309bc55`；Java `origin/v71` 为 `8ebd7db4`。Java 本地 HEAD `52271933` 与远端不同，22 项既有未提交改动未动；下述 outbox 身份/技能查找在两份源码中一致，不把本地 HEAD 当作部署版本。旧 Android `origin/test/v66.0.3` 为 `a0bedb12`，旧工作区只读。

## 客户端问题和修复

### 补充会议信息在结果后重复

账本该轮只保存一条 askUser 的 TOOL_REQUESTED。实时 questions.items 包含内部 id；Java `TimelineApiMapper.copyAskUserArguments` 返回历史 questionsJson 时只保留 prompt。Flutter `ConversationQuestions.parse` 要求 id，脱敏历史只能成为普通文案。原合并逻辑又要求历史 questions 对象非空，导致同一文案的实时与历史消息并存。

修复 `ConversationMessageMerge`：同 commandId、toolCallId 且文案相同的脱敏历史取代实时问题；不伪造问题 id、不增加表单、不删除其他轮次提问，不改账本或播报。回归使用合成问题及真实契约形状，不使用真实会议 fixtures。

### 确认阶段只有提示，完成后才看到卡片

15:17:27.909 账本已保存 confirmBatchTask 快照，15:17:28 实时 ask_user 发出固定确认提示；当前兼容事件没有直接携带快照。原 Flutter 直到批量结果后同步 timeline，因此卡片迟到。

`ConversationSignalFlow` 收到该批量确认提示时通过现有 history/timeline Repository 同步，按原 pendingToolCallId 展示结构化卡和原文案；有卡则不重复请求。失败进入已有 recoveryRequired 并允许历史重试，SSE done 不清掉失败；账号/代际已变则忽略迟到响应。同步不会执行、确认或重放外呼。

Android v71 对照：`AgentStreamSseEventParser.kt`、`LargeTaskTimelineProjection.kt`、`AgentStreamTimelineCommittedHandler.kt`，均沿用工具身份和统一账本。UI 保持 v66.0.3 既有卡片与自然语言回答。

### 通话收尾及精简提示

首页隐藏顶部任务提示和任务 Tab 数量，保留共享任务数据与已读同步。成功手动停止不加成功文案；请求失败和部分挂断失败保留重试。单路读取本次通话 awaitingOutcome；多路读取发送期间临时进度全部结束条件，复用原思考卡显示“正在整理通话结果”。最终结果到达清除；历史列表恢复不显示临时等待卡，不建立第二套任务状态机。

## 评分缺失：交给后端确认

**已证实会议 batch 与 outbox 的关联缺失；根据当前 v71 评分源码，该缺失会导致技能无法解析并返回无资格。本次手机评分接口的实际 HTTP 响应尚未取得，不能排除另有请求失败。** 客户端不强制显示无资格卡，不用 sessionId 替换 batchId。

只读事实：

| 检查 | 实际结果 |
| --- | --- |
| ACTIVE 评分策略 | new_eligibility_enabled=1，emergency_stopped=0，sample_percentage=100 |
| 技能及版本 | meeting_notification_v2 已启用，minimum_client_version=1.0.45，安装包为1.0.51 |
| 频控 | daily_limit=50、rolling_seven_day_limit=100；该账户今日/七日资格数均1 |
| 会议会话技能 | pinnedSkillId、activeSkillId 均为 meeting_notification_v2 |
| 最终账本 | TOOL_RESULT_RECORDED 15:19:11.211、ASSISTANT_TURN_COMMITTED 15:19:11.245 均有匹配 batchCallResult |
| 该 batch 的 assistant_call_record | 2条，call_state=ENDED，账户匹配 |
| 该 batch 的 call_command_outbox | 0条（同账户、deleted=0） |
| agent-session 对应评分资格 | 0条 |

Java `TaskRatingEligibilityServiceImpl.batch` 用原 batchId 查询通话，再 `resolveIdentity(accountId, batchId)`；`TaskRatingOutboxReadMapper.selectLatestByTaskIdAndAccountId` 查不到后回退 `source-task:<batchId>`、sessionId=null。随后 `resolveSkill` 把 batchId 当作会话查找，仍缺 outbox 关联，返回 null，早于100%抽样判断退出。请后端核对批量调度写入的 task_id 是否是子任务 ID，及 batchId→session 的可靠关联来源；不要未经确认直接补库。

客户端接口保持独立 App 契约：SDK `GET /aiassistant-sdk-api/api/task-ratings/batches/{batchId}?clientVersion=1.0.51`（单路为 calls/{callId}）。仅 eligible=true，且 eligibilityId、taskType/taskId、receiptAnchorType/receiptAnchorId 完整匹配时显示可提交评分。编排和 timeline 使用 Agent `/aiassistant-api/`；未修改网络基础层。

后端建议核验：以当前会议原始 batchId/accountId 在受控环境查询上述 GET，记录脱敏 HTTP 状态、eligible、anchor、资格 ID 是否存在；记录身份解析失败原因和实际部署 SHA。再验证批次关联修复后评分资格生成、单路/多路去重及重复打开，不向手机暴露内部异常。

另有时序：task_completed 日志在15:19:11.202，最终账本稍后提交。客户端初次资格查询可能早于终态可见；本次未取得请求时间，尚不能证明竞态发生。后端确认关联后若仍复现，再核对该时序，不把推测写成已修复。

## 验证与交付

固定 Flutter 3.32.0：analyze 无问题，OpenSpec 67项通过。确认卡同步/失败保持/账号迟到、脱敏补问去重、首页隐藏、停止静默、单路与批量等待反馈及现有回执/评分/历史入口定向回归继续记录下方交付结果。双平台 Widget 测试不等于 iOS 原生或真实电话验证。

没有新增真实电话验证、后台/媒体/生产升级或 iOS/macOS 构建证据；不归档当前变更。

交付结果：固定3.32最终analyze 11.9秒无问题；受影响对话/通话/反馈/通知/首页/任务和确认回执Shell共1301项、跨页与架构20项通过，OpenSpec67通过。首次扩大回归因新增测试自身StreamController.close等待而中断；改为模拟协议done并复验，最终完整集合通过，不把中断轮次累计。Android开发包33.1秒构建成功，APK SHA-256为84E7C28D1048998B03597DD5227A2447F1AE35E55D6C2B029FED65F1C876DEF3。16:27:08覆盖安装成功，firstInstallTime保持12:36:18，未卸载或清数据。构建采用已批准云端三服务前缀与完整私有C1配置，正常main入口且迁移预览关闭；APK备份仅在ignored运行目录。提交只覆盖本批需求文件，目标codex/refactor-conversation-task-flow，origin/codex/dev保留9a8d4e64；不归档，真实外呼、媒体、后台、生产升级及iOS原生验收仍待完成。