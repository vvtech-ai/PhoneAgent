# iOS 中断支付恢复业务码诊断

## Why
重启后发现交易且后台找到原单，但诊断只显示 rejected，丢失拒绝业务码。

## What Changes
- 封闭诊断模型保留 Apple 恢复相关白名单 businessCode，未知原文丢弃。
- 支付状态、恢复、finish 与 UI 不改变；配合后台兼容修复部署及用户授权覆盖安装。

## Impact
仅诊断字段；Android/支付宝业务不变。
