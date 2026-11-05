## Why
用户2026-10-28确认按附件浅色/深色说明统一三处“内容由AI生成”，固定11号字，不随系统字号缩放，并统一机型底距。
## What Changes
- 浅色#B0B4C3/100%，深色白色/34%，11sp/w400/居中/系统字体，不叠加按钮禁用透明度。
- 共用展示控件，文案不缩放，其他文字保持系统缩放。
- 键盘收起通常距安全区上沿20dp；用户2026-10-28追加确认：仅iOS原始底部安全区大于0时改为10dp，说明上方原间距增加10dp。对话键盘打开仍距键盘8dp；短屏调整上方内容，说明保持底部可见。
## Impact
PhoneAgent Flutter presentation；owner为AiContentNotice、ConversationComposer和原通话页面布局。入口为统一对话双输入模式、AI任务通话、实时翻译通话及其共用预览。无接口、账号/session/command/tool/call/attempt身份改变；保留STOP-01/VOICE-01/ENTRY-05既有业务规则。替代add-call-ai-content-notice旧灰色/70%字号及禁用透明度规则、add-conversation-ai-content-notice旧12sp样式；其余位置、完整显示和业务合同保留。不改原生/依赖/全局主题，不切分支、不提交推送、不构建安装。
