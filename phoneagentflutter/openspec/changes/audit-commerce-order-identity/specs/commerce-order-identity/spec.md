## ADDED Requirements

### Requirement: 订单详情限定原单身份
客户端 MUST 只在指定订单详情显示该 orderNo 对应的状态和动作；共享后台恢复不得替换详情的订单身份。

#### Scenario: 其他订单请求尚未完成
- **WHEN** 订单 A 请求繁忙时打开订单 B
- **THEN** 不显示 A 的信息或动作；请求完成后查询并展示 B，即使 A 已完成

#### Scenario: 指定原单查询失败
- **WHEN** 查询 B 失败或仍等待共享请求
- **THEN** 重试和轮询仍使用 B，不对 A 进行支付或关闭

### Requirement: Apple 原单重试重新确认真实价格
客户端 MUST 在可付款 PENDING 原单重试前展示并要求用户确认 StoreKit 当前真实价格；不使用之前会话缓存或服务端人民币参考价授权重付。

#### Scenario: 重启后继续可付款原单
- **WHEN** 用户继续 APPLE_IAP PENDING 原单
- **THEN** 读取原 SKU 当前真实价格，用户确认且会话/页面仍有效才拉起原单，拒绝则不拉起
- **AND** PROCESSING、未知原生交易及已收款订单不重复拉起

#### Scenario: 价格确认不占支付位置
- **WHEN** 用户拒绝价格确认、商品取价失败或页面/账号失效
- **THEN** 仅使用原单只读platformProductId，不调用payment准备接口，不将PENDING改为PROCESSING
- **AND** 用户确认后只调用一次payment，最终材料必须仍匹配已确认的原SKU

#### Scenario: 另一设备在确认期间占用原单
- **WHEN** 只读价格确认期间另一设备先prepare同一Apple原单，当前prepare被服务端以MEMBERSHIP_PAYMENT_UNKNOWN拒绝
- **THEN** 本端不拉起StoreKit、不创建替代订单，沿异常路径查询并显示原单PROCESSING及安全提示
- **AND** 不将其当作已取消，再次操作不能重复确认或prepare
