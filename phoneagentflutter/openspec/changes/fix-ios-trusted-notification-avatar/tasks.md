## 实施
- [x] 1 核对诊断、截图、当前配置、参考原生与现有 IPA，确认主应用 intent 声明缺口。
- [x] 2 OpenSpec 全仓184项通过；新增3项配置回归，旧配置仅主应用 intent 检查失败。
- [x] 3 补齐 Runner INSendMessageIntent 声明；3项配置测试、plist lint、Swift 策略与100次并发单次交付断言通过。
- [x] 4 Xcode26.3下通知扩展 Debug/iphoneos 无签名编译通过；diff 校验通过，根任务和问题记录更新。
- [ ] 5 新包在真实 APNs 触发下核验通知头像、缺图及超时回退；未验收不归档。

验证命令：`python3 -B tool/trusted_notification_configuration_test.py`；`plutil -lint ios/Runner/Info.plist`；`xcrun swiftc ios/TrustedCallerNotificationService/TrustedNotificationPolicy.swift ios/TrustedCallerNotificationService/TrustedNotificationCompletion.swift tool/trusted_notification_policy_test.swift -o <临时目录>/policy-test` 后运行；`xcodebuild -project ios/Runner.xcodeproj -target TrustedCallerNotificationService -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO CONFIGURATION_BUILD_DIR=/tmp/phoneagent-nse-avatar-build build -quiet`；`openspec validate --all`；`git diff --check`。

本轮只改平台 plist 与 Python 配置测试，不改 Dart，不重复 Flutter 全量测试/analyze 或 Android 构建。未执行真实网络下载/Intents donation/推送，没有签名导出新 IPA 或安装，不能将扩展编译与策略断言当作系统通知显示验收。没有新增日志代替修复，没有修改版本、服务端、业务 UI。用户随后授权本项提交推送codex/dev。

后续应用图标核对：源码通知/桌面图标均为声波；设备同时存在旧Aiphone Test及PhoneAgent test。实际推送目标与APNs绑定/缓存待核实，不能将intent声明修复说成应用图标来源错误已解决。
