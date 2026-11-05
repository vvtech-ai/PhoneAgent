# 对齐会员积分与订单展示

## Why
用户要求按 codex/phone-agent-monetization-linkage-20260814 Demo 恢复余额说明、订单列表说明和邮箱联系文案，并复核相关 UI。

## What Changes
- 会员余额卡复用真实费率和今日赠送到账数据，恢复通话分钟数提示。
- 有订单时恢复左右滑动说明，类型与渠道使用订单历史事实。
- 购买区统一邮箱文案，删除重复泛化售后入口；校正支付按钮和表头。

## Capabilities
### Modified Capabilities
- membership-commerce：商品、钱包和订单展示。

## Impact
Flutter presentation 与回归测试；支付状态、金额、权益、接口、数据库及声音克隆业务不变。
