## Why
2026-10-19 用户确认检查并修复 prod/test/dev 的 iOS 邀请配置。已检查的测试 IPA 将网页域名重复签入，缺少按钮实际目标 phoneagent-ioslink.vvtech.tech；工程 Debug/Profile 的权限文件为空，仅检查工程变量不足以交付。

## What Changes
- 三环境显式配置邀请域名，在构建前检查 Dart APP_ENV、Xcode 环境、Bundle ID、Scheme 和权限模板一致性。
- 修复开发权限文件；原生与 Dart 同时接收当前环境网页链接，兼容既有 agent.vvtech.tech。
- 增加最终签名 App/IPA 检查，验证权限、签名 App ID 和描述文件授权，失败返回非零。
- 检查线上下载配置与 AASA，记录共享身份/域名边界，不修改服务器、不新增 Bundle ID。

## Capabilities
### Modified Capabilities
- invite: 三环境 iOS 邀请构建与成包验证。

## Impact
仅修改本仓库配置、邀请接收策略、工具及研发记录；UI 不变。不切分支、提交推送、打包安装或执行真实注册。打包版本与安装授权另行确认。
