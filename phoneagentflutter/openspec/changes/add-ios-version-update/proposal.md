## Why
用户确认补齐 iOS 版本检测和 App Store 更新入口，自动检查时机与 Flutter Android 一致。当前服务器已用 sourceType 支持双平台，Flutter 仍仅装配 Android。

## What Changes
- 登录成功或恢复登录后检查；未登录不检查。普通检查成功按本地日期节流，强更记录不受当天限制；失败不写成功日期，不新增定时重试。
- iOS 关于页提供手动检查，复用现有 Flutter 列表、更新弹窗、按钮及提示。
- iOS 请求 sourceType=1，Android 显式 sourceType=0，继续原 SDK 路由及 v2 签名。
- iOS 使用 iosSourceUrl，空值使用 https://apps.apple.com/app/id6813455647；通过系统打开，不进入 Android 安装链。
- 强更返回前台重查；打开失败或重查失败不解除已显示的强更。

## Impact
涉及 app_update 数据、Provider、更新弹窗装配、关于页和 iOS 链接适配；不修改服务器、Android 安装流程、应用版本和工具链。不提交推送或安装，避免干扰共享工作区主任务。
