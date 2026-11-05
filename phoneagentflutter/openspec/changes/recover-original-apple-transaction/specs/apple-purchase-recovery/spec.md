## ADDED Requirements

### Requirement: Apple 金额独立于业务参考价
服务端 SHALL 从已验证交易保存原币种和千分金额；不要求等于后台参考价或 CNY，不用人民币兼容投影否定完整原币回执。原始支付事实冲突仍须拒绝，第三方支付校验不变。

#### Scenario: APPLE-MONEY-01
- **WHEN** 原币回执有效但后台参考金额或历史现金派生值不同
- **THEN** 按原币事实验证与显示，权益按原商品快照发放，不将兼容字段 0 解释成实际零支付

### Requirement: 旧交易始终恢复原订单
客户端 SHALL 在创建新订单前检查未完成交易；购买收到旧 token 时 SHALL 交给账号作用域恢复流程，服务端验证原订单归属，不将其绑定当前订单。

#### Scenario: APPLE-RECOVERY-01 购买前发现旧交易
- **WHEN** 购买前存在该商品未完成交易
- **THEN** 尝试恢复原单并停止本次购买，不创建新订单或自动再次扣款

#### Scenario: APPLE-RECOVERY-02 购买期间收到旧交易
- **WHEN** verified 同商品交易 token 与新订单不同
- **THEN** 验单恢复原单，结束新订单本地流程并保留迟到付款恢复；失败不 finish

#### Scenario: APPLE-RECOVERY-03 失败、重复与账号隔离
- **WHEN** 验单失败、重复回调、账号切换或旧响应迟到
- **THEN** 不重复交付、不错误 finish、不污染当前账号或订单，失败保留重试
