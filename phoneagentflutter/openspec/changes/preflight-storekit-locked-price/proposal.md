## Why
StoreKit 本地化展示价格不能证明购买时的币种和金额与服务端锁价一致。本期只支持 CNY，需要在唤起支付前拒绝不匹配商品。

## What Changes
- APPLE_IAP 材料携带 expectedCurrency 与 expectedCashAmountFen 字符串。
- iOS 重新获取 Product 后，使用 currencyCode 和精确 Decimal 价格进行校验，失败不调用 purchase。
- 专用原生错误映射固定中文，保留原单查询和服务端已付事实优先。

## Impact
- iOS 平台适配、Dart 通道错误与反馈、XCTest/Flutter 测试。
- 不修改 displayPrice、Android、JWS 核验或履约锁价，不支持外币/任意实际价格。
