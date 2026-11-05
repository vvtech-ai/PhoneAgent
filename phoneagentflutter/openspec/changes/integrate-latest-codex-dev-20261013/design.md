# 集成设计
先提交已验证的语音修复，再 fetch origin/codex/dev，采用三方 no-ff 合并。此次远端未改语音源文件、Podfile/lock 或 pubspec，交叉处主要为根任务与问题记录，冲突保留双方完整章节。对本地 Podfile/lock 记录哈希与补丁，合并后确认不变。

新增远端涉及翻译、录音、拨号、任务卡片、开发者设置、诊断及 iOS SDK；运行相应模块定向测试和语音直接调用方、analyze、可信 SDK 验证与 iOS 编译，不重复无关全量回归。既有 OpenSpec 3 个无关规范错误单独记录。验证完成后写合并提交并 push codex/dev，以远端 ref 和双方祖先确认回执。

集成测试发现 translation_access_test 仍将已有可信位置的刷新视为首次定位，已与 align-native-trusted-location-refresh 批准行为核对。仅更新该测试，保持没有可信位置时不可拨打，并验证已可信 resolved/refreshing 期间可用；产品代码不另改。独立复审认可该断言修正。
