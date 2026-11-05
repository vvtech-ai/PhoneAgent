# 通话异常终态结果同步修复

## 需求来源

禅道问题 23772、23773、23678。客户端诊断和 220 test 服务器日志显示：物理通话结束、网络异常或异常挂断后，后台结果可能稍晚于 `INCOMPLETE` 中间投影提交；客户端已收到 `finalResponse`、`batchCallResult` 或 `committed`，但当前会话仍显示加载/思考中，重新进入后才看到结果。

## 已确认事实

- 23772 sessionId：`c7d808a316533029244458d794917bb0`；23773 sessionId：`b9036f9c153dd09ec15add2f3fee15b`。
- 220 test 日志均出现 `TASK_STATUS_PROJECTED RUNNING -> INCOMPLETE reason=LEDGER_REPLAY`，随后出现 `ASSISTANT_BATCH_RESULT_COMMITTED result=committed reason=terminal_tool_result`、`task_completed` 和 `AGENT_STREAM_COMPLETED`。
- 重新读取 timeline 可取得完整事件，支持“后台结果事实与页面状态不同步”的共同根因。
- 23678 的客户端附件包含 `billingState=SETTLED`、`chargedPoints=100`，当次原因显示为商家无包房；积分不足的后台错误码仍待真实回包确认。

## 修复范围

1. 物理 hangup、SSE done、transport failure 与业务结果解耦。
2. 物理终态后按同一 session/task/callAttempt 身份继续有界读取，结果晚到时合并到当前页面。
3. 结果合并完成后清理思考/同步提示，并对任务列表执行幂等刷新/失效。
4. 业务失败、积分不足、结果未确认分别展示，不把传输信号当成功。
5. 重复结果和旧 generation 事件不得覆盖已确认结果。

## 验收标准

- 正常完成、业务失败/积分不足、网络失败和无结果超时均能退出无限 loading。
- 单路和多路结果均能在当前会话显示，任务列表读取后台终态。
- 同一结果重复到达只合并一次、只触发一次刷新；旧事件不能回退已确认结果。
- 未确认结果保留可恢复状态，可重新进入会话继续读取。

## 复现方式

### A. test 环境真实复现（需要明确的真实通话/断网授权）

1. 使用 test 环境登录同一账号，记录本轮 `sessionId`、任务标识和通话尝试标识。
2. 发起单路或多路通话，确认客户端已出现拨号/接通状态。
3. 在通话结束阶段制造一个已授权的异常终态：网络短暂断开、远端异常挂断，或等待服务端返回业务失败/积分不足结果；不重复提交、不重复拨号。
4. 保留客户端 diagnostics，核对是否出现物理终态、SSE done/transport failure，以及 `finalResponse`、`batchCallResult`、`committed` 等事件。
5. 同时按 `sessionId`、`taskId`、`callAttemptId` 读取 220 test 日志，核对结果写入、SSE/回执、客户端读取的顺序。
6. 在结果写入完成后观察当前会话和任务列表：修复后应在当前页面显示业务成功或业务失败，清除思考/同步提示，并刷新任务列表；未确认时应退出无限 loading 并提示可恢复同步。
7. 重新进入同一会话，确认恢复读取得到的结果与当前页面结果一致，且没有重复消息或重复任务刷新。

该流程需要真实外呼和网络操作授权；没有真实回包时，只能记录为待验，不能把模拟结果当作线上复现。

### B. 本地可重复回归

1. 构造物理终态已发生、当前消息尚无最终回执的会话。
2. 第一次历史读取只返回中间状态，第二次读取返回最终成功或结构化失败回执。
3. 断言结果出现后同步提示被清除，任务刷新只触发一次。
4. 重复投递相同结果，并投递旧 generation 的挂断/失败事件。
5. 断言不生成重复消息，旧事件不覆盖已确认结果；连续读取仍无结果时进入 `unconfirmed`，不继续无限等待。

本地回归入口为 `conversation_result_observation_test.dart`、`conversation_call_flow_test.dart` 和 `batch_conversation_lifecycle_test.dart`。

## 未确认项

23678 旧 session 的 220 历史归档未命中；2026-10-19 再激活的两个新 session 已通过 test 只读持久数据核对，见下节。真实环境回归仍待验证。

## 23678 再激活的两种现象

- `333a8cdef1d3aab15bb7d55e8c92673d`：积分耗尽自动停止后页面等待。积分流水确认为 `INSUFFICIENT_POINTS/SETTLED`，通话物理结束为 72641 ms，计费停点为 72000 ms；Agent 账本仅有 `CALL_STARTED`，缺通话终态。要求 SDK 能读出可信物理结果，随后 Agent 和客户端按原 attempt 显示结果；无语义结果时不得编造任务成功。
- `66b65a13bda88ce6da642a11ac19e7c8`：会员联系人上限拒绝，无实际拨号；后台三次 `RUN_FAILED/BATCH_CONTACT_LIMIT`，历史页多出执行确认卡。要求按失败命令移除多余执行卡，保留已确认的原批量快照、拒绝提示和继续修改任务能力。
