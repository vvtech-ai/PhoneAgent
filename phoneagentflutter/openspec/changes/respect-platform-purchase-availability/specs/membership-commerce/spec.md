## ADDED Requirements

### Requirement: 平台销售开关分别控制新购入口
客户端 SHALL 消费 CatalogResponse 的 membershipEnabled 与 pointsPackEnabled boolean，历史缺失字段 SHALL 兼容 true，非法 null/类型 SHALL 拒绝。会员关闭 SHALL 隐藏营销 tabs、价格、付费协议与新购按钮；积分关闭 SHALL 隐藏加购入口及直接购买页销售内容。总钱包入口、余额、当前已购权益、流水、订单、发票、原单恢复 SHALL 保留。

#### Scenario: 会员关闭但积分开放
- **WHEN** 当前平台目录 membershipEnabled=false、pointsPackEnabled=true
- **THEN** 展示真实当前会员权益和余额，积分加购仍可见，不显示会员营销与购买动作。

#### Scenario: 双销售关闭
- **WHEN** 当前平台两开关均 false
- **THEN** 总页、原单处理和历史读取仍可访问，不显示任何新购入口；已打开积分购买页不展示付款内容。

### Requirement: 新购回调不得绕过目录关闭
商品报价前 SHALL 校验对应类型开关；等待确认或材料期间更新为关闭 SHALL 阻止旧流程继续新购/唤醒。原单查询、取消、受控重试及 Apple 恢复 SHALL 不使用新购开关门禁。

#### Scenario: 旧购买回调直接调用
- **WHEN** 调用关闭类型的 MembershipCheckout.buy
- **THEN** 不发报价、不创建订单、不调用原生支付。

#### Scenario: 升级确认期间关闭会员购买
- **WHEN** 确认弹窗显示后目录更新为会员购买关闭
- **THEN** 旧确认不能创建新会员订单。
