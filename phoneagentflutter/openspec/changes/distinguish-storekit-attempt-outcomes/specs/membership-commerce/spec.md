## ADDED Requirements

### Requirement: StoreKit 尝试结果独立投影
客户端 MUST 区分 userCancelled 与 pending，且只描述本次尝试，不将 nativeOutcome 当作服务端订单状态。旧桥省略/null 兼容为未知，未知值或错误类型 MUST 被视为协议错误。

#### Scenario: 用户取消
- **WHEN** StoreKit 返回 userCancelled 且原单仍未完成
- **THEN** 桥返回 CANCELED，结果弹窗显示“支付已取消”和“本次支付已取消。”，仅保留“完成”，仍查询原单而不关闭或释放。

#### Scenario: 等待批准
- **WHEN** StoreKit 返回 pending
- **THEN** 桥返回 PENDING，显示“本次支付未完成”和“本次购买尚未完成。”，不提示再买或重试、不判失败、不判成功、不 finish，不创建新单。

#### Scenario: 服务端付款优先
- **WHEN** 本次取消或 pending 后服务端查单返回支付与履约 SUCCEEDED
- **THEN** 展示可信支付成功；支付成功但履约未完成仍显示权益处理中。

#### Scenario: 查询失败和原单隔离
- **WHEN** 原单查询失败或用户查询另一订单
- **THEN** 同原单保留本次尝试结果与未完成事实；另一原单不继承尝试结果。
