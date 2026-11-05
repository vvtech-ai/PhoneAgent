## ADDED Requirements

### Requirement: 结果语义与传输状态独立保留
客户端 MUST 保留 CALL_OUTCOME_REPORTED 原始业务 outcome 及 reason、headline、receiptFields；transport status 的归一映射 MUST NOT 覆盖业务语义。

#### Scenario: 需要重拨或用户取消
- **WHEN** 权威结果为 NEEDS_RECALL 或 USER_CANCELLED
- **THEN** transport status 分别沿用 FAILED 或 CANCELLED，业务 metadata 保留 NEEDS_RECALL 或 USER_CANCELLED，不改写为另一含义

### Requirement: 同一结果经所有入口业务等价
实时结果、列表恢复与只读详情 MUST 对同一 attempt 展示一致的状态、原因、字段及顺序；恢复 MUST 不发新命令或重播。

#### Scenario: 五种语义结果连续补全
- **WHEN** SUCCESS、USER_CANCELLED、NEEDS_RECALL、FAILED 或 UNCLEAR 的 finalResponse 后补入账本，再恢复和查看详情
- **THEN** 每一路同身份一份且内容等价，状态文案保持业务语义，历史无新增播放或执行
