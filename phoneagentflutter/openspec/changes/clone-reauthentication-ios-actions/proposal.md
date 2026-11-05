## Why
用户2026-10-09截图要求“重新认证并克隆音色？”弹窗下方两个按钮采用iOS风格，并确认执行。现有共用Material确认框右对齐动作不符。

## What Changes
- 仅此弹窗改为左取消/右继续、等宽居中系统蓝、细分隔线、Cupertino按压反馈。
- 保持现有标题、正文、弹窗尺寸/背景/形状、遮罩与取消/继续业务；允许大字换行增高。
- 不改其他确认弹窗、模型选择面板、认证/计费/平台能力或依赖。

## Capabilities
### New Capabilities
- `clone-reauthentication-ios-actions`: 单个重新认证确认弹窗的共用iOS按钮展示。
### Modified Capabilities
无。

## Impact
voice_clone展示层、直接回归测试及记录。共享工作区账号设置与pubspec.lock改动不纳入；不进行真实身份采集、上传或收费。
