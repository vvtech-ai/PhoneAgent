# 修复 iOS 取消后的购买占用

## Why
明确取消只触发查单，PROCESSING 原单既不能结束又不能继续，会员再次购买和重启恢复被持续阻止。

## What Changes
- 明确 StoreKit userCancelled 后向服务端请求本地购买流程结束，响应是最终原单依据。
- 为历史未付款 Apple PENDING/PROCESSING 原单提供显式结束能力；Pending/错误不自动结束。
- 验证取消后再购买、恢复历史原单、未知结果和成功后再次购买。

## Impact
购买编排与原单动作规则、定向测试；保留现有页面及 StoreKit finish 和账号隔离。服务端需先发布对应修复。
