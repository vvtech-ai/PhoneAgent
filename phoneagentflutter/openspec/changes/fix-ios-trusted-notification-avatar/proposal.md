## Why
用户反馈 iOS 可信来电通知显示应用图标而非身份头像。现有诊断的头像成功发生在通知点击后的应用内流程，不能代表通知扩展成功。Flutter Runner 及两份现有 1.0.52(45) IPA 缺少 NSUserActivityTypes；参考原生主应用声明 INSendMessageIntent，Flutter 扩展却已使用该 intent。

## What Changes
- 补齐主应用通讯通知 intent 声明，保持既有权限、Flutter UI 和扩展下载/回退行为。
- 增加主应用与扩展配置契约检查，防止只在扩展声明而遗漏主应用。
- 运行配置、现有策略/单次交付测试和 iOS 扩展编译。真实 APNs 头像效果独立待验，不将静态修复称为现场根因已证实。

## Impact
- capability：trusted-caller（现有能力仍由 active change 管理）。
- 仅 iOS 通讯通知配置及定向测试；不修改服务器、业务 UI、版本或签名，不触发真实来电，不提交推送。
