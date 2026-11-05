# 2026-10-20 test 批量外呼结果停留在进度卡

## 现场证据

- 身份：`sessionId=09044497c7e80b41f7eada4ef104e0f2`，`batchId=batch-29488143b5d037e480c989dda1ea8d2e`，杨光对应第 5 路 `callAttemptId=06d53735-98f8-3c15-b762-2900d67e680d`。截图是客户端显示证据，无法单独确定截图生成时刻。
- `aiassistant-telephony-host/info.log`：第 1 路 `c2b7c25a-1a62-36ea-9451-748ec08a2433` 于 10:19:27.974 收到 SIP 200、10:19:30.081 发本端 BYE；10:19:32.758 媒体摘要 `attached=false / receivedRtp=0`。`aiassistant-agent-sse/info.log` 10:22:22.073 仍为 `physicalState=ENDING / billingState=ACTIVE`，等待 208579ms 后 `TOTAL_TIMEOUT`。这些事实不能证明 10:19:17.568 `RENEW_CONTROL_LEASE` 503 的具体 Phone 分支。
- `aiassistant-agent-sse/info.log` 10:22:26.951 因第 1 路 `PHYSICAL_BILLING / required_terminal_fields_missing` 拒绝正常最终确认，随后记录 `BATCH_FINALIZATION_FAILED`。10:22:27.045 会话任务从 `RUNNING` 投影为 `INCOMPLETE`；10:22:27.117 写入 `ASSISTANT_TURN_COMMITTED`，序号 27。运行提交 `8c07f119` 的 `BatchCallResultFinalizer.executionError` 保留预备结果的 `PENDING` 状态并设置 `executionStatus=EXECUTION_ERROR`。
- 10:23:16.132 的 `BATCH_SNAPSHOT_READ` 返回 `resultSequence=27 / resultPresent=true`；10:23:16.287 `TIMELINE_SYNC` 从 25 同步两条至 27，`eventCount=2 / result=success`。10:24:08 和 10:30:33 的 timeline 读取也从 0 到 27。运行提交 `8c07f119` 的 `BatchCallProgressSnapshotService.Snapshot` 含 `batchCallResult` 和 `resultSequence`，Controller 用 `ApiResponse.success(snapshot)` 返回；这证明服务端处理路径已构造含回执的快照，但没有当时网络响应体的直接留存。
- 服务端 10:23:15.807、10:23:16.202、10:23:16.268 依次记录本会话的进度、会话、timeline 三个 GET 验签；客户端诊断在 10:23:16.354/.436/.497 记录三个 `accountRequest` HTTP 200，耗时分别为 445/74/58 ms。所查到的 16 次服务端进度读取均落在至少一条客户端请求的记录区间内，通常在临近的客户端请求完成前约 200 ms。顺序和时间形成较强关联，支持“此客户端很可能发起并完成了进度读取”的推断；服务器和 ZIP 都没有共同请求 ID、设备标识或响应摘要，不能严格一一对应，也不能证明客户端解析或显示了回执。
- 原始 `phoneagent-diagnostics-1792463017661.zip` 仅含 `diagnostics.jsonl`（301 条）。原文时间戳为带小数秒的 UTC；上述客户端时间按 +08:00 换算。包内没有本次 sessionId、callAttemptId、batchId，也没有 URL/路径、响应体或页面可见状态字段。`agentStream` 于 10:19:56.739 失败，最后一条 `agentEvent` 为 10:19:51.857，此后直到 ZIP 结束（10:23:36.725）都没有新的 `agentEvent`；最终回执不能由这份诊断证明已通过流事件交给页面。
- 当前客户端 `ConversationMessageMerge` 使用 `ReceiptOverlay.promote` 仲裁账本与本地进度卡。修前 `_terminal('PENDING')` 为 false，旧 `:batch-progress` 卡可覆盖同 batchId 的已提交回执；合成回放在修前得到空的 `executionStatus`，修后得到 `EXECUTION_ERROR` 且显示 5/5 待核对。本段是源码与合成回放证据，真机同故障复测仍待执行。
- 进度接口的 `batchCallResult` 来源是已提交的同批次账本事件；此前客户端只保留 `hasResult/resultSequence`，丢弃回执正文。新增回归以“进度接口有序号 27 和同批次回执，独立历史同步不可用”复现：修前等待 1 秒超时，修后当前卡直接显示 `EXECUTION_ERROR`、5/5 待核对并退出等待。回执身份不匹配时拒绝解析。此项仍是本地回放，不能替代旧现场的接口响应体或真机复测。
- 第 5 路主动挂断的独立证据：Phone 于 10:20:48.392 记录媒体接入，10:21:47.949 媒体摘要 `attached=true / receivedRtp=2932 / sentRtp=1753`。10:21:47.942 的 `PHONE_STOP_ORIGIN` 为 `AUTH_CAP_REACHED`，10:21:48.057 发本端 SIP BYE、10:21:48.066 收到 SIP 200，10:21:50.614 的 ended 事件 `delivered=true`。运行代码在已连接时按 `elapsedMs >= currentCap` 触发此原因；现有日志没有该次授权上限数值或未延长原因，不能进一步归因。此链节与第 1 路阻塞整批最终确认不同。

