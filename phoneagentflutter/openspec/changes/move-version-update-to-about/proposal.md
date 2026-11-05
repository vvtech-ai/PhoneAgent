## Why

2026-10-09用户确认执行：将版本更新入口及业务从设置首页移到关于PhoneAgent最后一项。无需副标题或右侧版本号，但保留必要状态文本。

## What Changes

- 首页移除更新目标、参数、Provider订阅和动作。
- 关于页末项复用NativeSettingCard，无副标题，右侧默认空，仅进行中显示检测中，无版本号。
- Android显式检查保持单次、结果提示和共享更新弹层/安装交接；iOS隐藏OTA。
- 既有Web隔离演练迁到关于页末项，明确MOCK且不调用正式端口。

## Capabilities

### New Capabilities
- `about-version-update`: 关于页手动更新入口位置、样式与平台业务装配。

### Modified Capabilities
无；本次位置决策覆盖active settings-home-parity和settings-interactions历史首页更新位置，既有更新安全契约不变。

## Impact

仅settings展示/路由、直接调用方、测试和规格记录。无平台配置、依赖、后端或安装协议变更；其他任务修改保留。
