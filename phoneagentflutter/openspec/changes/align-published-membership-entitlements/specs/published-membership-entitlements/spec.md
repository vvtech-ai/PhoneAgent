## ADDED Requirements

### Requirement: 支付与履约展示独立
订单列表和详情 MUST 将 PENDING、PROCESSING、SUCCEEDED、FAILED、CANCELED、CLOSED 显示为待支付、支付处理中、支付成功、支付失败、已取消、已关闭。履约提示和发票状态 MUST 独立保留，不改变支付状态机。
#### Scenario: 支付成功但权益处理中
- **WHEN** paymentState 为 SUCCEEDED 且 fulfillmentState 为 PROCESSING
- **THEN** 显示支付成功和独立权益处理中提示，不显示未付

### Requirement: 当前克隆准入与发布等级说明
会员权益 MUST 按 cloneEntitlements.enabled 显示支持或暂不支持。入口 MUST 根据当前有效权益决定准入，升级提示 MUST 动态列出 benefitsByLevel 中实际支持等级，返回购买页后重读当前权益，读取失败 MUST 提供重试。
#### Scenario: 非连续等级及排队
- **WHEN** 发布配置仅初级和高级支持克隆，当前有效权益不支持但排队套餐支持
- **THEN** 提示初级会员或高级会员，当前入口仍不放行

### Requirement: 积分包真实平台优惠
ProductOffer MUST 兼容可选 regularPlatformProductId、discountMembershipLevel。Android MUST 使用业务原价和实付价比较；iOS MUST 使用所选 SKU 原样本地化价格，仅用同币种结构化精确 Apple 金额计算真实折扣。购买 SKU 和金额预检 MUST 保持原有规则。
#### Scenario: 普通 Apple SKU 缺失
- **WHEN** 会员商品有效但无法读取普通 SKU 价格
- **THEN** 只展示实际 Apple 价格及配置等级专享价，不虚构原价或折扣
#### Scenario: 无优惠或币种不一致
- **WHEN** 普通价不高于会员价或币种不一致
- **THEN** 不显示折扣或划线原价

### Requirement: 翻译授权使用服务端目录
客户端 MUST 使用当前账号翻译 options 返回的 models 与 countries.availableModelIds，不根据会员等级或本地发布目录另行推测授权。
#### Scenario: 会员购买后读取
- **WHEN** 返回翻译配置并重新读取目录
- **THEN** 采用接口最新可用模型并保持账号生命周期和合法选择保护
#### Scenario: 后台发布后重新打开选择面板
- **WHEN** 用户打开正式翻译模型选择面板
- **THEN** 重新读取最新目录，刷新期间不显示旧授权选项，preview不触发目录刷新
