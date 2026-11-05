## ADDED Requirements

### Requirement: 结构化任务失败保留业务结果
task_failed 带 callResult 或 batchCallResult 时 MUST 保留结构结果和所属命令，进入既有业务结果链路；MUST NOT 退化为丢失结果的普通技术 error，也不得把失败改为成功。

#### Scenario: 批量积分拒绝
- **WHEN** SSE task_failed 含 batchCallResult，现有积分拒绝规则匹配
- **THEN** 原结果正常展示、余额按既有规则刷新、业务提示播报一次，重复事件不重拨

### Requirement: 未知故障不伪造结果
没有结构化结果的未知 task_failed MUST 保持原 error 分类；已识别会员拒绝 MUST 继续沿用原业务提示。

#### Scenario: 无结构结果的未知失败
- **WHEN** 事件没有 callResult / batchCallResult 且不匹配已知业务拒绝
- **THEN** 保留失败语义，不制造任务结果、资格或执行
