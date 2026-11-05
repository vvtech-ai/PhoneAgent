## Context
指定Android AssistantRealtimeCallVoiceSelectionRow的Surface38/CircleShape包含播放反馈，F2F7FF背景与19图标；iOS AISettingsRealtimeCallVoiceViewController.m的preview38/圆角19/中心图标。两端源码只读。

## Decisions
1. 保留Flutter48热区及38靠右视觉位置，不移动行尾布局；反馈改在38局部Material/圆形clip内，去除外部48灰色ink。外层热区继续触发同一动作，禁用时吸收点击防止落到行选择。
2. 按压/焦点/悬停统一蓝色低透明反馈，保留loading/playing与onPreview状态契约。取消自动恢复；布局不依赖业务状态。
3. 仅音色行共用控件修复，翻译录音播放按钮已有独立同心结构，避免无依据跨模块更改。
4. 源码批最多3文件，文档与格式化独立；当前分支沿用，不切换、不纳入pubspec.lock。

## Validation
先以像素回归复现灰圈，检查实际绘制圆外白色不变和内部反馈；正常/按下/释放/取消/loading/playing/disabled、热区边缘和行选择独立、短屏2x滚动。flutter analyze、call_models/直接clone及Shell定向，不执行全量。独立双平台UI合成状态参考不注册媒体、不上传或认证，不替换普通App；源码、离屏和设备证据分别记录。
