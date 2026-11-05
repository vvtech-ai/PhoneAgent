## Context
用户2026-10-12确认执行。只读Android AIAssistant1 HEAD a0bedb12a，FinalSettingsHomePage.kt SettingsLogoutAction：24圆角、80%白底、78%白边、10阴影、底距10、横/纵内距16；左FFFF3B30/16sp/Bold，右8A8F99/13sp脱敏手机号。覆盖settings-home-parity-adjustment历史iOS入口目标，仅限退出入口。

## Decisions
- 两平台使用同一Android目标，不保留居中/64固定最小高度/0.99缩放/淡红按压。
- Material InkWell常规水波反馈；按钮触摸区至少48，大字允许增高，窄屏必要时手机号移到下一行避免重叠。
- Route读取当前Session并仅传maskedPhone到Page及按钮；无会话显示未登录，不添加存储或网络读取。
- 原确认弹窗、取消、失败重试和signOut调用不变；不复制原生设备专用整页底部留白。

## Validation
Flutter3.32 analyze、设置页/确认/语义/导航定向测试、普通/两倍字体窄屏布局、OpenSpec及diff。无平台修改不重打包；设备像素验收待用户确认。
