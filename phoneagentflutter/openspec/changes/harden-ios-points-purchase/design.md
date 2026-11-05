# 设计

## 商品状态
服务端目录加载与 Apple 商品加载分离。目录保留时价格区域加载转圈；请求失败显示蓝色重新加载，点击重新查询整个目录的 Apple SKU，期间防重。成功缺 SKU、类型不支持或服务端禁售显示暂不可售。支付受设备内购权限、协议及订单状态限制。

## 价格契约
StoreKit 返回 displayPrice、Decimal 字符串 price、currencyCode、productType；不解析 displayPrice、不用 double。现有 cashAmountFen 是人民币分，当前只对 CNY 用 BigInt 精确比较；其他币种缺乏已批准单位契约时关闭支付并记录联调缺口，不做汇率推算。报价必须与目录和 StoreKit 一致。确认后再查询；Swift 拉起前比较已确认快照，防止异步价格变化。非自动续期会员保持既有支持，积分包仅 consumable。

## 恢复与所有权
原生监听 Transaction.updates，只通知存在未完成交易；交易材料由 restore 返回已验签 JWS。账号作用域控制器串行消费、同交易去重并在 dispose 后禁止确认；后台扫描拒绝他账号交易后不 finish。账号登录后持续持有恢复控制器，前台恢复补扫描。服务端 API 不新增字段；保留现行可信 payment SUCCEEDED 后 finish、履约未成功继续原单恢复规则。真实服务的持久履约保证仍待外部验收。

## UI 与平台边界
iOS 积分显示取消、等待确认、结果待确认、积分处理中及到账；处理中复用中性反馈样式。Android 保留现有支付宝反馈/重试。共用控件只增加可选参数和 iOS 分支。未知或 Pending 不允许再次拉支付；原订单查询保留。

## 验证
OpenSpec、commerce 及直接调用方定向测试、analyze、iOS 无签名编译、本地 StoreKit 场景配置。真实 SKU、沙盒批准/扣款/到账和设备 UI 单独待验，不以合成通道测试代替系统支付。

## 最终语义与运行限制
2026-10-14用户确认覆盖distinguish-storekit-attempt-outcomes中的旧Pending文案：现显示等待支付确认；取消显示本次支付已取消。未知/Pending阻止重新拉支付，显式请求关闭仍由服务器验证，不自动关单。确认报价变化后重新读取服务端目录和Apple商品；价格区域的蓝色重新加载只查全列表Apple信息。

原生测试已编译并在独立宿主实际启动，但SKTestSession配置保存返回SKInternalErrorDomain Code3，两项未通过。原因尚未确认，不能将其直接归因产品或环境。继续保留真实SKU、CNY定价契约、服务器持久履约与真实沙盒验收缺口；未归档。

## 购买全流程诊断（用户追加）
新增commerceFlow闭合事件schema及feature诊断helper，复用现有账号隔离journal/日志上传，不新增UI或上传动作。以sessionId及SHA256截断的商品/SKU/报价/订单/交易ref关联事件；不记录原始ID、JWS、收据、appAccountToken、完整参数或异常文本。记录目录、平台可用性/查询、每商品可售原因、协议/确认、报价/下单/支付材料、拉起与取消/Pending、验单/去重/finish、恢复及服务端付款/履约状态。常规成功查单只记状态变化，失败及关键请求记录耗时。原生错误仅允许受控domain及numeric code；日志失败不能影响支付。Debug控制台COMMERCE及原生COMMERCE_NATIVE，Profile/Release保留现有journal。

## 协议点击校验（最新确认）
iOS积分按钮移除agreementAccepted禁用条件，其他商品/渠道/价格/忙碌和原单条件不变。MembershipCheckout复用PurchaseController.preview的协议拒绝，记录agreementRequired；未同意时提示请先阅读并同意付费协议，不报价/下单/拉支付，也不因协议错误刷新目录。覆盖此前协议未选置灰的实现，Flutter布局/控件和Android行为保持。
