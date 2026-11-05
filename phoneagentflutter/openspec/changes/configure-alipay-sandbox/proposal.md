# 支付宝 Android 沙箱环境选择

## Why
后端已按可信渠道配置生成支付宝沙箱支付材料，但 Android 15.8.42 SDK 默认使用 ONLINE。当前桥未接收环境，不能仅靠后端网关选择保证客户端进入沙箱。

## What Changes
- 使用服务端支付材料 `parameters.environment`，严格接受 SANDBOX 或 PRODUCTION。
- 将环境选择和 SDK 设置封装为小策略，在原生 payV2 前明确切换。
- 缺失或未知环境拒绝启动，不从 APP_ENV、签名串或 UI 猜测。
- 保留服务端原单查单与未知支付结果语义。

## Impact
- 仅 Android 支付桥、环境策略和针对性测试；共享 Flutter 已原样透传 parameters。
- 不变更 SDK 版本、渠道凭据、iOS、支付金额或到账判断，不安装设备或执行真实支付。
