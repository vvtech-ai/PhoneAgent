## Why
用户确认 iOS Debug/Profile 必须使用 com.chaken.phoneagent.test，当前主工程误设为 .demo；独立交付副本使用 .test 不能修复主工程。

## What Changes
- 将 Runner Debug/Profile 的 Bundle ID 恢复为 .test。
- 保持 Release 正式身份、扩展身份、Team、签名、服务配置与 UI 不变。

## Impact
仅主工程两行配置及必要研发记录；不构建、安装、提交或推送，不修改本地私有参数。
