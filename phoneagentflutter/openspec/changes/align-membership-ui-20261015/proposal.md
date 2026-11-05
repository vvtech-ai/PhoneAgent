# 会员购买界面对齐

## Why
用户要求Flutter会员权益、积分包、订单与购买界面对齐指定Demo最新分支及两张截图。当前空订单缺表头、会员摘要与权益层级及购买确认样式不一致。

## What Changes
- 固定参考luojie/aiassistant phoneagent-membership-ui-20261015 d82d363fc66d6cd6a486b360540d6936f91e0e06。
- 空订单保留六列表头和居中暂无更多数据；会员摘要置于余额下方。
- 对齐权益卡、周期卡、积分购买说明、协议位置及购买确认展示。
- 仅Flutter展示与必要接线，真实价格/权益/渠道及开票邮件规则保持服务端权威。

## Impact
commerce presentation与对应widget/route测试；不涉及Java、Web、数据库、SIP、ASR或TTS。
