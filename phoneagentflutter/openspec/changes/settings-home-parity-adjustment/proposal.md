## Why

2026-10-08用户确认执行设置页调整计划：移除首页日志上报及其页面装配，仅退出入口采用指定iOS原生样式，其余有效业务按两端原生统一展示和交互，暂不添加可信来电MCP服务。

## What Changes

- 移除SettingsPage日志目标、摘要与忙态，以及SettingsRoute日志订阅和上传动作。
- 设置页退出入口采用iOS居中红字独立页尾按钮、64正常高度、24圆角及按压反馈；确认弹层和退出业务沿用已有实现。
- 核对身份、模型、原音、关于、开发者和Android更新的顺序、摘要、返回与平台显隐；小屏大字体保持可达。
- 关于页独立日志入口及底层诊断保留；可信来电MCP服务不进入本次页面或流程。
- 调整受影响的连续测试和设备阶段入口，使保留的日志功能从关于页操作。

## Capabilities

### New Capabilities
- `settings-home-parity`: 当前设置首页的有效入口、日志范围和iOS退出入口统一目标。

### Modified Capabilities
无已归档设置能力。本次用户决定优先于settings-interactions和native-ui-interaction-parity active change中要求首页日志入口的历史条目。

## Impact

主要修改features/settings的presentation及直接测试/演练调用方。无鉴权、存储、上传协议或原生权限变更；不升级工具链。其他任务正在修改的翻译文件保持独立，不混入本次提交。
