## Why

iOS 跟读现场仅有 sdkCapture 开始及随后重新启动的业务事件，没有故障线程和镜像信息。现有原生崩溃导入只覆盖 Android，排查依赖用户手动导出系统报告。

## What Changes

- 增加固定版本 PLCrashReporter 本地采集，不启用第三方上传；下次启动将脱敏摘要导入原有日志 ZIP。
- 保留崩溃时版本、信号、故障线程、镜像 UUID 与偏移；按崩溃时账号哈希隔离，持久化成功后才确认删除。
- 补齐边界与连续回归、符号化说明。独立评估阿里云 SDK 2.3.53，当前认证 SDK 保持 2.3.50。
- 增加原生认证生命周期、SDK 调用边界、线程与只读音频状态观察，以及独立有界存储；补充进程/构建身份、丢弃与写入失败计数。目标是下次复现取得证据，不先猜测 SDK 内部竞争并加锁。

## Capabilities

### New Capabilities
- `ios-native-crash-diagnostics`: 原生崩溃采集、恢复、脱敏及日志上传。

### Modified Capabilities

无。

## Impact

Flutter diagnostics 与 app_logs、iOS 独立本地 Pod、AppDelegate 注册。新增固定 PLCrashReporter 1.12.0 依赖；无接口、数据库、认证/克隆业务和音频状态变更。自动回放与 iOS 编译、真实崩溃验证分别记录。系统强杀、OOM、采集器初始化前和处理器被其他 SDK 替换等情形不保证可捕获。
