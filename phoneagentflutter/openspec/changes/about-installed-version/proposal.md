## Why

2026-10-09用户批准关于页动态显示当前安装App版本；读取中、失败、空值均为""，不显示失败/重试。正式双端app_info已读取安装元信息，Shell演练默认合成1.0导致与当前包不一致。

## What Changes

- 复用现有Android PackageManager与iOS Bundle通道，不新增版本常量或服务端来源。
- 关于展示trim版本，非空保留V前缀；读取中/失败/空值隐藏整个版本文字区域，不显示重试。
- Shell演练取消About合成源覆盖及专用开关，版本也读取其自身安装包；通道不可用时留空。
- OTA演练独立合成源与底部更新业务不变。

## Capabilities

### New Capabilities
- `about-installed-version`: 安装版本动态来源及静默空值展示。

### Modified Capabilities
无，覆盖既有关于顶部版本失败提示/重试行为。

## Impact

仅关于Page/Route、Shell工具入口、直接测试及文档；无原生/依赖/构建配置修改。当前pubspec.lock他任务修改不纳入。
