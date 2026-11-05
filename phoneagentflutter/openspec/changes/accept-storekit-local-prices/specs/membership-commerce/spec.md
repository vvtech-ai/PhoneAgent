## ADDED Requirements

### Requirement: Apple 采用 StoreKit 当地价格和币种
客户端 SHALL 采用 StoreKit 商品本地化价格展示和实际购买，不要求 CNY 或与后台人民币金额相等，不对展示字符串做解析/换汇。该要求覆盖此前 Apple 人民币锁价预检；支付宝规则不变。

#### Scenario: Apple 商品使用美元日元或三位小数币种
- **WHEN** StoreKit 返回匹配 SKU 的当地价格
- **THEN** 商品和购买确认原样展示 displayPrice，不因当地币种和人民币参考价不同而拒绝 purchase
- **AND** 保留产品类型、账号 token、verified transaction、原单身份与当前账号/路由保护

#### Scenario: StoreKit 当次价格在确认后变化
- **WHEN** 重新读取的同一 SKU 本地价格或币种与用户当次确认不一致
- **THEN** 提示刷新重新确认，比较来源均为 StoreKit，不使用后台人民币参考金额

### Requirement: Apple 可信实付必须独立于业务参考价
服务端 SHALL 从验证通过的 JWS 读取实际 currency 与 price milliunits，精确保留，不转换为人民币分或信任客户端金额。客户端 SHALL 使用服务端可信实付信息展示历史订单，不冒称参考价为当地实付。

#### Scenario: 服务端验单与恢复
- **WHEN** 客户端上传交易凭证或恢复未 finish 交易
- **THEN** 服务端验证应用、环境、SKU、账号绑定、交易身份和数量后处理支付事实
- **AND** 仅服务端接受后 finish，不用去掉客户端预检代替后端闭环验证

#### Scenario: 历史订单与恢复显示精确真实实付
- **WHEN** 响应包含 platformPaidCurrency 与 platformPaidAmountMilliunits
- **THEN** 客户端精确显示真实币种和千分单位金额，不经过浮点数或套用“分”格式化
- **AND** 缺失历史字段兼容原响应，部分或非法字段拒绝解析，不回退成错误人民币实付
- **AND** referenceValueFen 仅作权益参考，Apple 待付款不展示人民币参考金额为应付

#### Scenario: Apple 已付订单缺少可信原币回执
- **WHEN** Apple 订单已付款且原币字段同时为 null 或缺失，即使 cashPaidFen 为正
- **THEN** 订单金额显示“以 Apple 账单为准”，不得将兼容现金字段推断为可信人民币实付
- **AND** 未付款仍显示“以 Apple 显示价格为准”；合法历史人民币回执由服务端提供可信原币字段
