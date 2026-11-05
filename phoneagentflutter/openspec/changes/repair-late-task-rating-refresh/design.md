## Context

当前 `TaskRatingController.load` 由 provider 初次调用。`TaskRatingRoute` 只取得 owner；实时与详情的 `CallEvaluationRoute` 仅收到 target，不收到结果更新。原生 `8f235920` 的 `claimCard` 在再次取得 owner 时重查，且 load generation 隔离旧结果；v66 `a0bedb12` 尚无该修复。

## Decisions

- 资格与草稿状态继续由原 TaskRatingController 唯一持有，不创建第二套状态机。
- feedback 的 receipt 投影生成值相等的结果 revision；通过共享 `CallEvaluationRoute` 工厂传到 TaskRatingRoute。实时与详情仅修改 feedback builder 接线，避免把网络逻辑放进大页面。
- 新 revision 及 owner 交接调用现有查询；相同结果重建不触发查询。无无限轮询，不把失败视为永久无资格。请求中更新使旧 generation 失效，并合并待处理刷新；编辑/提交期间延迟处理，不覆盖已提交事实。
- 不改服务端资格判定。若最后一次结果之后服务端才完成资格且没有新的可观察事实，单靠现有结果信号无法保证自动发现；必须记录该后端/协议边界，不伪造资格。
- 独立审查补充守护：批量 item 的结构化 receiptFields、recalled、abnormal 与整批 totalHint 也是业务结果补全，必须纳入值 revision；headline/detail/status 全未变也应重查。同值重建和仅 targetName 等显示信息变化不重查。此项是 RATING-01/02 合同防护，不代表已取得线上同会话缺陷证据。

## Files and validation

`receipt_feedback_target.dart` 负责稳定反馈投影；`task_rating_controller.dart` 负责刷新/代次；`task_rating_route.dart` 负责生命周期；`call_evaluation_route.dart` 与两端 builder 只负责接线。同类入口以后复用共享工厂。每批不超过三个手写生产文件，不整体格式化。

先跑真实 provider/widget 连续回放得到 RED，再做最小 GREEN；覆盖无资格→结果补全、错误→补全、旧响应、账号/target 隔离、owner 交接、只读与批次范围。固定 Flutter 3.32.0，`--no-pub`，不打包、不联网或外呼。
