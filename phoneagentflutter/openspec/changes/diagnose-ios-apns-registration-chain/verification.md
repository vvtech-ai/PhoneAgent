# 验证记录（2026-10-21）

## 变更与自动验证
- 基于 codex/dev@5132667b，加工作区本次诊断差异；未切换分支、提交或推送。原生注册/driver/诊断层与 Flutter 白名单分别小批修改，测试独立；所有新增手写文件小于500行。
- RED：新增 Flutter 注册阶段导出回归因旧白名单丢弃事件失败；补全后可信来电及 core/diagnostics 共149项通过，flutter analyze --no-pub 无问题。
- 新原生连续测试执行实际 PushRegistration 源码，替身只替代 OS/SDK 与观察计时：配置缺失/不匹配、无回调有界观察、不自动重试、成功/失败回调撤销旧观察、token拒绝与成功、SDK初始化失败保留显式重试、旧consumer及退出解绑通过。此测试本身不请求真实APNs或SDK。
- 原有 Foundation incoming_diagnostics、push_binding_state、push_binding_driver 三项回归通过；Python APNs entitlement 与 SDK环境两项通过；本 change OpenSpec strict 与 diff检查通过。

## 编译、签名与设备（DEVICE-01 / ENTRY-03）
- 按项目现有版本1.0.52（45）构建 Profile/test/arm64；Xcode BUILD SUCCEEDED。Bundle ID com.chaken.phoneagent.test；最终签名完整性通过，包内与签名 APNs 均为 development。
- 用户指定数据线连接的XFeng的iPhone（iPhone15）；保留数据覆盖安装、启动并回读原生控制台。未卸载、清数据、主动认证、外呼或支付。安装前读取到既有诊断目录；加密诊断不能直接按JSON解析，未读取密钥或绕过加密，运行证据取原生安全阶段日志。
- 系统日志证明新代码实际运行，token校验成功、SDK初始化成功及绑定回调成功。有效token没有输出原文。成功回调后没有误报20秒等待；SDK bind success 不代替真实推送送达或来电展示验收。
- 构建时 CocoaPods 自动规范化 project.pbxproj，构建后仅还原本次机械差异，无工程行为改动。首次进程过滤因URL字段不支持contains失败，改用JSON读取验证，不影响App运行。

## 脱敏现场阶段
```text
2026-10-21 18:01:12.643366 TrustedIncoming stage=pushBinding code=IOS_BIND_WAIT_OWNER result=received
2026-10-21 18:01:12.643437 TrustedIncoming stage=incomingDelivery code=IOS_EVENT_CLEARED result=cancelled
2026-10-21 18:01:12.679023 TrustedIncoming stage=incomingActivity code=IOS_ACTIVITY_ENDED result=cancelled
2026-10-21 18:01:12.679314 TrustedIncoming stage=pushRegistration code=IOS_APNS_ALLOWED result=succeeded
2026-10-21 18:01:12.679336 TrustedIncoming stage=pushRegistration code=IOS_APNS_REGISTER_REQUESTED result=started
2026-10-21 18:01:12.679930 TrustedIncoming stage=pushRegistration code=IOS_APNS_REGISTER_RETURNED result=received
2026-10-21 18:01:12.725902 TrustedIncoming stage=pushBinding code=IOS_BIND_WAIT_PERMISSION result=received
2026-10-21 18:01:12.725936 TrustedIncoming stage=incomingDelivery code=IOS_EVENT_CLEARED result=cancelled
2026-10-21 18:01:12.727028 TrustedIncoming stage=pushRegistration code=IOS_APNS_ALLOWED result=succeeded
2026-10-21 18:01:12.727047 TrustedIncoming stage=pushBinding code=IOS_BIND_WAIT_TOKEN result=received
2026-10-21 18:01:12.727069 TrustedIncoming stage=pushRegistration code=IOS_APNS_REGISTER_REQUESTED result=started
2026-10-21 18:01:12.727094 TrustedIncoming stage=pushRegistration code=IOS_APNS_REGISTER_RETURNED result=received
2026-10-21 18:01:12.768598 TrustedIncoming stage=pushRegistration code=IOS_APNS_ALLOWED result=succeeded
2026-10-21 18:01:12.768648 TrustedIncoming stage=pushRegistration code=IOS_APNS_REGISTER_REQUESTED result=started
2026-10-21 18:01:12.768672 TrustedIncoming stage=pushRegistration code=IOS_APNS_REGISTER_RETURNED result=received
2026-10-21 18:01:13.104942 TrustedIncoming stage=pushRegistration code=IOS_APNS_TOKEN_CALLBACK result=received
2026-10-21 18:01:13.105010 TrustedIncoming stage=pushRegistration code=IOS_APNS_TOKEN_RECEIVED result=succeeded
2026-10-21 18:01:13.105046 TrustedIncoming stage=pushBinding code=IOS_SDK_INIT_STARTED result=started
2026-10-21 18:01:13.511731 TrustedIncoming stage=pushBinding code=IOS_SDK_INIT_SUCCEEDED result=succeeded
2026-10-21 18:01:13.511862 TrustedIncoming stage=pushBinding code=IOS_BIND_STARTED result=started
2026-10-21 18:01:13.595699 TrustedIncoming stage=pushBinding code=IOS_BIND_SUCCEEDED result=succeeded
```

## 结论与范围
本次设备运行已确认获取 APNs token 并成功绑定可信来电 SDK。旧日志18/19仅能说明权限已允许，不能据新结果断言旧现场具体根因。真实推送送达、可信来电展示、其他设备、Android画面与音频均未验；不改共享规则，不归档本change。

## 新增原生回归命令
```sh
xcrun clang -fobjc-arc -fblocks -Wno-nullability-completeness -Wno-incomplete-implementation -framework Foundation -Itool/trusted_push_registration_stubs -Iios/TrustedCallerSDK/Classes tool/trusted_caller_push_registration_test.m ios/TrustedCallerSDK/Classes/TrustedCallerPushBindingDriver.m ios/TrustedCallerSDK/Classes/TrustedCallerPushBindingState.m ios/TrustedCallerSDK/Classes/TrustedCallerIncomingDiagnostics.m -o /tmp/phoneagent-push-registration-test
/tmp/phoneagent-push-registration-test
```
