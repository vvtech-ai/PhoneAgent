## Why
用户指出未勾选协议反馈缺少参考iOS文本变化/抖动，Toast被键盘遮挡，确认计划后于2026-10-09批准执行。
## What Changes
- 登录协议区采用原生错误样式和240ms抖动，双端共用，不新增错误说明行。
- 通用showNativeNotice按键盘/安全区避让，所有调用方受益。
## Capabilities
### New Capabilities
- agreement-feedback-toast-keyboard: 协议错误反馈和通用Toast键盘避让。
## Impact
仅登录反馈与通用Toast以及定向测试；不改认证接口，不触发真实业务，不混入正在进行的克隆改动。追加用户确认的原生白色Toast样式、96/16位置、180ms淡入淡出及可选停留时长；保持替换/穿透行为。
