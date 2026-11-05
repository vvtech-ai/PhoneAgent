## Why
用户确认 Android 实时翻译位置权限弹窗时机、内容和系统接线对齐 aiassistant_app 8f23592，保留 Flutter UI 风格与 iOS 行为。
## What Changes
- 区分首次未申请与系统禁止再次申请，统一读取两个历史位置申请记录。
- 首次说明与主动翻译开关按原生分流；重复进入不重复说明。
- Android 授权前关闭业务弹窗；设置返回自动只读复查，移除额外返回确认框。
- 国家选择页位置卡片在不能申请时直接打开设置，返回授权后自动定位。
## Impact
Android 权限/定位适配与 Flutter dialer/controller/host、位置 controller/host/provider；不改变共用弹窗样式、iOS、其他权限、计费和通话流程。不安装、真实外呼、提交推送；Debug 编译仅验证平台源码。
