## Decisions

1. 基线 HEAD 已有该缺陷；本轮全量检出，属于任务失败结果链路的同类遗漏。
2. 在 task_failed 普通 error guard 同时排除 batchCallResult，继续使用原 finalResponse 分类，不另造状态机。
3. 以现有 batch=true 钱包刷新预期1实际0为业务 RED，新增两种结构化结果字段的身份 / 内容断言；未知失败及会员拒绝行为保持原规则。

## Validation

解码单通 / 批量守护先 RED 后 GREEN，fresh_balance_admission、membership_denial_reply / speech 与 raw_final_interactive_contract 定向回归；静态检查和 strict OpenSpec。
