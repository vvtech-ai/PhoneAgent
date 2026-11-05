## 证据与设计
当前 codex/dev 起点 b97ff229，工作区干净。用户提供的诊断只有应用端 incomingAvatar 成功，没有 NSE 接收/转换证据；截图下方可信来电通知仍为应用图标。两份现有 IPA 的 Runner 没有 NSUserActivityTypes，扩展已声明 INSendMessageIntent，Runner 已具有 communication entitlement。

参考原生 AIAssistant/iOS/PhoneAgent/PhoneAgent/Info.plist 包含 INStartCallIntent 与 INSendMessageIntent。Apple 官方要求在应用 Info.plist 的 NSUserActivityTypes 登记支持捐赠的 intent：https://developer.apple.com/documentation/usernotifications/implementing-communication-notifications 。本次只登记现有扩展实际使用的 INSendMessageIntent，不增加未使用的 intent 或额外权限。

新增独立 Python unittest 使用 plistlib 读取真实配置，检查主应用 intent、communication entitlement、扩展入口和 intent。测试只检查通讯通知必要接线，不匹配源码字符串。先验证遗漏失败，再修复通过。

## 边界与验收
不改变通知数据契约、认证结果、头像下载安全限制、5秒期限或原通知回退。不把配置遗漏认定为唯一现场原因；实际 mutable-content、NSE 日志、图片响应与 iOS 展示仍须新安装包及用户触发推送验证。现有导出 IPA 不会因源码修改自动改变。