上述远端日志通过 `read_call_logs.py --environment test --action logs` 只读获取；SDK 该 attempt 的当前尾部无命中，补查最近归档命中。服务器回执为 `CST/+08:00`、`__REMOTE_EXIT__=0`。日志编号来自读取窗口，不作为原文件绝对行号。

## 版本与修改

- Flutter 开始排查时本地 `codex/dev` 与 `origin/codex/dev` 均为 `e4d524997b776b67a27835990a6d8f612fab66e4`；2026-10-20 再次 `git fetch origin codex/dev` 后远端仍为 `e4d52499`，本地 `9b120f9a` 包含远端且领先两笔（道歉音色 `d731f04b`、确认提问及评分入口 `9b120f9a`）。本次修复仍为未提交工作树改动。test 后端正在运行 Jenkins `phoneagent-backend #336` 的 `8c07f11959821549925b5be2787c53733ba8f2a3`；远端测试分支已到 `096ee527d570d2b9993f09376a8b755562a28bca`，差异为 iOS OTA 事务修复，当前运行版本不能称作远端最新。
- 客户端让同批次已提交的非运行回执优先于旧进度卡。结果仍缺失时，恢复读取约五分钟后停止轮询并显示“结果尚未确认”，保留当前页面批次身份和发送门禁；不重拨、不补造成功或结算。
- 客户端诊断新增 `batchResultSync`：`progressFetch` 记录进度请求开始、API 解包后的结果存在、序号、执行态、耗时，以及失败类别；`progressRead` 记录完成解析的快照；`historyRead` 记录独立同步；`visibleResult` 在快照应用后和解除等待后分别记录可见回执、计数与 `pageWaiting`。实际 provider 已接入诊断日志。只允许固定枚举、标识和数字，不保存号码、正文、URL 查询参数或凭据。新事件需安装新版本后才会出现在诊断包中，不能回填到本次旧 ZIP。
- 禅道 #23793 的重拨积分拒绝属于另一 test 会话，但与本次批次卡失真共享进度与结果合并链。客户端在第二次准入失败且没有物理拨号证据时，撤销“已重拨”临时计数，保留“重拨未发起”提示；其后端逐路隔离及快照修复见 `D:/aiProject/aiassistant-java/openspec/changes/isolate-batch-retry-admission-failure/verification.md`。不把两次现场通话的挂断原因混同。
- 最新后端测试分支另在 Phone 续期命令 503 分支增加固定原因码日志，见 `D:/aiProject/aiassistant-java/openspec/changes/repair-phone-closure-ack-race/verification.md`；尚未部署，不用于追认旧现场。

## 验证

- 回归先红后绿：`receipt_overlay_test.dart` 在修前报期望 `EXECUTION_ERROR`、实际为空；修后通过。
- 定向测试：`receipt_overlay_test.dart`、`batch_progress_recovery_test.dart`、`task_160_stop_test.dart`、`task_160_pending_batch_failure_test.dart`、`conversation_result_read_host_test.dart`、`batch_receipt_widget_test.dart`、`task_parity_api_test.dart`、`native_business_recovery_test.dart`，36 项通过，包含真实回执组件的 5/5、执行结果与待核对标题渲染。
- 诊断补强另验证 `batch_progress_recovery_test.dart`、`task_160_stop_test.dart`、`task_parity_api_test.dart` 共 18 项通过。新增测试在接线前分别因缺少诊断注入、日志未写入 journal、历史同步未返回前缺少页面状态而失败；修后验证序号 27 的脱敏摘要、身份不匹配的格式失败，以及 `pageWaiting=true -> false`。这是本地测试，不是旧现场日志。
- #23793 关联回归 `batch_progress_tracker_test.dart` 修前把被拒的第二次尝试计作 2 次，修后为 1 次；另一个回归修前允许零版本准入快照覆盖同次已收物理进度，修后保留较强状态。该文件与 `batch_progress_recovery_test.dart` 共 21 项通过，`flutter analyze --no-pub` 无问题。后端 SSE 相关 10 项通过。均为本地验证，未做 test 真实外呼。
- `flutter analyze`：无问题。`openspec validate repair-hangup-result-synchronization --type change`：有效。`openspec validate --all`：213 项通过、3 项其他既有 change 失败。
- 未构建/安装测试包，未做真机同故障回归，也未更改 test 服务或数据库。

## 2026-10-20 远端分支复核

- 本轮重新 `git fetch origin codex/dev` 后，远端推进到 `0b61e228`；当前本地 `codex/dev` 为 `a17ca247`，两者从 `e4d52499` 分叉。远端新增提交涉及 `conversation_presentation_projection.dart`，该文件在当前通话修复工作区也有未提交修改，因此本地测试不能证明修复已与最新远端客户端代码集成。未覆盖或移动现有工作区改动。
