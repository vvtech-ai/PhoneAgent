# 双平台可信来电 Properties 适配

## Why
2026-10-20 用户批准适配新参数。根配置已分 android/ios 和 dev/test/pro，旧 Android 解析器读取失败；iOS 仍读取原生历史提交并合并 dev/test。源码机制已确认，未声称现场 SDK 授权故障。

## What Changes
- 两端仅使用根 local.properties 的 trustedCaller.<platform>.<environment>.appKey/appSecret。
- iOS 在 CocoaPods 准备及编译前生成私有源码，校验 APP_ENV、PHONEAGENT_IOS_ENV 与 SDK 环境；prod 对应 pro。
- 保留 Properties 语义、安全校验、业务与签名门禁、UI、SDK 版本及调用接口。

## Impact
PhoneAgent 构建/原生配置层负责凭据选择；入口为 Android 打包预检/Gradle、iOS pod install/Pod 编译。不涉及服务接口或账号/session 身份，不改变 ENTRY/MODEL/CONFIRM/THINK/RATING/HISTORY/VOICE/STOP/MEMORY 回放；DEVICE-01 的配置基础验证适用，真机及真实 SDK 授权仍需独立验收。
