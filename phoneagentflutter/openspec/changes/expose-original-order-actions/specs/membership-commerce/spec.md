## ADDED Requirements

### Requirement: 原订单查询入口必须可见
未付款或履约未完成订单 SHALL 在固定操作列提供可见查看订单入口，进入已有本人原单查询/恢复页，不自动创建或续付。PROCESSING SHALL 保留PAYING及未知结果语义，不成为可重复付款事实。已完成付款及履约订单 SHALL 保留发票入口。

#### Scenario: 支付结果确认中
- **WHEN** 原订单paymentState为PROCESSING
- **THEN** 可见查看订单并查询本人原单，canPay仍为false

### Requirement: 订单名称与渠道仅展示真实事实
订单会员名称 SHALL 依据可空原购买快照membershipLevel/membershipMonths展示会员等级及单次包月/包季/包年；旧字段缺失保留历史productName，不按名称猜测。ALIPAY SHALL 显示支付宝，暂停微信不提供假渠道。

#### Scenario: 带原快照字段
- **WHEN** 会员原单包含BASIC和1个月快照信息
- **THEN** 列表显示初级会员·包月；不声称连续自动扣费

#### Scenario: 旧响应无会员快照字段
- **WHEN** OrderResponse省略两个可选字段
- **THEN** 保留历史商品名，严格状态/金额解析不变
