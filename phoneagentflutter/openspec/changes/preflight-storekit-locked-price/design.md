## 方案
新增 Foundation 纯校验模块，接收服务端材料、Product.priceFormatStyle.currencyCode 与 Product.price。拒绝缺失/非法/非正整数字符串锁价、非 CNY 和 Decimal 运算错误；精确乘以 100 后通过 NSDecimalNumber.compare 与锁价比较，禁止 Double 或 displayPrice 解析。

CommercePaymentChannel 仅在重新读取 Product 后、purchase 前调用校验。校验失败返回 APPLE_PRICE_UNAVAILABLE，Dart 仅在 APPLE_IAP 映射固定提示“当前商品价格或币种不符合购买条件，暂不可购买”；不输出平台原文。现有控制器继续查原单，服务端支付成功优先。

两个生产微批：Swift helper/bridge/Xcode 注册，以及 Dart launcher/domain message/feedback 白名单。使用已有 RunnerTests target 编译同一个 helper 做纯校验；Windows 无 Xcode，测试仅编写待执行，不用 Dart 镜像算法冒充 Swift 验证。
