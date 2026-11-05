# Apple 购买前锁价预检（2026-10-14）

> 历史记录，已由用户最新决定覆盖：Apple 使用 StoreKit 当地币种与价格，取消后台人民币等价预检。当前实现与待验范围见 `openspec/changes/accept-storekit-local-prices/tasks.md`；以下不再是发布要求。

基点 `73d0a07e`，沿用本期 CNY 和服务端业务锁价。Java 材料新增字符串 `expectedCurrency`、`expectedCashAmountFen`。客户端不据本地化文本生成报价，不支持任意实价或外币。

## 实现与职责
- 原生微批：新增 19 行 `ios/Runner/StoreKitPriceValidation.swift` 纯 Foundation 校验；`CommercePaymentChannel` 重新取 Product 后、purchase 前调用；Xcode 工程把同一 helper 注册到 Runner 和已有 RunnerTests target。
- 校验拒绝缺少字段、非 CNY、非 ASCII 正整数/Int64 溢出锁价、NaN/非正价格与 Decimal 运算错误。使用 NSDecimalMultiply 精确乘 100，NSDecimalNumber.compare 比较，不经 Double/displayPrice。
- Dart 三文件微批：DevicePaymentLauncher 仅识别 APPLE_IAP 的 `APPLE_PRICE_UNAVAILABLE`；CommerceFailure 与反馈白名单固定“当前商品价格或币种不符合购买条件，暂不可购买”。未知原文不曝光，Android 仍原样抛其原有异常。
- 不改 Controller 状态机：继续查询原单；没有关闭/替换单；已付/履约事实优先。本地化 displayPrice、Android 原生、JWS 和服务端金额不变。

## 实际验证
1. 新通道契约 + StoreKit 尝试反馈两文件真实 RED：11 项中 9 通过/2 失败，证明专用异常映射/安全文案未实现。修复后 11 通过。
2. 8 文件定向回归：apple_price_preflight_contract、storekit_attempt_feedback、native_payment_launcher、payment_attempt_feedback、payment_retry_error_contract、purchase_controller、original_payment_feedback_route、payment_feedback_geometry 共 72 项通过（15 秒测试输出）。包含材料字段原样转发、displayPrice 保留、Apple 专用映射、Android 不受影响、未知错误隐藏、查原单和已付优先、现有弹层布局。
3. `flutter analyze` 无问题（17.5 秒）；`openspec validate --all` 132 项通过；git diff --check、中文 UTF-8 回读通过。
4. 日志：`D:/Temp/story1837-apple-preflight-{red,green,regression,analyze,spec}-20261014.log`。

## 原生待验，不能等同 Flutter 通过
发布顺序：先在 macOS 完成原生编译、XCTest 和 StoreKit 联调，再发布带此预检的 iOS 客户端，最后启用或修改不再手填价格的 Apple 商品映射。旧客户端不会执行新增预检，不能仅靠服务端新增材料字段就声称已保护旧客户端。完成该验收前可通过后台独立关闭 iOS 新购入口，原交易恢复仍保留。本批没有修改运行环境开关，也没有修复历史外币已扣款异常。

当前 Windows 的 Get-Command 未发现 xcodebuild 或 swift。RunnerTests 5 个方法覆盖 CNY/折扣 SKU 精确金额、1 分、超过 Double 安全整数范围、子分小数不取整、两边币种、缺失/非法/溢出锁价、NaN 和 Decimal 溢出；已写入既有 Xcode target，但未编译/执行。没有镜像 Swift 算法的 Dart 测试。

macOS 后续在 `ios/Runner.xcworkspace` 打开 Runner scheme，选择可用 iOS Simulator 运行 RunnerTests；或在依赖就绪后执行 `xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,id=<可用模拟器ID>' -only-testing:RunnerTests`。需另以 StoreKit 测试环境验证错误币种/金额不唤起 purchase，匹配普通及折扣 SKU 才唤起，材料缺失失败关闭；真实 App Store 商品/账号地域配置仍待验。未构建 APK、操作手机、真实收费、提交或推送。

API 依据：[Product.price](https://developer.apple.com/documentation/storekit/product/price)、[Product.priceFormatStyle](https://developer.apple.com/documentation/storekit/product/priceformatstyle)、[Decimal.Currency.currencyCode](https://developer.apple.com/documentation/foundation/decimal/formatstyle/currency/currencycode)、[NSDecimalMultiply](https://developer.apple.com/documentation/foundation/nsdecimalmultiply(_:_:_:_:))。这些文档只支持 API 选择，不是本补丁的原生编译证据。
