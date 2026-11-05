# 区分 StoreKit 取消与待批准结果

## Why
StoreKit 的 userCancelled 与 pending 当前均返回空 map，取消被展示为未知。需要准确描述本次支付尝试，同时保留服务端订单事实优先。

## What Changes
- 原生桥增加可选 nativeOutcome：CANCELED / PENDING。
- Flutter 严格解析并在同原单查询期间保留本次尝试结果。
- 取消显示“支付已取消”，pending 显示“本次支付未完成”；结果仍只有“完成”。
- 旧桥空 map 兼容为未知，Android numeric resultStatus 与公共 HTTP 不变。

## Capabilities
### Modified Capabilities
- membership-commerce：StoreKit 尝试结果与服务端付款、履约事实分离。

## Impact
仅 iOS bridge 与 Flutter 支付消费者、展示和回归测试；不新增购买，不关闭、释放或 finish 未确认交易。
