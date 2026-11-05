# 设计

## 信任边界
Android只将resultStatus过滤为4位数字后送至NativePaymentResult，完全忽略memo/result/orderString且不日志输出。PurchaseState保存原单绑定的本次attempt结果；6001显示本次取消、4000显示本次失败，8000/6004/timeout/未知显示本次未完成。9000仍只查服务端，SUCCEEDED+SUCCEEDED才显示支付成功/升级成功；SUCCEEDED但履约未完成显示已支付、权益处理中，覆盖本次native取消/失败。PAYING内部不变，前台label改未完成支付，未知原单保持占位，不自动重付/关单。

## 购买编排
独立Checkout协调器组合现有PurchaseController，不在page加入金融计算。普通ALIPAY已同意协议后直接内部报价、下单、原生、查原单，不调用确认UI；升级仅quote.purchaseType=UPGRADE需要确认，金额、折算秒数、预计到期来自server quote，不拷贝Demo补发差额或到期不变文案。升级报价本身不代表协议接受，下单前再次要求真实确认。iOS保留StoreKit平台价格核对与平台确认，不能伪造第三方后备渠道。

同套餐判定仅用current实际level/currentMonths与真实product，不从名字猜。已开通同档同周期弹当前套餐信息不报价/下单，其他报价规则仍由服务端决定。切号/页面离开时旧编排不得创建订单或显示旧账号反馈。

确认后再次匹配已展示 quoteId/productId；创建与材料返回后复核捕获的 owner 当前路由及登录 epoch，页面被覆盖或退出不再自动拉支付，已创建原单保留。返回旧原单不继承本次报价的升级成功标签。历史跨端原单可查询，但只在 channel 与本端一致时显示可执行支付入口。

## 显式原单重试
用户追加失败原单占位优化。ALIPAY 原单 payment=PENDING/PROCESSING、fulfillment=NOT_STARTED、cashPaidFen=0 可显示“重新支付”，仅发起现有 material(orderNo) 的服务端核验，不宣称客户端已可收款。自动新单 launch 仍限 PENDING、同 quoteId、同 channel。服务端独占过期/NOT_EXIST/lease/锁内状态校验和实际材料截止；客户端不根据 OrderResponse.expiresAt 判断支付过期、不创建替代单、不释放槽位。material 业务错误保留中文投影并继续查询原单，服务端支付成功优先覆盖本次尝试错误。允许码 AC0006、CONFIGURATION_CONFLICT、CHANNEL_UNAVAILABLE、MEMBERSHIP_PAYMENT_UNKNOWN 等仅映射已知中文，供应商 raw message/code 不泄露。

## 页面职责
MembershipRoute只连接用户事件、确认/反馈Sheet和刷新。升级确认及已开通提示为独立小Widget；反馈Sheet独立读取PurchaseState、查询原单并显示安全投影，不包含原生SDK或Repository。原订单历史仍进入PurchaseResultRoute，不自动付钱。普通反馈只在当前页，完成关闭后重新请求权益/余额；所有显示积分值或期限必须有真实接口事实，不本地加分。

## 用户最终覆盖：支付反馈只留完成
用户追加覆盖前述次要原单动作：SDK 唤醒等待与返回不显示订单相关信息。PurchaseFeedbackSheet 最终仅图标/标题/安全一句反馈/完成，原单号、订单商品与实付明细、查询/查看/关闭/重试/售后动作全部移除；后台query保持，用于真实成功判定，完成不受只读query busy禁用。原生6001采用浅粉感叹号和“支付已取消”，不复制Demo“订单未支付/积分和权益未变化”金融结论。升级确认只显示服务端秒数换算的天数，不展示技术秒数。

历史详情可正常阅读与受控原单重试；点击支付时 PurchaseResultRoute 切为无订单信息的等待界面，SDK返回后使用同一简洁反馈，完成后恢复正常详情阅读。普通购买不进入历史结果页面，反馈回调/次要跳转已删除。本覆盖优先于本文件早期原单反馈动作描述，不修改金融状态或重试控制器规则。

## 验证
原生数字过滤、Dart参数接收、Controller取消/失败/9000与服务端优先、query失败/占位、普通直购/升级确认/同套餐/协议/切号回归先RED。375/390/430及大字Sheet验证与合成图只读检查。日常定向/analyze/OpenSpec，不运行真实支付，不构建/安装/提交。
