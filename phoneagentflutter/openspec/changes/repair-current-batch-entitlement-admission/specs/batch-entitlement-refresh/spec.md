## ADDED Requirements

### Requirement: 当前批量权益同步
系统 SHALL 按当前账号与最新发布等级权益处理后续批量任务，不将购买时权益视为当前批量权限。

#### Scenario: 当前配置生效
- **WHEN** BATCH_CONTACT_LIMIT、BATCH_CONCURRENCY_LIMIT、BATCH_ENTITLEMENT_LIMIT 拒绝触发一次刷新，普通回复、积分不足、旧账号和已取消任务不触发。
- **THEN** 系统执行新规则并保留历史快照、事件及已开始通话记录

### Requirement: 正常行为兼容
系统 SHALL 保留正常任务、历史回执、积分及购买快照的既有语义。

#### Scenario: 不相关流程
- **WHEN** 正常任务未触发批量权益拒绝或用户读取已有订单
- **THEN** 不产生自动重试、额外外呼或资产改写
