## 客户端
删除 StoreKitPriceValidation 及其 Xcode 注册/撤销规则测试。保留新合入的 StoreKit 当次展示与重新取得 Product 的价格变化保护，比较源必须均为 StoreKit 本地报价，支持 USD/JPY/KWD，不比较服务端 CNY 参考值。仍检查商品 ID、支持商品类型、UUID appAccountToken、verified transaction、回执产品和绑定；服务端接受前不 finish。产品 displayPrice 原样展示，不从金额/币种猜格式。

新合入的 catalog、checkout、purchase 和 diagnostics 也必须撤销 matchesAmount 人民币约束；SKU、类型、报价身份、账号生命周期及恢复机制保留。价格元数据缺失仍不能唤起购买。

删除 DevicePaymentLauncher 专用价格异常映射、CommerceFailure 对应中文及反馈白名单。取消确认样式的另一个未提交微批保持不动。MembershipCheckout 不再用后台报价和目录价格一致性对 Apple 特判拦截，保留报价身份及 current/账号/协议保护；升级框由 route 注入当前 StoreKit 展示价格，Android 仍原报价。

## 服务端依赖（仅调查，未修改）
AppleTransactionPolicy 当前硬 CNY 且 price/10 转 fen；PaymentEvidenceValidator 比对订单 currency 与 cashAmountFen；CommercePaymentFactService 写 cashPaidFen 并在金额不等时置异常。因此客户端改变不能单独宣称闭环。

Apple 官方 JWS price 是币种的千分之一整数（1 主单位=1000 milliunits），不是统一“分”。主代理已冻结 OrderResponse/RecoveryPreview 可选 platformPaidCurrency:String 与 platformPaidAmountMilliunits:String，来自可信事件，无 DDL。金额采用精确整数/字符串格式化，不经 double，不把 JPY/KWD 写入 CNY cash_paid_fen。RecoveryPreview.referenceValueFen 是内部权益参考，不当成实付。Flutter 历史订单/完成详情/恢复预览优先真实实付，旧字段继续兼容；Apple 待付只提示以 Apple 显示为准，不把 CNY 参考值展示为应付。SUM 统计按币种分组，会员恢复与升级基于购买 SKU/快照权益参考，无 FX。

依据：https://developer.apple.com/documentation/AppStoreServerAPI/price 。该文档不是本次真实 StoreKit 验收。

## 验证
Dart 通道/Controller 和展示走真实 RED→GREEN；只删除已撤销 Swift 金额规则，不用源码镜像伪造原生测试。Windows 无 Xcode，原生编译、各地区沙箱购买、Java 可信 JWS 到履约/查询及订单金额展示在完成前保持待验。此前默认币种规格以本次用户授权覆盖。
