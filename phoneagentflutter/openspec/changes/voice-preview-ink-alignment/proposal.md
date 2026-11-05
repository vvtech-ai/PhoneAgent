## Why
用户2026-10-10截图指出所有音色试听按钮按压出现偏左灰圈，批准计划后执行。共用NativeVoiceSelectionRow以48热区InkWell包38靠右背景，反馈中心偏左5且绘制在外层Material。

## What Changes
- 48热区保留，38可见圆形以自身Material裁剪承载反馈，蓝色反馈与背景/图标同心。
- 系统/克隆共同修复；加载、停止、禁用、取消、快速点击和滚动状态验证。
- 不改变音频端口、选择、确认、计费或其他录音按钮。

## Capabilities
### New Capabilities
- `voice-preview-ink-alignment`: 音色试听圆形反馈边界。
### Modified Capabilities
无。

## Impact
音色选择行、直接测试及独立演练工具。pubspec.lock已有外部差异，不改或提交。固定Flutter3.32/Dart3.8。真实音频与真机验收独立。
