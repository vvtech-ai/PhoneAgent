# 保留 iOS 通讯通知权限

## Why
用户要求补充 com.apple.developer.usernotifications.communication。Debug/Profile 模板缺该项；Release 模板已有但手工签名白名单未复制，因此既有两份 IPA 主包签名均缺失，主包 profile 已授权。

## What Changes
- Debug/Profile 主包 entitlement 补 true，Release 保持已有声明。
- 主包 profile 选择、签名生成与最终签名验收校验并保留该权限；profile 未授权则失败，不伪造扩展权限。
- 定向回归及 test/Profile 真实签名产物验证，保护已有 SDK/APNs、账号/Token/绑定规则与 UI。

## Impact
PhoneAgent iOS 构建/签名 owner；入口为构建和成包验收，身份为主包及其原 profile/Team。两个 extension 的现有 ID、权限与接线不变，NSE 继续执行头像装饰。相关 DEVICE-01 和通知扩展回归；不修改共享任务编排规则、云配置或凭据，不自动提交推送。
