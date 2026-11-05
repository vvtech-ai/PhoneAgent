## Why
设置页模型卡片绕过切换提示，套餐明细使用默认弹窗而与支付样式不一致，对话辅助按钮禁用时没有视觉反馈。用户已授权本轮修复，并包含 Java 邀约记忆规则。

## What Changes
- 模型卡片与音色入口复用同一保存结果提示。
- 套餐明细采用会员支付弹窗的白底、宽度、圆角及边距，分组使用分隔线。
- AI 忙碌期间辅助入口同时禁用和置灰，恢复可交互后恢复外观。

## Capabilities
### New Capabilities
- `model-plan-busy-feedback`: 模型切换、套餐弹窗及对话禁用视觉反馈。
### Modified Capabilities
无。

## Impact
Flutter shell 展示接线、commerce 套餐组件、conversation 输入组件及定向测试。无接口、数据库、依赖或版本修改；Java 规则记录在同名后端 change。
