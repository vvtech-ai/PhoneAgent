## Why
用户2026-10-09确认执行联系人Tab入口修正。当前Flutter先切换再读取，遗漏双端原生授权前拦截。
## What Changes
- 联系人Tab先查权限，成功才选中和刷新；取消/拒绝保留当前页。
- Android深色说明及系统拒绝可重试判断；iOS未决定说明、拒绝直接设置、有限授权允许。
- 显式设置返回重查，单飞、离开/账号/销毁迟到保护，独立权限查询不枚举联系人。
## Capabilities
### New Capabilities
- `contacts-tab-entry-parity`: 联系人Tab权限入口。
### Modified Capabilities
无。
## Impact
联系人入口协调、Shell最小接线、双端现有联系人薄通道、合成参考与定向测试。不改业务接口/依赖/发布身份，不触发真实外呼或认证。
