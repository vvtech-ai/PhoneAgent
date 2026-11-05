## Context
参考 aiassistant_app 8f23592 及 AIAssistant1 邀请错误映射。现有 align-current-server-contracts 禁止按输入格式猜测来源；本变更保持此规则，扩展 MANUAL 提交的稳定身份。现有 migrate-v67-invite-records-ledger 的记录入口与账本事实保持。

## Decisions
- AuthController 在实际邀请码提交时调用 PendingInviteController.begin；键包含手机号、码、真实来源。既有 REFERRAL 键兼容，MANUAL 来源不改为 REFERRAL。短信与 challenge 不持久化。
- 本地后端可信 classify 可把手工码分流到 referral，register 强制请求号；SmsReferralReplayStore 仅缓存显式 REFERRAL，手工注册丢响应后的认证重放仍需服务端确认，不修改后端、不声称完全闭环。
- me/code DTO 与 Controller 双层拒绝缺活动快照；完整新周期响应可替换旧活动，不能拼接。
- 刷新开始清旧 overview/code，失败不恢复旧分享；loading/acting 时合并刷新，操作结束后执行。延后刷新不等待非关键统计请求。所有异步保留 mounted/generation 保护。
- 活动提示独立纯 Dart 映射，注册 InviteFailure 提示按 AIAssistant1；欢迎页独立平台策略保持不变。无需改 Flutter 布局或平台链接地址。

## Validation
固定 Flutter3.32.0/Dart3.8.0；每个源码微批≤3文件，测试批独立。analyze、邀请/auth 直接调用方定向测试、双主题入口/欢迎/海报/奖励回归；未改平台/插件/依赖，不重复打双端包。真实系统唤起、相册和服务注册仍待设备及明确授权。
