# Android Debug 诊断日志直接读取

## Why
Android Debug 的私有诊断文件仍为加密内容，ADB run-as 取出后无法直接排查。用户明确要求仅 Debug 可直接读取，测试交付继续 Release 1.0.52（45）。

## What Changes
- Android Debug 生成既有脱敏诊断的可读副本，保留加密权威档案，支持读取升级前内容。
- Release、Profile 和其他平台沿用加密存储，不增加导出目录、备份权限或 debuggable。
- 保留账号分区、轮转、上传水位与清理语义，提供 ADB 读取说明。

## Capabilities
### New Capabilities
- `android-debug-diagnostic-read`: 编译模式限定的诊断文件可读性。

## Impact
仅日志 IO 适配器、工厂接线、真实临时目录回归与文档；无业务流程、凭据、公共权限和上传接口变更。
