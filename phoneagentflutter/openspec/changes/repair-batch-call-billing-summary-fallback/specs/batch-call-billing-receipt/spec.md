## ADDED Requirements

### Requirement: 批量通话回执必须复用精确匹配的 Timeline 账单事实

批量通话回执在批次结果项缺少结构化账单时 MUST 仅从同一会话、同一 `callAttemptId` 的 Timeline 通话回执复用有效账单；MUST NOT 依据余额变化、积分流水、时长或其他通话尝试推算或借用账单。批次结果项已提供账单时 MUST 保持批次账单为准。

#### Scenario: 批量账单缺失但同一尝试存在 Timeline 账单

- **WHEN** 批量项未携带账单，且 Timeline 中同一 session 与 callAttemptId 有结构化 billingSummary
- **THEN** 批量结果项显示该账单信息
- **AND** 不改变批量结果项的其他状态与字段

#### Scenario: 其他通话或会话存在账单

- **WHEN** 账单属于不同 session 或不同 callAttemptId
- **THEN** 批量结果项不得显示该账单
- **AND** 缺少精确匹配时不推算扣费金额

#### Scenario: 批次结果已提供账单

- **WHEN** 批量项已包含一个或多个结构化 billingSummaries
- **THEN** 保留批量项原有账单，不追加或覆盖 Timeline 单路账单
