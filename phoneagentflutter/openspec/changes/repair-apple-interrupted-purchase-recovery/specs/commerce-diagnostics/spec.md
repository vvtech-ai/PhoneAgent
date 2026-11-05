## ADDED Requirements

### Requirement: Apple 恢复保留安全业务码
诊断 MUST 保留恢复验单相关白名单 businessCode，未知字符串 MUST 丢弃；不得改变业务结果或 UI。

#### Scenario: 重启后验单拒绝
- **WHEN** 服务器返回支付验证失败等已登记业务码
- **THEN** JSONL 可持久化并读回原业务码以关联后台拒绝原因

#### Scenario: 非法错误信息
- **WHEN** 错误码包含未知内容或私有文本
- **THEN** 不写入日志，不改变支付恢复逻辑
