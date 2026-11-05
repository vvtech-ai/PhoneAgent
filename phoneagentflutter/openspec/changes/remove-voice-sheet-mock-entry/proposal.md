## Why
用户2026-10-10反馈Flutter Android正式音色弹层出现“创建克隆交互演练（MOCK）”。CallVoicesPage直接引用默认Debug开启的演练开关和演练页面，造成正常业务UI混入测试入口。

## What Changes
- 移除正常音色页演练按钮、开关和页面跳转依赖，不以改文案或仅Release隐藏掩盖。
- 保留真实声音克隆、系统/克隆音色选择和试听；演练场景仍在独立tool工作台。
- 添加双平台正常/2x入口回归，默认及显式开启演练开关时均不得显示。

## Capabilities
### New Capabilities
- `voice-sheet-production-entry`: 正常音色页与独立演练入口隔离。
### Modified Capabilities
无。

## Impact
CallVoicesPage及定向测试，不改音频/认证/计费/平台或依赖。当前可信来电工作区变更和pubspec.lock保留，不混入提交。
