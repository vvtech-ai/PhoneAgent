## Why
可信被叫二次提醒复用空标题通用弹窗导致留白、正文灰小、按钮尺寸与旧版不符。

## What Changes
新增独立无标题提醒组件，280逻辑像素宽、20内边距、22圆角、14号深色正文与16号52高渐变按钮。主引导接入独立组件，二次提醒遮罩采用旧版18%深灰；保持关闭、返回、账号隔离和iOS原入口范围。小屏/大字可滚动，不修改通用弹窗或其他页面。

## Capabilities
### New Capabilities
- `trusted-reminder-layout`: 本次行为与验证边界。

## Impact
Flutter trusted_caller presentation；只改展示组件及宿主阶段遮罩，不改权限、SDK凭据、平台插件或服务端。
