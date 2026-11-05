# 对话联系人手机号别名解析

## ADDED Requirements

### Requirement: 联系人选项必须保留手机号别名
客户端解析对话选项时，若条目包含非空 `phone`，MUST 将其作为号码；若 `phone` 为空而 `phoneNumber` 非空，MUST 将 `phoneNumber` 作为同一号码用于详情、选项模型及后续选择。

#### Scenario: 候选只返回 phoneNumber
- **WHEN** 选项条目为 `{ "label": "杜燕", "phoneNumber": "13800000000" }`
- **THEN** 客户端选项的 `phone` 为 `13800000000`
- **AND** 选项详情包含该号码

#### Scenario: 候选同时返回两个别名
- **WHEN** 选项条目同时包含非空 `phone` 和 `phoneNumber`
- **THEN** 客户端使用 `phone`
- **AND** 不重复展示 `phoneNumber`

### Requirement: 按号码查询请求必须兼容手机号别名
客户端处理 `LOOKUP_CONTACT_REQUEST` 时，MUST 按 `phone` 优先、`phoneNumber` 回退提取查询号码；两者均为空时继续按原规则拒绝缺失上下文。

#### Scenario: 查询请求只返回 phoneNumber
- **WHEN** 查询事件只包含 `phoneNumber: "13800000000"`
- **THEN** 客户端向设备查询层传递 `13800000000`

#### Scenario: 查询请求没有号码
- **WHEN** 查询事件的 `phone` 和 `phoneNumber` 都为空
- **THEN** 客户端继续返回缺失查询上下文错误
