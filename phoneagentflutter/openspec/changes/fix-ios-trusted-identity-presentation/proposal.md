## Why
用户确认：iOS停留在可信来电MCP服务页面时收到来电，需在SDK页面上方显示Flutter身份详情，SDK页面不关闭、不重建。当前Flutter根Navigator被UIKit全屏SDK页面遮挡。
## What Changes
- 增加仅iOS启用的身份详情展示协调和独立Flutter展示引擎。
- 复用现有身份页、样式和资源，仅传递现有安全展示快照，不重复SDK初始化、账号绑定或验签。
- 同步更新/关闭/账号失效，区分路由创建和实际展示。
## Impact
仅trusted_caller展示适配、主入口及iOS薄桥；Android和普通Flutter来电展示保持。不得关闭SDK实现绕行。真实来电与设备验收单独授权；本侧不切分支、不提交推送、不安装。
