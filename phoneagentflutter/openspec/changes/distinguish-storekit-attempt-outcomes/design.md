# 最小设计

## 职责
Swift 只投影 StoreKit PurchaseResult。domain 使用可选 NativePaymentOutcome，data 校验 wire 字符串，PurchaseController 将尝试结果绑定原 orderNo，presenter 根据服务端事实优先展示。每批最多修改三个业务文件，不扩大支付协调器或反馈 sheet。

## 契约
nativeOutcome 可省略或为 null，表示旧桥/未知；仅接受 CANCELED、PENDING。verified success 沿用 transactionId/JWS/appAccountToken，不返回客户端成功枚举。Android nativeResultStatus 数字契约不变。取消与 pending 无 transaction，不触发 verify/acknowledge；仍查询原单。服务端 SUCCEEDED 优先于本次尝试结果。

## 验证
先在合成 MethodChannel 和原单仓库上观察 RED，再验证严格解析、取消/pending、查单失败、另一原单隔离、服务端成功优先及既有 Android/反馈回归。Windows 执行 Dart tests/analyze/OpenSpec；不能证明 Swift 编译或 iPhone Sandbox 行为，不安装、不付费。

## 数值价格后续缺口（本次不实现）
目前 PlatformProduct 只有 id/displayPrice；Quote 的 cashAmountFen/currency 是业务报价，Catalog 有 platformProductId，而 PaymentMaterial 没有已确认的期望价格/币种。后续需先冻结 StoreKit decimal price/currency 的桥接契约及原单的期望金额/SKU映射，才能精确比较；不得解析本地化 displayPrice、用 double 或猜测新增 HTTP 字段。价格展示仍沿 StoreKit 原行为。
