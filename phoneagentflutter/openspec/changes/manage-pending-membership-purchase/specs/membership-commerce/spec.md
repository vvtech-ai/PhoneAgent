## ADDED Requirements

### Requirement: 会员待处理购买可直接继续或确认取消
会员页 SHALL 提供不展示订单号的待处理购买入口；已有未完成会员购买时选择套餐 SHALL 引导处理原购买。ALIPAY 原单处于 PENDING/PROCESSING、NOT_STARTED、未实付时 SHALL 可在用户确认后请求服务端关闭，不扩大自动支付资格。客户端 SHALL 不凭原生失败、退出或本地超时释放。

#### Scenario: 用户取消未完成购买并换套餐
- **WHEN** 用户在会员页确认取消原 PROCESSING 购买
- **THEN** 只调用原单关闭接口；可信结束后刷新会员摘要与原单再允许选择，未知保持待处理。

### Requirement: 服务端取消处理中禁止重复付款
PAYMENT_CANCELLATION_PENDING SHALL 仅从原单 safeErrorCode 读取；未完成原单命中该码 SHALL 显示取消处理中并禁止继续付款，保留查询与稍后返回。服务端已支付事实 SHALL 优先。未命中该码的旧原单未知结果 SHALL 继续允许既有受控重试。

#### Scenario: 取消请求仍等待材料到期
- **WHEN** 关闭或重新查询返回 PROCESSING 和 PAYMENT_CANCELLATION_PENDING
- **THEN** 显示“取消处理中，请稍后查看”，不宣称已取消，不展示客户端释放倒计时，不请求支付材料。

### Requirement: 待处理购买支付仍使用简洁反馈
待处理入口请求支付后 SHALL 隐藏购买状态与全部操作，SDK 返回 SHALL 仅显示既有结果与完成，不显示订单号、技术订单页或重试关闭次动作。

#### Scenario: 原单继续支付后原生取消
- **WHEN** 用户继续支付且原生返回 6001
- **THEN** 仅显示本次支付已取消与完成，原单仍以后台查询事实决定是否占位。
