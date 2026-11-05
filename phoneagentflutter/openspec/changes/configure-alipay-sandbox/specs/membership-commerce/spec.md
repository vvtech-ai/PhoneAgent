## ADDED Requirements

### Requirement: Android 支付环境必须来自可信材料
Android 支付桥 SHALL 仅从后端支付材料 parameters.environment 接受严格 SANDBOX 或 PRODUCTION，并在 payV2 前分别设置 SDK SANDBOX 或 ONLINE。缺失或未知环境 SHALL 拒绝启动，不依据 APP_ENV、签名串或用户选项猜测。SDK 返回仍 SHALL 只触发服务端原订单查询。

#### Scenario: 沙箱支付材料
- **WHEN** 服务端返回 environment 为 SANDBOX 的支付宝支付材料
- **THEN** 原生 SDK 在调用 payV2 前进入 SANDBOX，客户端不生成到账事实

#### Scenario: 沙箱调用后收到生产材料
- **WHEN** 同一进程后续收到 environment 为 PRODUCTION 的材料
- **THEN** 明确设置 ONLINE 后再调用支付，不沿用上一次 SDK 全局环境

#### Scenario: 缺失或未知环境
- **WHEN** 支付材料未包含 environment 或值不严格匹配允许值
- **THEN** 不调用支付 SDK，保留服务端原订单查询和明确错误语义
