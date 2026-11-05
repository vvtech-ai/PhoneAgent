## ADDED Requirements

### Requirement: Apple 购买前必须验证人民币锁价
客户端 MUST 在重新获取 StoreKit Product 后、调用 purchase 前验证服务端 expectedCurrency 和 expectedCashAmountFen 存在且合法；实际 currencyCode 与 expectedCurrency MUST 同为 CNY，实际 Decimal 价格精确乘以 100 MUST 等于正整数锁价。不得解析 displayPrice 或使用 Double。

#### Scenario: 商品匹配当前锁价
- **WHEN** 商品人民币价格精确等于材料金额
- **THEN** 按现有绑定账号的购买流程继续，本地化展示价格保持原样

#### Scenario: 材料缺失或币种金额不符
- **WHEN** 参数缺失、非法、非 CNY 或精确金额不符
- **THEN** 不调用 purchase，并显示固定安全中文不可购买提示
- **AND** 不关闭或替换原单，仍可查询原单，服务端可信已付结果优先

#### Scenario: 未识别平台异常
- **WHEN** 原生返回未知错误码或原始错误文案
- **THEN** 不向用户回显原始错误内容，也不改变 Android 异常映射
